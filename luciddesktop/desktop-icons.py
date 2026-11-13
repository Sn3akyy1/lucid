#!/usr/bin/env python3
# the desktop folder for the icon layer.
#
#   desktop-icons.py watch [--theme T] [--size PX] [--hidden] [--thumbs] [--drives]
#       the folder as one json line, then a fresh line on every change to it,
#       the trash, the mounted drives or a thumbnail, for as long as the shell runs
#   desktop-icons.py peek <dir> [--theme T] [--size PX]
#       how many things a folder holds and the first few
#   desktop-icons.py apps-for <uri> [--theme T] [--size PX]
#       the apps that open a file, the default first
#   desktop-icons.py new folder|text|markdown|empty|template [template path]
#       a new item on the desktop under a free name, which it prints
#   desktop-icons.py duplicate|link <path>...
#       "<name> copy" next to each, or a "Link to <name>"; one "<src>\t<new name>" line each
#   desktop-icons.py compress <path>...
#       a zip next to the first; prints its name
#   desktop-icons.py extract <archive>
#       into a folder named after it, or straight in when it holds one thing; prints the name
#   desktop-icons.py info <path>
#       one json line at once, a second with a folder's full size when it is counted
#   desktop-icons.py set-tags <tag,tag|""> <path>...
#   desktop-icons.py restore <original path>...
#       back out of the trash, the latest of each name
#   desktop-icons.py delete <path>...
#       for good, no trash
#   desktop-icons.py clip
#       what the clipboard holds that a paste can use: {"mode", "uris", "image"}
#   desktop-icons.py paste-image <dest-dir>
#       a copied picture saved as a png; prints its name
#   desktop-icons.py put copy|move|auto <dest-dir> <uri>...
#       copies or moves, never over an existing name; one "<uri>\t<new name>"
#       line each. auto moves on the same drive and copies across
#   desktop-icons.py add-dock-app <window class> <icon> <name> <command>
#       a dock pin's launcher on the desktop: the app's own, or one written from the pin
#   desktop-icons.py add-app <desktop-id>
#       an app's launcher on the desktop, allowed to run
#   desktop-icons.py rename <path> <new name>
#       a launcher keeps its file name and gets a new Name=
#   desktop-icons.py trust <path>
#   desktop-icons.py luma <image> <screen width> <screen height>
#       how light the wallpaper is across the screen, a grid of L* values
#   desktop-icons.py open <uri>...
#       folders in a file manager (never an editor that claims them), files with their default app
#   desktop-icons.py open-trash
import ctypes
import hashlib
import json
import os
import shlex
import shutil
import signal
import stat
import subprocess
import sys

import gi

gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

# newer glib moved the desktop entry reader to GioUnix
try:
    gi.require_version("GioUnix", "2.0")
    from gi.repository import GioUnix  # noqa: E402
    DesktopAppInfo = GioUnix.DesktopAppInfo
except (ValueError, ImportError):
    DesktopAppInfo = Gio.DesktopAppInfo

ATTRS = ",".join([
    "standard::name", "standard::display-name", "standard::type", "standard::icon",
    "standard::content-type", "standard::size", "standard::is-hidden", "standard::is-backup",
    "standard::is-symlink", "time::modified", "thumbnail::path", "thumbnail::is-valid",
    "thumbnail::failed", "access::can-execute", "metadata::lucid-tags",
])

THUMB_SIZE = 256
THUMB_ROOT = os.path.join(GLib.get_user_cache_dir(), "thumbnails")
# what glib reads to answer thumbnail::failed, so a file manager skips it too
FAIL_DIR = os.path.join(THUMB_ROOT, "fail", "gnome-thumbnail-factory")
THUMB_LIMIT = {"video": 8 << 30, "audio": 1 << 30}


def desktop_dir():
    d = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DESKTOP)
    # with no user-dirs.dirs glib answers $HOME, never what anyone wants here
    if not d or os.path.realpath(d) == os.path.realpath(GLib.get_home_dir()):
        d = os.path.join(GLib.get_home_dir(), "Desktop")
    return d


def trash_dir():
    return os.path.join(GLib.get_user_data_dir(), "Trash", "files")


# ---- the icon theme ----------------------------------------------------------

def icon_bases():
    out = [os.path.join(GLib.get_user_data_dir(), "icons"), os.path.join(GLib.get_home_dir(), ".icons")]
    out += [os.path.join(d, "icons") for d in GLib.get_system_data_dirs()]
    seen, uniq = set(), []
    for d in out:
        if d not in seen and os.path.isdir(d):
            seen.add(d)
            uniq.append(d)
    return uniq


class SubDir:
    def __init__(self, path, kf, group):
        def num(key, default):
            try:
                return kf.get_integer(group, key)
            except GLib.Error:
                return default
        self.path = path
        self.size = num("Size", 0)
        self.scale = num("Scale", 1)
        self.min = num("MinSize", self.size)
        self.max = num("MaxSize", self.size)
        self.threshold = num("Threshold", 2)
        try:
            self.type = kf.get_string(group, "Type")
        except GLib.Error:
            self.type = "Threshold"
        # a symbolic set is monochrome: the last resort for a colour icon
        self.symbolic = "symbolic" in path.lower()

    # px in logical pixels, at the screen's scale: an @2x set is for hidpi only
    def matches(self, px, scale):
        if self.scale != scale:
            return False
        if self.type == "Fixed":
            return self.size == px
        if self.type == "Scalable":
            return self.min <= px <= self.max
        return self.size - self.threshold <= px <= self.size + self.threshold

    def distance(self, px, scale):
        want = px * scale
        # another scale's art is drawn for another density: only if nothing else has the name
        off = 0 if self.scale == scale else 10000
        if self.type == "Fixed":
            return abs(self.size * self.scale - want) + off
        lo, hi = (self.min, self.max) if self.type == "Scalable" else (self.size - self.threshold, self.size + self.threshold)
        if want < lo * self.scale:
            return lo * self.scale - want + off
        if want > hi * self.scale:
            return want - hi * self.scale + off
        return off


class Theme:
    def __init__(self, name, bases):
        self.name = name
        self.roots = [os.path.join(b, name) for b in bases if os.path.isdir(os.path.join(b, name))]
        self.subdirs = []
        self.inherits = []
        for r in self.roots:
            index = os.path.join(r, "index.theme")
            if not os.path.isfile(index):
                continue
            kf = GLib.KeyFile()
            try:
                kf.load_from_file(index, GLib.KeyFileFlags.NONE)
            except GLib.Error:
                continue
            dirs = []
            for key in ("Directories", "ScaledDirectories"):
                try:
                    dirs += [d for d in kf.get_string("Icon Theme", key).split(",") if d.strip()]
                except GLib.Error:
                    pass
            for d in dirs:
                d = d.strip()
                if kf.has_group(d):
                    self.subdirs.append(SubDir(d, kf, d))
            try:
                self.inherits = [t.strip() for t in kf.get_string("Icon Theme", "Inherits").split(",") if t.strip()]
            except GLib.Error:
                pass
            break


