#!/usr/bin/env python3
# lumen's file daemon: one long-running process the window talks to in json lines.
# requests come in on stdin as {"id": n, "op": ...}; replies go out carrying the same
# id, and events ({"ev": ...}) whenever a watched folder, a job or a drive changes.
# the gio plumbing the desktop already trusts (theme lookup, thumbnails, naming) is
# imported from luciddesktop/desktop-icons.py rather than copied
import collections
import contextlib
import ctypes
import errno
import fnmatch
import hashlib
import importlib.util
import io
import json
import os
import pwd
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
import urllib.parse
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("desk", os.path.join(HERE, "..", "luciddesktop", "desktop-icons.py"))
dk = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(dk)
Gio, GLib = dk.Gio, dk.GLib
try:
    import gi
    gi.require_version("GdkPixbuf", "2.0")
    from gi.repository import GdkPixbuf
except (ImportError, ValueError):
    GdkPixbuf = None

ATTRS = dk.ATTRS + ",standard::target-uri,trash::orig-path,trash::deletion-date,owner::user,access::can-write,access::can-rename,access::can-delete,access::can-trash"
BATCH = 300
SEARCH_LIMIT = 3000
OUT = threading.Lock()
# gvfs shows every share it mounts here as well, as folders any app can open
REMOTE_ROOT = os.path.join(GLib.get_user_runtime_dir(), "gvfs")
# what to install for an address gio can't reach yet
SCHEME_PACKAGES = {"smb": "gvfs-smb", "dav": "gvfs-dnssd", "davs": "gvfs-dnssd", "dns-sd": "gvfs-dnssd",
                   "nfs": "gvfs-nfs", "wsdd": "gvfs-wsdd", "afc": "gvfs-afc", "mtp": "gvfs-mtp",
                   "google-drive": "gvfs-google", "onedrive": "gvfs-onedrive"}
NETWORK_SCHEMES = ("smb", "sftp", "ftp", "ftps", "ftpis", "dav", "davs", "nfs", "afp", "http", "https")
# a share's mount folder names its address: sftp:host=example.com,user=bob
FUSE_SCHEMES = {"sftp": "sftp", "ftp": "ftp", "ftps": "ftps", "ftpis": "ftpis", "smb-share": "smb", "nfs": "nfs",
                "afp-volume": "afp"}


def is_remote(path):
    return path.startswith(REMOTE_ROOT + "/") or ("://" in path and not path.startswith(("file:", "trash:", "recent:")))


def fuse_uri(path):
    """the address a share's folder path stands for, mounted or not"""
    if not path.startswith(REMOTE_ROOT + "/"):
        return ""
    spec, _, rest = path[len(REMOTE_ROOT) + 1:].partition("/")
    kind, _, args = spec.partition(":")
    kv = {}
    for part in args.split(","):
        k, _, val = part.partition("=")
        kv[k] = urllib.parse.unquote(val)
    scheme = FUSE_SCHEMES.get(kind, "")
    if kind == "dav":
        scheme = "davs" if kv.get("ssl") == "true" else "dav"
    host = kv.get("host") or kv.get("server") or ""
    if not scheme or not host:
        return ""
    q = urllib.parse.quote
    netloc = (q(kv["domain"], safe="") + ";" if kv.get("domain") else "") + (q(kv["user"], safe="") + "@" if kv.get("user") else "")
    netloc += ("[%s]" % host if ":" in host else host) + (":" + kv["port"] if kv.get("port") else "")
    prefix = "/" + kv["share"] if kv.get("share") else kv.get("prefix", "").rstrip("/")
    if kv.get("volume"):
        prefix = "/" + kv["volume"]
    return scheme + "://" + netloc + q(prefix) + "/" + q(rest)


def browsing(uri):
    # a list of places to connect to rather than files: the network, a
    # windows server's shares. these are listed by address, never as a folder
    scheme = uri.split(":", 1)[0]
    if scheme in ("network", "dns-sd", "wsdd"):
        return True
    return scheme == "smb" and urllib.parse.urlsplit(uri).path.strip("/") == ""


def remote_label(uri):
    # a share's folder by its own name, a server's top by the server's
    u = urllib.parse.urlsplit(uri)
    tail = urllib.parse.unquote(u.path.rstrip("/").rpartition("/")[2])
    return tail or u.hostname or uri


ICON_CACHE = os.path.join(GLib.get_user_cache_dir(), "lucid", "lumen-icons")
_flat = {}


def flat_icon(path, px=256):
    """an svg icon drawn once by librsvg into a png, the way gtk apps see it: qt's
    own renderer paints filters, and gradients that borrow another's stops, as
    black. anything else passes straight through"""
    if not path or not path.endswith(".svg") or GdkPixbuf is None:
        return path
    hit = _flat.get((path, px))
    if hit is not None:
        return hit or path
    out = ""
    try:
        st = os.stat(path)
        key = "%s:%d:%d" % (os.path.realpath(path), st.st_mtime_ns, px)
        out = os.path.join(ICON_CACHE, hashlib.sha1(key.encode()).hexdigest()[:20] + ".png")
        if not os.path.exists(out):
            os.makedirs(ICON_CACHE, exist_ok=True)
            GdkPixbuf.Pixbuf.new_from_file_at_size(path, px, px).savev(out + ".tmp", "png", [], [])
            os.replace(out + ".tmp", out)
    except (OSError, GLib.Error):
        out = ""
    _flat[(path, px)] = out
    return out or path


# the sidebar's places in an icon theme, for legacy icons: each slot's names, best first
SLOT_NAMES = {
    "folder": ["folder"], "folder-home": ["user-home", "folder-home"], "folder-desktop": ["user-desktop", "folder-desktop"],
    "folder-documents": ["folder-documents"], "folder-download": ["folder-download"], "folder-music": ["folder-music"],
    "folder-pictures": ["folder-pictures"], "folder-videos": ["folder-videos"], "folder-templates": ["folder-templates"],
    "folder-public": ["folder-publicshare"], "folder-remote": ["folder-remote", "network-workgroup"],
    "recent": ["document-open-recent", "folder-recent"], "trash": ["user-trash"],
    "trash-full": ["user-trash-full", "user-trash"], "computer": ["computer"], "drive": ["drive-harddisk"],
    "drive-usb": ["drive-removable-media-usb", "drive-removable-media"], "drive-optical": ["drive-optical", "media-optical"],
    "phone": ["phone"], "network": ["network-workgroup", "network-server"],
}


def send(obj):
    line = json.dumps(obj, separators=(",", ":"), ensure_ascii=False)
    with OUT:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()


def captured(fn, *args):
    # the desktop helper's one-shot commands print what they made, and sys.exit()
    # when they fail, which inside the main loop would end the daemon
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            fn(*args)
    except SystemExit as e:
        raise RuntimeError(e.code if isinstance(e.code, str) else "it failed") from None
    return buf.getvalue().strip()


# ---- what each file is drawn as: shared with the desktop, in desktop-icons.py

SPECIAL_DIRS, SPECIALS, named_type, slot_for = dk.SPECIAL_DIRS, dk.SPECIALS, dk.named_type, dk.slot_for


# ---- folders you can't read: another user's home, say ------------------------------
#
# a listing turned down for permission comes back with gvfs's admin:// address for
# it to connect to, as a share's does: mounting it runs gvfsd-admin through pkexec,
# so lucid's polkit agent asks for the password, and the folder is read through gvfs.
# nothing else can read it there: an outside thumbnailer or app would be a client of
# its own, with a password prompt of its own. so lumend makes the thumbnails, and the
# preview and whatever opens a file get a private copy it fetched

ADMIN_COPIES = os.path.join(GLib.get_user_cache_dir(), "lucid", "lumen-admin")


def fetch_copy(gf, mtime):
    """a private copy of a file only gio can reach, fetched once per version"""
    os.makedirs(ADMIN_COPIES, mode=0o700, exist_ok=True)
    os.chmod(ADMIN_COPIES, 0o700)
    folder = os.path.join(ADMIN_COPIES, hashlib.md5(gf.get_uri().encode()).hexdigest())
    dest = os.path.join(folder, gf.get_basename())
    try:
        if int(os.stat(dest).st_mtime) == int(mtime):
            return dest
    except OSError:
        pass
    os.makedirs(folder, mode=0o700, exist_ok=True)
    part = dest + ".part"
    gf.copy(Gio.File.new_for_path(part), Gio.FileCopyFlags.OVERWRITE | Gio.FileCopyFlags.NOFOLLOW_SYMLINKS, None, None, None)
    os.chmod(part, 0o600)
    os.utime(part, (mtime, mtime))
    os.replace(part, dest)
    return dest


class AdminThumbs:
    """pictures only gio can reach, decoded here in a thread of their own straight to
    thumbnail size, and kept where every thumbnail is"""

    LIMIT = 64 << 20

    def __init__(self, done):
        self.done = done
        self.mimes = {m for f in GdkPixbuf.Pixbuf.get_formats() for m in f.get_mime_types()} if GdkPixbuf else set()
        self.queue = collections.deque()
        self.tried = set()
        self.cv = threading.Condition()
        self.worker = None

    def can(self, mime):
        return mime in self.mimes

    @staticmethod
    def dest(uri):
        return os.path.join(dk.THUMB_ROOT, "large", hashlib.md5(uri.encode()).hexdigest() + ".png")

    def cached(self, uri, mtime):
        try:
            return self.dest(uri) if os.stat(self.dest(uri)).st_mtime >= mtime else ""
        except OSError:
            return ""

    def want(self, uri, mtime, size):
        if size > self.LIMIT or (uri, mtime) in self.tried:
            return
        self.tried.add((uri, mtime))
        with self.cv:
            self.queue.append((uri, mtime))
            self.cv.notify()
        if self.worker is None:
            self.worker = threading.Thread(target=self.run, daemon=True)
            self.worker.start()

    def run(self):
        while True:
            with self.cv:
                while not self.queue:
                    self.cv.wait()
                uri, mtime = self.queue.popleft()
            path = self.make(uri, mtime)
            if path:
                GLib.idle_add(lambda u=uri, p=path: (self.done(u, p), False)[1])

    def make(self, uri, mtime):
        dest = self.dest(uri)
        try:
            stream = Gio.File.new_for_uri(uri).read(None)
            try:
                pb = GdkPixbuf.Pixbuf.new_from_stream_at_scale(stream, dk.THUMB_SIZE, dk.THUMB_SIZE, True, None)
            finally:
                stream.close(None)
            pb = pb.apply_embedded_orientation() or pb
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            part = dest + ".part"
            pb.savev(part, "png", ["tEXt::Thumb::URI", "tEXt::Thumb::MTime", "tEXt::Software"], [uri, str(mtime), "Lucid"])
            os.replace(part, dest)
            return dest
        except (GLib.Error, OSError):
            return ""

