#!/usr/bin/env python3
"""Receives files sent over Bluetooth for LucidShell.

Registers itself with obexd (bluez-obex) as the agent that answers object
push requests. Each request becomes a notification with Accept and Decline;
once accepted, the same notification follows the transfer, and a last one
says where the file went. obexd only writes inside its own root folder, so
files land in a private folder under it first and are moved to the chosen
folder once they are complete.

Speaks JSON lines: state and received files go out on stdout, settings come
in on stdin as {"cmd": "config", "folder": "...", "autoPaired": bool}.
"""

import json
import os
import shutil
import signal
import sys
import time

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

OBEX = "org.bluez.obex"
OBEX_PATH = "/org/bluez/obex"
AGENT_PATH = "/org/lucid/obex/agent"
NOTIFY = "org.freedesktop.Notifications"
NOTIFY_PATH = "/org/freedesktop/Notifications"
PROPS = "org.freedesktop.DBus.Properties"
STAGE_DIR = "lucid-bluetooth"
# a finished batch waits this long for the sender's next file
BATCH_GRACE_MS = 2500
# progress repaints at most this often
PAINT_MS = 400

AGENT_XML = """
<node>
  <interface name="org.bluez.obex.Agent1">
    <method name="Release"/>
    <method name="AuthorizePush">
      <arg type="o" name="transfer" direction="in"/>
      <arg type="s" name="path" direction="out"/>
    </method>
    <method name="Cancel"/>
  </interface>
</node>
"""


def emit(obj):
    try:
        sys.stdout.write(json.dumps(obj) + "\n")
        sys.stdout.flush()
    except (BrokenPipeError, ValueError):
        raise SystemExit(0)


def log(msg):
    try:
        sys.stderr.write("bt-receive: %s\n" % msg)
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


def pretty_path(path):
    home = os.path.expanduser("~")
    if path == home:
        return "~"
    if path.startswith(home + "/"):
        return "~" + path[len(home):]
    return path


def safe_name(name):
    name = (name or "").replace("/", "_").replace("\0", "").strip()
    # a dot file would vanish from view once it lands
    name = name.lstrip(".")
    return name or "file"


def unique_path(folder, name):
    path = os.path.join(folder, name)
    if not os.path.lexists(path):
        return path
    stem, ext = os.path.splitext(name)
    # keep .tar.gz and friends together
    if stem.endswith(".tar"):
        stem, ext = stem[:-4], ".tar" + ext
    n = 1
    while True:
        path = os.path.join(folder, "%s (%d)%s" % (stem, n, ext))
        if not os.path.lexists(path):
            return path
        n += 1


def default_folder():
    d = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DOWNLOAD)
    if d and d != os.path.expanduser("~"):
        return d
    return os.path.expanduser("~/Downloads")


def is_image(path):
    ctype, _ = Gio.content_type_guess(path, None)
    return bool(ctype) and ctype.startswith("image/")


class Batch:
    """Everything one device sends in one go shares a notification."""

    def __init__(self, session, address, device):
        self.session = session
        self.address = address
        self.device = device
        self.accepted = False
        self.declined = False
        self.notif = 0
        self.paired = False
        self.pending = None  # (invocation, transfer, name, size)
        self.transfer = None
        self.sub = 0
        self.name = ""
        self.stage = ""
        self.size = -1
        self.done_bytes = 0
        self.status = ""
        self.cancelled = False
        self.files = []
        self.failed = []
        self.finish_timer = 0
        self.last_paint = 0
        self.painted = None


