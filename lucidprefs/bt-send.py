#!/usr/bin/env python3
"""Sends files over Bluetooth for LucidShell.

bt-send.py --address AA:BB:.. [--name NAME] [FILE...]

With no files it opens the desktop's file chooser first. The files go out
one after another in a single object push session through obexd (bluez-obex),
and one notification follows it all: connecting, waiting for the other side
to accept, progress with a Cancel button, and how it ended. The process lives
as long as the session, since obexd ties a session to whoever opened it.
"""

import argparse
import os
import signal
import subprocess
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

OBEX = "org.bluez.obex"
OBEX_PATH = "/org/bluez/obex"
NOTIFY = "org.freedesktop.Notifications"
NOTIFY_PATH = "/org/freedesktop/Notifications"
PORTAL = "org.freedesktop.portal.Desktop"
PORTAL_PATH = "/org/freedesktop/portal/desktop"
PROPS = "org.freedesktop.DBus.Properties"
# progress repaints at most this often
PAINT_MS = 400
# connecting can sit on a slow radio, and the other side may take a while
# to answer its pairing or accept prompt
CONNECT_TIMEOUT_MS = 60000

def fill(text, *args):
    out = text
    for i, a in enumerate(args):
        out = out.replace("%%%d" % (i + 1), str(a))
    return out


def log(msg):
    try:
        sys.stderr.write("bt-send: %s\n" % msg)
        sys.stderr.flush()
    except (BrokenPipeError, ValueError):
        pass


def human_size(n):
    if n is None or n < 0:
        return ""
    units = ["B", "KB", "MB", "GB"]
    v = float(n)
    for u in units:
        if v < 1000 or u == units[-1]:
            if u == "B":
                return "%d B" % v
            return ("%.1f %s" if v < 10 else "%.0f %s") % (v, u)
        v /= 1000.0
    return ""


def esc(text):
    # notification bodies are markup: a file called "a<b" must not break them
    return GLib.markup_escape_text(text or "")