class Icons:
    """the freedesktop lookup, in gtk's order: every name in a theme before
    the next theme, so the chosen set's generic icon beats hicolor's own"""

    def __init__(self, theme, size, scale=1):
        self.size = max(8, int(size))
        self.scale = max(1, int(scale))
        self.bases = icon_bases()
        self.chain = []
        seen = set()

        def walk(name):
            if not name or name in seen:
                return
            seen.add(name)
            t = Theme(name, self.bases)
            if not t.roots:
                return
            self.chain.append(t)
            for parent in t.inherits:
                walk(parent)

        walk(theme or "hicolor")
        # gtk 4's own fallback, so a missing theme still has folders
        walk("Adwaita")
        walk("hicolor")
        self.listings = {}
        self.cache = {}

    def files_in(self, d):
        hit = self.listings.get(d)
        if hit is None:
            try:
                hit = set(os.listdir(d))
            except OSError:
                hit = set()
            self.listings[d] = hit
        return hit

    def in_theme(self, theme, name, px):
        for symbolic in (False, True):
            best, gap = "", None
            for sub in theme.subdirs:
                if sub.symbolic != symbolic:
                    continue
                for root in theme.roots:
                    d = os.path.join(root, sub.path)
                    files = self.files_in(d)
                    for ext in (".svg", ".png"):
                        if name + ext not in files:
                            continue
                        if sub.matches(px, self.scale):
                            return os.path.join(d, name + ext)
                        g = sub.distance(px, self.scale)
                        if gap is None or g < gap:
                            best, gap = os.path.join(d, name + ext), g
            if best:
                return best
        return ""

    def find(self, names, px=None):
        px = px or self.size
        names = [n for n in names if n]
        key = (tuple(names), px)
        if key in self.cache:
            return self.cache[key]
        hit = ""
        for n in names:
            if n.startswith("/") and os.path.isfile(n):
                hit = n
                break
        if not hit:
            # a symbolic name only once every colour one has had its chance
            ordered = [n for n in names if not n.endswith("-symbolic")] + [n for n in names if n.endswith("-symbolic")]
            for theme in self.chain:
                for n in ordered:
                    if n.startswith("/"):
                        continue
                    hit = self.in_theme(theme, n, px)
                    if hit:
                        break
                if hit:
                    break
        if not hit:
            for n in names:
                for ext in (".svg", ".png", ".xpm"):
                    p = os.path.join("/usr/share/pixmaps", n + ext)
                    if os.path.isfile(p):
                        hit = p
                        break
                if hit:
                    break
        self.cache[key] = hit
        return hit


def icon_names(icon):
    if icon is None:
        return []
    if isinstance(icon, Gio.ThemedIcon):
        return list(icon.get_names())
    if isinstance(icon, Gio.FileIcon):
        p = icon.get_file().get_path()
        return [p] if p else []
    if isinstance(icon, Gio.EmblemedIcon):
        return icon_names(icon.get_icon())
    return []


# ---- thumbnails ----------------------------------------------------------------

def thumbnailers():
    out = {}
    dirs = [GLib.get_user_data_dir()] + list(GLib.get_system_data_dirs())
    for d in dirs:
        td = os.path.join(d, "thumbnailers")
        try:
            names = sorted(os.listdir(td))
        except OSError:
            continue
        for f in names:
            if not f.endswith(".thumbnailer"):
                continue
            kf = GLib.KeyFile()
            try:
                kf.load_from_file(os.path.join(td, f), GLib.KeyFileFlags.NONE)
                exe = kf.get_string("Thumbnailer Entry", "Exec")
                mimes = kf.get_string("Thumbnailer Entry", "MimeType")
            except GLib.Error:
                continue
            try:
                tryexec = kf.get_string("Thumbnailer Entry", "TryExec")
            except GLib.Error:
                tryexec = shlex.split(exe)[0] if exe else ""
            if tryexec and not shutil.which(tryexec):
                continue
            for m in mimes.split(";"):
                if m and m not in out:
                    out[m] = exe
    return out


class Thumbs:
    """one thumbnailer at a time, in the background, saved where every file
    manager looks: ~/.cache/thumbnails/large, keyed by the md5 of the uri"""

    def __init__(self, done):
        self.done = done
        self.by_mime = thumbnailers()
        self.queue = []
        self.tried = set()
        self.proc = None

    def can(self, mime):
        return mime in self.by_mime

    def want(self, uri, mime, mtime, size):
        key = (uri, mtime)
        if key in self.tried or mime not in self.by_mime:
            return
        limit = THUMB_LIMIT.get(mime.split("/")[0], 256 << 20)
        if size > limit:
            return
        self.tried.add(key)
        self.queue.append((uri, mime, mtime))
        self.kick()

    def kick(self):
        if self.proc is not None or not self.queue:
            return
        uri, mime, mtime = self.queue.pop(0)
        md5 = hashlib.md5(uri.encode()).hexdigest()
        large = os.path.join(THUMB_ROOT, "large")
        os.makedirs(large, exist_ok=True)
        tmp = os.path.join(large, ".lucid-%s-%d.png" % (md5, os.getpid()))
        path = Gio.File.new_for_uri(uri).get_path() or ""
        argv = []
        for a in shlex.split(self.by_mime[mime]):
            a = a.replace("%%", "\0").replace("%i", path).replace("%u", uri).replace("%o", tmp).replace("%s", str(THUMB_SIZE))
            argv.append(a.replace("\0", "%"))
        try:
            self.proc = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDOUT_SILENCE | Gio.SubprocessFlags.STDERR_SILENCE)
        except GLib.Error:
            self.fail(uri, mtime)
            GLib.idle_add(self.kick)
            return
        proc = self.proc
        timer = GLib.timeout_add_seconds(30, lambda: (proc.force_exit(), False)[1])

        def finished(p, res):
            GLib.source_remove(timer)
            try:
                ok = p.wait_check_finish(res)
            except GLib.Error:
                ok = False
            if ok and os.path.isfile(tmp):
                ok = self.save(tmp, os.path.join(large, md5 + ".png"), uri, mtime)
            if not ok:
                self.fail(uri, mtime)
            try:
                os.unlink(tmp)
            except OSError:
                pass
            self.proc = None
            self.done()
            self.kick()

        proc.wait_check_async(None, finished)

    def save(self, src, dest, uri, mtime):
        # the spec wants the uri and mtime inside the png, or nobody trusts it
        gi.require_version("GdkPixbuf", "2.0")
        from gi.repository import GdkPixbuf
        try:
            pb = GdkPixbuf.Pixbuf.new_from_file(src)
            w, h = pb.get_width(), pb.get_height()
            if max(w, h) > THUMB_SIZE:
                k = THUMB_SIZE / max(w, h)
                pb = pb.scale_simple(max(1, round(w * k)), max(1, round(h * k)), GdkPixbuf.InterpType.BILINEAR)
            part = dest + ".part"
            pb.savev(part, "png", ["tEXt::Thumb::URI", "tEXt::Thumb::MTime", "tEXt::Software"], [uri, str(mtime), "Lucid"])
            os.replace(part, dest)
            return True
        except GLib.Error:
            return False

    def fail(self, uri, mtime):
        gi.require_version("GdkPixbuf", "2.0")
        from gi.repository import GdkPixbuf
        try:
            os.makedirs(FAIL_DIR, exist_ok=True)
            pb = GdkPixbuf.Pixbuf.new(GdkPixbuf.Colorspace.RGB, True, 8, 1, 1)
            pb.fill(0)
            dest = os.path.join(FAIL_DIR, hashlib.md5(uri.encode()).hexdigest() + ".png")
            pb.savev(dest, "png", ["tEXt::Thumb::URI", "tEXt::Thumb::MTime"], [uri, str(mtime)])
        except GLib.Error:
            pass


