#!/usr/bin/env python3
# lucid's updater: fetches a release (or a beta build) and runs that release's
# own install.sh in a pty, outside the shell, so a reload or a restart of the
# shell can't take it down halfway. --src runs a tree already on disk instead,
# for the graphical installer (installer.qml).
#
# the shell follows <dir>/events.jsonl (one json object a line) and answers on
# <dir>/answers, a fifo. the password goes into sudo once and is never kept.

import argparse
import codecs
import errno
import fcntl
import json
import math
import os
import pty
import re
import select
import shutil
import signal
import struct
import tarfile
import termios
import threading
import time
import urllib.request
from collections import deque

# csi, osc, charset picks and keypad modes, then any stray control but \t \n \r
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[()][0-9A-Za-z]|\x1b[=>78]|[\x00-\x08\x0b\x0c\x0e-\x1a\x1c-\x1f\x7f]")
PASSWORD = re.compile(r"(?i)(password|passphrase)[^\n]{0,80}:\s*$")
YESNO = re.compile(r"[\[(]\s*([Yy])\s*/\s*([Nn])\s*[\])]\s*[:?]?\s*$")
TEXTISH = re.compile(r"[:?>]\s*$")
# the shell asks about the restart itself; older installers still ask too
RESTART = re.compile(r"Restart it now\?")
STEP = re.compile(r'^\s*step "([^"$]+)"', re.M)

# the pty's first job: sudo once, keep it warm, then wait for the unpacked tree
WRAPPER = r"""
command -v sudo >/dev/null 2>&1 || exit 96
sudo -v -p '[lucid] password for %u: ' || exit 97
printf '@@lucid:authok\n'
( while sleep 50; do sudo -n -v 2>/dev/null || exit 0; done ) &
keep=$!
trap 'kill "$keep" 2>/dev/null; sudo -k 2>/dev/null' EXIT
stty -echo 2>/dev/null
IFS= read -r src || exit 98
stty echo 2>/dev/null
[ -f "$src/install.sh" ] || exit 98
cd "$src" || exit 98
bash ./install.sh "$@"
"""


def collapse(line):
    # a carriage return redraws the line, so only its last drawing counts
    line = line.rstrip("\r")
    if "\r" in line:
        segs = [s for s in line.split("\r") if s.strip()]
        line = segs[-1] if segs else ""
    return line


class Events:
    def __init__(self, path):
        self.lock = threading.Lock()
        self.f = open(path, "a", buffering=1, encoding="utf-8")

    def emit(self, e, **kw):
        kw["e"] = e
        kw["t"] = int(time.time() * 1000)
        with self.lock:
            self.f.write(json.dumps(kw, ensure_ascii=False) + "\n")


