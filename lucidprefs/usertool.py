#!/usr/bin/env python3
"""Reads and writes the machine's user accounts for LucidShell.

Everything privileged goes through AccountsService on the system bus, so the
session's polkit agent does the asking and this script never needs to be root.
Four modes, all printing one JSON object:

  probe            every human account, plus the shells and groups this
                   machine has and who is logged in right now
  faces            the stock account pictures this machine ships with
  set              change one account; the JSON command arrives on stdin
  create           add an account, optionally with its first password
  delete           remove an account, with or without its files

Passwords are read from stdin as part of the command and are never passed as
arguments, so they stay out of the process list.
"""

import hashlib
import json
import os
import pwd
import grp
import re
import subprocess
import sys
import tempfile

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

ACCOUNTS = "org.freedesktop.Accounts"
ACCOUNTS_PATH = "/org/freedesktop/Accounts"
USER_IFACE = "org.freedesktop.Accounts.User"
PROPS_IFACE = "org.freedesktop.DBus.Properties"
LOGIND = "org.freedesktop.login1"
LOGIND_PATH = "/org/freedesktop/login1"
LOGIND_IFACE = "org.freedesktop.login1.Manager"
TIMEOUT = 25000
# a privileged call blocks while the polkit dialog is up, and a person typing a
# password takes far longer than dbus's default 25s
AUTH_TIMEOUT = 300000

# accountsservice's account types
STANDARD = 0
ADMIN = 1

# the groups that mean "this account can administer the machine"
ADMIN_GROUPS = ("wheel", "sudo")
AVATAR_PX = 256
NAME_RE = re.compile(r"^[a-z_][a-z0-9_-]{0,31}$")

_bus = None


def bus():
    global _bus
    if _bus is None:
        _bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    return _bus


def call(path, iface, method, args=None, ret=None, service=ACCOUNTS, timeout=TIMEOUT):
    # ALLOW_INTERACTIVE_AUTHORIZATION is what lets accountsservice ask polkit to
    # *prompt*. Without it polkit refuses outright and every privileged change
    # comes back "not authorised" with no dialog ever shown.
    reply = bus().call_sync(service, path, iface, method, args,
                            GLib.VariantType(ret) if ret else None,
                            Gio.DBusCallFlags.ALLOW_INTERACTIVE_AUTHORIZATION,
                            timeout, None)
    return reply.unpack() if reply is not None else ()


def get_all(path):
    return call(path, PROPS_IFACE, "GetAll", GLib.Variant("(s)", (USER_IFACE,)), "(a{sv})")[0]


def user_path(uid):
    return call(ACCOUNTS_PATH, ACCOUNTS, "FindUserById", GLib.Variant("(x)", (int(uid),)), "(o)")[0]


def fail(msg, kind="error"):
    print(json.dumps({"ok": False, "error": msg, "kind": kind}))
    sys.exit(0)


def friendly(err):
    """Turns a D-Bus/polkit failure into something worth showing a person."""
    text = str(err)
    if "Cancelled" in text or "dismissed" in text.lower():
        return "Cancelled.", "cancelled"
    if "NotAuthorized" in text or "AccessDenied" in text or "not authorized" in text.lower():
        # polkit reports a dismissed prompt, a wrong password and a faillock
        # lockout identically, so say what all three have in common
        return ("Not authorised. The administrator password prompt was dismissed "
                "or not accepted — repeated wrong answers lock the account for a "
                "few minutes."), "denied"
    if "org.freedesktop.Accounts" in text and "ServiceUnknown" in text:
        return "The accounts service is not available on this machine.", "missing"
    # dbus errors arrive as "GDBus.Error:<name>: <message>"; the tail is the readable half
    if ":" in text:
        tail = text.rsplit(":", 1)[-1].strip()
        if tail:
            return tail, "error"
    return text, "error"


# ------------------------------------------------------------------- probing

def readable(path):
    return bool(path) and os.path.isfile(path) and os.access(path, os.R_OK)


def avatar_for(name, icon_file):
    """The first avatar that is actually on disk, in the order tools write them."""
    for p in (icon_file,
              f"/var/lib/AccountsService/icons/{name}",
              os.path.expanduser(f"~{name}/.face"),
              os.path.expanduser(f"~{name}/.face.icon")):
        if readable(p):
            return p
    return ""


def canon_shell(path):
    """/bin is a symlink to /usr/bin here, so /etc/shells lists every shell
    twice. Prefer the /usr/bin spelling when it is the same file. Note this
    deliberately does NOT resolve symlinks: sh and rbash point at bash but are
    different shells, chosen by argv[0]."""
    if not path:
        return ""
    cand = "/usr/bin/" + os.path.basename(path)
    try:
        if cand != path and os.path.exists(cand) and os.path.samefile(cand, path):
            return cand
    except OSError:
        pass
    return path