# ---- one entry --------------------------------------------------------------

def hidden_list(folder):
    # nautilus hides the names a folder lists in its .hidden
    try:
        with open(os.path.join(folder, ".hidden"), encoding="utf-8") as f:
            return {line.strip() for line in f if line.strip()}
    except OSError:
        return set()



# ---- what each file is drawn as in lucid's own icons: lumen uses this too ------------

SPECIAL_DIRS = [(GLib.UserDirectory.DIRECTORY_DESKTOP, "folder-desktop", "Desktop", "desktop_windows"),
                (GLib.UserDirectory.DIRECTORY_DOCUMENTS, "folder-documents", "Documents", "description"),
                (GLib.UserDirectory.DIRECTORY_DOWNLOAD, "folder-download", "Downloads", "download"),
                (GLib.UserDirectory.DIRECTORY_MUSIC, "folder-music", "Music", "music_note"),
                (GLib.UserDirectory.DIRECTORY_PICTURES, "folder-pictures", "Pictures", "image"),
                (GLib.UserDirectory.DIRECTORY_VIDEOS, "folder-videos", "Videos", "movie"),
                (GLib.UserDirectory.DIRECTORY_TEMPLATES, "folder-templates", "Templates", "file_copy"),
                (GLib.UserDirectory.DIRECTORY_PUBLIC_SHARE, "folder-public", "Public", "share")]


def special_folders():
    home = os.path.realpath(GLib.get_home_dir())
    out = {home: "folder-home"}
    for kind, slot, _, _ in SPECIAL_DIRS:
        d = GLib.get_user_special_dir(kind)
        if d and os.path.realpath(d) != home:
            out[os.path.realpath(d)] = slot
    return out


SPECIALS = special_folders()

MIME_SLOTS = {
    "application/pdf": "pdf",
    "application/epub+zip": "ebook", "application/x-mobipocket-ebook": "ebook", "application/vnd.amazon.ebook": "ebook",
    "image/vnd.djvu": "ebook", "application/x-fictionbook+xml": "ebook",
    "application/vnd.oasis.opendocument.text": "document", "application/msword": "document", "application/rtf": "document",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "document", "text/rtf": "document",
    "application/vnd.oasis.opendocument.spreadsheet": "spreadsheet", "application/vnd.ms-excel": "spreadsheet",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": "spreadsheet", "text/csv": "spreadsheet",
    "text/tab-separated-values": "spreadsheet",
    "application/vnd.oasis.opendocument.presentation": "presentation", "application/vnd.ms-powerpoint": "presentation",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation": "presentation",
    "application/x-cd-image": "disk-image", "application/x-iso9660-image": "disk-image", "application/x-raw-disk-image": "disk-image",
    "application/vnd.efi.iso": "disk-image", "application/x-qemu-disk": "disk-image", "application/x-apple-diskimage": "disk-image",
    "application/vnd.debian.binary-package": "package", "application/x-rpm": "package", "application/vnd.flatpak.ref": "package",
    "application/vnd.flatpak": "package", "application/vnd.appimage": "package", "application/x-iso9660-appimage": "package",
    "application/x-shellscript": "script", "application/x-executable": "script", "application/x-pie-executable": "script",
    "application/x-sharedlib": "script", "application/x-desktop": "script",
    "text/plain": "text", "text/markdown": "text", "text/x-log": "text", "application/x-zerosize": "file",
}
ARCHIVE_HINTS = ("zip", "tar", "rar", "7z", "bzip", "gzip", "xz", "lzma", "zstd", "lz4", "compress", "cpio", "archive")
CODE_HINTS = ("text/x-", "application/javascript", "application/json", "text/javascript", "application/xml", "text/xml",
              "text/html", "text/css", "application/x-yaml", "application/toml", "application/x-php", "application/sql",
              "application/x-perl", "application/x-ruby", "text/x-qml", "application/x-ipynb+json")


def named_type(name, mime):
    # an empty file has no content to go by: its name says what it will be
    if mime in ("", "application/x-zerosize", "application/octet-stream"):
        guess, uncertain = Gio.content_type_guess(name, None)
        if guess and not (uncertain and guess == "application/octet-stream"):
            return guess
    return mime


def slot_for(item):
    if item["kind"] == "dir":
        real = os.path.realpath(item["path"]) if item.get("path") else ""
        return SPECIALS.get(real, "folder")
    mime = named_type(item.get("name", ""), item.get("mime") or "")
    if mime in MIME_SLOTS:
        return MIME_SLOTS[mime]
    top = mime.split("/")[0]
    if top in ("image", "video", "audio"):
        return top
    if top == "font" or "font" in mime:
        return "font"
    if mime.startswith("application/") and any(h in mime for h in ARCHIVE_HINTS):
        # pacman's own packages are zstd tarballs with a name to say so
        return "package" if item["name"].endswith((".pkg.tar.zst", ".pkg.tar.xz")) else "archive"
    if mime.startswith(CODE_HINTS):
        return "code"
    if mime and Gio.content_type_is_a(mime, "text/plain"):
        return "text"
    return "file"


def entry(folder, info, icons, thumbs=None, hidden_names=()):
    name = info.get_name()
    path = os.path.join(folder, name)
    gfile = Gio.File.new_for_path(path)
    ctype = info.get_content_type() or ""
    is_dir = info.get_file_type() == Gio.FileType.DIRECTORY
    names = icon_names(info.get_icon())
    if is_dir:
        # the theme's folder, not the generic inode-directory art
        names = [n for n in names if not n.startswith("inode-directory")]
        names = names + ["folder"] if "folder" not in names else names
    mtime = info.get_attribute_uint64("time::modified")
    item = {
        "name": name,
        "label": info.get_display_name() or name,
        "path": path,
        "uri": gfile.get_uri(),
        "kind": "dir" if is_dir else "file",
        "mime": "inode/directory" if is_dir else ctype,
        "desc": Gio.content_type_get_description(ctype) if ctype else "",
        "icon": icons.find(names or ["text-x-generic"]) if icons else "",
        "thumb": "",
        "canThumb": False,
        "size": info.get_size(),
        "mtime": mtime,
        "link": info.get_is_symlink(),
        "hidden": info.get_is_hidden() or info.get_is_backup() or name in hidden_names,
        "exec": False,
        "tags": [t for t in (info.get_attribute_stringv("metadata::lucid-tags") or []) if t],
    }
    if not is_dir and info.get_attribute_boolean("thumbnail::is-valid"):
        item["thumb"] = info.get_attribute_byte_string("thumbnail::path") or ""
    elif not is_dir and thumbs is not None and thumbs.can(ctype):
        item["canThumb"] = True
        if not info.get_attribute_boolean("thumbnail::failed"):
            thumbs.want(item["uri"], ctype, mtime, item["size"])
    if not is_dir and name.endswith(".desktop"):
        try:
            app = DesktopAppInfo.new_from_filename(path)
        except TypeError:
            app = None
        if app is not None:
            item["kind"] = "app"
            item["label"] = app.get_name() or name[:-8]
            item["desc"] = app.get_description() or "Application"
            # apps put their icons in hicolor: their own name in every theme
            # before a generic one wins
            if icons:
                item["icon"] = icons.find(icon_names(app.get_icon())) or icons.find(["application-x-executable"])
            # kde's rule: a launcher runs only once it is executable, so one
            # that came in a download cannot fire on a click
            item["exec"] = info.get_attribute_boolean("access::can-execute")
            # which app it is, so lucid's icons can give it its own tile
            app_names = icon_names(app.get_icon())
            item["appId"] = name[:-8]
            item["iconName"] = app_names[0] if app_names else ""
            item["wmClass"] = app.get_startup_wm_class() or ""
            item["cats"] = [c for c in (app.get_categories() or "").split(";") if c]
    item["slot"] = slot_for(item)
    return item


