#!/usr/bin/env python3
"""Long-lived KDE Connect bridge for LucidShell.

Speaks JSON lines. Every change on the KDE Connect D-Bus service pushes a
fresh snapshot on stdout; commands arrive one JSON object per line on stdin.
Nothing here blocks the shell: every call is made off the QML thread and a
dead or missing daemon degrades to an empty snapshot instead of an error.
"""

import json
import re
import sys
import threading

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

SERVICE = "org.kde.kdeconnect"
DAEMON_PATH = "/modules/kdeconnect"
DAEMON_IFACE = "org.kde.kdeconnect.daemon"
DEVICE_IFACE = "org.kde.kdeconnect.device"
PROPS_IFACE = "org.freedesktop.DBus.Properties"
TIMEOUT = 4000

# plugin node name -> the bits of it worth showing
PLUGIN_IFACE = "org.kde.kdeconnect.device.%s"


def emit(obj):
    try:
        sys.stdout.write(json.dumps(obj) + "\n")
        sys.stdout.flush()
    except (BrokenPipeError, ValueError):
        raise SystemExit(0)


class Bridge:
    def __init__(self):
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.present = False
        self.pending = None
        self.subs = []
        self.last = None

    # ---------------------------------------------------------------- d-bus

    def call_at(self, dest, path, iface, method, args=None, reply=None):
        return self.bus.call_sync(dest, path, iface, method, args, reply,
                                  Gio.DBusCallFlags.NONE, TIMEOUT, None)

    def call(self, path, iface, method, args=None, reply=None):
        return self.call_at(SERVICE, path, iface, method, args, reply)

    def try_call(self, path, iface, method, args=None, reply=None):
        try:
            return self.call(path, iface, method, args, reply)
        except GLib.Error:
            return None

    def get_all(self, path, iface):
        r = self.try_call(path, PROPS_IFACE, "GetAll",
                          GLib.Variant("(s)", (iface,)),
                          GLib.VariantType("(a{sv})"))
        return r.unpack()[0] if r else {}

    def set_prop(self, path, iface, name, variant):
        return self.try_call(path, PROPS_IFACE, "Set",
                             GLib.Variant("(ssv)", (iface, name, variant)))

    # kdeconnect's numeric properties are int on some builds and qint64 on
    # others, and a mismatched signature is simply refused, so try both
    def set_number(self, path, iface, name, value):
        for code in ("x", "i", "u", "d"):
            if self.set_prop(path, iface, name, GLib.Variant(code, value)) is not None:
                return True
        return False

    def call_number(self, path, iface, method, prefix, value):
        for code in ("i", "x", "u", "d"):
            args = GLib.Variant("(%s%s)" % (prefix, code),
                                tuple(list(prefix and [value[0]] or []) + [value[-1]]))
            if self.try_call(path, iface, method, args) is not None:
                return True
        return False

    def children(self, path):
        r = self.try_call(path, "org.freedesktop.DBus.Introspectable", "Introspect")
        if not r:
            return []
        xml = r.unpack()[0]
        # only direct children, and only the <node name=".."/> stubs
        return re.findall(r'<node name="([^"/]+)"\s*/>', xml)

    def device_path(self, dev_id):
        return "%s/devices/%s" % (DAEMON_PATH, dev_id)

    # ------------------------------------------------------------- snapshot

    def plugin_state(self, base, nodes):
        out = {}
        if "battery" in nodes:
            p = self.get_all(base + "/battery", PLUGIN_IFACE % "battery")
            if p:
                out["battery"] = {
                    "charge": p.get("charge", -1),
                    "charging": bool(p.get("isCharging", False)),
                }
        if "connectivity_report" in nodes:
            p = self.get_all(base + "/connectivity_report",
                             PLUGIN_IFACE % "connectivity_report")
            if p:
                out["signal"] = {
                    "type": p.get("cellularNetworkType", ""),
                    "strength": p.get("cellularNetworkStrength", -1),
                }
        if "lockdevice" in nodes:
            p = self.get_all(base + "/lockdevice", PLUGIN_IFACE % "lockdevice")
            if p:
                out["locked"] = bool(p.get("isLocked", False))
        if "sftp" in nodes:
            r = self.try_call(base + "/sftp", PLUGIN_IFACE % "sftp", "isMounted",
                              None, GLib.VariantType("(b)"))
            mounted = bool(r.unpack()[0]) if r else False
            point = ""
            if mounted:
                m = self.try_call(base + "/sftp", PLUGIN_IFACE % "sftp",
                                  "mountPoint", None, GLib.VariantType("(s)"))
                point = m.unpack()[0] if m else ""
            out["sftp"] = {"mounted": mounted, "point": point}
        if "remotecommands" in nodes:
            p = self.get_all(base + "/remotecommands",
                             PLUGIN_IFACE % "remotecommands")
            raw = p.get("commands", "")
            try:
                parsed = json.loads(raw) if raw else {}
            except ValueError:
                parsed = {}
            out["commands"] = [
                {"key": k, "name": v.get("name", k), "cmd": v.get("command", "")}
                for k, v in parsed.items()
            ]
        if "share" in nodes:
            p = self.get_all(base + "/share", PLUGIN_IFACE % "share")
            out["share"] = {"dest": p.get("destUrl", "")}
        if "mprisremote" in nodes:
            p = self.get_all(base + "/mprisremote", PLUGIN_IFACE % "mprisremote")
            if p:
                out["mpris"] = {
                    "player": p.get("player", ""),
                    "players": list(p.get("playerList", [])),
                    "playing": bool(p.get("isPlaying", False)),
                    "title": p.get("title", ""),
                    "artist": p.get("artist", ""),
                    "album": p.get("album", ""),
                    "length": int(p.get("length", 0) or 0),
                    "position": int(p.get("position", 0) or 0),
                    "volume": int(p.get("volume", -1) or -1),
                    "canSeek": bool(p.get("canSeek", False)),
                    "art": p.get("albumArtUrl", "") or p.get("localAlbumArtUrl", ""),
                }
        if "remotesystemvolume" in nodes:
            r = self.try_call(base + "/remotesystemvolume",
                              PLUGIN_IFACE % "remotesystemvolume", "sinks",
                              None, GLib.VariantType("(s)"))
            try:
                out["sinks"] = json.loads(r.unpack()[0]) if r else []
            except ValueError:
                out["sinks"] = []
        if "remotekeyboard" in nodes:
            p = self.get_all(base + "/remotekeyboard",
                             PLUGIN_IFACE % "remotekeyboard")
            out["keyboard"] = bool(p.get("remoteState", False))
        if "notifications" in nodes:
            out["notifications"] = self.notifications(base)
        return out

    def notifications(self, base):
        r = self.try_call(base + "/notifications",
                          PLUGIN_IFACE % "notifications", "activeNotifications",
                          None, GLib.VariantType("(as)"))
        if not r:
            return []
        out = []
        iface = PLUGIN_IFACE % "notifications" + ".notification"
        for nid in r.unpack()[0]:
            p = self.get_all(base + "/notifications/" + nid, iface)
            if not p:
                continue
            out.append({
                "id": nid,
                "app": p.get("appName", ""),
                "title": p.get("title", ""),
                "text": p.get("text", ""),
                "ticker": p.get("ticker", ""),
                "icon": p.get("iconPath", "") if p.get("hasIcon", False) else "",
                "dismissable": bool(p.get("dismissable", False)),
                "replyId": p.get("replyId", ""),
                "silent": bool(p.get("silent", False)),
            })
        return out

    def snapshot(self):
        if not self.present:
            return {"t": "state", "running": False, "devices": [],
                    "selfId": "", "selfName": "", "backends": [], "requests": []}

        r = self.try_call(DAEMON_PATH, DAEMON_IFACE, "devices", None,
                          GLib.VariantType("(as)"))
        ids = r.unpack()[0] if r else []

        devices = []
        for dev_id in ids:
            base = self.device_path(dev_id)
            p = self.get_all(base, DEVICE_IFACE)
            if not p:
                continue
            reachable = bool(p.get("isReachable", False))
            nodes = self.children(base) if reachable else []
            loaded = self.try_call(base, DEVICE_IFACE, "loadedPlugins", None,
                                   GLib.VariantType("(as)"))
            dev = {
                "id": dev_id,
                "name": p.get("name", dev_id),
                "type": p.get("type", "unknown"),
                "reachable": reachable,
                "paired": bool(p.get("isPaired", False)),
                "pairRequested": bool(p.get("isPairRequested", False)),
                "pairRequestedByPeer": bool(p.get("isPairRequestedByPeer", False)),
                "pairState": p.get("pairState", 0),
                "key": p.get("verificationKey", ""),
                "addresses": list(p.get("reachableAddresses", [])),
                "links": list(p.get("activeProviderNames", [])),
                "supported": sorted(p.get("supportedPlugins", [])),
                "loaded": sorted(loaded.unpack()[0]) if loaded else [],
                "plugins": nodes,
            }
            dev.update(self.plugin_state(base, nodes))
            devices.append(dev)

        devices.sort(key=lambda d: (not d["reachable"], not d["paired"],
                                    d["name"].lower()))

        name = self.try_call(DAEMON_PATH, DAEMON_IFACE, "announcedName", None,
                             GLib.VariantType("(s)"))
        self_id = self.try_call(DAEMON_PATH, DAEMON_IFACE, "selfId", None,
                                GLib.VariantType("(s)"))
        daemon = self.get_all(DAEMON_PATH, DAEMON_IFACE)
        lp = self.try_call(DAEMON_PATH, DAEMON_IFACE, "linkProviders", None,
                           GLib.VariantType("(as)"))
        backends = []
        for entry in (lp.unpack()[0] if lp else []):
            bits = entry.split("|")
            if len(bits) >= 3:
                backends.append({"name": bits[0], "enabled": bits[2] == "enabled"})

        return {
            "t": "state",
            "running": True,
            "selfId": self_id.unpack()[0] if self_id else "",
            "selfName": name.unpack()[0] if name else "",
            "backends": backends,
            "requests": list(daemon.get("pairingRequests", []) or []),
            "devices": devices,
        }

    def push(self):
        self.pending = None
        try:
            snap = self.snapshot()
        except GLib.Error as e:
            emit({"t": "error", "msg": str(e)})
            return False
        line = json.dumps(snap)
        if line != self.last:
            self.last = line
            sys.stdout.write(line + "\n")
            sys.stdout.flush()
        return False

    def schedule(self, delay=180):
        if self.pending is not None:
            GLib.source_remove(self.pending)
        self.pending = GLib.timeout_add(delay, self.push)

    # ------------------------------------------------------------- watching

    def on_signal(self, *_a):
        self.schedule()

    def watch(self):
        # one net cast: anything the service says is a reason to re-read it
        for iface in (DAEMON_IFACE, PROPS_IFACE, None):
            self.subs.append(self.bus.signal_subscribe(
                SERVICE, iface, None, None, None,
                Gio.DBusSignalFlags.NONE, self.on_signal))

        def appeared(_c, _n, _owner):
            self.present = True
            self.schedule(60)

        def vanished(_c, _n):
            self.present = False
            self.schedule(60)

        Gio.bus_watch_name_on_connection(
            self.bus, SERVICE, Gio.BusNameWatcherFlags.AUTO_START,
            appeared, vanished)

    # ------------------------------------------------------------- commands

    # ------------------------------------------------------------ file picker

    def pick_files(self, dev_id, title):
        """Open the desktop's own file chooser, then hand the picks to the phone."""
        token = "lucid%d" % (GLib.get_monotonic_time() % 100000)
        who = self.bus.get_unique_name()[1:].replace(".", "_")
        path = "/org/freedesktop/portal/desktop/request/%s/%s" % (who, token)

        def responded(_c, _s, _p, _i, _sig, params):
            self.bus.signal_unsubscribe(sub)
            code, results = params.unpack()
            if code != 0:
                return
            uris = results.get("uris", [])
            if uris:
                self.try_call(self.device_path(dev_id) + "/share",
                              PLUGIN_IFACE % "share", "shareUrls",
                              GLib.Variant("(as)", (uris,)))
                emit({"t": "sent", "id": dev_id, "count": len(uris)})

        sub = self.bus.signal_subscribe(
            "org.freedesktop.portal.Desktop", "org.freedesktop.portal.Request",
            "Response", path, None, Gio.DBusSignalFlags.NONE, responded)

        opts = {
            "handle_token": GLib.Variant("s", token),
            "multiple": GLib.Variant("b", True),
            "modal": GLib.Variant("b", False),
        }
        try:
            self.call_at("org.freedesktop.portal.Desktop",
                         "/org/freedesktop/portal/desktop",
                         "org.freedesktop.portal.FileChooser", "OpenFile",
                         GLib.Variant("(ssa{sv})", ("", title, opts)),
                         GLib.VariantType("(o)"))
        except GLib.Error as e:
            self.bus.signal_unsubscribe(sub)
            emit({"t": "error", "msg": "no file chooser is available (%s)" % e.message})

    def handle(self, msg):
        c = msg.get("c", "")
        dev_id = msg.get("id", "")
        base = self.device_path(dev_id) if dev_id else ""
        s = lambda v: GLib.Variant("(s)", (v,))  # noqa: E731

        if c == "refresh":
            self.schedule(10)
        elif c == "rescan":
            self.try_call(DAEMON_PATH, DAEMON_IFACE, "forceOnNetworkChange")
            self.schedule(700)
        elif c == "pair":
            self.try_call(base, DEVICE_IFACE, "requestPairing")
        elif c == "unpair":
            self.try_call(base, DEVICE_IFACE, "unpair")
        elif c == "accept":
            self.try_call(base, DEVICE_IFACE, "acceptPairing")
        elif c == "cancel":
            self.try_call(base, DEVICE_IFACE, "cancelPairing")
        elif c == "ring":
            self.try_call(base + "/findmyphone", PLUGIN_IFACE % "findmyphone", "ring")
        elif c == "ping":
            text = msg.get("text", "")
            if text:
                self.try_call(base + "/ping", PLUGIN_IFACE % "ping", "sendPing", s(text))
            else:
                self.try_call(base + "/ping", PLUGIN_IFACE % "ping", "sendPing")
        elif c == "clipboard":
            self.try_call(base + "/clipboard", PLUGIN_IFACE % "clipboard",
                          "sendClipboard")
        elif c == "sharetext":
            self.try_call(base + "/share", PLUGIN_IFACE % "share", "shareText",
                          s(msg.get("text", "")))
        elif c == "shareurl":
            self.try_call(base + "/share", PLUGIN_IFACE % "share", "shareUrl",
                          s(msg.get("url", "")))
        elif c == "lock":
            self.set_prop(base + "/lockdevice", PLUGIN_IFACE % "lockdevice",
                          "isLocked", GLib.Variant("b", bool(msg.get("v", True))))
        elif c == "mount":
            self.try_call(base + "/sftp", PLUGIN_IFACE % "sftp", "mount")
            self.schedule(1500)
        elif c == "unmount":
            self.try_call(base + "/sftp", PLUGIN_IFACE % "sftp", "unmount")
            self.schedule(700)
        elif c == "browse":
            self.try_call(base + "/sftp", PLUGIN_IFACE % "sftp", "startBrowsing")
        elif c == "plugin":
            self.try_call(base, DEVICE_IFACE, "setPluginEnabled",
                          GLib.Variant("(sb)", (msg.get("name", ""),
                                                bool(msg.get("v", True)))))
            self.schedule(400)
        elif c == "runcmd":
            self.try_call(base + "/remotecommands", PLUGIN_IFACE % "remotecommands",
                          "triggerCommand", s(msg.get("key", "")))
        elif c == "sms":
            self.try_call(base + "/sms", PLUGIN_IFACE % "sms", "launchApp")
        elif c == "setname":
            self.try_call(DAEMON_PATH, DAEMON_IFACE, "setAnnouncedName",
                          s(msg.get("name", "")))
            self.schedule(300)
        elif c == "pickfiles":
            self.pick_files(dev_id, msg.get("title", "Send to your device"))
        elif c == "sharefiles":
            self.try_call(base + "/share", PLUGIN_IFACE % "share", "shareUrls",
                          GLib.Variant("(as)", (msg.get("uris", []),)))
        elif c == "opendest":
            self.try_call(base + "/share", PLUGIN_IFACE % "share",
                          "openDestinationFolder")
        elif c == "mpris":
            mp = base + "/mprisremote"
            iface = PLUGIN_IFACE % "mprisremote"
            act = msg.get("action", "")
            if act == "player":
                self.set_prop(mp, iface, "player",
                              GLib.Variant("s", msg.get("name", "")))
            elif act == "volume":
                self.set_number(mp, iface, "volume", int(msg.get("v", 0)))
            elif act == "position":
                self.set_number(mp, iface, "position", int(msg.get("v", 0)))
            elif act == "seek":
                self.call_number(mp, iface, "seek", "", (int(msg.get("v", 0)),))
            elif act == "refresh":
                self.try_call(mp, iface, "requestPlayerList")
            else:
                self.try_call(mp, iface, "sendAction", s(act))
            self.schedule(500)
        elif c == "sinkvolume":
            self.call_number(base + "/remotesystemvolume",
                             PLUGIN_IFACE % "remotesystemvolume", "sendVolume",
                             "s", (msg.get("name", ""), int(msg.get("v", 0))))
            self.schedule(500)
        elif c == "sinkmute":
            self.try_call(base + "/remotesystemvolume",
                          PLUGIN_IFACE % "remotesystemvolume", "sendMuted",
                          GLib.Variant("(sb)", (msg.get("name", ""),
                                                bool(msg.get("v", False)))))
            self.schedule(500)
        elif c == "dismiss":
            self.try_call(base + "/notifications/" + msg.get("nid", ""),
                          PLUGIN_IFACE % "notifications" + ".notification",
                          "dismiss")
            self.schedule(300)
        elif c == "notifreply":
            self.try_call(base + "/notifications/" + msg.get("nid", ""),
                          PLUGIN_IFACE % "notifications" + ".notification",
                          "sendReply", s(msg.get("text", "")))
        elif c == "cursor":
            self.try_call(base + "/remotecontrol", PLUGIN_IFACE % "remotecontrol",
                          "moveCursor",
                          GLib.Variant("((ii))", ((int(msg.get("dx", 0)),
                                                   int(msg.get("dy", 0))),)))
        elif c == "click":
            self.try_call(base + "/remotecontrol", PLUGIN_IFACE % "remotecontrol",
                          "sendCommand",
                          GLib.Variant("(sb)", (msg.get("name", "singleclick"),
                                                True)))
        elif c == "key":
            self.try_call(base + "/remotekeyboard",
                          PLUGIN_IFACE % "remotekeyboard", "sendKeyPress",
                          GLib.Variant("(sibbbb)", (msg.get("text", ""),
                                                    int(msg.get("special", 0)),
                                                    bool(msg.get("shift", False)),
                                                    bool(msg.get("ctrl", False)),
                                                    bool(msg.get("alt", False)),
                                                    True)))
        elif c == "backend":
            self.try_call(DAEMON_PATH, DAEMON_IFACE, "setLinkProviderState",
                          GLib.Variant("(sb)", (msg.get("name", ""),
                                                bool(msg.get("v", True)))))
            self.schedule(400)
        return False

    def reader(self):
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                msg = json.loads(line)
            except ValueError:
                continue
            GLib.idle_add(self.handle, msg)
        GLib.idle_add(lambda: loop.quit())


bridge = Bridge()
loop = GLib.MainLoop()
bridge.watch()
threading.Thread(target=bridge.reader, daemon=True).start()
bridge.schedule(40)
try:
    loop.run()
except KeyboardInterrupt:
    pass