class Receiver:
    def __init__(self):
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        try:
            self.sysbus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        except GLib.Error:
            self.sysbus = None
        self.folder = ""
        self.auto_paired = False
        self.registered = False
        self.registering = False
        self.obex_owner = ""
        self.retry = 0
        self.retry_timer = 0
        self.batches = {}
        # notification id -> batch (live) or finished-file actions
        self.by_notif = {}
        self.done_actions = {}
        self.stage_root = ""

        info = Gio.DBusNodeInfo.new_for_xml(AGENT_XML)
        # the closure form is the one newer PyGObject wants; older lacks it
        register = getattr(self.bus, "register_object_with_closures2", None) or self.bus.register_object
        self.agent_id = register(AGENT_PATH, info.interfaces[0], self.on_agent_call, None, None)

        self.bus.signal_subscribe(NOTIFY, NOTIFY, "ActionInvoked", NOTIFY_PATH,
                                  None, Gio.DBusSignalFlags.NONE,
                                  self.on_action, None)
        self.bus.signal_subscribe(NOTIFY, NOTIFY, "NotificationClosed",
                                  NOTIFY_PATH, None, Gio.DBusSignalFlags.NONE,
                                  self.on_closed, None)
        Gio.bus_watch_name_on_connection(
            self.bus, OBEX, Gio.BusNameWatcherFlags.NONE,
            self.on_obex_appeared, self.on_obex_vanished)

        GLib.io_add_watch(sys.stdin.fileno(), GLib.PRIORITY_DEFAULT,
                          GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, self.on_stdin)
        self.stdin_buf = b""

    # ---------------------------------------------------------- lifecycle

    def target_folder(self):
        return os.path.expanduser(self.folder) if self.folder else default_folder()

    def report(self, state, detail=""):
        emit({"type": "state", "state": state, "detail": detail,
              "defaultFolder": default_folder()})

    def register(self):
        self.retry_timer = 0
        if self.registering or self.registered:
            return False
        self.registering = True
        self.bus.call(OBEX, OBEX_PATH, "org.bluez.obex.AgentManager1",
                      "RegisterAgent", GLib.Variant("(o)", (AGENT_PATH,)),
                      None, Gio.DBusCallFlags.NONE, 10000, None,
                      self.on_registered, None)
        return False

    def on_registered(self, bus, res, _data):
        self.registering = False
        try:
            bus.call_finish(res)
        except GLib.Error as e:
            self.registered = False
            name = Gio.DBusError.get_remote_error(e) or ""
            if name in ("org.freedesktop.DBus.Error.ServiceUnknown",
                        "org.freedesktop.DBus.Error.NameHasNoOwner"):
                self.report("missing")
            elif name == "org.bluez.obex.Error.AlreadyExists":
                self.report("taken")
            else:
                Gio.DBusError.strip_remote_error(e)
                self.report("error", e.message)
                self.schedule_retry()
            return
        self.registered = True
        self.retry = 0
        self.report("ready")

    def schedule_retry(self):
        if self.retry_timer or self.retry >= 5:
            return
        self.retry += 1
        self.retry_timer = GLib.timeout_add(2000 * self.retry, self.register)

    def on_obex_appeared(self, _bus, _name, owner):
        self.obex_owner = owner
        if not self.registered and not self.retry_timer:
            self.register()

    def on_obex_vanished(self, _bus, _name):
        was = self.obex_owner
        self.obex_owner = ""
        if not was:
            # nothing is running yet: registering starts obexd on demand
            if not self.retry_timer:
                self.register()
            return
        # obexd went away (crash, restart): anything in flight is gone
        self.registered = False
        for b in list(self.batches.values()):
            if b.transfer and b.status not in ("complete", "error"):
                b.status = "error"
                self.transfer_ended(b)
        self.report("error", "obexd stopped; starting it again")
        self.schedule_retry()

    def shutdown(self, *_args):
        if self.registered:
            try:
                self.bus.call_sync(OBEX, OBEX_PATH,
                                   "org.bluez.obex.AgentManager1",
                                   "UnregisterAgent",
                                   GLib.Variant("(o)", (AGENT_PATH,)), None,
                                   Gio.DBusCallFlags.NONE, 2000, None)
            except GLib.Error:
                pass
        for b in self.batches.values():
            if b.pending:
                self.reject(b.pending[0], "Rejected")
            if b.notif and not b.files:
                self.close_notif(b.notif)
        loop.quit()
        return False

    # -------------------------------------------------------------- stdin

    def on_stdin(self, fd, cond):
        if cond & (GLib.IO_HUP | GLib.IO_ERR) and not cond & GLib.IO_IN:
            self.shutdown()
            return False
        try:
            chunk = os.read(fd, 65536)
        except OSError:
            chunk = b""
        if not chunk:
            self.shutdown()
            return False
        self.stdin_buf += chunk
        while b"\n" in self.stdin_buf:
            line, self.stdin_buf = self.stdin_buf.split(b"\n", 1)
            try:
                msg = json.loads(line.decode("utf-8", "replace"))
            except ValueError:
                continue
            cmd = msg.get("cmd")
            if cmd == "config":
                self.folder = str(msg.get("folder") or "")
                self.auto_paired = bool(msg.get("autoPaired"))
            elif cmd == "show" and msg.get("file"):
                self.show_in_folder([str(msg["file"])])
            elif cmd == "quit":
                self.shutdown()
                return False
        return True

    # ------------------------------------------------------------ helpers

    def get_all(self, path, iface):
        try:
            r = self.bus.call_sync(OBEX, path, PROPS, "GetAll",
                                   GLib.Variant("(s)", (iface,)),
                                   GLib.VariantType("(a{sv})"),
                                   Gio.DBusCallFlags.NONE, 3000, None)
            return r.unpack()[0]
        except GLib.Error:
            return {}

    def device_info(self, address):
        out = {"name": address or "A device", "paired": False}
        if not self.sysbus or not address:
            return out
        try:
            r = self.sysbus.call_sync("org.bluez", "/",
                                      "org.freedesktop.DBus.ObjectManager",
                                      "GetManagedObjects", None,
                                      GLib.VariantType("(a{oa{sa{sv}}})"),
                                      Gio.DBusCallFlags.NONE, 3000, None)
        except GLib.Error:
            return out
        for _path, ifaces in r.unpack()[0].items():
            dev = ifaces.get("org.bluez.Device1")
            if dev and dev.get("Address", "").upper() == address.upper():
                out["name"] = dev.get("Alias") or dev.get("Name") or address
                out["paired"] = bool(dev.get("Paired")) or bool(dev.get("Bonded"))
                break
        return out

    def notify(self, batch, summary, body, actions, hints=None, replace=0,
               expire=-1, icon="bluetooth"):
        h = dict(hints or {})
        try:
            r = self.bus.call_sync(
                NOTIFY, NOTIFY_PATH, NOTIFY, "Notify",
                GLib.Variant("(susssasa{sv}i)",
                             ("Bluetooth", replace, icon, summary, body,
                              actions, h, expire)),
                GLib.VariantType("(u)"), Gio.DBusCallFlags.NONE, 3000, None)
            return r.unpack()[0]
        except GLib.Error as e:
            log("notify failed: %s" % e.message)
            return 0

    def close_notif(self, nid):
        if not nid:
            return
        self.by_notif.pop(nid, None)
        try:
            self.bus.call_sync(NOTIFY, NOTIFY_PATH, NOTIFY, "CloseNotification",
                               GLib.Variant("(u)", (nid,)), None,
                               Gio.DBusCallFlags.NONE, 2000, None)
        except GLib.Error:
            pass

    def reject(self, invocation, what):
        try:
            invocation.return_dbus_error("org.bluez.obex.Error." + what,
                                         "Declined by the user" if what == "Rejected" else "Canceled")
        except Exception:  # noqa: BLE001 - obexd may already have gone
            pass

    # -------------------------------------------------------------- agent

    def on_agent_call(self, _conn, sender, _path, _iface, method, params,
                      invocation):
        if self.obex_owner and sender != self.obex_owner:
            invocation.return_dbus_error("org.bluez.obex.Error.Rejected",
                                         "Not obexd")
            return
        if method == "AuthorizePush":
            self.authorize(params.unpack()[0], invocation)
        elif method == "Cancel":
            invocation.return_value(None)
            self.on_cancel()
        elif method == "Release":
            invocation.return_value(None)
            self.registered = False
            self.report("taken")
        else:
            invocation.return_value(None)

    def authorize(self, transfer, invocation):
        t = self.get_all(transfer, "org.bluez.obex.Transfer1")
        session = t.get("Session", "")
        name = safe_name(t.get("Name") or "")
        size = t.get("Size", -1)
        b = self.batches.get(session)
        if b is None:
            s = self.get_all(session, "org.bluez.obex.Session1") if session else {}
            address = s.get("Destination", "")
            dev = self.device_info(address)
            b = Batch(session, address, dev["name"])
            b.paired = dev["paired"]
            root = s.get("Root") or os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
            self.stage_root = os.path.join(root, STAGE_DIR)
            self.batches[session] = b
        if b.finish_timer:
            GLib.source_remove(b.finish_timer)
            b.finish_timer = 0
        if b.declined:
            self.reject(invocation, "Rejected")
            return
        if b.accepted or (self.auto_paired and b.paired):
            b.accepted = True
            self.accept(b, invocation, transfer, name, size)
            return
        b.pending = (invocation, transfer, name, size)
        body = esc(name) + (" · " + human_size(size) if size and size > 0 else "")
        b.notif = self.notify(
            b, "%s wants to send you a file" % b.device, body,
            ["accept", "Accept", "decline", "Decline"],
            {"resident": GLib.Variant("b", True),
             "urgency": GLib.Variant("y", 1)},
            replace=b.notif, expire=0)
        if b.notif:
            self.by_notif[b.notif] = b
        emit({"type": "request", "device": b.device, "name": name,
              "size": size})

    def accept(self, b, invocation, transfer, name, size):
        b.pending = None
        stage = os.path.join(self.stage_root, "%d-%d" % (os.getpid(), int(time.monotonic() * 1000)))
        try:
            os.makedirs(stage, mode=0o700, exist_ok=True)
        except OSError as e:
            log("cannot make %s: %s" % (stage, e))
            self.reject(invocation, "Rejected")
            b.failed.append(name)
            self.finish(b)
            return
        b.transfer = transfer
        b.name = name
        b.stage = os.path.join(stage, name)
        b.size = size if size and size > 0 else -1
        b.done_bytes = 0
        b.status = "queued"
        b.cancelled = False
        b.sub = self.bus.signal_subscribe(
            OBEX, PROPS, "PropertiesChanged", transfer, None,
            Gio.DBusSignalFlags.NONE, self.on_transfer_changed, b)
        invocation.return_value(GLib.Variant("(s)", (b.stage,)))
        self.paint(b, force=True)

    def decline(self, b):
        b.declined = True
        if b.pending:
            self.reject(b.pending[0], "Rejected")
            b.pending = None
        self.close_notif(b.notif)
        b.notif = 0
        self.drop_later(b)

    def on_cancel(self):
        # obexd gave up waiting (it allows a minute) or the sender went away
        for b in list(self.batches.values()):
            if not b.pending:
                continue
            _inv, _t, name, _size = b.pending
            b.pending = None
            b.declined = True
            self.close_notif(b.notif)
            b.notif = 0
            self.notify(b, "Missed a file from %s" % b.device,
                        "%s wasn't accepted in time." % esc(name), [],
                        {"urgency": GLib.Variant("y", 1)})
            self.drop_later(b)

    # ----------------------------------------------------------- progress

    def on_transfer_changed(self, _conn, _sender, _path, _iface, _signal,
                            params, b):
        iface, changed, _inv = params.unpack()
        if iface != "org.bluez.obex.Transfer1":
            return
        if "Size" in changed and changed["Size"] > 0:
            b.size = changed["Size"]
        if "Transferred" in changed:
            b.done_bytes = changed["Transferred"]
        status = changed.get("Status")
        if status:
            b.status = status
        if status in ("complete", "error"):
            self.transfer_ended(b)
        else:
            self.paint(b, force=bool(status))

    def paint(self, b, force=False):
        now = GLib.get_monotonic_time() // 1000
        if not force and now - b.last_paint < PAINT_MS:
            return
        b.last_paint = now
        hints = {"resident": GLib.Variant("b", True),
                 "urgency": GLib.Variant("y", 1)}
        if b.size > 0:
            pct = int(min(100, b.done_bytes * 100 // b.size))
            hints["value"] = GLib.Variant("i", pct)
        if not b.done_bytes:
            line = "Starting…"
        elif b.size > 0:
            line = "%s of %s" % (human_size(b.done_bytes), human_size(b.size))
        else:
            line = human_size(b.done_bytes)
        # a batch counts its files: the sender never says how many are coming
        nth = len(b.files) + len(b.failed) + (0 if b.status == "complete" else 1)
        if nth > 1:
            line = "File %d · %s" % (nth, line)
        body = "%s · %s" % (esc(b.name), line)
        # queued and active read the same; an identical repaint is noise
        painted = (body, hints.get("value") and hints["value"].unpack())
        if b.notif and painted == b.painted:
            return
        b.painted = painted
        b.notif = self.notify(b, "Receiving from %s" % b.device, body,
                              ["cancel", "Cancel"], hints, replace=b.notif,
                              expire=0)
        if b.notif:
            self.by_notif[b.notif] = b

    def transfer_ended(self, b):
        if b.sub:
            self.bus.signal_unsubscribe(b.sub)
            b.sub = 0
        stage_dir = os.path.dirname(b.stage) if b.stage else ""
        if b.status == "complete" and b.stage and os.path.exists(b.stage):
            try:
                folder = self.target_folder()
                os.makedirs(folder, exist_ok=True)
                dest = unique_path(folder, b.name)
                shutil.move(b.stage, dest)
                mask = os.umask(0)
                os.umask(mask)
                os.chmod(dest, 0o666 & ~mask)
                b.files.append(dest)
                emit({"type": "received", "file": dest, "name": os.path.basename(dest),
                      "device": b.device, "time": int(time.time() * 1000)})
            except OSError as e:
                log("cannot move %s: %s" % (b.stage, e))
                b.failed.append(b.name)
        else:
            if not b.cancelled:
                b.failed.append(b.name)
            try:
                if b.stage and os.path.exists(b.stage):
                    os.remove(b.stage)
            except OSError:
                pass
        if stage_dir:
            try:
                os.rmdir(stage_dir)
            except OSError:
                pass
        b.transfer = None
        b.stage = ""
        if b.cancelled:
            b.declined = True
            self.finish(b)
            return
        if b.status == "complete":
            b.done_bytes = b.size if b.size > 0 else b.done_bytes
            self.paint(b, force=True)
        # the sender's next file, if any, arrives within a moment
        b.finish_timer = GLib.timeout_add(BATCH_GRACE_MS, self.finish, b)

    def finish(self, b):
        b.finish_timer = 0
        self.close_notif(b.notif)
        b.notif = 0
        files = b.files
        folder = self.target_folder()
        where = pretty_path(folder)
        if files:
            hints = {"urgency": GLib.Variant("y", 1)}
            if len(files) == 1:
                one = files[0]
                summary = "Received %s" % os.path.basename(one)
                actions = ["default", "Open", "open", "Open",
                           "folder", "Show in folder"]
                if is_image(one):
                    hints["image-path"] = GLib.Variant("s", Gio.File.new_for_path(one).get_uri())
            else:
                summary = "Received %d files" % len(files)
                actions = ["default", "Show in folder", "folder", "Show in folder"]
            body = "From %s · saved to %s" % (esc(b.device), esc(where))
            if b.failed:
                body += " · %d didn't arrive" % len(b.failed)
            nid = self.notify(b, summary, body, actions, hints)
            if nid:
                self.done_actions[nid] = list(files)
                # history can grow, the helper's memory should not
                while len(self.done_actions) > 50:
                    self.done_actions.pop(next(iter(self.done_actions)))
        elif b.failed:
            name = b.failed[0] if len(b.failed) == 1 else "%d files" % len(b.failed)
            self.notify(b, "Couldn't receive %s" % name,
                        "%s stopped sending before it was done." % esc(b.device), [],
                        {"urgency": GLib.Variant("y", 1)})
        elif b.cancelled:
            pass
        self.batches.pop(b.session, None)
        return False

    def drop_later(self, b):
        # a declined sender often retries the same session at once: keep the
        # answer around briefly so it is not asked twice
        def drop():
            if self.batches.get(b.session) is b and not b.transfer:
                self.batches.pop(b.session, None)
            return False
        GLib.timeout_add(5000, drop)

    # ------------------------------------------------------- notification

    def on_action(self, _conn, _sender, _path, _iface, _signal, params, _d):
        nid, key = params.unpack()
        b = self.by_notif.get(nid)
        if b is not None:
            if key == "accept" and b.pending:
                b.accepted = True
                inv, transfer, name, size = b.pending
                self.accept(b, inv, transfer, name, size)
            elif key == "decline" and b.pending:
                self.decline(b)
            elif key == "cancel" and b.transfer:
                b.cancelled = True
                try:
                    self.bus.call_sync(OBEX, b.transfer, "org.bluez.obex.Transfer1",
                                       "Cancel", None, None,
                                       Gio.DBusCallFlags.NONE, 3000, None)
                except GLib.Error as e:
                    log("cancel failed: %s" % e.message)
            return
        files = self.done_actions.get(nid)
        if not files:
            return
        if key in ("open", "default") and len(files) == 1:
            self.open_uri(Gio.File.new_for_path(files[0]).get_uri())
        elif key in ("folder", "default"):
            self.show_in_folder(files)

    def on_closed(self, _conn, _sender, _path, _iface, _signal, params, _d):
        nid, reason = params.unpack()
        b = self.by_notif.pop(nid, None)
        if b is None:
            return
        # dismissing the question is a no; dismissing progress just hides it
        if b.pending and reason == 2:
            self.decline(b)
        elif b.notif == nid:
            b.notif = 0

    def open_uri(self, uri):
        try:
            Gio.AppInfo.launch_default_for_uri(uri, None)
        except GLib.Error as e:
            log("cannot open %s: %s" % (uri, e.message))

    def show_in_folder(self, files):
        uris = [Gio.File.new_for_path(f).get_uri() for f in files if os.path.exists(f)]
        if not uris:
            self.open_uri(Gio.File.new_for_path(self.target_folder()).get_uri())
            return
        try:
            self.bus.call_sync("org.freedesktop.FileManager1",
                               "/org/freedesktop/FileManager1",
                               "org.freedesktop.FileManager1", "ShowItems",
                               GLib.Variant("(ass)", (uris, "")), None,
                               Gio.DBusCallFlags.NONE, 3000, None)
        except GLib.Error:
            self.open_uri(Gio.File.new_for_path(os.path.dirname(files[0])).get_uri())


def die_with_parent():
    # the shell restarting must not leave an agent behind
    try:
        import ctypes
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(1, signal.SIGTERM)
    except (OSError, AttributeError):
        pass


if __name__ == "__main__":
    die_with_parent()
    loop = GLib.MainLoop()
    receiver = Receiver()
    try:
        gi.require_version("GLibUnix", "2.0")
        from gi.repository import GLibUnix
        signal_add = GLibUnix.signal_add
    except (ImportError, ValueError):
        signal_add = GLib.unix_signal_add
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal_add(GLib.PRIORITY_DEFAULT, sig, receiver.shutdown)
    loop.run()