def snapshot(folder, hidden, icons, thumbs, monitor):
    items = []
    if os.path.isdir(folder):
        listed = hidden_list(folder)
        try:
            en = Gio.File.new_for_path(folder).enumerate_children(ATTRS, Gio.FileQueryInfoFlags.NONE, None)
            for info in en:
                if not hidden and (info.get_is_hidden() or info.get_is_backup() or info.get_name() in listed):
                    continue
                items.append(entry(folder, info, icons, thumbs, listed))
        except GLib.Error:
            pass
    try:
        trash = len(os.listdir(trash_dir()))
    except OSError:
        trash = 0
    specials = {
        "home": icons.find(["user-home", "folder-home", "folder"]),
        "trash": icons.find(["user-trash", "trash-empty"]),
        "trashFull": icons.find(["user-trash-full", "trash-full", "user-trash"]),
        "folderDrop": icons.find(["folder-drag-accept", "folder-open", "folder"]),
        "folder": icons.find(["folder"]),
        "drive": icons.find(["drive-removable-media", "drive-harddisk"]),
    }
    return {"dir": folder, "exists": os.path.isdir(folder), "items": items, "trash": trash,
            "specials": specials, "drives": drives(monitor, icons) if monitor else [],
            "templates": templates(icons), "places": places()}


# where send to can copy: the home folders that exist and are not the desktop itself
PLACES = [(GLib.UserDirectory.DIRECTORY_DOCUMENTS, "Documents", "description"),
          (GLib.UserDirectory.DIRECTORY_DOWNLOAD, "Downloads", "download"),
          (GLib.UserDirectory.DIRECTORY_PICTURES, "Pictures", "image"),
          (GLib.UserDirectory.DIRECTORY_MUSIC, "Music", "music_note"),
          (GLib.UserDirectory.DIRECTORY_VIDEOS, "Videos", "movie")]


def places():
    out = []
    home = os.path.realpath(GLib.get_home_dir())
    desk = os.path.realpath(desktop_dir())
    for which, label, glyph in PLACES:
        d = GLib.get_user_special_dir(which)
        if d and os.path.isdir(d) and os.path.realpath(d) not in (home, desk):
            out.append({"label": os.path.basename(d.rstrip("/")) or label, "path": d, "glyph": glyph})
    return out


def templates_dir():
    d = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_TEMPLATES)
    # unset, it answers $HOME, which is no folder of templates
    if not d or os.path.realpath(d) == os.path.realpath(GLib.get_home_dir()):
        return ""
    return d


def templates(icons):
    d = templates_dir()
    out = []
    if not d or not os.path.isdir(d):
        return out
    try:
        en = Gio.File.new_for_path(d).enumerate_children(ATTRS, Gio.FileQueryInfoFlags.NONE, None)
        for info in en:
            if info.get_is_hidden() or info.get_is_backup():
                continue
            e = entry(d, info, icons)
            label = e["label"]
            if e["kind"] == "file" and "." in label[1:]:
                label = label.rsplit(".", 1)[0]
            out.append({"path": e["path"], "label": label, "icon": e["icon"], "kind": e["kind"]})
    except GLib.Error:
        pass
    out.sort(key=lambda t: t["label"].lower())
    return out[:20]


def drives(monitor, icons):
    out = []
    for m in monitor.get_mounts():
        if m.is_shadowed():
            continue
        root = m.get_root()
        uri = root.get_uri()
        names = icon_names(m.get_icon()) + ["drive-removable-media", "drive-harddisk"]
        out.append({
            "key": "::drive:" + uri,
            "label": m.get_name(),
            "path": root.get_path() or "",
            "uri": uri,
            "icon": icons.find(names),
            "canEject": m.can_eject(),
            "canUnmount": m.can_unmount(),
        })
    out.sort(key=lambda d: d["label"].lower())
    return out


# ---- watching -----------------------------------------------------------------

def opts(a):
    def val(flag, default):
        if flag in a:
            i = a.index(flag)
            if i + 1 < len(a):
                return a[i + 1]
        return default
    return {
        "theme": theme_or_system(val("--theme", "")),
        "size": int(float(val("--size", "48"))),
        "scale": int(float(val("--scale", "1"))),
        "hidden": "--hidden" in a,
        "thumbs": "--thumbs" in a,
        "drives": "--drives" in a,
    }


def theme_or_system(name):
    if name:
        return name
    # gio aborts on a schema that is not installed, so look it up first
    src = Gio.SettingsSchemaSource.get_default()
    if src is None or src.lookup("org.gnome.desktop.interface", True) is None:
        return "hicolor"
    return Gio.Settings.new("org.gnome.desktop.interface").get_string("icon-theme") or "hicolor"


def watch(o):
    # follow the shell down instead of lingering after a reload
    try:
        ctypes.CDLL("libc.so.6").prctl(1, signal.SIGTERM)
    except OSError:
        pass
    folder = desktop_dir()
    icons = Icons(o["theme"], o["size"], o["scale"])
    loop = GLib.MainLoop()
    pending = [0]

    def emit():
        pending[0] = 0
        sys.stdout.write(json.dumps(snapshot(folder, o["hidden"], icons, thumbs, monitor)) + "\n")
        sys.stdout.flush()
        return False

    def changed(*_):
        # a copy is a burst of events; one line once it settles
        if pending[0]:
            GLib.source_remove(pending[0])
        pending[0] = GLib.timeout_add(150, emit)

    thumbs = Thumbs(changed) if o["thumbs"] else None
    monitor = Gio.VolumeMonitor.get() if o["drives"] else None
    if monitor:
        for sig in ("mount-added", "mount-removed", "mount-changed"):
            monitor.connect(sig, changed)
    watchers = []
    for d in (folder, trash_dir(), templates_dir()):
        if not d:
            continue
        try:
            m = Gio.File.new_for_path(d).monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
            m.connect("changed", changed)
            watchers.append(m)
        except GLib.Error:
            pass
    # the folder itself may come and go (or not exist yet): watch its parent too
    try:
        pm = Gio.File.new_for_path(os.path.dirname(folder)).monitor_directory(Gio.FileMonitorFlags.NONE, None)
        pm.connect("changed", lambda _m, f, _o, _e: changed() if f.get_path() == folder else None)
        watchers.append(pm)
    except GLib.Error:
        pass
    emit()
    signal.signal(signal.SIGTERM, lambda *_: loop.quit())
    loop.run()