class Sender:
    def __init__(self, address, device, files):
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.address = address
        self.device = device or address
        self.files = files
        self.index = 0
        self.sent = []
        self.session = ""
        self.transfer = ""
        self.sub = 0
        self.size = -1
        self.done_bytes = 0
        self.status = ""
        self.cancelled = False
        self.notif = 0
        self.last_paint = 0
        self.painted = None
        self.bus.signal_subscribe(NOTIFY, NOTIFY, "ActionInvoked", NOTIFY_PATH,
                                  None, Gio.DBusSignalFlags.NONE,
                                  self.on_action, None)
        self.bus.signal_subscribe(NOTIFY, NOTIFY, "NotificationClosed",
                                  NOTIFY_PATH, None, Gio.DBusSignalFlags.NONE,
                                  self.on_closed, None)
        self.obex_owner = ""
        self.ended = False
        Gio.bus_watch_name_on_connection(self.bus, OBEX, Gio.BusNameWatcherFlags.NONE,
                                         self.on_obex_appeared, self.on_obex_vanished)

    # ------------------------------------------------------- notifications

    def notify(self, summary, body, actions=(), hints=None, expire=-1, keep=True):
        h = {"urgency": GLib.Variant("y", 1)}
        h.update(hints or {})
        try:
            r = self.bus.call_sync(
                NOTIFY, NOTIFY_PATH, NOTIFY, "Notify",
                GLib.Variant("(susssasa{sv}i)",
                             ("Bluetooth", self.notif if keep else 0, "bluetooth",
                              summary, body, list(actions), h, expire)),
                GLib.VariantType("(u)"), Gio.DBusCallFlags.NONE, 3000, None)
            nid = r.unpack()[0]
        except GLib.Error as e:
            log("notify failed: %s" % e.message)
            return
        if keep:
            self.notif = nid

    def close_notif(self):
        if not self.notif:
            return
        nid, self.notif = self.notif, 0
        try:
            self.bus.call_sync(NOTIFY, NOTIFY_PATH, NOTIFY, "CloseNotification",
                               GLib.Variant("(u)", (nid,)), None,
                               Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error:
            pass

    def live(self, summary, body, value=None):
        hints = {"resident": GLib.Variant("b", True)}
        if value is not None:
            hints["value"] = GLib.Variant("i", value)
        painted = (summary, body, value)
        if self.notif and painted == self.painted:
            return
        self.painted = painted
        self.notify(summary, body, ["cancel", fill("Cancel")], hints, expire=0)

    def on_action(self, _conn, _sender, _path, _iface, _signal, params, _d):
        nid, key = params.unpack()
        if nid == self.notif and key == "cancel":
            self.cancel()

    def on_closed(self, _conn, _sender, _path, _iface, _signal, params, _d):
        nid, _reason = params.unpack()
        # dismissing the progress only hides it; the end still says how it went
        if nid == self.notif:
            self.notif = 0
            self.painted = None

    # ------------------------------------------------------------- session

    def on_obex_appeared(self, _bus, _name, owner):
        self.obex_owner = owner

    def on_obex_vanished(self, _bus, _name):
        # obexd 5.87 can crash tearing a busy session down (a cancel among other
        # things, bluez#323 and #2450); it comes back on its own, the session does not
        was, self.obex_owner = self.obex_owner, ""
        if not was or not self.session:
            return
        self.session = ""
        if self.sub:
            self.bus.signal_unsubscribe(self.sub)
            self.sub = 0
        failed = self.files[self.index] if self.transfer else ""
        self.transfer = ""
        if self.cancelled:
            self.close_notif()
            self.end()
        else:
            self.finish(failed=failed or self.files[min(self.index, len(self.files) - 1)])

    def start(self):
        if len(self.files) == 1:
            what = esc(os.path.basename(self.files[0]))
        else:
            what = esc(fill("%1 files", len(self.files)))
        self.live(fill("Connecting to %1…", self.device), what)
        self.bus.call(OBEX, OBEX_PATH, "org.bluez.obex.Client1", "CreateSession",
                      GLib.Variant("(sa{sv})", (self.address, {"Target": GLib.Variant("s", "opp")})),
                      GLib.VariantType("(o)"), Gio.DBusCallFlags.NONE,
                      CONNECT_TIMEOUT_MS, None, self.on_session, None)

    def on_session(self, bus, res, _data):
        try:
            self.session = bus.call_finish(res).unpack()[0]
        except GLib.Error as e:
            name = Gio.DBusError.get_remote_error(e) or ""
            Gio.DBusError.strip_remote_error(e)
            log("CreateSession: %s %s" % (name, e.message))
            if self.cancelled:
                self.end()
            elif name in ("org.freedesktop.DBus.Error.ServiceUnknown",
                          "org.freedesktop.DBus.Error.NameHasNoOwner"):
                self.close_notif()
                self.notify(fill("Can't send over Bluetooth"),
                            fill("Sending files needs bluez-obex."), keep=False)
                self.end()
            else:
                self.close_notif()
                self.notify(fill("Couldn't reach %1", self.device),
                            fill("Check that its Bluetooth is on and that it is close by."), keep=False)
                self.end()
            return
        if self.cancelled:
            self.end()
            return
        self.next_file()

    def next_file(self):
        if self.index >= len(self.files):
            self.finish()
            return
        path = self.files[self.index]
        self.size = -1
        self.done_bytes = 0
        self.status = "queued"
        try:
            r = self.bus.call_sync(OBEX, self.session, "org.bluez.obex.ObjectPush1",
                                   "SendFile", GLib.Variant("(s)", (path,)),
                                   GLib.VariantType("(oa{sv})"),
                                   Gio.DBusCallFlags.NONE, 10000, None)
        except GLib.Error as e:
            log("SendFile %s: %s" % (path, e.message))
            self.finish(failed=path)
            return
        self.transfer, props = r.unpack()
        self.size = props.get("Size", -1)
        self.sub = self.bus.signal_subscribe(
            OBEX, PROPS, "PropertiesChanged", self.transfer, None,
            Gio.DBusSignalFlags.NONE, self.on_transfer_changed, None)
        # it may have moved on before the subscription was in place
        try:
            r = self.bus.call_sync(OBEX, self.transfer, PROPS, "GetAll",
                                   GLib.Variant("(s)", ("org.bluez.obex.Transfer1",)),
                                   GLib.VariantType("(a{sv})"),
                                   Gio.DBusCallFlags.NONE, 3000, None)
            self.apply(r.unpack()[0])
        except GLib.Error:
            self.paint(force=True)

    def on_transfer_changed(self, _conn, _sender, _path, _iface, _signal, params, _d):
        iface, changed, _inv = params.unpack()
        if iface == "org.bluez.obex.Transfer1":
            self.apply(changed)

    def apply(self, changed):
        if not self.transfer:
            return
        if changed.get("Size", 0) > 0:
            self.size = changed["Size"]
        if "Transferred" in changed:
            self.done_bytes = changed["Transferred"]
        status = changed.get("Status")
        if status:
            self.status = status
        if self.status == "complete":
            self.transfer_ended(True)
        elif self.status == "error":
            self.transfer_ended(False)
        else:
            self.paint(force=bool(status))

    def paint(self, force=False):
        now = GLib.get_monotonic_time() // 1000
        if not force and now - self.last_paint < PAINT_MS:
            return
        self.last_paint = now
        name = esc(os.path.basename(self.files[self.index]))
        many = len(self.files) > 1
        prefix = fill("File %1 of %2", self.index + 1, len(self.files)) + " · " if many else ""
        # the other side shows an accept prompt before any byte moves
        if not self.done_bytes:
            self.live(fill("Waiting for %1 to accept", self.device), prefix + name)
            return
        value = None
        if self.size > 0:
            value = int(min(100, self.done_bytes * 100 // self.size))
            line = fill("%1 of %2", human_size(self.done_bytes), human_size(self.size))
        else:
            line = human_size(self.done_bytes)
        self.live(fill("Sending to %1", self.device), "%s%s · %s" % (prefix, name, line), value)

    def transfer_ended(self, ok):
        if self.sub:
            self.bus.signal_unsubscribe(self.sub)
            self.sub = 0
        path = self.files[self.index]
        self.transfer = ""
        if self.cancelled:
            self.close_notif()
            self.end()
            return
        if not ok:
            self.finish(failed=path)
            return
        self.sent.append(path)
        self.index += 1
        self.next_file()

    def cancel(self):
        if self.cancelled:
            return
        self.cancelled = True
        self.close_notif()
        if self.session:
            # Transfer1.Cancel on a busy push crashes obexd (bluez#323): dropping
            # the whole session stops it as well
            self.end()
        # still connecting: on_session ends it when the answer comes

    def finish(self, failed=""):
        self.close_notif()
        n = len(self.files)
        if not failed:
            if n == 1:
                summary = fill("Sent %1", os.path.basename(self.sent[0]))
            else:
                summary = fill("Sent %1 files", n)
            self.notify(summary, fill("To %1", esc(self.device)), keep=False)
        elif self.sent:
            self.notify(fill("Sent %1 of %2 files", len(self.sent), n),
                        fill("%1 declined the rest or stopped answering.", esc(self.device)),
                        keep=False)
        else:
            self.notify(fill("Couldn't send %1", os.path.basename(failed)),
                        fill("%1 declined it or stopped answering.", esc(self.device)),
                        keep=False)
        self.end()

    def end(self):
        if self.ended:
            return False
        self.ended = True
        if self.sub:
            self.bus.signal_unsubscribe(self.sub)
            self.sub = 0
        if self.session:
            try:
                self.bus.call_sync(OBEX, OBEX_PATH, "org.bluez.obex.Client1",
                                   "RemoveSession", GLib.Variant("(o)", (self.session,)),
                                   None, Gio.DBusCallFlags.NONE, 3000, None)
            except GLib.Error:
                pass
            self.session = ""
        loop.quit()
        return False

    def interrupted(self, *_args):
        self.cancel()
        self.end()
        return False


# ---------------------------------------------------------------- picking

def pick_portal(bus, title, done):
    """The desktop's own file chooser. Calls done(paths), or done(None) if
    there is no portal to ask."""
    token = "lucidbt%d" % (GLib.get_monotonic_time() % 1000000)
    who = bus.get_unique_name()[1:].replace(".", "_")
    path = "/org/freedesktop/portal/desktop/request/%s/%s" % (who, token)
    sub = 0

    def responded(_c, _s, _p, _i, _sig, params):
        bus.signal_unsubscribe(sub)
        code, results = params.unpack()
        if code != 0:
            done([])
            return
        out = []
        for uri in results.get("uris", []):
            p = Gio.File.new_for_uri(uri).get_path()
            if p:
                out.append(p)
        done(out)

    sub = bus.signal_subscribe(PORTAL, "org.freedesktop.portal.Request",
                               "Response", path, None,
                               Gio.DBusSignalFlags.NONE, responded)
    opts = {
        "handle_token": GLib.Variant("s", token),
        "multiple": GLib.Variant("b", True),
        "modal": GLib.Variant("b", False),
    }
    try:
        bus.call_sync(PORTAL, PORTAL_PATH, "org.freedesktop.portal.FileChooser",
                      "OpenFile", GLib.Variant("(ssa{sv})", ("", title, opts)),
                      GLib.VariantType("(o)"), Gio.DBusCallFlags.NONE, 10000, None)
    except GLib.Error as e:
        bus.signal_unsubscribe(sub)
        log("no portal file chooser: %s" % e.message)
        done(None)


def pick_zenity(title):
    try:
        out = subprocess.run(["zenity", "--file-selection", "--multiple",
                              "--separator=\n", "--title=" + title],
                             capture_output=True, text=True).stdout
    except OSError:
        return []
    return [p for p in out.split("\n") if p]


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--address", required=True)
    ap.add_argument("--name", default="")
    ap.add_argument("files", nargs="*")
    a = ap.parse_args()

    loop = GLib.MainLoop()
    sender = None

    def go(paths):
        global sender
        if paths is None:
            paths = pick_zenity(fill("Send to %1", a.name or a.address))
        # obex pushes files, not folders
        paths = [os.path.abspath(p) for p in paths if os.path.isfile(p)]
        if not paths:
            loop.quit()
            return
        sender = Sender(a.address, a.name, paths)
        try:
            gi.require_version("GLibUnix", "2.0")
            from gi.repository import GLibUnix
            signal_add = GLibUnix.signal_add
        except (ImportError, ValueError):
            signal_add = GLib.unix_signal_add
        for sig in (signal.SIGTERM, signal.SIGINT):
            signal_add(GLib.PRIORITY_DEFAULT, sig, sender.interrupted)
        sender.start()

    if a.files:
        GLib.idle_add(lambda: go(a.files) and False)
    else:
        bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        GLib.idle_add(lambda: pick_portal(bus, fill("Send to %1", a.name or a.address), go) and False)
    loop.run()