class Runner:
    def __init__(self, a):
        self.a = a
        self.dir = a.dir
        self.ev = Events(os.path.join(self.dir, "events.jsonl"))
        self.log = open(os.path.join(self.dir, "install.log"), "a", buffering=1, encoding="utf-8")
        self.decoder = codecs.getincrementaldecoder("utf-8")("replace")
        self.carry = ""
        self.partial = ""
        self.live_sent = ""
        self.live_at = 0.0
        self.last_out = time.monotonic()
        self.recent = deque(maxlen=8)
        self.ask = None
        self.asked_for = None
        self.seq = 0
        self.answers = b""
        self.phase = "auth"
        self.progress = 0.0
        self.authok = False
        self.steps = []
        self.step_of = 0
        self.step_n = 0
        self.worker = None
        self.result = None
        self.src = ""
        self.sent_src = False
        self.cancelled = False
        self.kill_at = 0.0
        self.child_exit = None
        self.backup = ""
        self.timed_out = False
        self.version = ""
        self.sha = a.sha
        self.hypr_kept = False

    # --- the pty ---------------------------------------------------------

    def spawn(self):
        pid, fd = pty.fork()
        if pid == 0:
            env = dict(os.environ)
            env.update({
                "LUCID_UPDATER": "1",
                "TERM": "dumb",
                "PAGER": "cat",
                "SYSTEMD_PAGER": "",
                "GIT_PAGER": "cat",
            })
            os.chdir(self.dir)
            os.execvpe("bash", ["bash", "-c", WRAPPER, "lucid-update"] + self.a.install_args, env)
        self.pid = pid
        self.fd = fd
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 50, 132, 0, 0))

    def send(self, text):
        try:
            os.write(self.fd, text.encode())
        except OSError:
            pass

    # --- output ----------------------------------------------------------

    def feed(self, text):
        self.last_out = time.monotonic()
        # anything new means a question on screen was not the last word
        if self.ask is not None:
            self.ev.emit("unask", n=self.ask["n"])
            self.ask = None
        self.asked_for = None
        s = self.carry + text
        k = s.rfind("\x1b")
        if k != -1 and len(s) - k < 32 and not ANSI.match(s, k):
            self.carry = s[k:]
            s = s[:k]
        else:
            self.carry = ""
        self.take(ANSI.sub("", s))

    def take(self, s):
        parts = s.split("\n")
        parts[0] = self.partial + parts[0]
        for line in parts[:-1]:
            self.line(collapse(line))
        tail = parts[-1]
        # keep the partial short: only its last drawing matters
        if "\r" in tail.rstrip("\r"):
            ended = tail.endswith("\r")
            tail = collapse(tail) + ("\r" if ended else "")
        self.partial = tail

    def line(self, text):
        if text.strip() == "@@lucid:authok":
            self.on_authok()
            return
        # install.sh left Hyprland's config alone, so nothing starts the shell at login
        if text.strip() == "@@lucid:hypr-kept":
            self.hypr_kept = True
            return
        self.log.write(text + "\n")
        self.recent.append(text)
        m = re.search(r"moving it to (\S+quickshell\.backup-\S+)", text)
        if m:
            self.backup = m.group(1)
        if "timed out reading password" in text:
            self.timed_out = True
        head = text.strip()
        if head.startswith("==> ") and head[4:].strip() in self.steps:
            self.step_n += 1
            name = head[4:].strip()
            total = max(1, self.step_of)
            self.set_progress(0.16 + 0.82 * min(self.step_n - 1, total) / total)
            self.ev.emit("step", text=name, n=self.step_n, of=total, p=self.progress)
        self.ev.emit("line", text=text)

    def set_progress(self, p):
        self.progress = max(self.progress, min(1.0, p))

    def phase_to(self, phase, text, known=True):
        self.phase = phase
        self.ev.emit("phase", phase=phase, text=text, p=self.progress, known=known)

    # --- questions -------------------------------------------------------

    def tick(self):
        now = time.monotonic()
        idle = now - self.last_out
        if self.carry and idle > 0.3:
            c = self.carry
            self.carry = ""
            self.take(ANSI.sub("", c))
        shown = collapse(self.partial)
        if shown != self.live_sent and now - self.live_at > 0.2:
            self.live_sent = shown
            self.live_at = now
            self.ev.emit("live", text=shown)
        if self.ask is None and shown.strip() and idle > 0.15 and shown != self.asked_for:
            self.classify(shown, idle)
        # the download finished: hand the tree to the waiting wrapper
        if self.result is not None and not self.sent_src and not self.cancelled:
            self.sent_src = True
            if self.result.get("ok"):
                self.set_progress(0.16)
                self.phase_to("install", "Installing")
                self.send(self.src + "\n")
            else:
                self.stop()
        if self.kill_at and now > self.kill_at:
            self.kill_at = 0.0
            try:
                os.killpg(self.pid, signal.SIGKILL)
            except OSError:
                pass

    def classify(self, shown, idle):
        if RESTART.search(shown):
            self.asked_for = shown
            self.send("n\n")
            return
        kind = None
        default = ""
        m = YESNO.search(shown)
        if PASSWORD.search(shown):
            kind = "password"
        elif m:
            kind = "yesno"
            if m.group(1) == "Y" and m.group(2) == "n":
                default = "y"
            elif m.group(1) == "y" and m.group(2) == "N":
                default = "n"
        elif idle > 2.5 and TEXTISH.search(shown):
            kind = "text"
        if kind is None:
            return
        self.asked_for = shown
        self.seq += 1
        retry = kind == "password" and any("try again" in l.lower() for l in list(self.recent)[-2:])
        context = [l for l in list(self.recent)[-5:] if l.strip() and not l.strip().startswith("==>")]
        self.ask = {"n": self.seq, "kind": kind, "text": shown.strip(), "def": default, "retry": retry, "context": context[-4:], "auth": not self.authok}
        self.ev.emit("ask", **self.ask)

    def read_answers(self, ffd):
        try:
            chunk = os.read(ffd, 65536)
        except BlockingIOError:
            return
        self.answers += chunk
        while b"\n" in self.answers:
            raw, self.answers = self.answers.split(b"\n", 1)
            try:
                msg = json.loads(raw.decode("utf-8", "replace"))
            except ValueError:
                continue
            if msg.get("cancel"):
                self.cancel()
            elif self.ask is not None and msg.get("n") == self.ask["n"]:
                value = str(msg.get("value", "")).replace("\n", " ")
                kind = self.ask["kind"]
                self.send(value + "\n")
                self.ev.emit("answered", n=self.ask["n"])
                self.ask = None
                # an answer is not echoed by a password prompt, so log the fact
                if kind == "password":
                    self.log.write("(password sent)\n")

    # --- the release itself ----------------------------------------------

    def on_authok(self):
        if self.authok:
            return
        self.authok = True
        self.ev.emit("authok")
        self.set_progress(0.02)
        if self.a.src:
            try:
                self.prepare(os.path.abspath(self.a.src))
            except Exception as e:
                self.result = {"ok": False, "reason": "unpack", "text": "This folder has no usable installer: " + str(e)}
            return
        self.phase_to("download", "Downloading " + self.a.label, known=False)
        self.worker = threading.Thread(target=self.fetch, daemon=True)
        self.worker.start()

    def fetch(self):
        tarpath = os.path.join(self.dir, "release.tar.gz")
        dest = os.path.join(self.dir, "src")
        try:
            req = urllib.request.Request(self.a.url, headers={"User-Agent": "lucid-updater"})
            got = 0
            sent = 0.0
            with urllib.request.urlopen(req, timeout=30) as r, open(tarpath, "wb") as out:
                total = int(r.headers.get("Content-Length") or 0)
                while True:
                    if self.cancelled:
                        raise InterruptedError()
                    buf = r.read(262144)
                    if not buf:
                        break
                    out.write(buf)
                    got += len(buf)
                    now = time.monotonic()
                    if now - sent > 0.25:
                        sent = now
                        # github sends no size for archives, so ease towards the end
                        frac = got / total if total else 1 - math.exp(-got / 60e6)
                        self.set_progress(0.02 + 0.10 * frac)
                        self.ev.emit("bytes", n=got, of=total, p=self.progress)
            self.ev.emit("bytes", n=got, of=total, p=self.progress)
        except InterruptedError:
            self.result = {"ok": False, "reason": "cancelled"}
            return
        except Exception as e:
            self.result = {"ok": False, "reason": "download", "text": "The download failed: " + str(e)}
            return
        try:
            self.set_progress(0.12)
            self.phase_to("unpack", "Unpacking")
            if os.path.isdir(dest):
                shutil.rmtree(dest)
            os.makedirs(dest)
            # member by member, so a stop lands between files
            with tarfile.open(tarpath, "r:*") as t:
                for m in t:
                    if self.cancelled:
                        raise InterruptedError()
                    t.extract(m, dest, filter="data")
                # github's archives carry their commit in the pax header
                sha = str(t.pax_headers.get("comment", ""))
            if re.fullmatch(r"[0-9a-f]{40}", sha):
                self.sha = sha
            tops = [d for d in os.listdir(dest) if os.path.isdir(os.path.join(dest, d))]
            if len(tops) != 1:
                raise ValueError("the archive has no single top folder")
            os.unlink(tarpath)
            self.prepare(os.path.join(dest, tops[0]))
        except InterruptedError:
            self.result = {"ok": False, "reason": "cancelled"}
        except Exception as e:
            self.result = {"ok": False, "reason": "unpack", "text": "The download could not be unpacked: " + str(e)}

    # the tree the wrapper is handed: its steps give the bar its stages
    def prepare(self, src):
        for need in ("install.sh", "shell.qml"):
            if not os.path.isfile(os.path.join(src, need)):
                raise ValueError("there is no " + need)
        with open(os.path.join(src, "install.sh"), encoding="utf-8", errors="replace") as f:
            titles = STEP.findall(f.read())
        self.steps = set(titles)
        self.step_of = len([t for t in titles if not t.startswith("Skipping")])
        version = ""
        vf = os.path.join(src, "VERSION")
        if os.path.isfile(vf):
            with open(vf, encoding="utf-8") as f:
                version = f.read().strip()
        self.version = version
        self.src = src
        self.result = {"ok": True}

    # --- stopping --------------------------------------------------------

    def cancel(self):
        if self.cancelled:
            return
        self.cancelled = True
        self.ev.emit("phase", phase="stopping", text="Stopping", p=self.progress, known=False)
        self.stop()

    def stop(self):
        try:
            os.killpg(self.pid, signal.SIGTERM)
        except OSError:
            pass
        self.kill_at = time.monotonic() + 4

    def loop(self, ffd):
        exited_at = 0.0
        while True:
            try:
                r, _, _ = select.select([self.fd, ffd], [], [], 0.1)
            except InterruptedError:
                r = []
            if self.fd in r:
                try:
                    data = os.read(self.fd, 65536)
                except OSError as e:
                    if e.errno != errno.EIO:
                        raise
                    data = b""
                if not data:
                    break
                self.feed(self.decoder.decode(data))
            if ffd in r:
                self.read_answers(ffd)
            self.tick()
            # something the installer started may hold the pty open after it is gone
            if self.child_exit is None:
                done, status = os.waitpid(self.pid, os.WNOHANG)
                if done:
                    self.child_exit = os.waitstatus_to_exitcode(status)
                    exited_at = time.monotonic()
            elif time.monotonic() - exited_at > 1.5:
                break
        self.take(ANSI.sub("", self.carry + self.decoder.decode(b"", final=True)) + "\n")
        if self.child_exit is None:
            _, status = os.waitpid(self.pid, 0)
            self.child_exit = os.waitstatus_to_exitcode(status)
        return self.child_exit

    def finish(self, code):
        last = [l.strip() for l in self.recent if l.strip()]
        errs = [l for l in last if re.search(r"(?i)\berror\b|failed|not found", l)]
        out = {"code": code, "backup": self.backup, "version": self.version, "hyprKept": self.hypr_kept}
        if self.cancelled:
            out.update(ok=False, reason="cancelled", text="The install was stopped." if self.a.src else "The update was stopped.")
        elif self.result is not None and not self.result.get("ok"):
            out.update(ok=False, reason=self.result.get("reason", "download"), text=self.result.get("text", ""))
        elif code == 96:
            out.update(ok=False, reason="nosudo", text="sudo is not installed, and the installer needs it.")
        elif code == 97:
            reason = "timeout" if self.timed_out else "password"
            text = "No password was given in time." if self.timed_out else "The password was not accepted."
            out.update(ok=False, reason=reason, text=text)
        elif code == 98:
            out.update(ok=False, reason="unpack", text="The downloaded release has no installer.")
        elif code == 0:
            out.update(ok=True, reason="", text="")
            self.record()
        else:
            out.update(ok=False, reason="install", text=(errs or last or ["The installer stopped with code %d." % code])[-1])
        self.ev.emit("done", **out)

    def record(self):
        path = os.path.join(os.path.dirname(self.dir), "installed.json")
        data = {"channel": self.a.channel, "ref": self.a.ref, "sha": self.sha, "version": self.version, "at": int(time.time() * 1000)}
        tmp = path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f)
        os.replace(tmp, path)

    def tidy(self):
        shutil.rmtree(os.path.join(self.dir, "src"), ignore_errors=True)
        for name in ("release.tar.gz", "answers"):
            try:
                os.unlink(os.path.join(self.dir, name))
            except OSError:
                pass
        # the last few runs keep their logs, older ones go
        base = os.path.dirname(self.dir)
        runs = sorted(d for d in os.listdir(base) if d.startswith("run-") and os.path.isdir(os.path.join(base, d)))
        for d in runs[:-3]:
            shutil.rmtree(os.path.join(base, d), ignore_errors=True)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dir", required=True)
    where = p.add_mutually_exclusive_group(required=True)
    where.add_argument("--url")
    where.add_argument("--src")
    p.add_argument("--channel", default="release")
    p.add_argument("--ref", default="")
    p.add_argument("--sha", default="")
    p.add_argument("--label", default="the update")
    p.add_argument("--shell-pid", type=int, default=0)
    p.add_argument("install_args", nargs="*")
    a = p.parse_args()

    os.makedirs(a.dir, exist_ok=True)
    # a crash leaves its trace in the run folder, not in the shell's log
    err = os.open(os.path.join(a.dir, "runner.err"), os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    os.dup2(err, 2)
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    signal.signal(signal.SIGPIPE, signal.SIG_IGN)

    fifo = os.path.join(a.dir, "answers")
    if os.path.lexists(fifo):
        os.unlink(fifo)
    os.mkfifo(fifo, 0o600)
    # read-write, so the fifo never reads as closed between answers
    ffd = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)

    r = Runner(a)
    r.ev.emit("start", pid=os.getpid(), shell=a.shell_pid, channel=a.channel, ref=a.ref, label=a.label)
    r.phase_to("auth", "Waiting for your password")
    r.spawn()
    code = r.loop(ffd)
    # an unpack still running would refill src/ after tidy() emptied it
    if r.worker is not None:
        r.worker.join(timeout=120)
    r.finish(code)
    os.close(ffd)
    r.tidy()


if __name__ == "__main__":
    main()