# ---- one-off commands -----------------------------------------------------------

def free_name(dest, name):
    if not os.path.lexists(os.path.join(dest, name)):
        return name
    stem, ext = name, ""
    if not name.startswith(".") and "." in name:
        stem, ext = name.rsplit(".", 1)
        ext = "." + ext
        # photos.tar.gz -> photos (2).tar.gz
        if stem.endswith(".tar"):
            stem, ext = stem[:-4], ".tar" + ext
    n = 2
    while os.path.lexists(os.path.join(dest, "%s (%d)%s" % (stem, n, ext))):
        n += 1
    return "%s (%d)%s" % (stem, n, ext)


def unique(folder, base):
    # "New Folder", then "New Folder 2"; an extension stays at the end
    stem, ext = base, ""
    if "." in base[1:]:
        stem, ext = base.rsplit(".", 1)
        ext = "." + ext
    name, n = base, 2
    while os.path.lexists(os.path.join(folder, name)):
        name = "%s %d%s" % (stem, n, ext)
        n += 1
    return name


def new_item(kind, template=""):
    folder = desktop_dir()
    os.makedirs(folder, exist_ok=True)
    if kind == "folder":
        name = unique(folder, "New Folder")
        os.mkdir(os.path.join(folder, name))
    elif kind == "template" and template:
        name = unique(folder, os.path.basename(template.rstrip("/")))
        if os.path.isdir(template):
            shutil.copytree(template, os.path.join(folder, name), symlinks=True)
        else:
            shutil.copyfile(template, os.path.join(folder, name))
    else:
        base = {"text": "New Document.txt", "markdown": "New Document.md"}.get(kind, "Untitled")
        name = unique(folder, base)
        open(os.path.join(folder, name), "x").close()
    print(name)


def copy_any(src, dest):
    if os.path.isdir(src) and not os.path.islink(src):
        shutil.copytree(src, dest, symlinks=True)
    elif os.path.islink(src):
        os.symlink(os.readlink(src), dest)
    else:
        shutil.copy2(src, dest)


def duplicate(paths):
    for p in paths:
        folder, base = os.path.split(p.rstrip("/"))
        stem, ext = base, ""
        if os.path.isfile(p) and "." in base[1:]:
            stem, ext = base.rsplit(".", 1)
            ext = "." + ext
        name = "%s copy%s" % (stem, ext)
        n = 2
        while os.path.lexists(os.path.join(folder, name)):
            name = "%s copy %d%s" % (stem, n, ext)
            n += 1
        try:
            copy_any(p, os.path.join(folder, name))
            print("%s\t%s" % (p, name), flush=True)
        except OSError as e:
            print("error\t%s\t%s" % (p, e), file=sys.stderr, flush=True)


def make_links(paths):
    for p in paths:
        folder, base = os.path.split(p.rstrip("/"))
        name = unique(folder, "Link to " + base)
        try:
            os.symlink(p, os.path.join(folder, name))
            print("%s\t%s" % (p, name), flush=True)
        except OSError as e:
            print("error\t%s\t%s" % (p, e), file=sys.stderr, flush=True)


def compress(paths):
    import zipfile
    paths = [p.rstrip("/") for p in paths]
    folder = os.path.dirname(paths[0])
    base = os.path.basename(paths[0]) if len(paths) == 1 else "Archive"
    if len(paths) == 1 and os.path.isfile(paths[0]) and "." in base[1:]:
        base = base.rsplit(".", 1)[0]
    name = unique(folder, base + ".zip")
    dest = os.path.join(folder, name)
    tmp = os.path.join(folder, "." + name + ".part")
    try:
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
            for p in paths:
                root = os.path.dirname(p)
                if os.path.isdir(p) and not os.path.islink(p):
                    for d, dirs, files in os.walk(p):
                        rel = os.path.relpath(d, root)
                        if not dirs and not files:
                            z.write(d, rel)
                        for f in files:
                            fp = os.path.join(d, f)
                            if os.path.isfile(fp):
                                z.write(fp, os.path.join(rel, f))
                else:
                    z.write(p, os.path.basename(p))
        os.replace(tmp, dest)
    except (OSError, zipfile.BadZipFile) as e:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        sys.exit("compress failed: %s" % e)
    print(name)


ARCHIVES = (".zip", ".tar", ".tar.gz", ".tgz", ".tar.xz", ".txz", ".tar.bz2", ".tbz2", ".tar.zst",
            ".7z", ".rar", ".gz", ".xz", ".bz2", ".zst", ".jar", ".iso", ".cpio")


def archive_stem(base):
    low = base.lower()
    for ext in sorted(ARCHIVES, key=len, reverse=True):
        if low.endswith(ext):
            return base[:-len(ext)] or base
    return base


def extract(path, into=False):
    folder, base = os.path.split(path)
    stem = archive_stem(base)
    work = os.path.join(folder, "." + stem + ".extracting")
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(work)
    try:
        if shutil.which("bsdtar"):
            subprocess.run(["bsdtar", "-xf", path, "-C", work], check=True, capture_output=True)
        else:
            shutil.unpack_archive(path, work)
    except (subprocess.CalledProcessError, shutil.ReadError, ValueError) as e:
        shutil.rmtree(work, ignore_errors=True)
        sys.exit("extract failed: %s" % e)
    inside = os.listdir(work)
    # one thing inside comes out as itself, not wrapped in a folder of its own name,
    # unless it was asked into a new folder
    if len(inside) == 1 and not into:
        name = unique(folder, inside[0])
        os.rename(os.path.join(work, inside[0]), os.path.join(folder, name))
        os.rmdir(work)
    else:
        name = unique(folder, stem)
        os.rename(work, os.path.join(folder, name))
    print(name)


def mode_string(mode):
    out = "d" if stat.S_ISDIR(mode) else ("l" if stat.S_ISLNK(mode) else "-")
    for who in ("USR", "GRP", "OTH"):
        for what, ch in (("R", "r"), ("W", "w"), ("X", "x")):
            out += ch if mode & getattr(stat, "S_I%s%s" % (what, who)) else "-"
    return out