def shells():
    out = []
    try:
        with open("/etc/shells", "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or not os.path.exists(line):
                    continue
                c = canon_shell(line)
                if c not in out:
                    out.append(c)
    except OSError:
        pass
    return out or ["/bin/bash"]


def groups_of(name):
    out = []
    try:
        base = pwd.getpwnam(name)
        out.append(grp.getgrgid(base.pw_gid).gr_name)
    except (KeyError, OSError):
        pass
    for g in grp.getgrall():
        if name in g.gr_mem and g.gr_name not in out:
            out.append(g.gr_name)
    return sorted(out)


def all_groups():
    """Groups worth offering: not per-account, not plumbing, not admin rights —
    the account type owns those, so listing them here would be two ways to set
    one thing."""
    people = {e.pw_name for e in pwd.getpwall()}
    out = []
    for g in grp.getgrall():
        n = g.gr_name
        if n.startswith(("systemd-", "_")) or n in people or n in ADMIN_GROUPS:
            continue
        if g.gr_gid < 900 and g.gr_gid != 0 or n in ("root", "nobody"):
            continue
        out.append(n)
    return sorted(set(out))


def logged_in():
    try:
        users = call(LOGIND_PATH, LOGIND_IFACE, "ListUsers", None, "(a(uso))", service=LOGIND)[0]
        return [int(u[0]) for u in users]
    except GLib.Error:
        return []


def probe():
    me = os.getuid()
    try:
        paths = call(ACCOUNTS_PATH, ACCOUNTS, "ListCachedUsers", None, "(ao)")[0]
    except GLib.Error as e:
        msg, kind = friendly(e)
        fail(msg, kind)

    active = logged_in()
    users = []
    seen = set()
    for p in paths:
        try:
            props = get_all(p)
        except GLib.Error:
            continue
        if props.get("SystemAccount", False):
            continue
        uid = int(props.get("Uid", 0))
        name = props.get("UserName", "")
        seen.add(uid)
        users.append({
            "uid": uid,
            "name": name,
            "realName": props.get("RealName", ""),
            "accountType": int(props.get("AccountType", STANDARD)),
            "avatar": avatar_for(name, props.get("IconFile", "")),
            "locked": bool(props.get("Locked", False)),
            "shell": canon_shell(props.get("Shell", "")),
            "home": props.get("HomeDirectory", ""),
            "email": props.get("Email", ""),
            "location": props.get("Location", ""),
            "autoLogin": bool(props.get("AutomaticLogin", False)),
            "passwordMode": int(props.get("PasswordMode", 0)),
            "passwordHint": props.get("PasswordHint", ""),
            "lastLogin": int(props.get("LoginTime", 0)),
            "logins": int(props.get("LoginFrequency", 0)),
            "groups": groups_of(name),
            "online": uid in active,
            "isMe": uid == me,
        })

    # accountsservice only caches accounts it has been told about; anyone else
    # with a login shell is still a real user and belongs in the list
    for e in pwd.getpwall():
        if e.pw_uid in seen or e.pw_uid < 1000 or e.pw_uid >= 65534:
            continue
        users.append({
            "uid": e.pw_uid,
            "name": e.pw_name,
            "realName": e.pw_gecos.split(",")[0] if e.pw_gecos else "",
            "accountType": ADMIN if any(g in ADMIN_GROUPS for g in groups_of(e.pw_name)) else STANDARD,
            "avatar": avatar_for(e.pw_name, ""),
            "locked": False,
            "shell": canon_shell(e.pw_shell),
            "home": e.pw_dir,
            "email": "",
            "location": "",
            "autoLogin": False,
            "passwordMode": 0,
            "passwordHint": "",
            "lastLogin": 0,
            "logins": 0,
            "groups": groups_of(e.pw_name),
            "online": e.pw_uid in active,
            "isMe": e.pw_uid == me,
            "uncached": True,
        })

    users.sort(key=lambda u: (not u["isMe"], u["uid"]))
    print(json.dumps({
        "ok": True,
        "me": me,
        "users": users,
        "shells": shells(),
        "groups": all_groups(),
        "canAdmin": any(g in ADMIN_GROUPS for g in groups_of(pwd.getpwuid(me).pw_name)),
    }))


# ------------------------------------------------------------------ avatars

FACE_DIRS = (
    "/usr/share/sddm/faces",
    "/usr/share/pixmaps/faces",
    "/usr/share/plasma/avatars",
    "/usr/share/lightdm/avatars",
    "/usr/share/apps/kdm/pics/users",
    os.path.expanduser("~/.local/share/lucid/avatars"),
)
FACE_EXT = (".png", ".jpg", ".jpeg", ".webp", ".icon")


def faces():
    """Stock pictures worth offering, skipping the per-account defaults."""
    out = []
    for d in FACE_DIRS:
        if not os.path.isdir(d):
            continue
        try:
            entries = sorted(os.listdir(d))
        except OSError:
            continue
        for f in entries:
            # "root.face.icon" is an account's own picture, and a dotfile is the
            # theme's own fallback silhouette — neither is a choice worth offering
            if f.startswith("root.") or f.startswith("."):
                continue
            path = os.path.join(d, f)
            if readable(path) and f.lower().endswith(FACE_EXT):
                label = os.path.basename(f).lstrip(".").split(".")[0]
                out.append({"path": path, "name": label or "Default"})
    print(json.dumps({"ok": True, "faces": out}))


HISTORY_DIR = os.path.expanduser("~/.local/share/lucid/avatars/history")
HISTORY_MAX = 12
HISTORY_BYTES = 8 * 1024 * 1024


def history_dir(uid, make=False):
    d = os.path.join(HISTORY_DIR, str(int(uid)))
    if make:
        os.makedirs(d, mode=0o700, exist_ok=True)
    return d


def history_items(uid):
    """Newest first, so the strip reads left to right as most recent."""
    d = history_dir(uid)
    out = []
    try:
        entries = os.listdir(d)
    except OSError:
        return out
    for f in entries:
        if not f.lower().endswith(".png"):
            continue
        path = os.path.join(d, f)
        try:
            st = os.stat(path)
        except OSError:
            continue
        out.append({"path": path, "when": int(st.st_mtime), "bytes": st.st_size})
    out.sort(key=lambda i: i["when"], reverse=True)
    return out


def history_trim(uid):
    """Oldest go first, once either the count or the byte budget is spent."""
    items = history_items(uid)
    used = 0
    for n, item in enumerate(items):
        used += item["bytes"]
        if n < HISTORY_MAX and used <= HISTORY_BYTES:
            continue
        try:
            os.unlink(item["path"])
        except OSError:
            pass


def history_push(uid, source):
    """Square the picture down to 256 and keep it, named by what it looks like.

    Content-hashed, so re-applying a picture already in the history just moves
    it back to the front instead of storing it twice.
    """
    if not readable(source):
        return
    try:
        gi.require_version("GdkPixbuf", "2.0")
        from gi.repository import GdkPixbuf

        buf = GdkPixbuf.Pixbuf.new_from_file(source)
        side = min(buf.get_width(), buf.get_height())
        buf = buf.new_subpixbuf((buf.get_width() - side) // 2,
                                (buf.get_height() - side) // 2, side, side)
        if side != AVATAR_PX:
            buf = buf.scale_simple(AVATAR_PX, AVATAR_PX, GdkPixbuf.InterpType.BILINEAR)
        ok, data = buf.save_to_bufferv("png", [], [])
        if not ok:
            return
        d = history_dir(uid, make=True)
        dest = os.path.join(d, hashlib.sha1(data).hexdigest() + ".png")
        if os.path.exists(dest):
            os.utime(dest, None)
        else:
            with open(dest, "wb") as fh:
                fh.write(data)
            os.chmod(dest, 0o600)
        history_trim(uid)
    except Exception:
        # a picture that cannot be kept is not a reason to refuse the change
        pass


def history(cmd):
    print(json.dumps({"ok": True, "items": history_items(int(cmd["uid"]))}))


def history_clear(cmd):
    d = history_dir(int(cmd["uid"]))
    try:
        for f in os.listdir(d):
            if f.lower().endswith(".png"):
                try:
                    os.unlink(os.path.join(d, f))
                except OSError:
                    pass
    except OSError:
        pass
    print(json.dumps({"ok": True, "items": []}))


def stage_avatar(source, name, is_me):
    """Squares and shrinks an image, then hands back a path the daemon can read.

    Returns (path, cleanup) — cleanup is a path to unlink once the daemon has
    copied the file, or "" when the file is meant to stay where it is.
    """
    gi.require_version("GdkPixbuf", "2.0")
    from gi.repository import GdkPixbuf

    buf = GdkPixbuf.Pixbuf.new_from_file(source)
    side = min(buf.get_width(), buf.get_height())
    buf = buf.new_subpixbuf((buf.get_width() - side) // 2,
                            (buf.get_height() - side) // 2, side, side)
    if side != AVATAR_PX:
        buf = buf.scale_simple(AVATAR_PX, AVATAR_PX, GdkPixbuf.InterpType.BILINEAR)

    if is_me:
        # ~/.face is where the lock screen and every other tool already looks
        dest = os.path.expanduser("~/.face")
        buf.savev(dest, "png", [], [])
        os.chmod(dest, 0o644)
        return dest, ""

    fd, dest = tempfile.mkstemp(prefix="lucid-avatar-", suffix=".png", dir="/tmp")
    os.close(fd)
    buf.savev(dest, "png", [], [])
    os.chmod(dest, 0o644)
    return dest, dest


# ----------------------------------------------------------------- mutations

def hash_password(plain):
    p = subprocess.run(["openssl", "passwd", "-6", "-stdin"],
                       input=plain, capture_output=True, text=True, timeout=20)
    line = p.stdout.strip()
    if p.returncode != 0 or not line.startswith("$"):
        raise RuntimeError("Could not hash the password on this machine.")
    return line


def set_groups(name, wanted):
    """Supplementary groups are not accountsservice's business, so gpasswd does
    them — batched into one pkexec so the agent asks once, not once per group."""
    have = set(groups_of(name))
    try:
        primary = grp.getgrgid(pwd.getpwnam(name).pw_gid).gr_name
    except (KeyError, OSError):
        primary = ""
    wanted = set(wanted)
    known = {g.gr_name for g in grp.getgrall()}
    # admin rights belong to the account type, and the primary group is not ours
    def eligible(g):
        return g in known and g != primary and g not in ADMIN_GROUPS

    add = sorted(g for g in wanted - have if eligible(g))
    drop = sorted(g for g in have - wanted if eligible(g))
    if not add and not drop:
        return []

    import shlex
    script = "; ".join(
        [f"gpasswd -a {shlex.quote(name)} {shlex.quote(g)}" for g in add]
        + [f"gpasswd -d {shlex.quote(name)} {shlex.quote(g)}" for g in drop]
    )
    p = subprocess.run(["pkexec", "sh", "-c", script], capture_output=True, text=True, timeout=120)
    if p.returncode == 126 or p.returncode == 127:
        # pkexec's own codes for "dismissed" and "not authorised"
        raise RuntimeError("Cancelled." if p.returncode == 126 else "You were not authorised to change group membership.")
    if p.returncode != 0:
        raise RuntimeError((p.stderr or "").strip().splitlines()[-1] if p.stderr.strip() else "Group membership could not be changed.")
    return add + drop


def do_set(cmd):
    uid = int(cmd["uid"])
    path = user_path(uid)
    props = get_all(path)
    name = props.get("UserName", "")
    is_me = uid == os.getuid()
    cleanup = ""
    done = []

    def send(method, sig, *args):
        call(path, USER_IFACE, method, GLib.Variant(sig, args), timeout=AUTH_TIMEOUT)

    if "realName" in cmd and cmd["realName"] != props.get("RealName", ""):
        send("SetRealName", "(s)", cmd["realName"])
        done.append("realName")
    if "userName" in cmd and cmd["userName"] != name:
        want = cmd["userName"].strip()
        if not NAME_RE.match(want):
            fail("A username must start with a letter and use only lowercase letters, digits, - and _.")
        try:
            pwd.getpwnam(want)
            fail(f"There is already an account called “{want}”.")
        except KeyError:
            pass
        send("SetUserName", "(s)", want)
        name = want
        done.append("userName")
    if "email" in cmd and cmd["email"] != props.get("Email", ""):
        send("SetEmail", "(s)", cmd["email"])
        done.append("email")
    if "location" in cmd and cmd["location"] != props.get("Location", ""):
        send("SetLocation", "(s)", cmd["location"])
        done.append("location")
    if "shell" in cmd and cmd["shell"] and cmd["shell"] != props.get("Shell", ""):
        send("SetShell", "(s)", cmd["shell"])
        done.append("shell")
    if "accountType" in cmd and int(cmd["accountType"]) != int(props.get("AccountType", STANDARD)):
        send("SetAccountType", "(i)", int(cmd["accountType"]))
        done.append("accountType")
    if "passwordHint" in cmd and cmd["passwordHint"] != props.get("PasswordHint", ""):
        send("SetPasswordHint", "(s)", cmd["passwordHint"])
        done.append("passwordHint")
    if "autoLogin" in cmd and bool(cmd["autoLogin"]) != bool(props.get("AutomaticLogin", False)):
        send("SetAutomaticLogin", "(b)", bool(cmd["autoLogin"]))
        done.append("autoLogin")

    if cmd.get("avatar") is not None:
        want = cmd["avatar"]
        # the picture on its way out is kept first: for your own account
        # stage_avatar overwrites ~/.face in place, so this cannot wait
        history_push(uid, avatar_for(name, props.get("IconFile", "")))
        if want == "":
            send("SetIconFile", "(s)", "")
            for stale in (os.path.expanduser("~/.face"),) if is_me else ():
                try:
                    os.unlink(stale)
                except OSError:
                    pass
        else:
            if not readable(want):
                fail("That image could not be read.")
            try:
                staged, cleanup = stage_avatar(want, name, is_me)
            except Exception as e:  # a broken or unsupported image file
                fail(f"That image could not be used: {e}")
            send("SetIconFile", "(s)", staged)
        done.append("avatar")

    # password mode and the password itself have to move in the right order, or
    # setting a password would clear the "must choose one at next login" flag
    if cmd.get("password"):
        send("SetPassword", "(ss)", hash_password(cmd["password"]), cmd.get("passwordHint", props.get("PasswordHint", "")))
        done.append("password")
    if "passwordMode" in cmd and int(cmd["passwordMode"]) != int(props.get("PasswordMode", 0)):
        send("SetPasswordMode", "(i)", int(cmd["passwordMode"]))
        done.append("passwordMode")

    # locking last: a locked account refuses the changes above
    if "locked" in cmd and bool(cmd["locked"]) != bool(props.get("Locked", False)):
        send("SetLocked", "(b)", bool(cmd["locked"]))
        done.append("locked")

    if "groups" in cmd:
        touched = set_groups(name, cmd["groups"])
        if touched:
            done.append("groups")

    if cleanup:
        try:
            os.unlink(cleanup)
        except OSError:
            pass
    print(json.dumps({"ok": True, "changed": done, "uid": uid}))


def do_create(cmd):
    name = (cmd.get("name") or "").strip()
    if not NAME_RE.match(name):
        fail("A username must start with a letter and use only lowercase letters, digits, - and _.")
    try:
        pwd.getpwnam(name)
        fail(f"There is already an account called “{name}”.")
    except KeyError:
        pass

    path = call(ACCOUNTS_PATH, ACCOUNTS, "CreateUser",
                GLib.Variant("(ssi)", (name, cmd.get("realName", ""),
                                       int(cmd.get("accountType", STANDARD)))), "(o)",
                timeout=AUTH_TIMEOUT)[0]
    props = get_all(path)
    uid = int(props.get("Uid", 0))

    if cmd.get("password"):
        call(path, USER_IFACE, "SetPassword",
             GLib.Variant("(ss)", (hash_password(cmd["password"]), cmd.get("passwordHint", ""))),
             timeout=AUTH_TIMEOUT)
    elif cmd.get("passwordMode") is not None:
        call(path, USER_IFACE, "SetPasswordMode", GLib.Variant("(i)", (int(cmd["passwordMode"]),)),
             timeout=AUTH_TIMEOUT)

    if cmd.get("shell"):
        call(path, USER_IFACE, "SetShell", GLib.Variant("(s)", (cmd["shell"],)), timeout=AUTH_TIMEOUT)
    if cmd.get("groups"):
        set_groups(name, cmd["groups"])

    print(json.dumps({"ok": True, "uid": uid, "name": name}))


def do_delete(cmd):
    uid = int(cmd["uid"])
    if uid == os.getuid():
        fail("You cannot delete the account you are signed in to.")
    call(ACCOUNTS_PATH, ACCOUNTS, "DeleteUser",
         GLib.Variant("(xb)", (uid, bool(cmd.get("removeFiles", False)))), timeout=AUTH_TIMEOUT)
    print(json.dumps({"ok": True, "uid": uid}))


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "probe"
    if mode == "probe":
        probe()
        return
    if mode == "faces":
        faces()
        return

    raw = sys.stdin.read()
    try:
        cmd = json.loads(raw) if raw.strip() else {}
    except ValueError:
        fail("The command could not be read.")

    try:
        if mode == "history":
            history(cmd)
        elif mode == "history-clear":
            history_clear(cmd)
        elif mode == "set":
            do_set(cmd)
        elif mode == "create":
            do_create(cmd)
        elif mode == "delete":
            do_delete(cmd)
        else:
            fail(f"Unknown mode “{mode}”.")
    except GLib.Error as e:
        msg, kind = friendly(e)
        fail(msg, kind)
    except RuntimeError as e:
        fail(str(e))


if __name__ == "__main__":
    main()
