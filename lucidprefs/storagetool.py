#!/usr/bin/env python3
"""What fills the disks, and what could go. Every mode prints JSON.

  volumes                  mounted filesystems and the drives under them
  scan PATH OUT [HINT]     walks the filesystem PATH is on, from PATH down, and
                           writes the tree to OUT. while it runs stdout gets
                           "p <files> <bytes>" lines, and a last "d" line.
                           HINT (bytes) marks a re-scan of one folder
  cleanup                  what could be reclaimed, measured
  clean ID                 reclaims one of those
  trash-old DAYS           drops trash that was deleted more than DAYS days ago
  health DEVICE            smartctl's report on a drive, through pkexec

Sizes are allocated bytes, as du counts them, so they add up to what df says.
"""

import hashlib
import heapq
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import time

HOME = os.path.realpath(os.path.expanduser("~"))
UID = os.getuid()
CACHE = os.path.realpath(os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache"))
DATA = os.path.realpath(os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local", "share"))
TRASH = os.path.join(DATA, "Trash")
GIB = 1 << 30
MIB = 1 << 20

# what a file is, by extension; the map draws each kind in its own colour
KINDS = ["other", "video", "image", "audio", "docs", "archive", "code", "apps"]
EXT = {}
for _k, _exts in (
    (1, "mp4 mkv webm avi mov m4v wmv flv mpg mpeg 3gp m2ts mts vob ogv"),
    (2, "jpg jpeg png gif webp bmp tif tiff heic heif avif svg ico jxl raw cr2 cr3 nef arw dng orf rw2 psd xcf kra exr hdr"),
    (3, "mp3 flac wav ogg oga opus m4a aac wma aiff aif alac ape mid midi mka"),
    (4, "pdf doc docx odt rtf txt md epub mobi azw3 xls xlsx ods csv ppt pptx odp tex djvu"),
    (5, "zip tar gz tgz xz txz zst bz2 tbz 7z rar lz4 lzma iso img qcow2 vdi vmdk vhd vhdx dmg wim cab deb rpm"),
    (6, "py pyc js mjs cjs ts tsx jsx c h cc cpp hpp rs go java kt kts class jar dart swift rb php lua sh json yaml yml toml lock o a rlib rmeta pack idx dex map wasm"),
    (7, "so exe dll appimage apk aab msi flatpak snap"),
):
    for _e in _exts.split():
        EXT[_e] = _k

# where the space goes, for the overview bar. home is sorted by kind, the rest
# of the root filesystem is the system unless a rule says otherwise
CATS = ["system", "apps", "pkgcache", "caches", "trash", "video", "image", "audio", "docs", "archive", "code", "other"]
CAT = {c: i for i, c in enumerate(CATS)}
KIND_CAT = [CAT["other"], CAT["video"], CAT["image"], CAT["audio"], CAT["docs"], CAT["archive"], CAT["code"], CAT["apps"]]
BY_KIND = -1

MAX_KIDS = 120
LARGE_MIN = 64 * MIB
LARGE_KEEP = 60
DUP_MIN = 16 * MIB
DUP_KEEP = 40
# a copy inside a package tree belongs to the package, so it is not offered
LIBRARY = re.compile(r"/(site-packages|dist-packages|node_modules|\.git|\.venv|venv|\.tox|\.gradle|\.m2)/")


def out(obj):
    sys.stdout.write(json.dumps(obj, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def run(args, timeout=20, **kw):
    try:
        env = dict(os.environ, LC_ALL="C")
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout, env=env, **kw)
    except Exception:
        return None


def have(cmd):
    return shutil.which(cmd) is not None


def kind_of(name, mode):
    i = name.rfind(".")
    if i > 0:
        k = EXT.get(name[i + 1:].lower())
        if k:
            return k
        if ".so." in name:
            return 7
        return 0
    return 7 if mode & 0o111 else 0


def du(path):
    """allocated bytes and file count under path, hard links once"""
    total = 0
    count = 0
    seen = set()
    stack = [path]
    try:
        st = os.lstat(path)
    except OSError:
        return 0, 0
    if not stat.S_ISDIR(st.st_mode):
        return st.st_blocks * 512, 1
    dev = st.st_dev
    while stack:
        p = stack.pop()
        try:
            it = os.scandir(p)
        except OSError:
            continue
        with it:
            for e in it:
                try:
                    s = e.stat(follow_symlinks=False)
                except OSError:
                    continue
                if stat.S_ISDIR(s.st_mode):
                    if s.st_dev == dev:
                        stack.append(e.path)
                    total += s.st_blocks * 512
                    continue
                if s.st_nlink > 1:
                    key = (s.st_dev, s.st_ino)
                    if key in seen:
                        continue
                    seen.add(key)
                total += s.st_blocks * 512
                count += 1
    return total, count


# ------------------------------------------------------------------ mounts

def unescape(s):
    return re.sub(r"\\([0-7]{3})", lambda m: chr(int(m.group(1), 8)), s)


def mountinfo():
    rows = []
    try:
        with open("/proc/self/mountinfo") as f:
            for line in f:
                left, _, right = line.partition(" - ")
                a = left.split()
                b = right.split()
                if len(a) < 6 or len(b) < 2:
                    continue
                rows.append({
                    "root": unescape(a[3]),
                    "mount": unescape(a[4]),
                    "opts": a[5].split(","),
                    "fstype": b[0],
                    "source": unescape(b[1]),
                })
    except OSError:
        pass
    return rows


def mount_of(path, rows):
    best = None
    for r in rows:
        m = r["mount"]
        if path == m or path.startswith(m.rstrip("/") + "/") or m == "/":
            if best is None or len(m) > len(best["mount"]):
                best = r
    return best


def statvfs(path):
    try:
        s = os.statvfs(path)
    except OSError:
        return None
    size = s.f_blocks * s.f_frsize
    return {
        "size": size,
        "used": (s.f_blocks - s.f_bfree) * s.f_frsize,
        "avail": s.f_bavail * s.f_frsize,
    }


def lsblk():
    r = run(["lsblk", "-J", "-b", "-o",
             "NAME,KNAME,PATH,SIZE,TYPE,FSTYPE,LABEL,PARTLABEL,MOUNTPOINTS,MODEL,VENDOR,TRAN,RM,HOTPLUG,ROTA"])
    try:
        return json.loads(r.stdout).get("blockdevices", []) if r else []
    except ValueError:
        return []


def truthy(v):
    return v is True or v == "1" or v == 1


def temps():
    """drive temperatures in °C, keyed by block device name"""
    out_ = {}
    base = "/sys/class/hwmon"
    try:
        hw = os.listdir(base)
    except OSError:
        return out_
    blocks = []
    try:
        blocks = os.listdir("/sys/block")
    except OSError:
        pass
    for h in hw:
        p = os.path.join(base, h)
        try:
            name = open(os.path.join(p, "name")).read().strip()
            t = int(open(os.path.join(p, "temp1_input")).read().strip()) / 1000
        except (OSError, ValueError):
            continue
        dev = os.path.realpath(os.path.join(p, "device"))
        if name == "nvme":
            ctrl = os.path.basename(dev)
            for b in blocks:
                m = re.match(r"(nvme\d+)n\d+$", b)
                if m and m.group(1) == ctrl:
                    out_[b] = t
        elif name == "drivetemp":
            for b in blocks:
                if os.path.realpath("/sys/block/%s/device" % b) == dev:
                    out_[b] = t
    return out_


def pretty_label(label):
    label = (label or "").strip()
    if not label:
        return ""
    label = label.replace("_", " ")
    return label.title() if label.isupper() else label


def volume_name(mount, fstype, label, removable, model):
    if mount == "/":
        return "System"
    if mount in ("/home", HOME):
        return "Home"
    if mount in ("/efi", "/boot/efi") or fstype == "vfat" and not removable and mount.startswith("/boot"):
        return "EFI"
    if mount == "/boot":
        return "Boot"
    nice = pretty_label(label)
    if nice:
        return nice
    if removable and model:
        return model.strip()
    base = os.path.basename(mount.rstrip("/")) or mount
    return base[:1].upper() + base[1:]


def volumes():
    rows = mountinfo()
    tree = lsblk()
    devs = {}
    disks = []

    def visit(d, disk):
        devs[d.get("path")] = (d, disk)
        devs["/dev/" + (d.get("kname") or "")] = (d, disk)
        for c in d.get("children") or []:
            visit(c, disk)

    for d in tree:
        if d.get("type") != "disk" or re.match(r"^(zram|loop|ram)", d.get("name") or ""):
            continue
        disks.append(d)
        visit(d, d)

    home_mount = mount_of(HOME, rows)
    th = temps()
    seen = {}
    for r in rows:
        src = r["source"]
        if not src.startswith("/dev/"):
            continue
        prev = seen.get(src)
        # one entry per filesystem: "/" wins, then the shortest mount point
        if prev is None or r["mount"] == "/" or (prev["mount"] != "/" and len(r["mount"]) < len(prev["mount"])):
            seen[src] = r

    vols = []
    for src, r in seen.items():
        if "snapshot" in r["root"]:
            continue
        sv = statvfs(r["mount"])
        if not sv or sv["size"] == 0:
            continue
        d, disk = devs.get(src) or devs.get(os.path.realpath(src)) or ({}, {})
        removable = truthy(disk.get("rm")) or truthy(disk.get("hotplug"))
        label = d.get("label") or ""
        vols.append({
            "mount": r["mount"],
            "source": src,
            "fstype": r["fstype"],
            "label": label,
            "name": volume_name(r["mount"], r["fstype"], label, removable, disk.get("model")),
            "size": sv["size"],
            "used": sv["used"],
            "avail": sv["avail"],
            "readonly": "ro" in r["opts"],
            "removable": removable,
            "disk": disk.get("name") or "",
            "device": d.get("name") or os.path.basename(src),
            "home": bool(home_mount) and home_mount["source"] == src,
            "root": r["mount"] == "/",
        })
    vols.sort(key=lambda v: (not v["root"], not v["home"], v["removable"], -v["size"]))

    drives = []
    for disk in disks:
        parts = []
        for c in disk.get("children") or []:
            mounts = [m for m in (c.get("mountpoints") or []) if m]
            sv = None
            real = [m for m in mounts if m.startswith("/")]
            if real:
                sv = statvfs(real[0])
            parts.append({
                "name": c.get("name"),
                "path": c.get("path"),
                "size": c.get("size") or 0,
                "fstype": c.get("fstype") or "",
                "label": pretty_label(c.get("label") or ""),
                "partlabel": c.get("partlabel") or "",
                "mounts": mounts,
                "used": sv["used"] if sv else -1,
                "avail": sv["avail"] if sv else -1,
                "fssize": sv["size"] if sv else -1,
            })
        drives.append({
            "name": disk.get("name"),
            "path": disk.get("path"),
            "model": (disk.get("model") or "").strip(),
            "vendor": (disk.get("vendor") or "").strip(),
            "size": disk.get("size") or 0,
            "tran": disk.get("tran") or "",
            "rota": truthy(disk.get("rota")),
            "removable": truthy(disk.get("rm")) or truthy(disk.get("hotplug")),
            "temp": th.get(disk.get("name"), -1),
            "parts": parts,
        })
    return {"volumes": vols, "drives": drives, "home": HOME}


# -------------------------------------------------------------------- scan

def path_rules(mount):
    r = {
        "/var/cache/pacman": CAT["pkgcache"],
        "/var/lib/flatpak": CAT["apps"],
        "/opt": CAT["apps"],
        os.path.join(CACHE, "yay"): CAT["pkgcache"],
        os.path.join(CACHE, "paru"): CAT["pkgcache"],
        CACHE: CAT["caches"],
        TRASH: CAT["trash"],
        os.path.join(DATA, "flatpak"): CAT["apps"],
        os.path.join(DATA, "Steam"): CAT["apps"],
        os.path.join(HOME, ".steam"): CAT["apps"],
        os.path.join(HOME, ".npm"): CAT["caches"],
        os.path.join(HOME, ".gradle", "caches"): CAT["caches"],
        os.path.join(HOME, ".cargo", "registry"): CAT["caches"],
        os.path.join(HOME, ".m2", "repository"): CAT["caches"],
        os.path.join(HOME, ".pub-cache"): CAT["caches"],
        os.path.join(HOME, "go", "pkg", "mod"): CAT["caches"],
        os.path.join(HOME, ".bun", "install", "cache"): CAT["caches"],
        "/home": BY_KIND,
        HOME: BY_KIND,
    }
    m = mount.rstrip("/")
    r[m + "/.Trash-%d" % UID] = CAT["trash"]
    r[m + "/.Trash"] = CAT["trash"]
    # a windows partition
    if os.path.isdir(m + "/Windows/System32"):
        r[m + "/Windows"] = CAT["system"]
        r[m + "/Program Files"] = CAT["apps"]
        r[m + "/Program Files (x86)"] = CAT["apps"]
        r[m + "/ProgramData"] = CAT["apps"]
        r[m + "/$Recycle.Bin"] = CAT["trash"]
        for f in ("pagefile.sys", "hiberfil.sys", "swapfile.sys"):
            r[m + "/" + f] = CAT["system"]
    return r


class Scan:
    def __init__(self, root, keep_min, rules, skip):
        self.root = root
        self.keep_min = keep_min
        self.rules = rules
        self.skip = skip
        self.files = 0
        self.bytes = 0
        self.errors = 0
        self.cats = [0] * len(CATS)
        self.large = []
        self.seen_dirs = set()
        self.seen_links = set()
        self.sizes = {}
        self.last = 0.0

    def tick(self):
        now = time.monotonic()
        if now - self.last > 0.2:
            self.last = now
            sys.stdout.write("p %d %d\n" % (self.files, self.bytes))
            sys.stdout.flush()

    def walk(self, path, name, cat, own):
        kinds = [0] * len(KINDS)
        size = own
        count = 0
        kids = []
        small_s = 0
        small_n = 0
        if cat >= 0:
            self.cats[cat] += own
        else:
            self.cats[CAT["other"]] += own
        self.bytes += own
        try:
            it = os.scandir(path)
        except OSError:
            self.errors += 1
            return {"n": name, "t": 1, "s": size, "f": 0, "k": 0, "u": 1}, kinds
        with it:
            for e in it:
                try:
                    st = e.stat(follow_symlinks=False)
                except OSError:
                    self.errors += 1
                    continue
                mode = st.st_mode
                if stat.S_ISDIR(mode):
                    p = e.path
                    if p in self.skip:
                        continue
                    key = (st.st_dev, st.st_ino)
                    if key in self.seen_dirs:
                        continue
                    self.seen_dirs.add(key)
                    sub, sk = self.walk(p, e.name, self.rules.get(p, cat), st.st_blocks * 512)
                    for i in range(len(KINDS)):
                        kinds[i] += sk[i]
                    size += sub["s"]
                    count += sub["f"]
                    if sub["s"] >= self.keep_min:
                        kids.append(sub)
                    else:
                        small_s += sub["s"]
                        small_n += 1
                    continue
                if st.st_nlink > 1:
                    key = (st.st_dev, st.st_ino)
                    if key in self.seen_links:
                        continue
                    self.seen_links.add(key)
                b = st.st_blocks * 512
                k = kind_of(e.name, mode) if stat.S_ISREG(mode) else 0
                kinds[k] += b
                size += b
                count += 1
                self.files += 1
                self.bytes += b
                c = self.rules.get(e.path, cat)
                self.cats[KIND_CAT[k] if c == BY_KIND else c] += b
                if b >= self.keep_min:
                    kids.append({"n": e.name, "t": 0, "s": b, "k": k, "m": int(st.st_mtime)})
                else:
                    small_s += b
                    small_n += 1
                # only your own files are offered as big or duplicated
                if c == BY_KIND and b >= DUP_MIN and stat.S_ISREG(mode) and not LIBRARY.search(e.path):
                    # copies inside hidden folders are some app's own business
                    if "/." not in e.path:
                        self.sizes.setdefault(st.st_size, []).append((e.path, b, int(st.st_mtime), k))
                    if b >= LARGE_MIN:
                        item = (b, e.path, int(st.st_mtime), k)
                        if len(self.large) < LARGE_KEEP:
                            heapq.heappush(self.large, item)
                        elif b > self.large[0][0]:
                            heapq.heapreplace(self.large, item)
                if not self.files & 1023:
                    self.tick()
        kids.sort(key=lambda n: n["s"], reverse=True)
        if len(kids) > MAX_KIDS:
            for n in kids[MAX_KIDS:]:
                small_s += n["s"]
                small_n += 1
            kids = kids[:MAX_KIDS]
        if small_s > 0 or small_n > 0:
            kids.append({"n": "", "t": 2, "s": small_s, "o": small_n})
        node = {"n": name, "t": 1, "s": size, "f": count, "k": max(range(len(KINDS)), key=lambda i: kinds[i]) if size else 0}
        if kids:
            node["c"] = kids
        return node, kinds

    # files of one size are compared by eight samples spread through them;
    # reading every byte of every big file would take minutes
    def dupes(self):
        groups = []
        for size, files in self.sizes.items():
            if len(files) < 2:
                continue
            by = {}
            for p, b, m, k in files:
                h = sample_hash(p, size)
                if h:
                    by.setdefault(h, []).append({"p": p, "s": b, "m": m, "k": k})
            for fs in by.values():
                if len(fs) > 1:
                    fs.sort(key=lambda f: f["m"])
                    groups.append({"size": size, "waste": sum(f["s"] for f in fs) - max(f["s"] for f in fs), "files": fs})
        groups.sort(key=lambda g: -g["waste"])
        return groups[:DUP_KEEP]


def sample_hash(path, size):
    chunk = 64 * 1024
    h = hashlib.blake2b(digest_size=16)
    try:
        with open(path, "rb") as f:
            for i in range(8):
                f.seek(max(0, (size - chunk) * i // 7))
                h.update(f.read(chunk))
    except OSError:
        return None
    return h.hexdigest()


def scan(root, dest, hint=0):
    root = os.path.realpath(root)
    rows = mountinfo()
    vol = mount_of(root, rows)
    source = vol["source"] if vol else ""
    skip = set()
    for r in rows:
        m = r["mount"]
        if m == root:
            continue
        if r["source"] != source or "snapshot" in r["root"] or m.endswith("/.snapshots"):
            skip.add(m)
    sv = statvfs(root) or {"size": 0, "used": 0, "avail": 0}
    at_mount = bool(vol) and vol["mount"] == root
    if hint > 0:
        keep_min = max(64 * 1024, hint // 30000)
    else:
        keep_min = max(MIB, sv["used"] // 40000)
    rules = path_rules(vol["mount"] if vol else root)
    # the nearest rule at or above the start applies to everything below it
    cat = CAT["system"] if vol and vol["mount"] == "/" else BY_KIND
    p = root
    while True:
        if p in rules:
            cat = rules[p]
            break
        if p in ("/", ""):
            break
        p = os.path.dirname(p)
    home_vol = mount_of(HOME, rows)

    t0 = time.monotonic()
    s = Scan(root, keep_min, rules, skip)
    try:
        own = os.lstat(root).st_blocks * 512
    except OSError:
        own = 0
    tree, _ = s.walk(root, os.path.basename(root) or root, cat, own)
    large = sorted(s.large, reverse=True)
    dupes = s.dupes() if hint == 0 else []
    result = {
        "v": 1,
        "root": root,
        "mount": vol["mount"] if vol else root,
        "source": source,
        "atMount": at_mount,
        "time": int(time.time()),
        "took": round(time.monotonic() - t0, 1),
        "size": sv["size"],
        "used": sv["used"],
        "avail": sv["avail"],
        "files": s.files,
        "scanned": s.bytes,
        "errors": s.errors,
        "keepMin": keep_min,
        "home": HOME if home_vol and home_vol["source"] == source and (HOME + "/").startswith(root.rstrip("/") + "/") else "",
        "cats": {CATS[i]: v for i, v in enumerate(s.cats) if v > 0},
        "large": [{"p": p, "s": b, "m": m, "k": k} for b, p, m, k in large],
        "dupes": dupes,
        "tree": tree,
    }
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    tmp = dest + ".part"
    with open(tmp, "w") as f:
        json.dump(result, f, separators=(",", ":"))
    os.replace(tmp, dest)
    sys.stdout.write("d %d %d %d\n" % (s.files, s.bytes, s.errors))
    sys.stdout.flush()


# ----------------------------------------------------------------- cleanup

CURATED = [
    ("thumbnails", "Thumbnails", os.path.join(CACHE, "thumbnails")),
    ("pip", "pip downloads", os.path.join(CACHE, "pip")),
    ("yay", "yay build files", os.path.join(CACHE, "yay")),
    ("paru", "paru build files", os.path.join(CACHE, "paru")),
    ("npm", "npm cache", os.path.join(HOME, ".npm", "_cacache")),
    ("yarn", "Yarn cache", os.path.join(CACHE, "yarn")),
    ("bun", "Bun cache", os.path.join(HOME, ".bun", "install", "cache")),
    ("gobuild", "Go build cache", os.path.join(CACHE, "go-build")),
    ("nodegyp", "node-gyp headers", os.path.join(CACHE, "node-gyp")),
    ("cargo", "Cargo registry", os.path.join(HOME, ".cargo", "registry")),
    ("gradle", "Gradle caches", os.path.join(HOME, ".gradle", "caches")),
    ("maven", "Maven repository", os.path.join(HOME, ".m2", "repository")),
    ("electron", "Electron downloads", os.path.join(CACHE, "electron")),
    ("composer", "Composer cache", os.path.join(CACHE, "composer")),
    ("shaders", "Shader caches", os.path.join(CACHE, "mesa_shader_cache")),
    ("shadersdb", "Shader caches", os.path.join(CACHE, "mesa_shader_cache_db")),
]


def trash_dirs():
    dirs = [TRASH]
    for r in mountinfo():
        if not r["source"].startswith("/dev/"):
            continue
        m = r["mount"].rstrip("/")
        for d in (m + "/.Trash-%d" % UID, m + "/.Trash/%d" % UID):
            if os.path.isdir(d) and d not in dirs:
                dirs.append(d)
    return dirs


def trash_size():
    total = 0
    count = 0
    for d in trash_dirs():
        for sub in ("files", "expunged"):
            total += du(os.path.join(d, sub))[0]
        try:
            count += sum(1 for n in os.listdir(os.path.join(d, "info")) if n.endswith(".trashinfo"))
        except OSError:
            pass
    return total, count


def pacman_cachedirs():
    dirs = []
    try:
        for line in open("/etc/pacman.conf"):
            m = re.match(r"^\s*CacheDir\s*=\s*(.+?)\s*$", line)
            if m:
                dirs.extend(m.group(1).split())
    except OSError:
        pass
    return dirs or ["/var/cache/pacman/pkg/"]


PKG = re.compile(r"^(.+)-([^-]+)-([^-]+)-([^-]+)\.pkg\.tar(\.\w+)?$")


def pacman_cache():
    if not have("pacman"):
        return None
    r = run(["pacman", "-Q"])
    if not r or r.returncode != 0:
        return None
    installed = {}
    for line in r.stdout.splitlines():
        p = line.split()
        if len(p) == 2:
            installed[p[0]] = p[1]
    total = 0
    reclaim = 0
    old = 0
    gone = 0
    for d in pacman_cachedirs():
        try:
            it = os.scandir(d)
        except OSError:
            continue
        with it:
            for e in it:
                try:
                    st = e.stat(follow_symlinks=False)
                except OSError:
                    continue
                if not stat.S_ISREG(st.st_mode):
                    continue
                b = st.st_blocks * 512
                total += b
                name = e.name[:-4] if e.name.endswith(".sig") else e.name
                m = PKG.match(name)
                if not m:
                    continue
                pkg, ver, rel = m.group(1), m.group(2), m.group(3)
                have_ver = installed.get(pkg)
                if have_ver == ver + "-" + rel:
                    continue
                reclaim += b
                if not e.name.endswith(".sig"):
                    if have_ver is None:
                        gone += 1
                    else:
                        old += 1
    return {"id": "pacman", "size": reclaim, "total": total, "count": old + gone, "old": old, "gone": gone, "root": True}


SIZE_UNITS = {"B": 1, "K": 1 << 10, "M": 1 << 20, "G": 1 << 30, "T": 1 << 40}


def parse_size(s):
    m = re.match(r"^\s*([\d.]+)\s*([KMGT]?)i?B?\s*$", s.strip())
    if not m:
        return 0
    return int(float(m.group(1)) * SIZE_UNITS.get(m.group(2) or "B", 1))


def orphans():
    if not have("pacman"):
        return None
    r = run(["pacman", "-Qdtq"])
    if not r:
        return None
    names = r.stdout.split()
    if not names:
        return {"id": "orphans", "size": 0, "count": 0, "names": [], "root": True}
    q = run(["pacman", "-Qi"] + names, timeout=30)
    sizes = {}
    if q and q.returncode == 0:
        cur = None
        for line in q.stdout.splitlines():
            if line.startswith("Name"):
                cur = line.split(":", 1)[1].strip()
            elif line.startswith("Installed Size") and cur:
                sizes[cur] = parse_size(line.split(":", 1)[1].replace(" ", ""))
    items = sorted(({"n": n, "s": sizes.get(n, 0)} for n in names), key=lambda x: -x["s"])
    return {"id": "orphans", "size": sum(sizes.values()), "count": len(names), "names": items, "root": True}


JOURNAL_KEEP = 200 * MIB


def journal():
    r = run(["journalctl", "--disk-usage"])
    if not r or r.returncode != 0:
        return None
    m = re.search(r"take up ([\d.]+\s*[KMGT]?)", r.stdout)
    if not m:
        return None
    total = parse_size(m.group(1).replace(" ", ""))
    archived = 0
    known = False
    for base in ("/var/log/journal", "/run/log/journal"):
        try:
            ids = os.listdir(base)
        except OSError:
            continue
        for i in ids:
            try:
                for e in os.scandir(os.path.join(base, i)):
                    if "@" in e.name and e.name.endswith((".journal", ".journal~")):
                        archived += e.stat(follow_symlinks=False).st_blocks * 512
                        known = True
            except OSError:
                pass
    reclaim = max(0, total - JOURNAL_KEEP)
    if known:
        reclaim = min(reclaim, archived)
    return {"id": "journal", "size": reclaim, "total": total, "keep": JOURNAL_KEEP, "root": True}


def coredumps():
    d = "/var/lib/systemd/coredump"
    total = 0
    count = 0
    try:
        for e in os.scandir(d):
            try:
                st = e.stat(follow_symlinks=False)
            except OSError:
                continue
            if stat.S_ISREG(st.st_mode):
                total += st.st_blocks * 512
                count += 1
    except OSError:
        return None
    return {"id": "coredumps", "size": total, "count": count, "root": True}


FLATPAK_UNITS = {"bytes": 1, "kB": 1000, "MB": 1000 ** 2, "GB": 1000 ** 3, "TB": 1000 ** 4}


def flatpak_unused():
    if not have("flatpak"):
        return None
    try:
        p = subprocess.run(["flatpak", "uninstall", "--unused"], input="n\n", capture_output=True, text=True, timeout=30,
                           env=dict(os.environ, LC_ALL="C"))
    except Exception:
        return None
    refs = []
    for line in (p.stdout + "\n" + p.stderr).splitlines():
        m = re.match(r"^\s*\d+\.\s+(\S+)\s+(\S+)", line)
        if m:
            refs.append((m.group(1), m.group(2)))
    if not refs:
        return {"id": "flatpak", "size": 0, "count": 0, "names": []}
    sizes = {}
    r = run(["flatpak", "list", "--columns=application,branch,size"], timeout=30)
    if r and r.returncode == 0:
        for line in r.stdout.splitlines():
            c = line.split("\t")
            if len(c) >= 3:
                m = re.match(r"^\s*([\d.]+)\s*(\S+)", c[2].replace("\xa0", " "))
                if m:
                    sizes[(c[0], c[1])] = int(float(m.group(1)) * FLATPAK_UNITS.get(m.group(2), 1))
    items = [{"n": a + " " + b, "s": sizes.get((a, b), 0)} for a, b in refs]
    return {"id": "flatpak", "size": sum(i["s"] for i in items), "count": len(items), "names": items}


def xdg_dir(key, fallback):
    try:
        for line in open(os.path.join(HOME, ".config", "user-dirs.dirs")):
            m = re.match(r'^\s*%s\s*=\s*"(.*)"' % key, line)
            if m:
                return os.path.realpath(m.group(1).replace("$HOME", HOME))
    except OSError:
        pass
    return os.path.join(HOME, fallback)


OLD_DAYS = 90


def downloads():
    d = xdg_dir("XDG_DOWNLOAD_DIR", "Downloads")
    if not os.path.isdir(d):
        return None
    cutoff = time.time() - OLD_DAYS * 86400
    total = 0
    old = 0
    count = 0
    try:
        top = list(os.scandir(d))
    except OSError:
        return None
    for e in top:
        try:
            st = e.stat(follow_symlinks=False)
        except OSError:
            continue
        b = du(e.path)[0] if stat.S_ISDIR(st.st_mode) else st.st_blocks * 512
        total += b
        if st.st_mtime < cutoff:
            old += b
            count += 1
    return {"id": "downloads", "size": old, "total": total, "count": count, "days": OLD_DAYS, "path": d}


def cleanup():
    items = []
    t, n = trash_size()
    items.append({"id": "trash", "size": t, "count": n})

    cache_top = {}
    try:
        for e in os.scandir(CACHE):
            if e.is_dir(follow_symlinks=False):
                cache_top[e.path] = du(e.path)[0]
    except OSError:
        pass
    curated_in_cache = 0
    merged = {}
    for cid, title, path in CURATED:
        size = cache_top[path] if path in cache_top else du(path)[0]
        if path in cache_top:
            curated_in_cache += size
        if size <= 0:
            continue
        key = title
        if key in merged:
            merged[key]["size"] += size
            merged[key]["paths"].append(path)
        else:
            merged[key] = {"id": "cache:" + cid, "title": title, "size": size, "paths": [path], "path": path}
    for v in merged.values():
        if v["size"] >= 8 * MIB:
            items.append(v)

    other = sum(cache_top.values()) - curated_in_cache
    curated_paths = {p for _, _, p in CURATED}
    top = sorted(((os.path.basename(p), s) for p, s in cache_top.items() if p not in curated_paths), key=lambda x: -x[1])[:4]
    items.append({"id": "othercaches", "size": other, "path": CACHE, "top": [{"n": n_, "s": s_} for n_, s_ in top]})

    for fn in (pacman_cache, orphans, journal, coredumps, flatpak_unused, downloads):
        try:
            r = fn()
        except Exception:
            r = None
        if r:
            items.append(r)
    return {"items": items, "time": int(time.time()), "pkexec": have("pkexec")}


def empty_dir(path):
    if not os.path.isdir(path) or os.path.islink(path):
        return

    # read-only folders (go's module cache makes them) are opened up and retried
    def onerr(func, p, exc):
        try:
            os.chmod(os.path.dirname(p), 0o700)
            os.chmod(p, 0o700)
            func(p)
        except OSError:
            pass

    kw = {"onexc": onerr} if sys.version_info >= (3, 12) else {"onerror": onerr}
    for e in os.scandir(path):
        try:
            if e.is_dir(follow_symlinks=False):
                shutil.rmtree(e.path, **kw)
            else:
                os.unlink(e.path)
        except OSError:
            pass


def pk(args):
    if not have("pkexec"):
        return False, "pkexec is not installed"
    try:
        p = subprocess.run(["pkexec"] + args, capture_output=True, text=True, timeout=1800,
                           env=dict(os.environ, LC_ALL="C"))
    except Exception as e:
        return False, str(e)
    if p.returncode in (126, 127):
        return False, "cancelled"
    if p.returncode != 0:
        err = (p.stderr or p.stdout).strip().splitlines()
        return False, err[-1] if err else "exit %d" % p.returncode
    return True, ""


def clean(cid):
    where = "/" if cid in ("pacman", "orphans", "journal", "coredumps") else HOME
    before = statvfs(where) or {"avail": 0}
    ok, err = True, ""
    if cid == "trash":
        r = run(["gio", "trash", "--empty"], timeout=600) if have("gio") else None
        if not r or r.returncode != 0:
            for d in trash_dirs():
                for sub in ("files", "info", "expunged"):
                    empty_dir(os.path.join(d, sub))
    elif cid.startswith("cache:"):
        want = cid[6:]
        title = next((t for c, t, _ in CURATED if c == want), None)
        if title is None:
            ok, err = False, "unknown cache"
        else:
            for c, t, path in CURATED:
                if t == title:
                    empty_dir(path)
    elif cid == "pacman":
        ok, err = pk(["pacman", "-Sc", "--noconfirm"])
    elif cid == "orphans":
        r = run(["pacman", "-Qdtq"])
        names = r.stdout.split() if r else []
        if names:
            ok, err = pk(["pacman", "-Rns", "--noconfirm"] + names)
    elif cid == "journal":
        ok, err = pk(["journalctl", "--vacuum-size=%dM" % (JOURNAL_KEEP // MIB)])
    elif cid == "coredumps":
        ok, err = pk(["find", "/var/lib/systemd/coredump", "-mindepth", "1", "-type", "f", "-delete"])
    elif cid == "flatpak":
        r = run(["flatpak", "uninstall", "--unused", "-y", "--noninteractive"], timeout=1800)
        if not r or r.returncode != 0:
            ok, err = False, ((r.stderr or "").strip().splitlines() or ["flatpak failed"])[-1] if r else "flatpak failed"
    else:
        ok, err = False, "unknown item"
    after = statvfs(where) or {"avail": 0}
    return {"id": cid, "ok": ok, "error": err, "freed": max(0, after["avail"] - before["avail"])}


def trash_old(days):
    cutoff = time.time() - days * 86400
    removed = 0
    freed = 0
    for d in trash_dirs():
        info = os.path.join(d, "info")
        try:
            names = os.listdir(info)
        except OSError:
            continue
        for n in names:
            if not n.endswith(".trashinfo"):
                continue
            ip = os.path.join(info, n)
            try:
                text = open(ip, errors="replace").read()
            except OSError:
                continue
            m = re.search(r"^DeletionDate=(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)", text, re.M)
            if not m:
                continue
            try:
                when = time.mktime(time.strptime(m.group(1), "%Y-%m-%dT%H:%M:%S"))
            except ValueError:
                continue
            if when >= cutoff:
                continue
            fp = os.path.join(d, "files", n[:-len(".trashinfo")])
            size = du(fp)[0] if os.path.lexists(fp) else 0
            try:
                if os.path.isdir(fp) and not os.path.islink(fp):
                    shutil.rmtree(fp)
                elif os.path.lexists(fp):
                    os.unlink(fp)
                os.unlink(ip)
            except OSError:
                continue
            removed += 1
            freed += size
    return {"removed": removed, "freed": freed}


# ------------------------------------------------------------------ health

def health(dev):
    if not re.match(r"^/dev/[A-Za-z0-9]+$", dev):
        return {"ok": False, "error": "not a drive"}
    if not have("smartctl"):
        return {"ok": False, "error": "smartctl is not installed (smartmontools)"}
    if not have("pkexec"):
        return {"ok": False, "error": "pkexec is not installed"}
    try:
        p = subprocess.run(["pkexec", "smartctl", "-j", "-a", dev], capture_output=True, text=True, timeout=120)
    except Exception as e:
        return {"ok": False, "error": str(e)}
    if p.returncode in (126, 127) and not p.stdout.strip():
        return {"ok": False, "error": "cancelled"}
    try:
        j = json.loads(p.stdout)
    except ValueError:
        return {"ok": False, "error": (p.stderr.strip().splitlines() or ["smartctl gave no answer"])[-1]}
    res = {"ok": True, "dev": dev, "time": int(time.time())}
    res["passed"] = (j.get("smart_status") or {}).get("passed")
    res["temp"] = (j.get("temperature") or {}).get("current")
    res["hours"] = (j.get("power_on_time") or {}).get("hours")
    res["cycles"] = j.get("power_cycle_count")
    nv = j.get("nvme_smart_health_information_log")
    if nv:
        res["wear"] = nv.get("percentage_used")
        res["spare"] = nv.get("available_spare")
        res["written"] = (nv.get("data_units_written") or 0) * 512000
        res["mediaErrors"] = nv.get("media_errors")
        res["unsafe"] = nv.get("unsafe_shutdowns")
        res["warning"] = nv.get("critical_warning")
    else:
        table = ((j.get("ata_smart_attributes") or {}).get("table")) or []
        by = {a.get("id"): a for a in table}
        for aid in (231, 177, 233, 169, 202):
            a = by.get(aid)
            if a and isinstance(a.get("value"), int):
                res["wear"] = max(0, 100 - a["value"])
                break
        a = by.get(241)
        if a:
            res["written"] = ((a.get("raw") or {}).get("value") or 0) * (j.get("logical_block_size") or 512)
        bad = 0
        for aid in (5, 197, 198):
            a = by.get(aid)
            if a:
                bad += (a.get("raw") or {}).get("value") or 0
        res["mediaErrors"] = bad
    msgs = (j.get("smartctl") or {}).get("messages") or []
    if res["passed"] is None and msgs:
        res["note"] = msgs[-1].get("string", "")
    return res


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return 2
    mode = a[0]
    if mode == "volumes":
        out(volumes())
    elif mode == "scan" and len(a) >= 3:
        sys.setrecursionlimit(20000)
        scan(a[1], a[2], int(a[3]) if len(a) > 3 else 0)
    elif mode == "cleanup":
        out(cleanup())
    elif mode == "clean" and len(a) >= 2:
        out(clean(a[1]))
    elif mode == "trash-old" and len(a) >= 2:
        out(trash_old(max(1, int(a[1]))))
    elif mode == "health" and len(a) >= 2:
        out(health(a[1]))
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