def info(path, o):
    import pwd
    import grp
    f = Gio.File.new_for_path(path)
    try:
        gi_ = f.query_info("standard::*,time::*,unix::*,owner::*,access::*,thumbnail::path,thumbnail::is-valid,metadata::lucid-tags",
                           Gio.FileQueryInfoFlags.NONE, None)
    except GLib.Error as e:
        sys.exit(e.message)
    st = os.lstat(path)
    ctype = gi_.get_content_type() or ""
    is_dir = gi_.get_file_type() == Gio.FileType.DIRECTORY
    default = Gio.AppInfo.get_default_for_type(ctype, False) if ctype and not is_dir else None
    if is_dir:
        fm = file_manager()
        default = fm
    out = {
        "path": path,
        "name": gi_.get_display_name(),
        "where": os.path.dirname(path),
        "dir": is_dir,
        "mime": ctype,
        "desc": Gio.content_type_get_description(ctype) if ctype else "",
        "size": gi_.get_size(),
        "created": gi_.get_attribute_uint64("time::created"),
        "modified": gi_.get_attribute_uint64("time::modified"),
        "accessed": gi_.get_attribute_uint64("time::access"),
        "owner": pwd.getpwuid(st.st_uid).pw_name if st.st_uid is not None else "",
        "group": grp.getgrgid(st.st_gid).gr_name if st.st_gid is not None else "",
        "mode": mode_string(os.stat(path).st_mode if os.path.exists(path) else st.st_mode),
        "exec": os.access(path, os.X_OK) and not is_dir,
        "writable": os.access(path, os.W_OK),
        "target": os.readlink(path) if os.path.islink(path) else "",
        "app": default.get_display_name() if default else "",
        "tags": [t for t in (gi_.get_attribute_stringv("metadata::lucid-tags") or []) if t],
        "counted": not is_dir,
        "items": 0,
    }
    try:
        fs = f.query_filesystem_info("filesystem::size,filesystem::free,filesystem::type", None)
        out["fsSize"] = fs.get_attribute_uint64("filesystem::size")
        out["fsFree"] = fs.get_attribute_uint64("filesystem::free")
        out["fsType"] = fs.get_attribute_string("filesystem::type") or ""
    except GLib.Error:
        pass
    print(json.dumps(out), flush=True)
    if not is_dir:
        return
    # a folder's real size, walked once; a huge one stops at a few seconds and says so
    import time
    t0, total, items, partial = time.monotonic(), 0, 0, False
    for d, dirs, files in os.walk(path):
        items += len(dirs) + len(files)
        for fn in files:
            try:
                total += os.lstat(os.path.join(d, fn)).st_size
            except OSError:
                pass
        if time.monotonic() - t0 > 4:
            partial = True
            break
    out.update({"size": total, "items": items, "counted": True, "partial": partial})
    print(json.dumps(out), flush=True)


def set_tags(tags, paths):
    want = [t for t in tags.split(",") if t]
    for p in paths:
        f = Gio.File.new_for_path(p)
        try:
            if want:
                fi = Gio.FileInfo()
                fi.set_attribute_stringv("metadata::lucid-tags", want)
                f.set_attributes_from_info(fi, Gio.FileQueryInfoFlags.NONE, None)
            else:
                f.set_attribute("metadata::lucid-tags", Gio.FileAttributeType.INVALID, None, Gio.FileQueryInfoFlags.NONE, None)
        except GLib.Error as e:
            print("error\t%s\t%s" % (p, e.message), file=sys.stderr)


def restore(paths, tags=None):
    # read the trash's own records rather than trash:///, which needs gvfs: the
    # newest entry for each original path goes back where it was
    from urllib.parse import unquote
    base = os.path.join(GLib.get_user_data_dir(), "Trash")
    want = {os.path.abspath(p): None for p in paths}
    try:
        infos = os.listdir(os.path.join(base, "info"))
    except OSError:
        infos = []
    for fn in infos:
        if not fn.endswith(".trashinfo"):
            continue
        orig, when = "", ""
        try:
            with open(os.path.join(base, "info", fn), encoding="utf-8") as f:
                for line in f:
                    if line.startswith("Path="):
                        orig = unquote(line[5:].strip())
                    elif line.startswith("DeletionDate="):
                        when = line[13:].strip()
        except OSError:
            continue
        if orig in want and (want[orig] is None or when > want[orig][1]):
            want[orig] = (fn[:-len(".trashinfo")], when)
    for orig, hit in want.items():
        if hit is None:
            continue
        folder, name0 = os.path.split(orig)
        name = name0 if not os.path.lexists(orig) else unique(folder, name0)
        try:
            os.makedirs(folder, exist_ok=True)
            shutil.move(os.path.join(base, "files", hit[0]), os.path.join(folder, name))
            os.unlink(os.path.join(base, "info", hit[0] + ".trashinfo"))
            # tags live in metadata kept by path, which the trip to the trash lost
            if tags and tags.get(orig):
                set_tags(",".join(tags[orig]), [os.path.join(folder, name)])
            print("%s\t%s" % (orig, name), flush=True)
        except OSError as e:
            print("error\t%s\t%s" % (orig, e), file=sys.stderr, flush=True)


def relocate(pairs):
    # undo of a move: each file back where it came from, beside anything now in its place
    for i in range(0, len(pairs) - 1, 2):
        src, dst = pairs[i], pairs[i + 1]
        if not os.path.lexists(src):
            continue
        folder, base = os.path.split(dst)
        name = base if not os.path.lexists(dst) else unique(folder, base)
        try:
            os.makedirs(folder, exist_ok=True)
            shutil.move(src, os.path.join(folder, name))
            print("%s\t%s" % (src, name), flush=True)
        except OSError as e:
            print("error\t%s\t%s" % (src, e), file=sys.stderr, flush=True)


def delete(paths):
    for p in paths:
        try:
            if os.path.isdir(p) and not os.path.islink(p):
                shutil.rmtree(p)
            else:
                os.unlink(p)
        except OSError as e:
            print("error\t%s\t%s" % (p, e), file=sys.stderr, flush=True)


def clip():
    # nautilus says copy or cut in its own type; anything else with a uri list is a copy
    def paste(t):
        try:
            return subprocess.run(["wl-paste", "--no-newline", "--type", t], capture_output=True, timeout=3).stdout.decode("utf-8", "replace")
        except (OSError, subprocess.TimeoutExpired):
            return ""
    try:
        types = subprocess.run(["wl-paste", "--list-types"], capture_output=True, timeout=3).stdout.decode().split()
    except (OSError, subprocess.TimeoutExpired):
        types = []
    out = {"mode": "copy", "uris": [], "image": False}
    if "x-special/gnome-copied-files" in types:
        lines = [l for l in paste("x-special/gnome-copied-files").splitlines() if l]
        if lines and lines[0] in ("copy", "cut"):
            out["mode"] = lines[0]
            out["uris"] = lines[1:]
    elif "text/uri-list" in types:
        out["uris"] = [l for l in paste("text/uri-list").splitlines() if l and not l.startswith("#")]
    out["uris"] = [u for u in out["uris"] if "://" in u]
    out["image"] = not out["uris"] and any(t.startswith("image/png") for t in types)
    print(json.dumps(out))