def owner_of(path):
    """whose a folder is, by the nearest part of its path that can be looked at"""
    p = path
    while p and p != "/":
        try:
            uid = os.stat(p).st_uid
            break
        except OSError:
            p = os.path.dirname(p)
    else:
        return ""
    if uid == os.getuid():
        return ""
    try:
        pw = pwd.getpwuid(uid)
    except KeyError:
        return ""
    return pw.pw_gecos.split(",")[0] or pw.pw_name



# ---- the daemon -------------------------------------------------------------------

class View:
    def __init__(self, vid):
        self.vid = vid
        self.path = ""
        self.hidden = False
        self.gen = 0
        self.cancel = None
        self.monitor = None
        self.timer = 0
        self.count = 0
        self.search_gen = 0
        self.remote = False


class Lumen:
    def __init__(self):
        self.views = {}
        self.jobs = {}
        self.next_job = 1
        self.theme = ""
        self.legacy = False
        self.icons = dk.Icons(dk.theme_or_system(""), 64)
        self.app_icons = self.icons
        self.thumbs = Thumbs(self.thumbs_done)
        self.admin_thumbs = AdminThumbs(lambda uri, path: send({"ev": "thumb", "uri": uri, "thumb": path}))
        self.tidy_admin_copies()
        self.volumes = Gio.VolumeMonitor.get()
        for sig in ("mount-added", "mount-removed", "mount-changed", "volume-added", "volume-removed", "volume-changed"):
            self.volumes.connect(sig, lambda *_: self.later("volumes", 250, self.volumes_moved))
        # gio's monitor skips mounts it doesn't show, like a windows partition in /mnt
        self.unix_mounts = None
        try:
            import gi
            gi.require_version("GioUnix", "2.0")
            from gi.repository import GioUnix
            self.unix_mounts = GioUnix.MountMonitor.get()
            self.unix_mounts.connect("mounts-changed", lambda *_: self.later("volumes", 250, self.emit_volumes))
        except (ImportError, ValueError, AttributeError):
            pass
        self.system = self.system_name()
        self.sent_volumes = ""
        # a share's room, asked for in the background: {root uri: {free, total}}
        self.remote_space = {}
        # connections being made, by the request that asked: {uri, op, cancel, asked, hops}
        self.connects = {}
        self.remote_thumbs = RemoteThumbs(self.thumbs)
        # free space moves with every write: checked now and then, sent when it changed
        GLib.timeout_add_seconds(20, self.poll_volumes)
        self.timers = {}
        self.watch_static()
        self.portal = None

    # -- plumbing

    def later(self, key, ms, fn):
        if self.timers.get(key):
            GLib.source_remove(self.timers[key])

        def run():
            self.timers[key] = 0
            fn()
            return False
        self.timers[key] = GLib.timeout_add(ms, run)

    def watch_static(self):
        self.static = []
        targets = [(os.path.join(GLib.get_user_data_dir(), "Trash", "files"), lambda: self.later("trash", 300, self.emit_trash)),
                   (os.path.join(GLib.get_user_config_dir(), "gtk-3.0"), lambda: self.later("bookmarks", 300, self.emit_bookmarks))]
        for path, fn in targets:
            try:
                os.makedirs(path, exist_ok=True)
                m = Gio.File.new_for_path(path).monitor_directory(Gio.FileMonitorFlags.NONE, None)
                m.connect("changed", lambda *_a, f=fn: f())
                self.static.append(m)
            except (GLib.Error, OSError):
                pass

    def handle(self, req):
        op = req.get("op", "")
        fn = getattr(self, "op_" + op.replace("-", "_"), None)
        rid = req.get("id")
        if fn is None:
            send({"id": rid, "ok": False, "error": "unknown op " + op})
            return
        try:
            out = fn(req)
            if out is not None:
                out.setdefault("ok", True)
                out["id"] = rid
                send(out)
        except Exception as e:  # noqa: BLE001 - every failure goes back to the window
            send({"id": rid, "ok": False, "error": str(e)})
        if op in self.CHANGES:
            self.later("unwatched", 250, self.relist_unwatched)

    # what changes a folder. a share can't be watched (gvfs has no monitor for
    # sftp, smb or ftp), so a view on one looks again after each of these
    CHANGES = ("mkdir", "newFile", "rename", "link", "compress", "extract", "trash", "restore", "delete",
               "pasteImage")

    def relist_unwatched(self):
        try:
            live = set(os.listdir(REMOTE_ROOT))
        except OSError:
            live = set()
        for v in list(self.views.values()):
            if not v.path or v.monitor is not None or v.path.startswith(("recent:", "network:")) or "://" in v.path:
                continue
            if v.path.startswith(REMOTE_ROOT + "/") and v.path[len(REMOTE_ROOT) + 1:].split("/")[0] not in live:
                continue
            self.start_list(v)

    # -- hello

    def op_hello(self, req):
        self.set_theme(req.get("iconTheme", ""))
        self.legacy = req.get("legacy", False) is True
        home = GLib.get_home_dir()
        real = GLib.get_real_name()
        return {"home": home, "user": real if real and real != "Unknown" else GLib.get_user_name(), "places": self.places(),
                "bookmarks": self.bookmarks(), "volumes": self.volume_list(), "system": self.system, "trash": self.trash_count(),
                "slotIcons": self.slot_icons(), "remoteRoot": REMOTE_ROOT, "schemes": self.schemes(),
                "desktop": dk.desktop_dir(), "templates": dk.templates_dir() or ""}

    def set_theme(self, name):
        if name != self.theme:
            self.theme = name
            self.icons = dk.Icons(dk.theme_or_system(name), 64)

    def op_theme(self, req):
        self.set_theme(req.get("iconTheme", ""))
        self.legacy = req.get("legacy", False) is True
        return {"slotIcons": self.slot_icons()}

    def slot_icons(self):
        return {slot: flat_icon(self.icons.find(names) or "", 96) for slot, names in SLOT_NAMES.items()}

    def places(self):
        out = []
        home = os.path.realpath(GLib.get_home_dir())
        for kind, slot, label, glyph in SPECIAL_DIRS:
            d = GLib.get_user_special_dir(kind)
            if not d or os.path.realpath(d) == home or not os.path.isdir(d):
                continue
            out.append({"path": d, "label": os.path.basename(d) or label, "slot": slot, "glyph": glyph})
        return out

    # -- listing

    def view(self, vid):
        v = self.views.get(vid)
        if v is None:
            v = self.views[vid] = View(vid)
        return v

    def op_list(self, req):
        v = self.view(req["view"])
        v.path = req.get("path") or GLib.get_home_dir()
        v.hidden = bool(req.get("hidden"))
        self.start_list(v)
        return None

    def op_unwatch(self, req):
        v = self.views.pop(req["view"], None)
        if v:
            if v.cancel:
                v.cancel.cancel()
            v.monitor = None
            v.search_gen += 1
        return None

    def start_list(self, v):
        v.gen += 1
        if v.cancel:
            v.cancel.cancel()
        v.cancel = Gio.Cancellable()
        v.monitor = None
        v.count = 0
        if v.path.startswith("recent:"):
            self.list_recent(v)
            return
        gfile = Gio.File.new_for_uri(v.path) if "://" in v.path else Gio.File.new_for_path(v.path)
        gen = v.gen
        gfile.enumerate_children_async(ATTRS, Gio.FileQueryInfoFlags.NONE, GLib.PRIORITY_DEFAULT, v.cancel,
                                       self.on_enum, (v, gen, gfile))

    def on_enum(self, src, res, data):
        v, gen, gfile = data
        if gen != v.gen:
            return
        try:
            en = src.enumerate_children_finish(res)
        except GLib.Error as e:
            # someone else's folder: the window connects to it as gvfs's admin://, which
            # asks for the password, and lists it from there
            if e.matches(Gio.io_error_quark(), Gio.IOErrorEnum.PERMISSION_DENIED) and "://" not in v.path \
                    and "admin" in self.schemes():
                admin = Gio.File.new_for_path(v.path).get_uri().replace("file://", "admin://", 1)
                send({"ev": "list", "view": v.vid, "gen": gen, "path": v.path, "reset": True, "items": []})
                send({"ev": "listDone", "view": v.vid, "gen": gen, "path": v.path, "count": 0, "error": e.message,
                      "connect": admin, "owner": owner_of(v.path)})
                return
            if not e.matches(Gio.io_error_quark(), Gio.IOErrorEnum.CANCELLED):
                # a share not connected (now, or since the last login): the window
                # connects to its address and comes back
                again = ""
                if e.matches(Gio.io_error_quark(), Gio.IOErrorEnum.NOT_MOUNTED):
                    again = v.path
                elif v.path.startswith(REMOTE_ROOT + "/"):
                    # a share gone stays a folder to stat for a while; the list knows
                    try:
                        live = os.listdir(REMOTE_ROOT)
                    except OSError:
                        live = []
                    if v.path[len(REMOTE_ROOT) + 1:].split("/")[0] not in live:
                        again = fuse_uri(v.path)
                msg = e.message
                scheme = v.path.split(":", 1)[0] if "://" in v.path else ""
                if scheme and scheme not in self.schemes():
                    msg = self.unreachable(scheme)
                send({"ev": "list", "view": v.vid, "gen": gen, "path": v.path, "reset": True, "items": [], "error": msg,
                      "connect": again})
                send({"ev": "listDone", "view": v.vid, "gen": gen, "path": v.path, "count": 0, "error": msg,
                      "connect": again})
            return
        # an address already connected: its folder, which every app can open
        if "://" in v.path and is_remote(v.path) and not browsing(v.path):
            local = gfile.get_path()
            if local:
                en.close_async(GLib.PRIORITY_DEFAULT, None, None)
                send({"ev": "listDone", "view": v.vid, "gen": gen, "path": v.path, "count": 0, "redirect": local})
                return
        hidden = dk.hidden_list(v.path) if "://" not in v.path else set()
        v.remote = is_remote(v.path)
        en.next_files_async(BATCH, GLib.PRIORITY_DEFAULT, v.cancel, self.on_batch, (v, gen, gfile, en, True, hidden))

    def on_batch(self, en, res, data):
        v, gen, gfile, _, first, hidden = data
        if gen != v.gen:
            return
        try:
            infos = en.next_files_finish(res)
        except GLib.Error:
            infos = []
        items = []
        for info in infos:
            # some servers leave these out, and gio's getters complain at a missing one
            for attr in ("standard::is-hidden", "standard::is-backup"):
                if not info.has_attribute(attr):
                    info.set_attribute_boolean(attr, False)
            if not v.hidden and (info.get_is_hidden() or info.get_is_backup() or info.get_name() in hidden):
                continue
            items.append(self.item(v.path, info, hidden))
        if items or first:
            send({"ev": "list", "view": v.vid, "gen": gen, "path": v.path, "reset": first, "items": items})
        v.count += len(items)
        if infos:
            en.next_files_async(BATCH, GLib.PRIORITY_DEFAULT, v.cancel, self.on_batch, (v, gen, gfile, en, False, hidden))
            return
        en.close_async(GLib.PRIORITY_DEFAULT, None, None)
        send({"ev": "listDone", "view": v.vid, "gen": gen, "path": v.path, "count": v.count, "free": self.space_of(v.path),
              "writable": self.writable(gfile), "remote": v.remote})
        try:
            v.monitor = gfile.monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
            v.monitor.connect("changed", lambda *_a: self.later("view:" + v.vid, 300, lambda: self.start_list(v)))
        except GLib.Error:
            v.monitor = None

    def item(self, folder, info, hidden=()):
        trash = folder.startswith("trash:")
        if trash:
            name = info.get_name()
            orig = info.get_attribute_byte_string("trash::orig-path") or ""
            ctype = info.get_content_type() or ""
            is_dir = info.get_file_type() == Gio.FileType.DIRECTORY
            uri = Gio.File.new_for_uri(folder).get_child(name).get_uri()
            it = {"name": name, "label": info.get_display_name() or name, "path": "", "uri": uri,
                  "kind": "dir" if is_dir else "file", "mime": "inode/directory" if is_dir else ctype,
                  "desc": Gio.content_type_get_description(ctype) if ctype else "", "icon": "", "thumb": "",
                  "canThumb": False, "size": info.get_size(), "mtime": info.get_attribute_uint64("time::modified"),
                  "link": False, "hidden": False, "exec": False, "tags": [], "orig": orig,
                  "deleted": info.get_attribute_as_string("trash::deletion-date") or ""}
            it["slot"] = slot_for(dict(it, path=""))
            it["icon"] = self.icons.find(dk.icon_names(info.get_icon()) or ["text-x-generic"])
            if self.legacy:
                it["icon"] = flat_icon(it["icon"])
            return it
        local = "://" not in folder
        target = info.get_attribute_string("standard::target-uri") or ""
        if target and info.get_file_type() in (Gio.FileType.MOUNTABLE, Gio.FileType.SHORTCUT) and not target.startswith("file:"):
            return self.shortcut(folder, info, target)
        thumbs = (self.remote_thumbs if folder.startswith(REMOTE_ROOT + "/") else self.thumbs) if local else None
        it = dk.entry(folder if local else (Gio.File.new_for_uri(folder).get_path() or folder), info, self.icons,
                      thumbs, hidden)
        if not local:
            it["uri"] = Gio.File.new_for_uri(folder).get_child(info.get_name()).get_uri()
            # with no fuse folder it has only its address, not a path to hand os
            if "://" in it["path"]:
                it["path"] = ""
            if folder.startswith("admin:") and it["kind"] == "file" and self.admin_thumbs.can(it.get("mime", "")):
                it["thumb"] = self.admin_thumbs.cached(it["uri"], it["mtime"])
                if not it["thumb"]:
                    it["canThumb"] = True
                    self.admin_thumbs.want(it["uri"], it["mtime"], it["size"])
        if it["kind"] != "dir":
            named = named_type(it["name"], it.get("mime") or "")
            if named != it.get("mime"):
                it["desc"] = Gio.content_type_get_description(named)
                it["icon"] = self.icons.find(dk.icon_names(Gio.content_type_get_icon(named)) or []) or it["icon"]
        # gtk icons are only seen in legacy mode, apps' own always
        if self.legacy or it["kind"] == "app":
            it["icon"] = flat_icon(it.get("icon", ""))
        it["slot"] = slot_for(it)
        it["canWrite"] = info.get_attribute_boolean("access::can-write") if info.has_attribute("access::can-write") else True
        return it

    def shortcut(self, folder, info, target):
        # somewhere to connect to: a computer the network found, a server's share
        names = dk.icon_names(info.get_icon())
        slot = "computer" if any("computer" in n or "server" in n for n in names) else "network"
        if any("folder" in n for n in names) or target.count("/") > 3:
            slot = "folder-remote"
        it = {"name": info.get_name(), "label": info.get_display_name() or info.get_name(), "path": "",
              "uri": Gio.File.new_for_uri(folder).get_child(info.get_name()).get_uri() if "://" in folder else target,
              "target": target, "kind": "dir", "mime": "inode/directory", "desc": "Network location",
              "icon": self.icons.find(names or ["folder-remote"]) or "", "thumb": "", "canThumb": False, "size": 0,
              "mtime": 0, "link": False, "hidden": False, "exec": False, "tags": [], "canWrite": False}
        if self.legacy:
            it["icon"] = flat_icon(it["icon"])
        it["slot"] = slot
        return it

    def list_recent(self, v):
        path = os.path.join(GLib.get_user_data_dir(), "recently-used.xbel")
        rows = []
        try:
            for b in ET.parse(path).getroot().iter("bookmark"):
                href = b.get("href") or ""
                if href.startswith("file://"):
                    rows.append((b.get("visited") or b.get("modified") or "", href))
        except (OSError, ET.ParseError):
            pass
        rows.sort(reverse=True)
        items, seen = [], set()
        for _, href in rows:
            if href in seen:
                continue
            seen.add(href)
            gf = Gio.File.new_for_uri(href)
            p = gf.get_path()
            if not p or not os.path.exists(p):
                continue
            try:
                info = gf.query_info(ATTRS, Gio.FileQueryInfoFlags.NONE, None)
            except GLib.Error:
                continue
            items.append(self.item(os.path.dirname(p), info))
            if len(items) >= 200:
                break
        send({"ev": "list", "view": v.vid, "gen": v.gen, "path": v.path, "reset": True, "items": items})
        send({"ev": "listDone", "view": v.vid, "gen": v.gen, "path": v.path, "count": len(items)})

    def space_of(self, path):
        # a share's room is asked for in the background: a dropped connection
        # would hold statvfs, and the daemon with it
        if is_remote(path):
            best, space = "", {"free": 0, "total": 0}
            for root, room in self.remote_space.items():
                rp = Gio.File.new_for_uri(root).get_path() or ""
                if rp and (path == rp or path.startswith(rp + "/")) and len(rp) > len(best):
                    best, space = rp, room
            return dict(space)
        return self.free_of(path)

    def free_of(self, path):
        try:
            st = os.statvfs(path)
            return {"free": st.f_bavail * st.f_frsize, "total": st.f_blocks * st.f_frsize}
        except OSError:
            return {"free": 0, "total": 0}

    def writable(self, gfile):
        try:
            info = gfile.query_info("access::can-write", Gio.FileQueryInfoFlags.NONE, None)
            # a server that doesn't say (ftp) is tried, and says no itself if it must
            if not info.has_attribute("access::can-write"):
                return True
            return info.get_attribute_boolean("access::can-write")
        except GLib.Error:
            return False

    # -- thumbnails

    def thumbs_done(self):
        uri, path = self.thumbs.last
        if uri and path:
            send({"ev": "thumb", "uri": uri, "thumb": path})

    # -- search

    def op_search(self, req):
        v = self.view(req["view"])
        v.search_gen += 1
        gen = v.search_gen
        root = req.get("root") or GLib.get_home_dir()
        query = (req.get("query") or "").strip()
        hidden = bool(req.get("hidden"))
        if not query:
            return None
        threading.Thread(target=self.search_walk, args=(v, gen, root, query, hidden), daemon=True).start()
        return None

    # never walked: the kernel's own trees, and caches nobody looks for files in
    SKIP_ROOTS = ("/proc", "/sys", "/dev", "/run", "/tmp", "/var/tmp", "/var/cache", "/var/lib/pacman/sync",
                  "/lost+found", "/snap")

    def search_walk(self, v, gen, root, query, hidden):
        glob = any(c in query for c in "*?[")
        q = query.lower()
        found, batch, first = 0, [], True
        home = os.path.realpath(GLib.get_home_dir())
        # the whole disk is home first, so your own files lead, then the rest of
        # it. level by level, so what is near the top comes before what is deep,
        # and never onto another disk or a network share mounted under it
        if root == "/":
            queue, skip = collections.deque([home, "/"]), set(self.SKIP_ROOTS) | {home}
            devices = set()
            for r in (home, "/"):
                try:
                    devices.add(os.stat(r).st_dev)
                except OSError:
                    pass
        else:
            queue, skip, devices = collections.deque([root]), set(self.SKIP_ROOTS), None
        t0 = time.time()

        def flush(done=False):
            nonlocal batch, first
            if batch or first:
                send({"ev": "search", "view": v.vid, "gen": gen, "reset": first, "items": batch})
                first = False
                batch = []
            if done:
                send({"ev": "searchDone", "view": v.vid, "gen": gen, "count": found, "truncated": found >= SEARCH_LIMIT})

        while queue and v.search_gen == gen:
            d = queue.popleft()
            try:
                with os.scandir(d) as it:
                    entries = sorted(it, key=lambda e: e.name.lower())
            except OSError:
                continue
            for e in entries:
                if v.search_gen != gen:
                    return
                if not hidden and e.name.startswith("."):
                    continue
                name = e.name.lower()
                hit = fnmatch.fnmatch(name, q) if glob else q in name
                try:
                    is_dir = e.is_dir(follow_symlinks=False)
                except OSError:
                    is_dir = False
                if hit:
                    try:
                        info = Gio.File.new_for_path(e.path).query_info(ATTRS, Gio.FileQueryInfoFlags.NONE, None)
                        it = dk.entry(d, info, self.icons, None, ())
                        it["slot"] = slot_for(it)
                        it["where"] = d
                        batch.append(it)
                        found += 1
                    except GLib.Error:
                        pass
                    if found >= SEARCH_LIMIT:
                        flush(True)
                        return
                    if len(batch) >= 60 or (batch and time.time() - t0 > 0.25):
                        t0 = time.time()
                        flush()
                if is_dir and e.path not in skip:
                    if devices is not None:
                        try:
                            if e.stat(follow_symlinks=False).st_dev not in devices:
                                continue
                        except OSError:
                            continue
                    queue.append(e.path)
        if v.search_gen == gen:
            flush(True)

    # -- opening

    @staticmethod
    def tidy_admin_copies():
        # the copies fetched out of someone else's folders are kept a day
        try:
            names = os.listdir(ADMIN_COPIES)
        except OSError:
            return
        cutoff = time.time() - 86400
        for n in names:
            p = os.path.join(ADMIN_COPIES, n)
            with contextlib.suppress(OSError):
                st = os.lstat(p)
                if max(st.st_mtime, st.st_ctime) < cutoff:
                    shutil.rmtree(p)

    def open_admin(self, rid, uris):
        made, failed = [], ""
        for uri in uris:
            gf = Gio.File.new_for_uri(uri)
            try:
                mtime = gf.query_info("time::modified", Gio.FileQueryInfoFlags.NONE, None).get_attribute_uint64("time::modified")
                made.append(fetch_copy(gf, mtime))
            except (GLib.Error, OSError) as e:
                failed = getattr(e, "message", None) or str(e)

        def launch():
            for dest in made:
                Gio.AppInfo.launch_default_for_uri_async(Gio.File.new_for_path(dest).get_uri(), None, None, None)
            send({"id": rid, "ok": not failed, "copies": len(made), "error": failed})
            return False
        GLib.idle_add(launch)

    def op_open(self, req):
        admin = [u for u in req.get("uris", []) if u.startswith("admin:")]
        if admin:
            threading.Thread(target=self.open_admin, args=(req.get("id"), admin), daemon=True).start()
        for uri in req.get("uris", []):
            if uri.startswith("admin:"):
                continue
            gf = Gio.File.new_for_uri(uri)
            path = gf.get_path() or ""
            if path.endswith(".desktop") and os.access(path, os.X_OK):
                try:
                    app = dk.DesktopAppInfo.new_from_filename(path)
                except TypeError:
                    app = None
                if app is not None:
                    app.launch_uris_async([], None, None, None)
                    continue
            Gio.AppInfo.launch_default_for_uri_async(uri, None, None, None)
        return None if admin else {}

    def op_appsFor(self, req):
        # by the name's type when the file is empty, so a new .pdf offers pdf apps
        try:
            info = Gio.File.new_for_uri(req["uri"]).query_info("standard::content-type,standard::name", Gio.FileQueryInfoFlags.NONE, None)
            ctype = named_type(info.get_name(), info.get_content_type() or "")
        except GLib.Error:
            ctype = ""
        out = []
        if ctype:
            default = Gio.AppInfo.get_default_for_type(ctype, False)
            seen = set()
            apps = ([default] if default else []) + list(Gio.AppInfo.get_recommended_for_type(ctype)) + list(Gio.AppInfo.get_fallback_for_type(ctype))
            for a in apps:
                if a is None or a.get_id() in seen or not a.should_show():
                    continue
                seen.add(a.get_id())
                icon = self.icons.find(dk.icon_names(a.get_icon())) or self.icons.find(["application-x-executable"])
                out.append({"id": a.get_id(), "name": a.get_display_name() or a.get_name(),
                            "file": a.get_filename() if hasattr(a, "get_filename") else "",
                            "icon": flat_icon(icon, 96), "default": default is not None and a.get_id() == default.get_id()})
                if len(out) >= 8:
                    break
        return {"mime": ctype, "apps": out}

    def op_openWith(self, req):
        app = dk.DesktopAppInfo.new(req["app"])
        if app is None:
            raise ValueError("no such app")
        if req.get("makeDefault") and req.get("mime"):
            app.set_as_default_for_type(req["mime"])
        app.launch_uris_async(req.get("uris", []), None, None, None)
        return {}

    def op_terminal(self, req):
        subprocess.Popen(["xdg-terminal-exec", "--dir=" + req["path"]], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {}

    # -- clipboard, as nautilus and the desktop speak it

    def op_clipCopy(self, req):
        uris = req.get("uris", [])
        if req.get("mode") == "cut":
            argv = ["wl-copy", "--type", "x-special/gnome-copied-files", "cut\n" + "\n".join(uris)]
        else:
            argv = ["wl-copy", "--type", "text/uri-list", "\r\n".join(uris) + "\r\n"]
        subprocess.Popen(argv, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {}

    def op_clipClear(self, req):
        subprocess.Popen(["wl-copy", "--clear"], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {}

    def op_clipRead(self, req):
        data = json.loads(captured(dk.clip) or "{}")
        return {"mode": data.get("mode", "copy"), "uris": data.get("uris", []), "image": data.get("image", False)}

    def op_clipText(self, req):
        subprocess.Popen(["wl-copy", "--", req.get("text", "")], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {}

    def op_pasteImage(self, req):
        name = captured(dk.paste_image, self.local_dest(req["dest"]))
        return {"name": name}

    def op_templates(self, req):
        return {"items": dk.templates(self.icons)}

    # -- making and changing things

    # a folder known only by its address (a share gvfs has no fuse folder for):
    # made through gio, never with os, which would take "sftp:" for a folder here
    def uri_unique(self, dest, name):
        folder = Gio.File.new_for_uri(dest)
        stem, dot, ext = name.rpartition(".") if "." in name[1:] else (name, "", "")
        n, out = 1, name
        while folder.get_child(out).query_exists(None):
            n += 1
            out = "%s (%d)%s%s" % (stem, n, dot, ext)
        return out

    def local_dest(self, dest):
        if "://" in dest:
            raise ValueError("Lumen can only do that on this server through gvfs's fuse folder, and gvfsd-fuse isn't running")
        return dest

    def op_mkdir(self, req):
        dest = req["dest"]
        if "://" in dest:
            name = req.get("name") or self.uri_unique(dest, "New Folder")
            gf = Gio.File.new_for_uri(dest).get_child(name)
            gf.make_directory(None)
            return {"path": gf.get_path() or "", "name": name}
        name = req.get("name") or dk.unique(dest, "New Folder")
        path = os.path.join(dest, name)
        os.makedirs(path)
        return {"path": path, "name": name}

    def op_newFile(self, req):
        dest = req["dest"]
        tpl = req.get("template") or ""
        if "://" in dest:
            name = self.uri_unique(dest, os.path.basename(tpl) if tpl else req.get("name") or "New Document.txt")
            gf = Gio.File.new_for_uri(dest).get_child(name)
            if tpl:
                Gio.File.new_for_path(tpl).copy(gf, Gio.FileCopyFlags.NONE, None, None, None)
            else:
                gf.create(Gio.FileCreateFlags.NONE, None).close(None)
            return {"path": gf.get_path() or "", "name": name}
        if tpl:
            name = dk.unique(dest, os.path.basename(tpl))
            dk.copy_any(tpl, os.path.join(dest, name))
        else:
            name = dk.unique(dest, req.get("name") or "New Document.txt")
            open(os.path.join(dest, name), "x").close()
        return {"path": os.path.join(dest, name), "name": name}

    def op_rename(self, req):
        gf = Gio.File.new_for_uri(req["uri"])
        new = gf.set_display_name(req["name"], None)
        return {"uri": new.get_uri(), "path": new.get_path() or ""}

    def op_link(self, req):
        made = []
        for uri in req.get("uris", []):
            src = Gio.File.new_for_uri(uri).get_path()
            if not src:
                continue
            dest = self.local_dest(req.get("dest") or os.path.dirname(src))
            name = dk.free_name(dest, "Link to " + os.path.basename(src))
            os.symlink(src, os.path.join(dest, name))
            made.append(os.path.join(dest, name))
        return {"made": made}

    def op_compress(self, req):
        paths = req.get("paths", [])
        name = captured(dk.compress, paths)
        return {"name": name, "path": os.path.join(os.path.dirname(paths[0]), name) if paths and name else ""}

    def op_extract(self, req):
        # into: always a new folder named after the archive, even for one thing inside
        try:
            name = captured(dk.extract, req["path"], bool(req.get("into")))
        except RuntimeError:
            return {"ok": False, "error": "Could not extract “%s”" % os.path.basename(req["path"])}
        return {"name": name}

    def op_trash(self, req):
        done, failed = [], []
        for uri in req.get("uris", []):
            gf = Gio.File.new_for_uri(uri)
            try:
                gf.trash(None)
                done.append({"uri": uri, "path": gf.get_path() or ""})
            except GLib.Error as e:
                failed.append({"uri": uri, "error": e.message})
        self.later("trash", 200, self.emit_trash)
        return {"done": done, "failed": failed}

    def op_restore(self, req):
        # from the trash view by trash uri, or for an undo by where things came from
        want = set(req.get("paths", []))
        uris = list(req.get("uris", []))
        if want:
            best = {}
            trash = Gio.File.new_for_uri("trash:///")
            for info in trash.enumerate_children("standard::name,trash::orig-path,trash::deletion-date", Gio.FileQueryInfoFlags.NONE, None):
                orig = info.get_attribute_byte_string("trash::orig-path") or ""
                when = info.get_attribute_as_string("trash::deletion-date") or ""
                if orig in want and (orig not in best or when > best[orig][0]):
                    best[orig] = (when, trash.get_child(info.get_name()).get_uri())
            uris += [u for _, u in best.values()]
        restored = []
        for uri in uris:
            gf = Gio.File.new_for_uri(uri)
            info = gf.query_info("trash::orig-path", Gio.FileQueryInfoFlags.NONE, None)
            orig = info.get_attribute_byte_string("trash::orig-path")
            if not orig:
                continue
            dest_dir = os.path.dirname(orig)
            os.makedirs(dest_dir, exist_ok=True)
            target = os.path.join(dest_dir, dk.free_name(dest_dir, os.path.basename(orig)))
            gf.move(Gio.File.new_for_path(target), Gio.FileCopyFlags.NOFOLLOW_SYMLINKS, None, None, None)
            restored.append(target)
        self.later("trash", 200, self.emit_trash)
        return {"restored": restored}

    def op_delete(self, req):
        done, failed = [], []
        for uri in req.get("uris", []):
            gf = Gio.File.new_for_uri(uri)
            path = gf.get_path()
            try:
                if path and os.path.isdir(path) and not os.path.islink(path):
                    shutil.rmtree(path)
                elif path:
                    os.remove(path)
                else:
                    self.delete_tree(gf)
                done.append(uri)
            except (OSError, GLib.Error) as e:
                failed.append({"uri": uri, "error": str(e)})
        self.later("trash", 200, self.emit_trash)
        return {"done": done, "failed": failed}

    def delete_tree(self, gf):
        try:
            kind = gf.query_file_type(Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None)
        except GLib.Error:
            kind = Gio.FileType.UNKNOWN
        if kind == Gio.FileType.DIRECTORY:
            for info in gf.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None):
                self.delete_tree(gf.get_child(info.get_name()))
        gf.delete(None)

    def op_emptyTrash(self, req):
        trash = Gio.File.new_for_uri("trash:///")
        for info in trash.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NONE, None):
            try:
                self.delete_tree(trash.get_child(info.get_name()))
            except GLib.Error:
                pass
        self.later("trash", 200, self.emit_trash)
        return {}

    def trash_count(self):
        try:
            return len(os.listdir(os.path.join(GLib.get_user_data_dir(), "Trash", "files")))
        except OSError:
            return 0

    def emit_trash(self):
        send({"ev": "trash", "count": self.trash_count()})

    # -- copying and moving, as jobs with progress

    def op_transfer(self, req):
        self.local_dest(req["dest"])
        jid = self.next_job
        self.next_job += 1
        job = Job(jid, req.get("mode", "copy"), req.get("uris", []), req["dest"], req.get("tag", ""))
        job.ended = lambda: self.later("unwatched", 250, self.relist_unwatched)
        self.jobs[jid] = job
        job.start()
        return {"job": jid}

    def op_chosen(self, req):
        if self.portal is not None:
            self.portal.finish(req)
        return {}

    def op_cancelJob(self, req):
        job = self.jobs.get(req.get("job"))
        if job:
            job.cancel.cancel()
        return {}

    # -- properties

    def op_info(self, req):
        gf = Gio.File.new_for_uri(req["uri"])
        info = gf.query_info("*", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None)
        path = gf.get_path() or ""
        ctype = named_type(info.get_name(), info.get_content_type() or "")
        mode = info.get_attribute_uint32("unix::mode")
        out = {"name": info.get_display_name(), "path": path, "uri": gf.get_uri(), "mime": ctype,
               "desc": Gio.content_type_get_description(ctype) if ctype else "",
               "size": info.get_size(), "mtime": info.get_attribute_uint64("time::modified"),
               "atime": info.get_attribute_uint64("time::access"), "ctime": info.get_attribute_uint64("time::created") or info.get_attribute_uint64("time::changed"),
               "owner": info.get_attribute_string("owner::user") or "", "group": info.get_attribute_string("owner::group") or "",
               "mode": dk.mode_string(mode) if mode else "", "octal": "%o" % (mode & 0o7777) if mode else "",
               "target": info.get_attribute_byte_string("standard::symlink-target") or "" if info.has_attribute("standard::symlink-target") else "",
               "isDir": info.get_file_type() == Gio.FileType.DIRECTORY,
               "where": os.path.dirname(path)}
        out["slot"] = slot_for({"kind": "dir" if out["isDir"] else "file", "path": path, "name": info.get_name(), "mime": ctype})
        if path:
            out.update(self.free_of(path if out["isDir"] else os.path.dirname(path)))
        if out["isDir"] and path:
            rid = req.get("id")
            threading.Thread(target=self.count_tree, args=(rid, path), daemon=True).start()
        return out

    # the preview pane's look at one file or folder: what info says, cheaper. a
    # folder counts only what is directly in it; text gives its first 64 kb; a
    # picture its size, read from its header
    def op_peek(self, req):
        gf = Gio.File.new_for_uri(req["uri"])
        info = gf.query_info("standard::*,time::*", Gio.FileQueryInfoFlags.NONE, None)
        path = gf.get_path() or ""
        ctype = named_type(info.get_name(), info.get_content_type() or "")
        is_dir = info.get_file_type() == Gio.FileType.DIRECTORY
        size = info.get_size()
        out = {"uri": gf.get_uri(), "path": path, "name": info.get_display_name(), "mime": ctype,
               "desc": Gio.content_type_get_description(ctype) if ctype else "", "size": size,
               "mtime": info.get_attribute_uint64("time::modified"),
               "ctime": info.get_attribute_uint64("time::created") or 0,
               "isDir": is_dir, "where": os.path.dirname(path)}
        if not path and not is_dir and out["uri"].startswith("admin:") and size <= AdminThumbs.LIMIT:
            rid = req.get("id")

            def fetched():
                try:
                    local = fetch_copy(gf, out["mtime"])
                except (GLib.Error, OSError):
                    local = ""
                if local:
                    out.update(self.peek_local(local, ctype, size), local=Gio.File.new_for_path(local).get_uri())
                send(dict(out, id=rid, ok=True))
            threading.Thread(target=fetched, daemon=True).start()
            return None
        if is_dir and path:
            files = dirs = seen = 0
            try:
                with os.scandir(path) as it:
                    for e in it:
                        seen += 1
                        if seen > 20000:
                            break
                        if e.name.startswith("."):
                            continue
                        try:
                            if e.is_dir():
                                dirs += 1
                            else:
                                files += 1
                        except OSError:
                            files += 1
            except OSError:
                pass
            out.update(files=files, dirs=dirs, more=seen > 20000)
        elif path:
            out.update(self.peek_local(path, ctype, size))
        return out

    @staticmethod
    def peek_local(path, ctype, size):
        out = {}
        if ctype.startswith("image/") and GdkPixbuf is not None:
            try:
                fmt, w, h = GdkPixbuf.Pixbuf.get_file_info(path)
                if fmt is not None:
                    out.update(width=w, height=h)
            except (GLib.Error, TypeError):
                pass
        elif size <= 8 * 1024 * 1024 and (Gio.content_type_is_a(ctype, "text/plain") or ctype in (
                "application/json", "application/xml", "application/x-shellscript", "application/javascript",
                "application/toml", "application/x-yaml", "application/x-desktop")):
            try:
                with open(path, "rb") as f:
                    data = f.read(65536)
                if b"\0" not in data[:8192]:
                    out.update(text=data.decode("utf-8", errors="replace"), cut=size > len(data))
            except OSError:
                pass
        return out

    def count_tree(self, rid, path):
        size = files = dirs = 0
        for root, dnames, fnames in os.walk(path):
            dirs += len(dnames)
            for f in fnames:
                try:
                    size += os.lstat(os.path.join(root, f)).st_blocks * 512
                    files += 1
                except OSError:
                    pass
        send({"ev": "infoSize", "req": rid, "size": size, "files": files, "dirs": dirs})

    # -- places: bookmarks and drives

    def bookmarks(self):
        out = []
        path = os.path.join(GLib.get_user_config_dir(), "gtk-3.0", "bookmarks")
        try:
            with open(path, encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    uri, _, label = line.partition(" ")
                    gf = Gio.File.new_for_uri(uri)
                    # a share's bookmark has its folder only while it is connected
                    p = gf.get_path() or ""
                    remote = not uri.startswith("file:")
                    name = remote_label(uri) if remote else (os.path.basename(p.rstrip("/")) if p else uri)
                    # custom: the name was written in the file, so a rewrite keeps it
                    out.append({"uri": uri, "path": p, "label": label or name, "remote": remote,
                                "custom": bool(label), "exists": bool(p) and (remote or os.path.isdir(p))})
        except OSError:
            pass
        return out

    def write_bookmarks(self, items):
        path = os.path.join(GLib.get_user_config_dir(), "gtk-3.0", "bookmarks")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path + ".lumen", "w", encoding="utf-8") as f:
            for b in items:
                f.write(b["uri"] + (" " + b["label"] if b.get("custom") else "") + "\n")
        os.replace(path + ".lumen", path)

    def op_bookmarkAdd(self, req):
        items = self.bookmarks()
        uri = Gio.File.new_for_path(req["path"]).get_uri()
        if not any(b["uri"] == uri for b in items):
            items.append({"uri": uri, "label": "", "custom": False})
            self.write_bookmarks(items)
        self.emit_bookmarks()
        return {}

    def op_bookmarkRename(self, req):
        # an empty name goes back to the folder's own
        items = self.bookmarks()
        for b in items:
            if b["uri"] == req["uri"]:
                name = (req.get("label") or "").strip().replace("\n", " ")
                b["label"], b["custom"] = name, bool(name)
        self.write_bookmarks(items)
        self.emit_bookmarks()
        return {}

    def op_bookmarkRemove(self, req):
        # matched on the parsed uri: the raw line still ends in its newline, so a
        # bookmark with no name of its own never matched and could not go
        items = [b for b in self.bookmarks() if b["uri"] != req["uri"]]
        self.write_bookmarks(items)
        self.emit_bookmarks()
        return {"count": len(items)}

    def emit_bookmarks(self):
        send({"ev": "bookmarks", "items": self.bookmarks()})

    def system_name(self):
        # the drive the system runs from goes by the system's name, beside windows on a dual boot
        try:
            with open("/etc/os-release", encoding="utf-8") as f:
                kv = dict(line.rstrip("\n").split("=", 1) for line in f if "=" in line)
            return kv.get("NAME", "").strip("\"'") or "System"
        except OSError:
            return "System"

    SYSTEM_MOUNTS = ("/", "/boot", "/efi", "/home", "/usr", "/var", "/opt", "/srv", "/tmp", "/root", "/nix", "/swap", "/.snapshots")
    SYSTEM_UNDER = ("/boot/", "/efi/", "/usr/", "/var/", "/proc/", "/sys/", "/dev/", "/snap/", "/nix/", "/.snapshots/", "/tmp/")

    def fixed_mounts(self):
        # disks mounted at boot outside /media, which gio leaves out unless fstab says
        # x-gvfs-show: a windows partition, a data drive. one row a disk, never the
        # system's own (its btrfs subvolumes share its device)
        try:
            with open("/proc/self/mountinfo", encoding="utf-8") as f:
                rows = [line.split() for line in f]
        except OSError:
            return []
        root = next((r[2] for r in rows if len(r) > 4 and r[4] == "/"), None)
        out, seen = [], set()
        for r in rows:
            if "-" not in r[6:]:
                continue
            sep = r.index("-", 6)
            dev = r[2]
            mp = re.sub(r"\\([0-7]{3})", lambda m: chr(int(m.group(1), 8)), r[4])
            fstype, source = r[sep + 1], r[sep + 2] if len(r) > sep + 2 else ""
            if not source.startswith("/dev/") or fstype in ("swap", "squashfs") or dev == root or dev in seen:
                continue
            if mp in self.SYSTEM_MOUNTS or mp.startswith(self.SYSTEM_UNDER) or (mp.startswith("/run/") and not mp.startswith("/run/media/")):
                continue
            seen.add(dev)
            out.append((mp, source, fstype))
        return out

    def fixed_label(self, mp, source, fstype):
        if fstype in ("ntfs", "ntfs3", "fuseblk") and os.path.isdir(os.path.join(mp, "Windows", "System32")):
            return "Windows"
        real = os.path.realpath(source)
        try:
            for name in os.listdir("/dev/disk/by-label"):
                if os.path.realpath(os.path.join("/dev/disk/by-label", name)) == real:
                    return re.sub(r"\\x([0-9a-fA-F]{2})", lambda m: chr(int(m.group(1), 16)), name)
        except OSError:
            pass
        return os.path.basename(mp) or mp

    def volume_list(self):
        system = {"id": "root", "label": self.system, "path": "/", "uri": "file:///", "mounted": True,
                  "canEject": False, "canUnmount": False, "slot": "computer"}
        system.update(self.free_of("/"))
        out, seen, paths = [], set(), {"/"}
        for m in self.volumes.get_mounts():
            if m.is_shadowed():
                continue
            root = m.get_root()
            path = root.get_path() or ""
            names = " ".join(dk.icon_names(m.get_icon()))
            vol = m.get_volume()
            uri = root.get_uri()
            seen.add(vol.get_uuid() if vol else uri)
            slot = self.drive_slot(names, uri)
            remote = slot in ("network", "cloud")
            entry = {"id": "m:" + uri, "label": m.get_name(), "path": path, "uri": uri, "mounted": True,
                     "canEject": m.can_eject(), "canUnmount": m.can_unmount(), "slot": slot, "remote": remote}
            if remote:
                entry.update(self.remote_space.get(uri, {"free": 0, "total": 0}))
            else:
                entry.update(self.free_of(path) if path else {"free": 0, "total": 0})
            out.append(entry)
            paths.add(path)
        for vol in self.volumes.get_volumes():
            if vol.get_mount() is not None or not vol.can_mount():
                continue
            key = vol.get_uuid() or vol.get_name()
            if key in seen:
                continue
            names = " ".join(dk.icon_names(vol.get_icon()))
            out.append({"id": "v:" + (vol.get_uuid() or vol.get_name()), "label": vol.get_name(), "path": "", "uri": "",
                        "mounted": False, "canEject": vol.can_eject(), "canUnmount": False,
                        "slot": self.drive_slot(names, ""), "free": 0, "total": 0})
        out.sort(key=lambda d: (not d["mounted"], d["label"].lower()))
        fixed = []
        for mp, source, fstype in self.fixed_mounts():
            if mp in paths:
                continue
            entry = {"id": "f:" + mp, "label": self.fixed_label(mp, source, fstype), "path": mp,
                     "uri": Gio.File.new_for_path(mp).get_uri(), "mounted": True, "canEject": False,
                     "canUnmount": False, "slot": "drive"}
            entry.update(self.free_of(mp))
            fixed.append(entry)
        fixed.sort(key=lambda d: d["label"].lower())
        return [system] + fixed + out

    def drive_slot(self, names, uri):
        if uri.startswith(("google-drive:", "onedrive:")):
            return "cloud"
        if uri.split(":", 1)[0] in NETWORK_SCHEMES:
            return "network"
        if uri.startswith(("mtp:", "gphoto2:", "afc:")) or "phone" in names:
            return "phone"
        if "optical" in names or "cdrom" in names:
            return "drive-optical"
        if "removable" in names or "usb" in names or "flash" in names:
            return "drive-usb"
        return "drive"

    def find_volume(self, vid):
        if vid.startswith("m:"):
            for m in self.volumes.get_mounts():
                if m.get_root().get_uri() == vid[2:]:
                    return m
        else:
            for vol in self.volumes.get_volumes():
                if (vol.get_uuid() or vol.get_name()) == vid[2:]:
                    return vol
        return None

    def op_mount(self, req):
        vol = self.find_volume(req["volume"])
        if vol is None or not isinstance(vol, Gio.Volume):
            raise ValueError("no such drive")
        rid = req.get("id")

        def done(v, res):
            try:
                v.mount_finish(res)
                m = v.get_mount()
                send({"id": rid, "ok": True, "path": m.get_root().get_path() if m else ""})
            except GLib.Error as e:
                send({"id": rid, "ok": False, "error": e.message})
        vol.mount(Gio.MountMountFlags.NONE, Gio.MountOperation(), None, done)
        return None

    def op_unmount(self, req):
        m = self.find_volume(req["volume"])
        if m is None or not isinstance(m, Gio.Mount):
            raise ValueError("no such drive")
        rid = req.get("id")
        eject = bool(req.get("eject")) and m.can_eject()

        def done(mt, res):
            try:
                (mt.eject_with_operation_finish if eject else mt.unmount_with_operation_finish)(res)
                send({"id": rid, "ok": True})
            except GLib.Error as e:
                send({"id": rid, "ok": False, "error": e.message})
        if eject:
            m.eject_with_operation(Gio.MountUnmountFlags.NONE, Gio.MountOperation(), None, done)
        else:
            m.unmount_with_operation(Gio.MountUnmountFlags.NONE, Gio.MountOperation(), None, done)
        return None

    def volumes_moved(self):
        # a share coming or going: its bookmarks gain or lose their folder
        self.emit_volumes()
        self.ask_space()
        self.later("bookmarks", 100, self.emit_bookmarks)

    def ask_space(self):
        live = set()
        for m in self.volumes.get_mounts():
            root = m.get_root()
            uri = root.get_uri()
            if self.drive_slot(" ".join(dk.icon_names(m.get_icon())), uri) not in ("network", "cloud"):
                continue
            live.add(uri)

            def got(f, res, uri=uri):
                try:
                    info = f.query_filesystem_info_finish(res)
                    space = {"free": info.get_attribute_uint64("filesystem::free"),
                             "total": info.get_attribute_uint64("filesystem::size")}
                except GLib.Error:
                    space = {"free": 0, "total": 0}
                if self.remote_space.get(uri) != space:
                    self.remote_space[uri] = space
                    self.later("volumes", 50, self.emit_volumes)
            root.query_filesystem_info_async("filesystem::free,filesystem::size", GLib.PRIORITY_LOW, None, got)
        for uri in list(self.remote_space):
            if uri not in live:
                del self.remote_space[uri]

    def emit_volumes(self):
        items = self.volume_list()
        text = json.dumps(items)
        if text != self.sent_volumes:
            self.sent_volumes = text
            send({"ev": "volumes", "items": items})

    def poll_volumes(self):
        self.emit_volumes()
        self.ask_space()
        return True

    # -- network: connecting to a server, and what it asks on the way

    def schemes(self):
        return sorted(Gio.Vfs.get_default().get_supported_uri_schemes())

    def unreachable(self, scheme):
        need = SCHEME_PACKAGES.get(scheme, "")
        return "Lumen can't reach %s:// addresses yet%s" % (scheme, ": install %s for them" % need if need else "")

    def op_connect(self, req):
        # an address to reach: mounted first if it isn't, through whatever it
        # points at (a computer nearby, a server's share), then its folder
        uri = (req.get("uri") or "").strip()
        rid = req.get("id")
        scheme = (GLib.Uri.peek_scheme(uri) or "") if "://" in uri else ""
        if not scheme:
            raise ValueError("That isn't a server address")
        if scheme not in self.schemes():
            return {"ok": False, "error": self.unreachable(scheme), "missing": SCHEME_PACKAGES.get(scheme, "")}
        self.connects[rid] = {"uri": uri, "op": Login(self, rid), "cancel": Gio.Cancellable(), "asked": 0, "hops": 0}
        self.reach(rid, Gio.File.new_for_uri(uri))
        return None

    def reach(self, cid, gf):
        c = self.connects.get(cid)
        if c is None:
            return

        def mounted(f, res):
            try:
                f.mount_enclosing_volume_finish(res)
            except GLib.Error as e:
                if not e.matches(Gio.io_error_quark(), Gio.IOErrorEnum.ALREADY_MOUNTED):
                    self.connected(cid, error=e)
                    return
            f.query_info_async("standard::type,standard::target-uri,standard::name,standard::display-name",
                               Gio.FileQueryInfoFlags.NONE, GLib.PRIORITY_DEFAULT, c["cancel"], resolved)

        def resolved(f, res):
            try:
                info = f.query_info_finish(res)
            except GLib.Error as e:
                self.connected(cid, error=e)
                return
            target = info.get_attribute_string("standard::target-uri") or ""
            kind = info.get_file_type()
            if target and kind in (Gio.FileType.MOUNTABLE, Gio.FileType.SHORTCUT) and c["hops"] < 4:
                c["hops"] += 1
                self.reach(cid, Gio.File.new_for_uri(target))
                return
            self.connected(cid, gf=f, info=info)
        gf.mount_enclosing_volume(Gio.MountMountFlags.NONE, c["op"], c["cancel"], mounted)

    def connected(self, cid, gf=None, info=None, error=None):
        c = self.connects.pop(cid, None)
        if c is None:
            return
        if error is not None:
            # a login turned down in the window is no failure to report
            quiet = error.matches(Gio.io_error_quark(), Gio.IOErrorEnum.CANCELLED) or \
                error.matches(Gio.io_error_quark(), Gio.IOErrorEnum.FAILED_HANDLED)
            send({"id": cid, "ok": False, "error": error.message, "cancelled": quiet})
            return
        path = "" if browsing(gf.get_uri()) else gf.get_path() or ""
        label = ""
        try:
            label = gf.find_enclosing_mount(None).get_name()
        except GLib.Error:
            pass
        is_dir = info.get_file_type() != Gio.FileType.REGULAR
        send({"id": cid, "ok": True, "path": path, "uri": gf.get_uri(), "label": label, "isDir": is_dir,
              "name": info.get_display_name() or info.get_name() or "",
              "where": os.path.dirname(path) if path and not is_dir else ""})
        self.later("volumes", 50, self.volumes_moved)

    def on_ask_password(self, op, message, user, domain, flags, cid):
        c = self.connects.get(cid)
        if c is None:
            op.reply(Gio.MountOperationResult.ABORTED)
            return
        c["asked"] += 1
        F = Gio.AskPasswordFlags
        send({"ev": "ask", "connect": cid, "kind": "password", "uri": c["uri"], "message": message or "",
              "user": user or "", "domain": domain or "", "retry": c["asked"] > 1,
              "needUser": bool(flags & F.NEED_USERNAME), "needDomain": bool(flags & F.NEED_DOMAIN),
              "needPassword": bool(flags & F.NEED_PASSWORD), "anonymous": bool(flags & F.ANONYMOUS_SUPPORTED),
              "canSave": bool(flags & F.SAVING_SUPPORTED)})

    def on_ask_question(self, op, message, choices, cid):
        c = self.connects.get(cid)
        if c is None:
            op.reply(Gio.MountOperationResult.ABORTED)
            return
        send({"ev": "ask", "connect": cid, "kind": "question", "uri": c["uri"], "message": message or "",
              "choices": list(choices or [])})

    def op_answer(self, req):
        c = self.connects.get(req.get("connect"))
        if c is None:
            return {}
        op = c["op"]
        if req.get("cancel"):
            op.reply(Gio.MountOperationResult.ABORTED)
            return {}
        if req.get("kind") == "question":
            op.set_choice(int(req.get("choice") or 0))
        else:
            anon = req.get("anonymous") is True
            op.set_anonymous(anon)
            if not anon:
                op.set_username(req.get("user") or "")
                op.set_domain(req.get("domain") or "")
                op.set_password(req.get("password") or "")
            op.set_password_save({"forever": Gio.PasswordSave.PERMANENTLY,
                                  "session": Gio.PasswordSave.FOR_SESSION}.get(req.get("save"), Gio.PasswordSave.NEVER))
        op.reply(Gio.MountOperationResult.HANDLED)
        return {}

    def op_cancelConnect(self, req):
        c = self.connects.get(req.get("connect"))
        if c is not None:
            c["cancel"].cancel()
        return {}


# ---- every app's open and save dialog ----------------------------------------------
#
# xdg-desktop-portal hands an app's file dialog to the backend its config names;
# ~/.config/xdg-desktop-portal/hyprland-portals.conf names this one, and a d-bus
# service file starts lumen when nothing owns the name yet. the request becomes a
# chooser window; what the person picks goes back as the method's reply

PORTAL_NAME = "org.freedesktop.impl.portal.desktop.lucid"
PORTAL_PATH = "/org/freedesktop/portal/desktop"
_ARGS = ('<arg type="o" name="handle" direction="in"/><arg type="s" name="app_id" direction="in"/>'
         '<arg type="s" name="parent_window" direction="in"/><arg type="s" name="title" direction="in"/>'
         '<arg type="a{sv}" name="options" direction="in"/><arg type="u" name="response" direction="out"/>'
         '<arg type="a{sv}" name="results" direction="out"/>')
CHOOSER_XML = ('<node><interface name="org.freedesktop.impl.portal.FileChooser">'
               + "".join('<method name="%s">%s</method>' % (m, _ARGS) for m in ("OpenFile", "SaveFile", "SaveFiles"))
               + '</interface></node>')
REQUEST_XML = '<node><interface name="org.freedesktop.impl.portal.Request"><method name="Close"/></interface></node>'


def portal_path(v):
    # the portal hands paths as nul-terminated byte arrays
    if v is None:
        return ""
    if isinstance(v, str):
        return v
    try:
        return bytes(v).rstrip(b"\0").decode("utf-8", "replace")
    except (TypeError, ValueError):
        return ""


class Portal:
    def __init__(self):
        self.pending = {}
        self.next = 1
        self.conn = None
        self.chooser = Gio.DBusNodeInfo.new_for_xml(CHOOSER_XML).interfaces[0]
        self.request = Gio.DBusNodeInfo.new_for_xml(REQUEST_XML).interfaces[0]
        Gio.bus_own_name(Gio.BusType.SESSION, PORTAL_NAME,
                         Gio.BusNameOwnerFlags.ALLOW_REPLACEMENT | Gio.BusNameOwnerFlags.REPLACE,
                         self.acquired, None, None)

    def acquired(self, conn, _name):
        self.conn = conn
        conn.register_object(PORTAL_PATH, self.chooser, self.call, None, None)

    def call(self, conn, _sender, _path, _iface, method, params, inv):
        handle, app_id, _parent, title, options = params.unpack()
        rid = self.next
        self.next += 1
        mode = {"OpenFile": "open", "SaveFile": "save", "SaveFiles": "saveFiles"}.get(method, "open")
        filters = [(str(n), [(int(t), str(p)) for t, p in rules]) for n, rules in (options.get("filters") or [])]
        current = -1
        cur = options.get("current_filter")
        if cur:
            for i, (n, rules) in enumerate(filters):
                if n == cur[0]:
                    current = i
                    break
            if current < 0:
                filters.append((str(cur[0]), [(int(t), str(p)) for t, p in cur[1]]))
                current = len(filters) - 1
        reg = 0
        try:
            # the app (or the portal) can take the dialog back: Close on the handle
            reg = conn.register_object(handle, self.request, lambda *a, r=rid: self.close(r, a[-1]), None, None)
        except GLib.Error:
            pass
        self.pending[rid] = {"inv": inv, "reg": reg, "filters": filters}
        folder = portal_path(options.get("current_folder"))
        current_file = portal_path(options.get("current_file"))
        send({"ev": "choose", "id": rid, "mode": mode, "title": title or "", "appId": app_id or "",
              "accept": options.get("accept_label") or "", "multiple": bool(options.get("multiple")),
              "directory": bool(options.get("directory")),
              "filters": [[n, [[t, p] for t, p in rules]] for n, rules in filters], "current": current,
              "folder": folder or (os.path.dirname(current_file) if current_file else ""),
              "name": options.get("current_name") or (os.path.basename(current_file) if current_file else ""),
              "files": [os.path.basename(portal_path(f)) for f in (options.get("files") or [])]})

    def close(self, rid, inv):
        p = self.pending.pop(rid, None)
        if inv is not None:
            inv.return_value(None)
        if p:
            self.drop(p)
            p["inv"].return_value(GLib.Variant("(ua{sv})", (2, {})))
            send({"ev": "chooseClose", "id": rid})

    def drop(self, p):
        if p["reg"] and self.conn:
            self.conn.unregister_object(p["reg"])
            p["reg"] = 0

    def finish(self, req):
        p = self.pending.pop(req.get("chooser"), None)
        if p is None:
            return
        self.drop(p)
        if req.get("cancel"):
            p["inv"].return_value(GLib.Variant("(ua{sv})", (1, {})))
            return
        results = {"uris": GLib.Variant("as", [str(u) for u in req.get("uris") or []]),
                   "writable": GLib.Variant("b", True)}
        fi = req.get("filter", -1)
        if isinstance(fi, int) and 0 <= fi < len(p["filters"]):
            results["current_filter"] = GLib.Variant("(sa(us))", p["filters"][fi])
        p["inv"].return_value(GLib.Variant("(ua{sv})", (0, results)))


class Login(Gio.MountOperation):
    """what a server asks while it connects, put to the window. gio's own
    handlers answer "not handled" at the next idle, before a person can type
    anything, so they are replaced rather than listened to"""

    def __init__(self, lumen, cid):
        super().__init__()
        self.lumen = lumen
        self.cid = cid

    def do_ask_password(self, message, user, domain, flags):
        self.lumen.on_ask_password(self, message, user, domain, flags, self.cid)

    def do_ask_question(self, message, choices):
        self.lumen.on_ask_question(self, message, choices, self.cid)

    def do_aborted(self):
        send({"ev": "askClose", "connect": self.cid})


class RemoteThumbs:
    """a share's thumbnails: each one fetches the whole file, so only for the
    files small enough for that"""

    LIMIT = 50 << 20

    def __init__(self, thumbs):
        self.thumbs = thumbs

    def can(self, mime):
        return self.thumbs.can(mime)

    def want(self, uri, mime, mtime, size):
        if size <= self.LIMIT:
            self.thumbs.want(uri, mime, mtime, size)


class Thumbs(dk.Thumbs):
    """the desktop's thumbnailer, telling which file it just finished"""

    def __init__(self, done):
        super().__init__(done)
        self.last = ("", "")

    def save(self, src, dest, uri, mtime):
        ok = super().save(src, dest, uri, mtime)
        self.last = (uri, dest if ok else "")
        return ok

    def fail(self, uri, mtime):
        self.last = (uri, "")
        super().fail(uri, mtime)


class Job(threading.Thread):
    """a copy or a move, in its own thread; never over an existing name"""

    def __init__(self, jid, mode, uris, dest, tag=""):
        super().__init__(daemon=True)
        self.jid = jid
        self.mode = mode
        self.uris = uris
        self.dest = dest
        # the caller's own label, echoed in every event (an undo marks its jobs)
        self.tag = tag
        self.cancel = Gio.Cancellable()
        self.total = self.done = self.base = 0
        self.files = self.count = 0
        self.last = 0
        self.current = ""
        # told when the job is over, on the daemon's own thread
        self.ended = None

    def report(self, state="running", force=False, **extra):
        now = time.time()
        if state == "running" and not force and now - self.last < 0.12:
            return
        self.last = now
        msg = {"ev": "job", "job": self.jid, "mode": self.mode, "state": state, "done": self.done, "total": self.total,
               "files": self.files, "count": self.count, "name": self.current, "dest": self.dest, "tag": self.tag}
        msg.update(extra)
        send(msg)

    def run(self):
        # moved holds [from, to] pairs and copied the new copies, so an undo knows
        # what to put back and what to take away, whatever order things finished in
        made, errors, moved, copied = [], [], [], []
        try:
            os.makedirs(self.dest, exist_ok=True)
            dest_dev = self.place(self.dest, os.stat(self.dest).st_dev)
            plan = []
            for uri in self.uris:
                src = Gio.File.new_for_uri(uri)
                spath = src.get_path()
                if not spath:
                    # someone else's file through gvfs's admin://, which has no folder here
                    if uri.startswith("admin:"):
                        plan.append((uri, "admin-move" if self.mode == "move" else "admin"))
                    else:
                        errors.append({"uri": uri, "error": "not a local file"})
                    continue
                if os.path.isdir(spath) and not os.path.islink(spath) and \
                        (os.path.abspath(self.dest) + "/").startswith(os.path.abspath(spath) + "/"):
                    errors.append({"uri": uri, "error": "a folder cannot go inside itself"})
                    continue
                same_dir = os.path.dirname(os.path.abspath(spath)) == os.path.abspath(self.dest)
                how = self.mode
                if how in ("move", "auto"):
                    try:
                        fast = self.place(spath, os.lstat(spath).st_dev) == dest_dev
                    except OSError:
                        fast = False
                    if same_dir:
                        if self.mode == "auto" or self.mode == "move":
                            continue
                    how = "rename" if fast else ("copy" if self.mode == "auto" else "move-copy")
                plan.append((spath, how))
            # sizes first, so the bar can tell how far along it is
            for spath, how in plan:
                if how == "rename":
                    self.count += 1
                    continue
                if how.startswith("admin"):
                    for _f, info in self.walk_gio(Gio.File.new_for_uri(spath)):
                        if info.get_file_type() != Gio.FileType.DIRECTORY:
                            self.total += info.get_size()
                            self.count += 1
                    continue
                for root, _d, fnames in self.walk(spath):
                    for f in fnames:
                        try:
                            self.total += os.lstat(os.path.join(root, f)).st_size
                        except OSError:
                            pass
                        self.count += 1
            self.report(force=True)
            for spath, how in plan:
                if self.cancel.is_cancelled():
                    break
                base = Gio.File.new_for_uri(spath).get_basename() if how.startswith("admin") else os.path.basename(spath)
                name = dk.free_name(self.dest, base)
                target = os.path.join(self.dest, name)
                self.current = base
                try:
                    if how.startswith("admin"):
                        src = Gio.File.new_for_uri(spath)
                        self.copy_gio(src, target)
                        # a move takes the original away too; there's no putting it back from here
                        if how == "admin-move" and not self.cancel.is_cancelled():
                            self.delete_gio(src)
                        made.append(target)
                        if how == "admin":
                            copied.append(target)
                        self.report()
                        continue
                    if how == "rename":
                        try:
                            os.rename(spath, target)
                            self.files += 1
                        except OSError as e:
                            # a server that won't rename from one of its folders to another
                            if e.errno not in (errno.EXDEV, errno.ENOSYS, errno.EOPNOTSUPP) or not is_remote(spath):
                                raise
                            how = "move-copy"
                            for root, _d, fnames in self.walk(spath):
                                for f in fnames:
                                    with contextlib.suppress(OSError):
                                        self.total += os.lstat(os.path.join(root, f)).st_size
                    if how != "rename":
                        self.copy_tree(spath, target)
                        if how == "move-copy" and not self.cancel.is_cancelled():
                            if os.path.isdir(spath) and not os.path.islink(spath):
                                shutil.rmtree(spath)
                            else:
                                os.remove(spath)
                    made.append(target)
                    if how in ("rename", "move-copy"):
                        moved.append([spath, target])
                    else:
                        copied.append(target)
                except (OSError, GLib.Error) as e:
                    errors.append({"uri": spath if "://" in spath else Gio.File.new_for_path(spath).get_uri(),
                                   "error": str(getattr(e, "message", e))})
                self.report()
        except (OSError, GLib.Error) as e:
            errors.append({"uri": "", "error": str(getattr(e, "message", e))})
        state = "cancelled" if self.cancel.is_cancelled() else "done"
        self.report(state, made=made, errors=errors, moved=moved, copied=copied, uris=self.uris)
        if self.ended:
            GLib.idle_add(lambda: (self.ended(), False)[1])

    @staticmethod
    def place(path, dev):
        # where a rename can go without copying: the same disk, and on gvfs's
        # one fuse filesystem the same share
        if path.startswith(REMOTE_ROOT + "/"):
            return path[len(REMOTE_ROOT) + 1:].split("/")[0]
        return dev

    def walk_gio(self, top):
        """a tree only gio can reach, as (file, info) pairs, its folders included"""
        attrs = "standard::name,standard::type,standard::size"
        todo = [top]
        while todo:
            f = todo.pop()
            try:
                info = f.query_info(attrs, Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, self.cancel)
            except GLib.Error:
                continue
            yield f, info
            if info.get_file_type() == Gio.FileType.DIRECTORY:
                try:
                    for child in f.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, self.cancel):
                        todo.append(f.get_child(child.get_name()))
                except GLib.Error:
                    pass

    def copy_gio(self, src, dst):
        info = src.query_info("standard::type,standard::size", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, self.cancel)
        if info.get_file_type() == Gio.FileType.DIRECTORY:
            os.makedirs(dst)
            for child in src.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, self.cancel):
                if self.cancel.is_cancelled():
                    return
                self.copy_gio(src.get_child(child.get_name()), os.path.join(dst, child.get_name()))
            return
        self.current = src.get_basename()
        self.base = self.done

        def progress(cur, _total, *_):
            self.done = self.base + cur
            self.report()
        # the copy is yours: gvfs's owner and the rest stay behind
        src.copy(Gio.File.new_for_path(dst), Gio.FileCopyFlags.NOFOLLOW_SYMLINKS, self.cancel, progress, None)
        self.done = self.base + info.get_size()
        self.files += 1

    def delete_gio(self, f):
        if f.query_info("standard::type", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None).get_file_type() == Gio.FileType.DIRECTORY:
            for child in f.enumerate_children("standard::name", Gio.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, None):
                self.delete_gio(f.get_child(child.get_name()))
        f.delete(None)

    def walk(self, path):
        if os.path.isdir(path) and not os.path.islink(path):
            return os.walk(path)
        return [(os.path.dirname(path), [], [os.path.basename(path)])]

    def copy_file(self, src, dst):
        self.base = self.done

        def progress(cur, _total, *_):
            self.done = self.base + cur
            self.report()
        Gio.File.new_for_path(src).copy(Gio.File.new_for_path(dst), Gio.FileCopyFlags.NOFOLLOW_SYMLINKS | Gio.FileCopyFlags.ALL_METADATA,
                                        self.cancel, progress, None)
        try:
            self.done = self.base + os.lstat(src).st_size
        except OSError:
            pass
        self.files += 1

    def copy_tree(self, src, dst):
        if os.path.islink(src):
            os.symlink(os.readlink(src), dst)
            self.files += 1
            return
        if not os.path.isdir(src):
            self.copy_file(src, dst)
            return
        os.makedirs(dst)
        try:
            shutil.copystat(src, dst, follow_symlinks=False)
        except OSError:
            # a share that keeps no dates or modes of its own
            pass
        for entry in sorted(os.scandir(src), key=lambda e: e.name):
            if self.cancel.is_cancelled():
                return
            self.current = entry.name
            self.copy_tree(entry.path, os.path.join(dst, entry.name))


def main():
    # follow the window down instead of lingering after it quits
    try:
        ctypes.CDLL("libc.so.6").prctl(1, signal.SIGTERM)
    except OSError:
        pass
    lumen = Lumen()
    try:
        lumen.portal = Portal()
    except GLib.Error as e:
        print("lumen: the file chooser portal did not start: %s" % e, file=sys.stderr)
    loop = GLib.MainLoop()
    buf = [b""]

    def readable(fd, cond):
        if cond & (GLib.IO_HUP | GLib.IO_ERR):
            loop.quit()
            return False
        chunk = os.read(fd, 65536)
        if not chunk:
            loop.quit()
            return False
        buf[0] += chunk
        while b"\n" in buf[0]:
            line, buf[0] = buf[0].split(b"\n", 1)
            if line.strip():
                try:
                    req = json.loads(line)
                except ValueError:
                    continue
                lumen.handle(req)
        return True

    GLib.io_add_watch(sys.stdin.fileno(), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, readable)
    signal.signal(signal.SIGTERM, lambda *_: loop.quit())
    send({"ev": "ready", "pid": os.getpid()})
    loop.run()


if __name__ == "__main__":
    main()