def paste_image(dest):
    import time
    dest = dest or desktop_dir()
    name = unique(dest, time.strftime("Pasted image %Y-%m-%d %H-%M-%S.png"))
    try:
        data = subprocess.run(["wl-paste", "--no-newline", "--type", "image/png"], capture_output=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        data = b""
    if not data:
        sys.exit("no picture on the clipboard")
    with open(os.path.join(dest, name), "wb") as f:
        f.write(data)
    print(name)


def put(mode, dest, uris):
    os.makedirs(dest, exist_ok=True)
    dest_dev = os.stat(dest).st_dev
    for uri in uris:
        src = Gio.File.new_for_uri(uri)
        base = src.get_basename() or "file"
        spath = src.get_path()
        # moved where it already is: nothing to do; a copy there is a second one
        if spath and os.path.dirname(os.path.abspath(spath)) == os.path.abspath(dest) and mode != "copy":
            print("%s\t%s" % (uri, base))
            continue
        # a folder into itself or one of its own
        if spath and os.path.isdir(spath) and (os.path.abspath(dest) + "/").startswith(os.path.abspath(spath) + "/"):
            continue
        name = free_name(dest, base)
        target = Gio.File.new_for_path(os.path.join(dest, name))
        how = mode
        if how == "auto":
            try:
                how = "move" if spath and os.stat(spath).st_dev == dest_dev else "copy"
            except OSError:
                how = "copy"
        try:
            if how == "link" and spath:
                os.symlink(spath, target.get_path())
            elif how == "move":
                src.move(target, Gio.FileCopyFlags.NOFOLLOW_SYMLINKS, None, None, None)
            elif spath and os.path.isdir(spath) and not os.path.islink(spath):
                # gio copies files only
                subprocess.run(["cp", "-a", "--", spath, target.get_path()], check=True)
            else:
                src.copy(target, Gio.FileCopyFlags.NOFOLLOW_SYMLINKS, None, None, None)
            print("%s\t%s" % (uri, name), flush=True)
        except (GLib.Error, subprocess.CalledProcessError, OSError) as e:
            print("error\t%s\t%s" % (uri, e), file=sys.stderr, flush=True)


def app_file(desktop_id):
    for cand in (desktop_id, desktop_id + ".desktop"):
        try:
            app = DesktopAppInfo.new(cand)
        except TypeError:
            app = None
        if app is not None and app.get_filename():
            return app.get_filename()
    # a hidden or odd entry the lookup skips: find the file itself
    name = desktop_id if desktop_id.endswith(".desktop") else desktop_id + ".desktop"
    for d in [GLib.get_user_data_dir()] + list(GLib.get_system_data_dirs()):
        p = os.path.join(d, "applications", name)
        if os.path.isfile(p):
            return p
    return None


def add_app(desktop_id):
    src = app_file(desktop_id)
    if src is None:
        sys.exit("no such application: " + desktop_id)
    folder = desktop_dir()
    os.makedirs(folder, exist_ok=True)
    name = free_name(folder, os.path.basename(src))
    path = os.path.join(folder, name)
    with open(src, "rb") as f, open(path, "wb") as out:
        out.write(f.read())
    trust(path)
    print(os.path.basename(src) + "\t" + name)


def app_for_dock(app_id, icon, command=""):
    # the dock knows an app by its window class, which is seldom its desktop id:
    # the id itself, a StartupWMClass, the icon's name, then a search. of those, the
    # one that runs what the pin runs wins (native steam and the flatpak share a class)
    found = []

    def take(app):
        if app is not None and app.get_filename() and app.get_filename() not in [a.get_filename() for a in found]:
            found.append(app)

    for cand in [app_id, app_id.lower(), icon, icon.lower()]:
        if not cand:
            continue
        for name in (cand, cand + ".desktop"):
            try:
                take(DesktopAppInfo.new(name))
            except TypeError:
                pass
    low = app_id.lower()
    for app in Gio.AppInfo.get_all():
        wm = app.get_startup_wm_class() if hasattr(app, "get_startup_wm_class") else None
        if wm and wm.lower() == low:
            take(app)
    for group in (DesktopAppInfo.search(app_id) if app_id else []):
        for app_name in group[:3]:
            try:
                take(DesktopAppInfo.new(app_name))
            except TypeError:
                pass

    def bare(cmd):
        return " ".join(t for t in (cmd or "").replace("@@u", "").replace("@@", "").split() if not t.startswith("%"))
    for app in found:
        if command and bare(app.get_commandline()) == bare(command):
            return app.get_filename()
    return found[0].get_filename() if found else None


def add_dock_app(app_id, icon, name, command):
    # a dock pin onto the desktop: the app's own launcher, or one written from the pin
    folder = desktop_dir()
    os.makedirs(folder, exist_ok=True)
    src = app_for_dock(app_id, icon, command)
    if src:
        dest = free_name(folder, os.path.basename(src))
        with open(src, "rb") as f, open(os.path.join(folder, dest), "wb") as out:
            out.write(f.read())
    else:
        kf = GLib.KeyFile()
        kf.set_string("Desktop Entry", "Type", "Application")
        kf.set_string("Desktop Entry", "Name", name or app_id)
        kf.set_string("Desktop Entry", "Exec", command)
        if icon:
            kf.set_string("Desktop Entry", "Icon", icon)
        if app_id:
            kf.set_string("Desktop Entry", "StartupWMClass", app_id)
        safe = "".join(c for c in (name or app_id or "App") if c not in "/\\0").strip() or "App"
        dest = free_name(folder, safe + ".desktop")
        kf.save_to_file(os.path.join(folder, dest))
    trust(os.path.join(folder, dest))
    print((src or app_id) + "\t" + dest)


def trust(path):
    mode = os.stat(path).st_mode
    os.chmod(path, mode | stat.S_IXUSR)


def rename(path, new):
    new = new.strip()
    if not new or "/" in new or new in (".", ".."):
        sys.exit("bad name")
    if path.endswith(".desktop") and os.path.isfile(path):
        kf = GLib.KeyFile()
        kf.load_from_file(path, GLib.KeyFileFlags.KEEP_COMMENTS | GLib.KeyFileFlags.KEEP_TRANSLATIONS)
        kf.set_string("Desktop Entry", "Name", new)
        # a translated name would win over the one just typed
        for key in kf.get_keys("Desktop Entry")[0]:
            if key.startswith("Name["):
                kf.remove_key("Desktop Entry", key)
        kf.save_to_file(path)
        print(os.path.basename(path))
        return
    dest = os.path.join(os.path.dirname(path), new)
    if os.path.lexists(dest):
        sys.exit("exists")
    os.rename(path, dest)
    print(new)


def peek(path, o, n=8):
    icons = Icons(o["theme"], o["size"], o["scale"])
    items = []
    try:
        en = Gio.File.new_for_path(path).enumerate_children(ATTRS, Gio.FileQueryInfoFlags.NONE, None)
        for info in en:
            if info.get_is_hidden() or info.get_is_backup():
                continue
            items.append(info)
    except GLib.Error:
        pass
    items.sort(key=lambda i: (i.get_file_type() != Gio.FileType.DIRECTORY, (i.get_display_name() or "").lower()))
    print(json.dumps({"count": len(items), "items": [entry(path, i, icons) for i in items[:n]]}))


def apps_for(uri, o):
    icons = Icons(o["theme"], o["size"], o["scale"])
    try:
        info = Gio.File.new_for_uri(uri).query_info("standard::content-type", Gio.FileQueryInfoFlags.NONE, None)
        ctype = info.get_content_type() or ""
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
            fname = a.get_filename() if hasattr(a, "get_filename") else None
            if not fname:
                continue
            out.append({
                "id": a.get_id(),
                "name": a.get_display_name() or a.get_name(),
                "file": fname,
                "icon": icons.find(icon_names(a.get_icon()), 24) or icons.find(["application-x-executable"], 24),
                "default": default is not None and a.get_id() == default.get_id(),
            })
            if len(out) >= 6:
                break
    print(json.dumps({"mime": ctype, "apps": out}))


# the dock's own order for the files slot, see detect_pinned in install.sh
FILE_MANAGERS = ["lucid.lumen", "org.gnome.Nautilus", "nautilus", "org.kde.dolphin", "dolphin", "thunar",
                 "nemo", "pcmanfm-qt", "pcmanfm", "caja"]


def is_file_manager(app):
    cats = app.get_categories() if hasattr(app, "get_categories") else None
    return "FileManager" in (cats or "").split(";")


def file_manager():
    # the default for folders is whatever registered first unless someone chose:
    # an editor that claims folders (vscodium, zed) is no place to open one
    default = Gio.AppInfo.get_default_for_type("inode/directory", False)
    if default is not None and is_file_manager(default):
        return default

    def rank(a):
        name = a.get_id()[:-8] if a.get_id().endswith(".desktop") else a.get_id()
        return FILE_MANAGERS.index(name) if name in FILE_MANAGERS else len(FILE_MANAGERS)
    apps = sorted((a for a in Gio.AppInfo.get_all_for_type("inode/directory") if is_file_manager(a)), key=rank)
    return apps[0] if apps else default


def launch(app, uris):
    # async with a loop to wait on: a d-bus activated app (nautilus) is only
    # asked once the call goes out, and this process would exit before that
    loop = GLib.MainLoop()

    def done(a, res):
        try:
            a.launch_uris_finish(res)
        except GLib.Error as e:
            print(e.message, file=sys.stderr)
        loop.quit()
    app.launch_uris_async(uris, None, None, done)
    GLib.timeout_add_seconds(15, loop.quit)
    loop.run()


def open_default(uri):
    loop = GLib.MainLoop()

    def done(_src, res):
        try:
            Gio.AppInfo.launch_default_for_uri_finish(res)
        except GLib.Error as e:
            print(e.message, file=sys.stderr)
        loop.quit()
    Gio.AppInfo.launch_default_for_uri_async(uri, None, None, done)
    GLib.timeout_add_seconds(15, loop.quit)
    loop.run()


def open_folders(uris):
    fm = file_manager()
    if fm is None:
        for u in uris:
            subprocess.Popen(["xdg-open", u], start_new_session=True)
        return
    # one that only takes paths (hyprfm's Exec is %F) gets the folder on disk
    if not fm.supports_uris():
        uris = [u if not u.startswith("trash:") else Gio.File.new_for_path(trash_dir()).get_uri() for u in uris]
    launch(fm, uris)


def open_uris(uris):
    # folders in a file manager, files with whatever opens their type
    folders = []
    for u in uris:
        f = Gio.File.new_for_uri(u)
        try:
            kind = f.query_file_type(Gio.FileQueryInfoFlags.NONE, None)
        except GLib.Error:
            kind = Gio.FileType.UNKNOWN
        if u.startswith("trash:") or kind == Gio.FileType.DIRECTORY:
            folders.append(u)
        else:
            open_default(u)
    if folders:
        open_folders(folders)


def open_trash():
    os.makedirs(trash_dir(), exist_ok=True)
    open_folders(["trash:///"])


def luma(path, sw, sh, cols=96, rows=54):
    # the picture cropped to cover the screen the way the wallpaper daemon
    # fills it, as a grid of lightness from 0 to 100
    gi.require_version("GdkPixbuf", "2.0")
    from gi.repository import GdkPixbuf
    try:
        info = GdkPixbuf.Pixbuf.get_file_info(path)
        if not info or not info[0]:
            raise GLib.Error("unknown")
        iw, ih = info[1], info[2]
        k = max(cols / iw, rows / ih) * 2
        pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, max(cols, round(iw * k)), max(rows, round(ih * k)), True)
    except GLib.Error:
        print(json.dumps({"cols": 0, "rows": 0, "l": []}))
        return
    w, h = pb.get_width(), pb.get_height()
    scale = max(sw / w, sh / h)
    vw, vh = sw / scale, sh / scale
    ox, oy = (w - vw) / 2, (h - vh) / 2
    px = pb.get_pixels()
    stride, n = pb.get_rowstride(), pb.get_n_channels()

    def lin(v):
        v /= 255
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4

    out = []
    for r in range(rows):
        for c in range(cols):
            acc = 0
            for sy in (0.25, 0.75):
                for sx in (0.25, 0.75):
                    x = min(w - 1, int(ox + (c + sx) * vw / cols))
                    y = min(h - 1, int(oy + (r + sy) * vh / rows))
                    i = y * stride + x * n
                    acc += 0.2126 * lin(px[i]) + 0.7152 * lin(px[i + 1]) + 0.0722 * lin(px[i + 2])
            y_ = acc / 4
            lstar = y_ * 903.3 if y_ <= 0.008856 else 116 * y_ ** (1 / 3) - 16
            out.append(round(lstar))
    print(json.dumps({"cols": cols, "rows": rows, "l": out}))


def main():
    a = sys.argv[1:]
    cmd = a[0] if a else "watch"
    if cmd == "watch":
        watch(opts(a))
    elif cmd == "peek":
        peek(a[1], opts(a))
    elif cmd == "apps-for":
        apps_for(a[1], opts(a))
    elif cmd == "new-folder":
        new_item("folder")
    elif cmd == "new":
        new_item(a[1], a[2] if len(a) > 2 else "")
    elif cmd == "duplicate":
        duplicate(a[1:])
    elif cmd == "link":
        make_links(a[1:])
    elif cmd == "compress":
        compress(a[1:])
    elif cmd == "extract":
        extract(a[1])
    elif cmd == "info":
        info(a[1], opts(a))
    elif cmd == "set-tags":
        set_tags(a[1], a[2:])
    elif cmd == "restore":
        if len(a) > 2 and a[1] == "--tags":
            restore(a[3:], json.loads(a[2] or "{}"))
        else:
            restore(a[1:])
    elif cmd == "delete":
        delete(a[1:])
    elif cmd == "relocate":
        relocate(a[1:])
    elif cmd == "clip":
        clip()
    elif cmd == "paste-image":
        paste_image(a[1] if len(a) > 1 else "")
    elif cmd == "put":
        dest = a[2] if a[2] else desktop_dir()
        put(a[1], dest, a[3:])
    elif cmd == "add-app":
        add_app(a[1])
    elif cmd == "add-dock-app":
        add_dock_app(a[1], a[2], a[3], a[4])
    elif cmd == "rename":
        rename(a[1], a[2])
    elif cmd == "trust":
        trust(a[1])
    elif cmd == "luma":
        luma(a[1], float(a[2]), float(a[3]))
    elif cmd == "open":
        open_uris(a[1:])
    elif cmd == "open-trash":
        open_trash()
    else:
        sys.exit("unknown command " + cmd)


if __name__ == "__main__":
    main()
