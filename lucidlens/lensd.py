#!/usr/bin/env python3
# lensd: lens's helper, json lines over stdin and stdout. folders of pictures and
# their thumbnails, a picture's details, saving edits, the trash, the clipboard,
# and the other things qml can't do itself. a request is {op, id, ...}; the
# reply carries the same id, and events carry "ev" instead
import concurrent.futures
import datetime
import hashlib
import importlib.util
import io
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time

sys.dont_write_bytecode = True

import gi

gi.require_version("Gio", "2.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf, Gio, GLib

try:
    from PIL import Image, ImageOps, PngImagePlugin
    Image.MAX_IMAGE_PIXELS = None
except ImportError:
    Image = None

HERE = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser("~")
CACHE = os.path.join(GLib.get_user_cache_dir(), "lucid", "lens")
# kept originals are the person's own pictures, so they live with data, not cache
ORIGINALS = os.path.join(GLib.get_user_data_dir(), "lucid", "lens", "originals")
THUMB_ROOT = os.path.join(GLib.get_user_cache_dir(), "thumbnails")
WALLPAPER = os.path.join(HOME, ".config", "hypr", "scripts", "wallpaper", "set-wallpaper.sh")
OUT = threading.Lock()

# what qt draws itself, and what goes through gdk-pixbuf's loaders into a png first
QT_EXTS = {"png", "jpg", "jpeg", "jpe", "jfif", "gif", "webp", "bmp", "svg", "svgz", "tif", "tiff", "ico",
           "icns", "tga", "wbmp", "avif", "pbm", "pgm", "ppm", "xbm", "xpm"}
DECODE_EXTS = {"heic", "heif", "jxl", "qoi", "exr", "dds", "cur", "ani"}
# what pillow writes back in the same format; anything else is saved as a copy
WRITABLE = {"png": "PNG", "jpg": "JPEG", "jpeg": "JPEG", "jpe": "JPEG", "jfif": "JPEG", "webp": "WEBP",
            "bmp": "BMP", "tif": "TIFF", "tiff": "TIFF", "tga": "TGA", "avif": "AVIF"}
# videos: qt plays them; ffmpeg makes their stills, cuts them and turns them
VIDEO_EXTS = {"mp4", "m4v", "mkv", "webm", "mov", "avi", "wmv", "flv", "mpg", "mpeg", "3gp", "3g2", "ogv", "mts",
              "m2ts"}
# what the wallpaper script plays as a live wallpaper
LIVE_EXTS = {"mp4", "webm", "mkv", "mov", "m4v"}
# where which way is up is a note in the file, so a turn encodes nothing again
TURNABLE = {"mp4", "m4v", "mov", "3gp", "3g2"}
FFMPEG = shutil.which("ffmpeg")
FFPROBE = shutil.which("ffprobe")
THUMBNAILER = shutil.which("ffmpegthumbnailer")


def send(obj):
    line = json.dumps(obj, separators=(",", ":")) + "\n"
    with OUT:
        sys.stdout.write(line)
        sys.stdout.flush()


def ext_of(name):
    i = name.rfind(".")
    return name[i + 1:].lower() if i > 0 else ""


def uri_of(path):
    return Gio.File.new_for_path(path).get_uri()


def gdk_extensions():
    got = set()
    for f in GdkPixbuf.Pixbuf.get_formats():
        got.update(e.lower() for e in f.get_extensions())
    return got


# -- thumbnails, where every file manager looks: ~/.cache/thumbnails/large by the
# md5 of the uri, with the file's mtime written in

def thumb_path(uri):
    return os.path.join(THUMB_ROOT, "large", hashlib.md5(uri.encode()).hexdigest() + ".png")


def png_ends(path):
    with open(path, "rb") as f:
        f.seek(-8, os.SEEK_END)
        return f.read() == b"IEND\xaeB`\x82"


def thumb_valid(tpath, mtime):
    try:
        ends = png_ends(tpath)
        with Image.open(tpath) as t:
            # a tag ahead of the pixels is read on opening, and every thumbnailer seen so
            # far puts it there. .text decodes the whole picture, which a folder of
            # thousands can't afford, so it is left for a file that was cut short
            got = t.info.get("Thumb::MTime") if ends else None
            return int(got or t.text.get("Thumb::MTime", "-1")) == int(mtime)
    except Exception:
        return False


def open_any(path, box=None):
    """a pillow image the right way up, through gdk-pixbuf for what pillow can't
    read; box asks for something about that size, which a jpeg decodes fast"""
    if Image is not None:
        try:
            im = Image.open(path)
            if box and im.format == "JPEG":
                im.draft("RGB", box)
            im = ImageOps.exif_transpose(im)
            return im
        except Exception:
            pass
    if box:
        pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, box[0], box[1], True)
    else:
        pb = GdkPixbuf.Pixbuf.new_from_file(path)
    pb = pb.apply_embedded_orientation() or pb
    mode = "RGBA" if pb.get_has_alpha() else "RGB"
    data = pb.get_pixels()
    return Image.frombuffer(mode, (pb.get_width(), pb.get_height()), data, "raw", mode, pb.get_rowstride(), 1)


def to8(im):
    """sixteen bits and floats squeezed into eight, or pillow clips them white"""
    if im.mode in ("I;16", "I;16B", "I;16L", "I;16N"):
        return im.convert("I").point(lambda v: v * (1 / 256)).convert("L")
    if im.mode in ("I", "F"):
        return im.point(lambda v: v * (1 / 256)).convert("L")
    return im


def is_video(path):
    return ext_of(path) in VIDEO_EXTS


def video_still(path, size):
    """a frame that stands for a video, about a tenth of the way in"""
    os.makedirs(CACHE, exist_ok=True)
    fd, tmp = tempfile.mkstemp(suffix=".png", dir=CACHE)
    os.close(fd)
    try:
        if THUMBNAILER:
            cmd = [THUMBNAILER, "-i", path, "-o", tmp, "-s", str(size), "-c", "png"]
        else:
            cmd = [FFMPEG, "-v", "error", "-y", "-ss", "1", "-i", path, "-frames:v", "1", "-vf",
                   "scale=%d:%d:force_original_aspect_ratio=decrease" % (size, size), tmp]
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60, check=True)
        with Image.open(tmp) as im:
            im.load()
            return im.copy()
    finally:
        os.unlink(tmp)


def make_thumb(path, mtime):
    uri = uri_of(path)
    dest = thumb_path(uri)
    if os.path.exists(dest) and thumb_valid(dest, mtime):
        return dest
    im = video_still(path, 256) if is_video(path) else open_any(path, (256, 256))
    if getattr(im, "n_frames", 1) > 1:
        im.seek(0)
    im = to8(im)
    im.thumbnail((256, 256), Image.LANCZOS)
    if im.mode not in ("RGB", "RGBA"):
        im = im.convert("RGBA" if "A" in im.getbands() or im.mode == "P" else "RGB")
    meta = PngImagePlugin.PngInfo()
    meta.add_text("Thumb::URI", uri)
    meta.add_text("Thumb::MTime", str(int(mtime)))
    meta.add_text("Software", "Lucid Lens")
    os.makedirs(os.path.dirname(dest), mode=0o700, exist_ok=True)
    tmp = dest + ".lens-%d" % os.getpid()
    im.save(tmp, "PNG", pnginfo=meta)
    os.replace(tmp, dest)
    return dest


class Thumbs(threading.Thread):
    """one worker, nearest first: a new ask puts its paths at the front"""

    def __init__(self):
        super().__init__(daemon=True)
        self.lock = threading.Condition()
        self.queue = []
        self.failed = set()

    def ask(self, items):
        with self.lock:
            want = [(it["path"], it["mtime"]) for it in items]
            keys = {p for p, _ in want}
            self.queue = want + [q for q in self.queue if q[0] not in keys]
            self.lock.notify()

    def run(self):
        while True:
            with self.lock:
                while not self.queue:
                    self.lock.wait()
                path, mtime = self.queue.pop(0)
            key = (path, mtime)
            if key in self.failed:
                continue
            # one already made is told again: another window may be asking
            try:
                got = make_thumb(path, mtime)
                send({"ev": "thumb", "path": path, "thumb": got})
            except Exception:
                self.failed.add(key)
                send({"ev": "thumb", "path": path, "thumb": "", "failed": True})


# -- details

def ratio(v):
    try:
        return float(v)
    except Exception:
        try:
            return v[0] / v[1]
        except Exception:
            return None


def shutter(v):
    s = ratio(v)
    if not s:
        return ""
    if s >= 1:
        return ("%g s" % round(s, 1))
    return "1/%d s" % round(1 / s)


def gps_of(gps):
    def deg(v, ref):
        try:
            d, m, s = (ratio(x) for x in v)
            out = d + m / 60 + s / 3600
            return -out if ref in ("S", "W") else out
        except Exception:
            return None
    lat = deg(gps.get(2), gps.get(1))
    lon = deg(gps.get(4), gps.get(3))
    if lat is None or lon is None:
        return None
    alt = ratio(gps.get(6))
    return {"lat": round(lat, 6), "lon": round(lon, 6), "alt": round(alt) if alt is not None else None}


FLASH = {0: "No flash", 1: "Flash fired", 5: "Flash fired", 7: "Flash fired", 9: "Flash fired", 16: "No flash",
         24: "No flash", 25: "Flash fired (auto)", 32: "No flash"}


def exif_of(im):
    out = {}
    try:
        ex = im.getexif()
    except Exception:
        return out
    if not ex:
        return out
    sub = {}
    try:
        sub = ex.get_ifd(0x8769)
    except Exception:
        pass
    allx = dict(ex)
    allx.update(sub)

    def txt(tag):
        v = allx.get(tag)
        if isinstance(v, bytes):
            v = v.decode("utf-8", "replace")
        return str(v).strip("\x00 ").strip() if v not in (None, "") else ""

    make, model = txt(0x010F), txt(0x0110)
    if model and make and model.lower().startswith(make.split()[0].lower()):
        out["camera"] = model
    elif make or model:
        out["camera"] = (make + " " + model).strip()
    if txt(0xA434):
        out["lens"] = txt(0xA434)
    f = ratio(allx.get(0x829D))
    if f:
        out["aperture"] = "f/%g" % round(f, 1)
    if allx.get(0x829A):
        out["shutter"] = shutter(allx.get(0x829A))
    iso = allx.get(0x8827)
    if isinstance(iso, (tuple, list)):
        iso = iso[0] if iso else None
    if iso:
        out["iso"] = "ISO %d" % int(iso)
    fl = ratio(allx.get(0x920A))
    if fl:
        out["focal"] = "%g mm" % round(fl, 1)
        f35 = allx.get(0xA405)
        if f35 and int(f35) != round(fl):
            out["focal"] += " (%d mm full frame)" % int(f35)
    bias = ratio(allx.get(0x9204))
    if bias:
        out["bias"] = "%+g EV" % round(bias, 1)
    if allx.get(0x9209) is not None:
        out["flash"] = FLASH.get(int(allx.get(0x9209)), "Flash fired" if int(allx.get(0x9209)) & 1 else "No flash")
    taken = txt(0x9003) or txt(0x0132)
    m = re.match(r"(\d{4}):(\d\d):(\d\d) (\d\d):(\d\d):?(\d\d)?", taken)
    if m:
        out["taken"] = "%s-%s-%sT%s:%s:%s" % (m.group(1), m.group(2), m.group(3), m.group(4), m.group(5), m.group(6) or "00")
    for tag, key in ((0x0131, "software"), (0x013B, "artist"), (0x8298, "copyright"), (0x010E, "caption")):
        if txt(tag):
            out[key] = txt(tag)[:200]
    try:
        g = gps_of(ex.get_ifd(0x8825))
        if g:
            out["gps"] = g
    except Exception:
        pass
    return out


CODECS = {"h264": "H.264", "hevc": "HEVC", "av1": "AV1", "vp9": "VP9", "vp8": "VP8", "mpeg4": "MPEG-4",
          "mpeg2video": "MPEG-2", "mpeg1video": "MPEG-1", "prores": "ProRes", "theora": "Theora", "wmv3": "WMV",
          "vc1": "VC-1", "mjpeg": "Motion JPEG", "aac": "AAC", "mp3": "MP3", "opus": "Opus", "vorbis": "Vorbis",
          "ac3": "AC-3", "eac3": "E-AC-3", "flac": "FLAC", "alac": "ALAC", "dts": "DTS", "wmav2": "WMA",
          "pcm_s16le": "PCM", "pcm_s24le": "PCM"}


def probe(path):
    res = subprocess.run([FFPROBE, "-v", "error", "-print_format", "json", "-show_format", "-show_streams", path],
                         capture_output=True, text=True, timeout=30)
    return json.loads(res.stdout or "{}")


def video_stream(p):
    return next((s for s in p.get("streams", []) if s.get("codec_type") == "video"
                 and not (s.get("disposition") or {}).get("attached_pic")), None)


def rotation_of(v):
    """degrees the video is turned counter-clockwise to stand upright, as ffmpeg
    writes them; older files say it as a tag, clockwise"""
    for sd in (v or {}).get("side_data_list") or []:
        if "rotation" in sd:
            return normal_angle(int(round(float(sd["rotation"]))))
    try:
        return normal_angle(-int((v or {}).get("tags", {}).get("rotate", 0)))
    except ValueError:
        return 0


def normal_angle(a):
    a %= 360
    return a - 360 if a > 180 else a


def rate(v):
    for key in ("avg_frame_rate", "r_frame_rate"):
        try:
            n, d = (int(x) for x in (v.get(key) or "0/0").split("/"))
            if n and d:
                return round(n / d, 3)
        except ValueError:
            pass
    return 0


def iso6709(s):
    """a place as quicktime writes it: +37.3349-122.0090+010.000/"""
    m = re.match(r"([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)?", s or "")
    if not m:
        return None
    alt = float(m.group(3)) if m.group(3) else None
    return {"lat": round(float(m.group(1)), 6), "lon": round(float(m.group(2)), 6),
            "alt": round(alt) if alt is not None else None}


def video_facts(p):
    """what someone wants to know of a video, from ffprobe's json"""
    fmt = p.get("format") or {}
    v = video_stream(p)
    a = next((s for s in p.get("streams", []) if s.get("codec_type") == "audio"), None)
    out = {"video": True, "format": fmt.get("format_long_name", ""), "duration": float(fmt.get("duration") or 0),
           "bitrate": int(fmt.get("bit_rate") or 0), "exif": {}}
    if v:
        w, h = v.get("width", 0), v.get("height", 0)
        # pixels that aren't square are shown at their true shape
        try:
            n, d = (int(x) for x in (v.get("sample_aspect_ratio") or "1:1").split(":"))
            if n and d and n != d:
                w = int(round(w * n / d / 2)) * 2
        except ValueError:
            pass
        rot = rotation_of(v)
        if rot % 180:
            w, h = h, w
        pix = v.get("pix_fmt") or ""
        out.update({"w": w, "h": h, "rotation": rot, "vcodec": CODECS.get(v.get("codec_name"), (v.get("codec_name") or "").upper()),
                    "fps": rate(v), "depth": 10 if "10" in pix else 12 if "12" in pix else 8,
                    "hdr": v.get("color_transfer") in ("smpte2084", "arib-std-b67")})
    if a:
        out.update({"acodec": CODECS.get(a.get("codec_name"), (a.get("codec_name") or "").upper()),
                    "channels": a.get("channels") or 0, "arate": int(a.get("sample_rate") or 0)})
    tags = {}
    for src in (fmt.get("tags") or {}, (v or {}).get("tags") or {}):
        for k, val in src.items():
            tags.setdefault(k.lower(), val)
    ex = out["exif"]
    # a phone's own note of when, with its offset, beats the utc creation_time
    when = tags.get("com.apple.quicktime.creationdate") or tags.get("creation_time") or ""
    try:
        t = datetime.datetime.fromisoformat(when.replace("Z", "+00:00"))
        if t.tzinfo is not None and "com.apple.quicktime.creationdate" not in tags:
            t = t.astimezone()
        if t.year > 1971:
            ex["taken"] = t.strftime("%Y-%m-%dT%H:%M:%S")
    except ValueError:
        pass
    make = tags.get("com.apple.quicktime.make") or tags.get("com.android.manufacturer") or tags.get("make") or ""
    model = tags.get("com.apple.quicktime.model") or tags.get("com.android.model") or tags.get("model") or ""
    if model and make and model.lower().startswith(make.split()[0].lower()):
        ex["camera"] = model
    elif make or model:
        ex["camera"] = (make + " " + model).strip()
    soft = tags.get("com.apple.quicktime.software") or tags.get("com.android.version") or tags.get("software")
    if soft:
        ex["software"] = ("Android " + soft) if tags.get("com.android.version") == soft else soft
    for key, name in (("title", "caption"), ("artist", "artist"), ("copyright", "copyright")):
        if tags.get(key):
            ex[name] = str(tags[key])[:200]
    g = iso6709(tags.get("com.apple.quicktime.location.iso6709") or tags.get("location") or "")
    if g:
        ex["gps"] = g
    return out


def histogram(im):
    small = im.copy()
    small.thumbnail((320, 320))
    if small.mode not in ("RGB", "RGBA"):
        small = small.convert("RGBA" if small.mode in ("LA", "PA", "P") else "RGB")
    rgb = small.convert("RGB")
    bins = 64
    out = {}
    for name, band in zip("rgb", rgb.split()):
        h = band.histogram()
        out[name] = [sum(h[i * 4:(i + 1) * 4]) for i in range(bins)]
    h = rgb.convert("L").histogram()
    out["l"] = [sum(h[i * 4:(i + 1) * 4]) for i in range(bins)]
    peak = max(max(v) for v in out.values()) or 1
    for k in out:
        out[k] = [round(v / peak, 4) for v in out[k]]
    # the brightest and darkest tenths, for the automatic fix
    lum = rgb.convert("L").histogram()
    total = sum(lum) or 1
    acc, lo, hi, mean = 0, 0, 255, 0
    for i, c in enumerate(lum):
        mean += i * c
        if acc < total * 0.01 <= acc + c:
            lo = i
        if acc < total * 0.99 <= acc + c:
            hi = i
        acc += c
    out["stats"] = {"lo": lo / 255, "hi": hi / 255, "mean": mean / total / 255}
    return out, small


def palette(small, n=6):
    im = small.convert("RGB")
    im.thumbnail((96, 96))
    q = im.quantize(colors=n * 2, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette()
    counts = sorted(q.getcolors(), reverse=True)
    out = []
    total = sum(c for c, _ in counts) or 1
    for count, idx in counts:
        r, g, b = pal[idx * 3:idx * 3 + 3]
        # near-duplicates read as one colour
        if any(abs(r - o[0]) + abs(g - o[1]) + abs(b - o[2]) < 48 for o in (x["rgb"] for x in out)):
            continue
        out.append({"rgb": (r, g, b), "hex": "#%02x%02x%02x" % (r, g, b), "share": round(count / total, 3)})
        if len(out) == n:
            break
    for o in out:
        del o["rgb"]
    return out


def unique_name(folder, stem, ext):
    name = "%s.%s" % (stem, ext)
    n = 2
    while os.path.exists(os.path.join(folder, name)):
        name = "%s %d.%s" % (stem, n, ext)
        n += 1
    return os.path.join(folder, name)


def copy_stem(path):
    base = os.path.basename(path)
    i = base.rfind(".")
    stem = base[:i] if i > 0 else base
    stem = re.sub(r" \(edited\)( \d+)?$", "", stem)
    return stem + " (edited)"


# the eight ways a picture can lie, as (quarter turns clockwise, mirrored first)
DIHEDRAL = {1: (0, False), 2: (0, True), 3: (2, False), 4: (2, True), 5: (1, True), 6: (1, False), 7: (3, True), 8: (3, False)}


def compose(a, b):
    """b after a, each (turns, mirrored): a mirror flips the sense of what follows"""
    ta, ma = a
    tb, mb = b
    return ((tb + (-ta if mb else ta)) % 4, ma != mb)


def apply_dihedral(im, d):
    turns, mirror = d
    if mirror:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    if turns == 1:
        im = im.transpose(Image.ROTATE_270)
    elif turns == 2:
        im = im.transpose(Image.ROTATE_180)
    elif turns == 3:
        im = im.transpose(Image.ROTATE_90)
    return im


JPEGTRAN = {(0, False): None, (0, True): ["-flip", "horizontal"], (1, False): ["-rotate", "90"],
            (2, False): ["-rotate", "180"], (3, False): ["-rotate", "270"], (2, True): ["-flip", "vertical"],
            (1, True): ["-transpose"], (3, True): ["-transverse"]}


def user_dihedral(turns, flip_h, flip_v):
    """lens turns first, then flips what is on screen: as (turns, mirrored)"""
    d = (turns % 4, False)
    if flip_h:
        d = compose(d, (0, True))
    if flip_v:
        d = compose(d, (2, True))
    return d


def replace_into(tmp, dest):
    """tmp in dest's place, keeping who may read it: a private picture stays private"""
    if os.path.exists(dest):
        shutil.copymode(dest, tmp)
    os.replace(tmp, dest)


def clone(src, dest):
    """dest as a second name for src's bytes, when both are on one drive: a kept
    original or a backup of a big video costs no time and no room until the
    picture is written again. lens writes a new file and swaps it in, never into
    the old one, so the second name keeps what it named. a file that already has
    other names (someone's own hard links) is copied: those may be written into"""
    try:
        if os.stat(src).st_nlink != 1:
            raise OSError
        os.link(src, dest)
    except OSError:
        shutil.copy2(src, dest)


def put_back(src, dest):
    """src's bytes in dest's place, its own dates and all, whole or not at all"""
    tmp = os.path.join(os.path.dirname(dest) or ".", ".%s.lens-%d" % (os.path.basename(dest), os.getpid()))
    try:
        clone(src, tmp)
        os.replace(tmp, dest)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def inside(path, folder):
    return os.path.realpath(path).startswith(os.path.realpath(folder) + os.sep)


def dims_of(path):
    """width and height as the picture (or video) stands, read from its header"""
    if is_video(path):
        try:
            f = video_facts(probe(path))
            return f.get("w", 0), f.get("h", 0)
        except Exception:
            return 0, 0
    try:
        with Image.open(path) as im:
            orient = 1
            try:
                orient = im.getexif().get(0x0112, 1) or 1
            except Exception:
                pass
            return im.size if orient < 5 else im.size[::-1]
    except Exception:
        try:
            _, w, h = GdkPixbuf.Pixbuf.get_file_info(path)
            return w, h
        except Exception:
            return 0, 0


# -- originals: a picture as it was before lens first saved over it, kept until
# it is reverted to or let go (never on a timer), so an edit can always be undone

def fingerprint(path):
    st = os.stat(path)
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return {"size": st.st_size, "mtime": st.st_mtime_ns, "sha1": h.hexdigest()}


def unchanged(path, fp):
    """still what lens wrote there: the size, then the date, then the bytes"""
    try:
        st = os.stat(path)
        if not fp or st.st_size != fp.get("size"):
            return False
        return st.st_mtime_ns == fp.get("mtime") or fingerprint(path)["sha1"] == fp.get("sha1")
    except OSError:
        return False


class Originals:
    """the kept originals, filed by their picture's path in index.json beside them"""

    def __init__(self):
        self.lock = threading.RLock()
        self.index = os.path.join(ORIGINALS, "index.json")
        self._entries = None

    def entries(self):
        if self._entries is None:
            try:
                with open(self.index, encoding="utf-8") as f:
                    data = json.load(f)
                self._entries = data.get("entries", {}) if isinstance(data, dict) else {}
            except FileNotFoundError:
                self._entries = {}
            except ValueError:
                # a broken index is set aside, never the pictures it filed
                os.replace(self.index, self.index + ".broken-%d" % int(time.time()))
                self._entries = {}
        return self._entries

    def write(self):
        os.makedirs(ORIGINALS, exist_ok=True)
        tmp = self.index + ".part"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({"version": 1, "entries": self._entries}, f, indent=1, sort_keys=True)
        os.replace(tmp, self.index)

    @staticmethod
    def file_of(e):
        return os.path.join(ORIGINALS, e["file"])

    def get(self, path):
        with self.lock:
            e = self.entries().get(path)
            if e and not os.path.exists(self.file_of(e)):
                del self._entries[path]
                self.write()
                return None
            return dict(e) if e else None

    def keep(self, src):
        """src as it is now, filed away the first time lens saves over it: the kept
        file, or "" when it has one already"""
        with self.lock:
            if self.get(src):
                return ""
            os.makedirs(ORIGINALS, exist_ok=True)
            name = "%d-%s" % (int(time.time() * 1000), os.path.basename(src))
            dest = os.path.join(ORIGINALS, name)
            clone(src, dest)
            st = os.stat(dest)
            w, h = dims_of(dest)
            self.entries()[src] = {"file": name, "at": int(time.time()), "size": st.st_size, "mtime": int(st.st_mtime),
                                   "w": w, "h": h}
            self.write()
            return dest

    def wrote(self, path):
        """what lens just wrote over a kept picture, to know it again"""
        with self.lock:
            e = self.entries().get(path)
            if e:
                e["saved"] = fingerprint(path)
                e.pop("gone", None)
                self.write()

    def drop(self, path):
        with self.lock:
            e = self.entries().pop(path, None)
            if e is None:
                return None
            self.write()
        try:
            os.unlink(self.file_of(e))
        except OSError:
            pass
        return e

    def refile(self, path, e):
        """an original back on file after a revert was undone: the picture there is it"""
        with self.lock:
            if self.get(path):
                raise ValueError("It has been edited again since")
            os.makedirs(ORIGINALS, exist_ok=True)
            clone(path, self.file_of(e))
            e = dict(e)
            e.pop("gone", None)
            self.entries()[path] = e
            self.write()

    def moved(self, old, new):
        with self.lock:
            ents = self.entries()
            if old in ents and new not in ents:
                ents[new] = ents.pop(old)
                ents[new].pop("gone", None)
                self.write()

    def found(self, path, st):
        """a picture lens saved over, turned up under another name: moved in lumen.
        a move keeps size and date, so nothing is read unless both match"""
        with self.lock:
            maybe = [p for p, e in self.entries().items()
                     if p != path and (e.get("saved") or {}).get("size") == st.st_size and not os.path.exists(p)]
        for p in maybe:
            with self.lock:
                e = self.entries().get(p)
            if e and unchanged(path, e.get("saved")):
                self.moved(p, path)
                return self.get(path)
        return None

    def tidy(self):
        """an original goes thirty days after its picture did. a picture whose folder
        isn't there (a drive taken out) hasn't gone"""
        now = int(time.time())
        with self.lock:
            ents = self.entries()
            changed = False
            for p, e in list(ents.items()):
                f = self.file_of(e)
                if not os.path.exists(f):
                    del ents[p]
                    changed = True
                elif os.path.exists(p):
                    if e.pop("gone", None) is not None:
                        changed = True
                elif os.path.isdir(os.path.dirname(p)):
                    if "gone" not in e:
                        e["gone"] = now
                        changed = True
                    elif now - e["gone"] > 30 * 86400:
                        os.unlink(f)
                        del ents[p]
                        changed = True
            if changed:
                self.write()


class Lens:
    def __init__(self):
        self.thumbs = Thumbs()
        self.thumbs.start()
        self.pool = concurrent.futures.ThreadPoolExecutor(3)
        self.monitors = {}
        self.timers = {}
        self.hidden_flag = {}
        self.gdk = gdk_extensions()
        self.dk = None
        self.icons = None
        self.kept = Originals()
        # a video needs ffmpeg for its stills; without it, videos aren't listed
        self.videos = FFMPEG is not None and FFPROBE is not None
        # running cuts by job id, so one can be stopped
        self.jobs = {}

    def handle(self, req):
        op = req.get("op", "")
        fn = getattr(self, "op_" + op, None)
        rid = req.get("id")

        def run():
            try:
                res = fn(req) if fn else {"ok": False, "error": "no such op: " + op}
                res = res or {}
                res.setdefault("ok", True)
            except Exception as e:
                res = {"ok": False, "error": str(e) or e.__class__.__name__}
            if rid is not None:
                res["id"] = rid
                send(res)

        if op in ("list", "hello", "unwatch", "thumbs"):
            run()
        else:
            self.pool.submit(run)

    def later(self, key, ms, fn):
        old = self.timers.pop(key, None)
        if old:
            GLib.source_remove(old)

        def fire():
            self.timers.pop(key, None)
            fn()
            return False
        self.timers[key] = GLib.timeout_add(ms, fire)

    def op_hello(self, req):
        self.tidy()
        tess = shutil.which("tesseract") is not None
        phone = shutil.which("kdeconnect-cli") is not None
        lumen = os.path.join(HERE, "..", "lucidlumen", "lumen")
        return {"home": HOME, "wallpaper": os.access(WALLPAPER, os.X_OK), "ocr": tess, "phone": phone,
                "lumen": os.path.realpath(lumen) if os.access(lumen, os.X_OK) else "",
                "pictures": GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_PICTURES) or os.path.join(HOME, "Pictures"),
                "decodable": sorted(DECODE_EXTS & self.gdk), "qt": sorted(QT_EXTS),
                "videos": sorted(VIDEO_EXTS) if self.videos else [], "live": sorted(LIVE_EXTS), "turnable": sorted(TURNABLE)}

    def tidy(self):
        """backups, pasted pictures and decoded copies go two weeks after they were
        made. a backup carries its picture's own date, so its age is the inode's"""
        cut = time.time() - 14 * 86400
        for sub in ("backups", "pasted", "decoded"):
            d = os.path.join(CACHE, sub)
            try:
                for e in os.scandir(d):
                    if not e.is_file():
                        continue
                    st = e.stat()
                    if max(st.st_mtime, st.st_ctime) < cut:
                        os.unlink(e.path)
            except OSError:
                pass
        try:
            self.kept.tidy()
        except OSError:
            pass

    # -- folders

    def shows(self, name):
        e = ext_of(name)
        return e in QT_EXTS or (e in DECODE_EXTS and e in self.gdk) or (e in VIDEO_EXTS and self.videos)

    def entry(self, path, st=None):
        st = st or os.stat(path)
        name = os.path.basename(path)
        mime = Gio.content_type_guess(name, None)[0] or ""
        return {"name": name, "path": path, "size": st.st_size, "mtime": int(st.st_mtime), "mime": mime,
                "desc": Gio.content_type_get_description(mime) if mime else "", "thumb": ""}

    def items_in(self, folder, hidden):
        out = []
        dotted = set()
        try:
            with open(os.path.join(folder, ".hidden"), encoding="utf-8", errors="replace") as f:
                dotted = {l.strip() for l in f if l.strip()}
        except OSError:
            pass
        with os.scandir(folder) as it:
            for e in it:
                try:
                    if not e.is_file() or not self.shows(e.name):
                        continue
                    if not hidden and (e.name.startswith(".") or e.name in dotted):
                        continue
                    out.append(self.entry(e.path, e.stat()))
                except OSError:
                    continue
        return out

    def op_list(self, req):
        folder = req["path"]
        hidden = req.get("hidden", False) is True
        self.hidden_flag[folder] = hidden
        self.watch(folder)
        return {"path": folder, "items": self.items_in(folder, hidden)}

    def op_files(self, req):
        out = []
        for p in req.get("paths", []):
            try:
                if os.path.isfile(p):
                    out.append(self.entry(p))
            except OSError:
                pass
        return {"items": out}

    def watch(self, folder):
        if folder in self.monitors:
            return
        try:
            mon = Gio.File.new_for_path(folder).monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
        except GLib.Error:
            return
        mon.connect("changed", lambda *_: self.later("folder:" + folder, 350, lambda: self.resend(folder)))
        self.monitors[folder] = mon

    def resend(self, folder):
        try:
            items = self.items_in(folder, self.hidden_flag.get(folder, False))
        except OSError:
            items = []
        send({"ev": "folder", "path": folder, "items": items})

    def op_unwatch(self, req):
        mon = self.monitors.pop(req.get("path", ""), None)
        if mon:
            mon.cancel()
        return {}

    def op_thumbs(self, req):
        self.thumbs.ask(req.get("items", []))
        return {}

    def op_decode(self, req):
        path = req["path"]
        st = os.stat(path)
        if is_video(path):
            return {"src": self.poster(path, st)}
        key = hashlib.md5(("%s:%d:%d" % (path, st.st_mtime_ns, st.st_size)).encode()).hexdigest()
        dest = os.path.join(CACHE, "decoded", key + ".png")
        if not os.path.exists(dest):
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            pb = GdkPixbuf.Pixbuf.new_from_file(path)
            pb = pb.apply_embedded_orientation() or pb
            tmp = dest + ".part"
            pb.savev(tmp, "png", ["compression"], ["3"])
            os.replace(tmp, dest)
        return {"src": dest}

    def poster(self, path, st):
        """a video's first frame at its full size, upright and with square pixels:
        what the stage shows until the video plays, and in its neighbours' places"""
        key = hashlib.md5(("%s:%d:%d" % (path, st.st_mtime_ns, st.st_size)).encode()).hexdigest()
        dest = os.path.join(CACHE, "decoded", key + ".jpg")
        if not os.path.exists(dest):
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            tmp = dest + ".part.jpg"
            res = subprocess.run([FFMPEG, "-v", "error", "-y", "-i", path, "-frames:v", "1", "-vf",
                                  "scale=trunc(iw*sar/2)*2:ih,setsar=1", "-q:v", "2", tmp],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True, timeout=60)
            if res.returncode != 0 or not os.path.exists(tmp):
                raise ValueError("There's no picture in it to show")
            os.replace(tmp, dest)
        return dest

    # -- a picture's details

    def op_info(self, req):
        path = req["path"]
        st = os.stat(path)
        if is_video(path):
            return self.video_info(path, st)
        out = {"path": path, "size": st.st_size, "mtime": int(st.st_mtime)}
        try:
            im = Image.open(path)
            out["format"] = im.format or ""
            out["frames"] = getattr(im, "n_frames", 1)
            out["exif"] = exif_of(im)
            icc = im.info.get("icc_profile")
            if icc:
                try:
                    from PIL import ImageCms
                    out["profile"] = ImageCms.getProfileDescription(ImageCms.ImageCmsProfile(io.BytesIO(icc))).strip()
                except Exception:
                    out["profile"] = "Embedded"
            bands = im.getbands()
            out["alpha"] = "A" in bands or (im.mode == "P" and "transparency" in im.info)
            out["depth"] = {"1": 1, "L": 8, "P": 8, "RGB": 8, "RGBA": 8, "CMYK": 8, "I;16": 16, "I": 32, "F": 32}.get(im.mode, 8)
            if im.mode.startswith("I;16") or im.mode in ("I;16B", "I;16L"):
                out["depth"] = 16
            out["mode"] = im.mode
            orient = 1
            try:
                orient = im.getexif().get(0x0112, 1) or 1
            except Exception:
                pass
            out["w"], out["h"] = im.size if orient < 5 else im.size[::-1]
            if out["frames"] > 1:
                im.seek(0)
            try:
                if im.format == "JPEG":
                    im.draft("RGB", (640, 640))
                hist, small = histogram(to8(ImageOps.exif_transpose(im)))
                out["histogram"] = hist
                out["palette"] = palette(small)
            except Exception:
                pass
        except Exception:
            try:
                f, w, h = GdkPixbuf.Pixbuf.get_file_info(path)
                out["w"], out["h"] = w, h
                out["format"] = (f.get_name() if f else ext_of(path)).upper()
                im = open_any(path, (640, 640))
                hist, small = histogram(im)
                out["histogram"] = hist
                out["palette"] = palette(small)
                out["alpha"] = im.mode == "RGBA"
            except Exception as e:
                out["error"] = str(e)
        out["original"] = self.original_of(path, st)
        return out

    def video_info(self, path, st):
        out = {"path": path, "size": st.st_size, "mtime": int(st.st_mtime)}
        out.update(video_facts(probe(path)))
        # the tones and colours of its first frame
        try:
            with Image.open(self.poster(path, st)) as im:
                im.draft("RGB", (640, 640))
                hist, small = histogram(im.convert("RGB"))
            out["histogram"] = hist
            out["palette"] = palette(small)
        except Exception:
            pass
        out["original"] = self.original_of(path, st)
        return out

    def original_of(self, path, st):
        """the original lens kept of this picture, if it has one"""
        try:
            e = self.kept.get(path) or self.kept.found(path, st)
        except (OSError, ValueError):
            return None
        if not e:
            return None
        f = self.kept.file_of(e)
        thumb = ""
        try:
            thumb = make_thumb(f, int(os.stat(f).st_mtime))
        except Exception:
            pass
        return {"file": f, "thumb": thumb, "at": e.get("at", 0), "size": e.get("size", 0), "w": e.get("w", 0),
                "h": e.get("h", 0), "changed": not unchanged(path, e.get("saved"))}

    # -- saving

    def metadata(self, src, size):
        """the original's exif and colour profile for the edited copy, upright now"""
        exif, icc = None, None
        try:
            with Image.open(src) as o:
                icc = o.info.get("icc_profile")
                ex = o.getexif()
                if ex:
                    ex[0x0112] = 1
                    try:
                        sub = ex.get_ifd(0x8769)
                        sub[0xA002], sub[0xA003] = size
                    except Exception:
                        pass
                    exif = ex.tobytes()
        except Exception:
            pass
        return exif, icc

    def write(self, im, out, fmt, quality, src):
        exif, icc = self.metadata(src, im.size) if src else (None, None)
        kw = {}
        if fmt == "JPEG":
            if im.mode in ("RGBA", "LA", "P", "PA"):
                im = im.convert("RGBA")
                bg = Image.new("RGB", im.size, (255, 255, 255))
                bg.paste(im, mask=im.getchannel("A"))
                im = bg
            elif im.mode not in ("RGB", "L", "CMYK"):
                im = im.convert("RGB")
            kw = {"quality": quality or 93, "optimize": True, "subsampling": "4:2:0" if (quality or 93) < 90 else "4:4:4"}
        elif fmt == "WEBP":
            kw = {"quality": quality or 92, "method": 4}
        elif fmt == "AVIF":
            kw = {"quality": quality or 85}
        elif fmt == "PNG":
            kw = {"compress_level": 6}
        elif fmt == "TIFF":
            kw = {"compression": "tiff_deflate"}
        if exif and fmt in ("JPEG", "WEBP", "PNG", "TIFF", "AVIF"):
            kw["exif"] = exif
        if icc and fmt in ("JPEG", "WEBP", "PNG", "TIFF", "AVIF"):
            kw["icc_profile"] = icc
        if fmt in ("BMP", "TGA") and im.mode not in ("RGB", "RGBA", "L"):
            im = im.convert("RGBA")
        folder = os.path.dirname(out) or "."
        tmp = os.path.join(folder, ".%s.lens-%d" % (os.path.basename(out), os.getpid()))
        try:
            im.save(tmp, fmt, **kw)
            replace_into(tmp, out)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)

    def backup_of(self, src):
        bdir = os.path.join(CACHE, "backups")
        os.makedirs(bdir, exist_ok=True)
        backup = os.path.join(bdir, "%d-%s" % (int(time.time() * 1000), os.path.basename(src)))
        clone(src, backup)
        return backup

    def target(self, req):
        """where an edit goes, and as what: over the picture, or a copy beside it. a
        format pillow can't write back makes a copy. the first save over a picture
        files it away as its original, which that save's undo puts back; a later
        save keeps the version before it in the cache, for its undo"""
        src = req["src"]
        e = ext_of(src)
        fmt = WRITABLE.get(e)
        if fmt == "AVIF" and "AVIF" not in Image.SAVE:
            fmt = None
        want = req.get("format", "")
        if want:
            fmt = {"jpeg": "JPEG", "png": "PNG", "webp": "WEBP"}.get(want, fmt)
        copy = req.get("copy", False) or fmt is None or (want and WRITABLE.get(e) != fmt)
        if fmt is None:
            fmt = "PNG" if req.get("alpha") else "JPEG"
        new_ext = {"JPEG": "jpg" if e not in ("jpeg", "jpe", "jfif") else e, "PNG": "png", "WEBP": "webp",
                   "AVIF": "avif", "TIFF": e if e in ("tif", "tiff") else "tiff", "BMP": "bmp", "TGA": "tga"}[fmt]
        folder = req.get("folder") or os.path.dirname(src)
        # a kept original is never written over: an edit of one is a copy elsewhere
        if not os.access(folder, os.W_OK) or inside(src, ORIGINALS):
            folder = req.get("fallback") or os.path.join(HOME, "Pictures")
            os.makedirs(folder, exist_ok=True)
            copy = True
        if copy:
            out = unique_name(folder, req.get("stem") or copy_stem(src), new_ext)
        else:
            out = src
        backup, first = self.aside(src) if not copy else ("", False)
        return out, fmt, copy, backup, first

    def aside(self, src):
        """before a save over src: its original filed away the first time, and the
        version before kept for undo the times after"""
        kept = self.kept.keep(src)
        if kept:
            return kept, True
        return self.backup_of(src), False

    def videos_dir(self):
        d = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_VIDEOS) or os.path.join(HOME, "Videos")
        os.makedirs(d, exist_ok=True)
        return d

    def beside(self, src, req):
        """the folder a new file made from src goes in: its own, if lens may write there"""
        folder = os.path.dirname(src)
        if os.access(folder, os.W_OK) and not inside(src, ORIGINALS):
            return folder
        return req.get("fallback") or (self.videos_dir() if is_video(src) else os.path.join(HOME, "Pictures"))

    def done(self, out, src, copy, backup, first, lossless=False):
        if not copy:
            self.kept.wrote(out)
        res = self.finished(out, src)
        res.update({"copy": copy, "backup": backup, "first": first})
        if lossless:
            res["lossless"] = True
        return res

    def finished(self, out, src):
        # the edited file's thumbnail is stale: drop it and draw it again
        try:
            os.unlink(thumb_path(uri_of(out)))
        except OSError:
            pass
        st = os.stat(out)
        try:
            send({"ev": "thumb", "path": out, "thumb": make_thumb(out, int(st.st_mtime))})
        except Exception:
            pass
        return {"path": out, "size": st.st_size, "mtime": int(st.st_mtime)}

    def op_render(self, req):
        """a picture lens drew with its edits (the qt grab in req.tmp), written as a file"""
        tmp = req["tmp"]
        try:
            out, fmt, copy, backup, first = self.target(req)
            try:
                with Image.open(tmp) as g:
                    im = g.convert("RGBA")
                    im.load()
                if not req.get("alpha"):
                    im = im.convert("RGB")
                w, h = req.get("w") or 0, req.get("h") or 0
                if w and h and (w, h) != im.size:
                    im = im.resize((int(w), int(h)), Image.LANCZOS)
                self.write(im, out, fmt, req.get("quality"), req["src"])
            except Exception:
                # nothing was saved over it, so there is no original to keep
                if first:
                    self.kept.drop(req["src"])
                raise
        finally:
            try:
                os.unlink(tmp)
            except OSError:
                pass
        return self.done(out, req["src"], copy, backup, first)

    def op_transform(self, req):
        """turns, flips and a crop only: exact, from the original's own pixels. a jpeg
        that is only turned is turned without being encoded again"""
        out, fmt, copy, backup, first = self.target(req)
        try:
            lossless = self.transformed(req, out, fmt)
        except Exception:
            if first:
                self.kept.drop(req["src"])
            raise
        return self.done(out, req["src"], copy, backup, first, lossless)

    def transformed(self, req, out, fmt):
        src = req["src"]
        d_user = user_dihedral(req.get("turns", 0), req.get("flipH", False), req.get("flipV", False))
        crop = req.get("crop")
        w, h = req.get("w") or 0, req.get("h") or 0
        e = ext_of(src)
        if fmt == "JPEG" and e in ("jpg", "jpeg", "jpe", "jfif") and not crop and not (w and h) and shutil.which("jpegtran"):
            orient = 1
            try:
                with Image.open(src) as o:
                    orient = o.getexif().get(0x0112, 1) or 1
            except Exception:
                pass
            whole = compose(DIHEDRAL.get(orient, (0, False)), d_user)
            args = JPEGTRAN[whole]
            folder = os.path.dirname(out)
            tmp = os.path.join(folder, ".%s.lens-%d" % (os.path.basename(out), os.getpid()))
            cmd = ["jpegtran", "-copy", "all", "-perfect"] + (args or []) + ["-outfile", tmp, src]
            ok = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
            # the pixels are upright now, so the tag that turned them has to go
            if ok and orient != 1:
                ok = shutil.which("exiv2") is not None and subprocess.run(
                    ["exiv2", "-M", "set Exif.Image.Orientation Short 1", tmp],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
            if ok:
                replace_into(tmp, out)
                return True
            if os.path.exists(tmp):
                os.unlink(tmp)
        with Image.open(src) as o:
            fmt_src = o.format
            im = ImageOps.exif_transpose(o)
            im.load()
        im = apply_dihedral(im, d_user)
        if crop:
            x, y, cw, ch = (int(round(v)) for v in crop)
            im = im.crop((max(0, x), max(0, y), min(im.width, x + cw), min(im.height, y + ch)))
        if w and h and (w, h) != im.size:
            im = im.resize((int(w), int(h)), Image.LANCZOS)
        quality = req.get("quality") or (95 if fmt_src == "JPEG" else None)
        self.write(im, out, fmt, quality, src)
        return False

    def op_turnVideo(self, req):
        """a video turned by the note in it that says which way is up: no frame is
        encoded again, so it takes a moment however long the video is"""
        src = req["src"]
        e = ext_of(src)
        if e not in TURNABLE:
            raise ValueError("Only MP4 and MOV videos can be turned without encoding them again")
        now = rotation_of(video_stream(probe(src)))
        # lens counts quarter turns clockwise; the note counts degrees the other way
        angle = normal_angle(now - 90 * (int(req.get("turns", 0)) % 4))
        copy = req.get("copy", False) is True
        folder = os.path.dirname(src)
        if not os.access(folder, os.W_OK) or inside(src, ORIGINALS):
            folder, copy = self.beside(src, req), True
        out = unique_name(folder, copy_stem(src), e) if copy else src
        backup, first = self.aside(src) if not copy else ("", False)
        tmp = os.path.join(os.path.dirname(out), ".%s.lens-%d.%s" % (os.path.basename(out), os.getpid(), e))
        try:
            # every stream if the container takes them all back, else the picture and sound
            for maps in (["-map", "0"], ["-map", "0:v", "-map", "0:a?"]):
                res = subprocess.run([FFMPEG, "-v", "error", "-y", "-display_rotation:v:0", str(angle), "-i", src]
                                     + maps + ["-c", "copy", "-map_metadata", "0", "-movflags", "use_metadata_tags", tmp],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
                if res.returncode == 0:
                    break
            if res.returncode != 0:
                raise ValueError((res.stderr.strip().splitlines() or ["Couldn't turn it"])[-1])
            replace_into(tmp, out)
        except Exception:
            if first:
                self.kept.drop(src)
            raise
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
        return self.done(out, src, copy, backup, first, True)

    def op_trim(self, req):
        """the part between start and end, as a new video beside it. as it is, the
        cut starts at the nearest frame a player can start from, at or before start;
        exact encodes it again, frame for frame, which takes a while"""
        src, job = req["src"], req.get("job", "")
        a, b = max(0.0, float(req["start"])), float(req["end"])
        exact = req.get("exact") is True
        if b - a < 0.05:
            raise ValueError("That's too short to keep")
        folder = self.beside(src, req)
        i = os.path.basename(src).rfind(".")
        stem = os.path.basename(src)[:i] if i > 0 else os.path.basename(src)
        ext = "mp4" if exact else ext_of(src)
        out = unique_name(folder, re.sub(r" \(trimmed\)( \d+)?$", "", stem) + " (trimmed)", ext)
        tmp = os.path.join(folder, ".%s.lens-%d.%s" % (os.path.basename(out), os.getpid(), ext))
        cmd = [FFMPEG, "-v", "error", "-y", "-nostats", "-progress", "pipe:1", "-ss", "%.3f" % a, "-i", src,
               "-t", "%.3f" % (b - a), "-map", "0:v:0", "-map", "0:a?", "-map_metadata", "0"]
        if exact:
            cmd += ["-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac",
                    "-b:a", "192k", "-movflags", "+faststart"]
        else:
            cmd += ["-c", "copy", "-avoid_negative_ts", "make_zero"]
        err = tempfile.TemporaryFile(mode="w+")
        proc = subprocess.Popen(cmd + [tmp], stdout=subprocess.PIPE, stderr=err, text=True)
        self.jobs[job] = proc
        last = 0
        try:
            for line in proc.stdout:
                if line.startswith("out_time_us="):
                    try:
                        t = int(line.split("=", 1)[1]) / 1e6 / (b - a)
                    except ValueError:
                        continue
                    if time.time() - last > 0.2:
                        last = time.time()
                        send({"ev": "progress", "job": job, "t": round(max(0, min(1, t)), 3)})
            code = proc.wait()
        finally:
            self.jobs.pop(job, None)
        if code != 0 or not os.path.exists(tmp):
            if os.path.exists(tmp):
                os.unlink(tmp)
            if code < 0:
                raise ValueError("Stopped")
            err.seek(0)
            raise ValueError((err.read().strip().splitlines() or ["Couldn't cut it"])[-1])
        os.replace(tmp, out)
        st = os.stat(out)
        return {"path": out, "name": os.path.basename(out), "size": st.st_size, "mtime": int(st.st_mtime)}

    def op_cancel(self, req):
        proc = self.jobs.get(req.get("job", ""))
        if proc:
            proc.terminate()
        return {}

    def op_strip(self, req):
        """frames along a video for the trim bar, each the frame a player can start
        from nearest its spot, which is quick to reach"""
        path = req["path"]
        n, h = max(1, min(40, int(req.get("n", 10)))), max(16, min(240, int(req.get("h", 96))))
        st = os.stat(path)
        dur = float(req.get("duration") or 0) or float((probe(path).get("format") or {}).get("duration") or 0)
        key = hashlib.md5(("%s:%d:%d" % (path, st.st_mtime_ns, st.st_size)).encode()).hexdigest()
        os.makedirs(os.path.join(CACHE, "decoded"), exist_ok=True)

        def one(i):
            dest = os.path.join(CACHE, "decoded", "%s-strip%d-%d-%d.jpg" % (key, n, h, i))
            if not os.path.exists(dest):
                tmp = dest + ".part.jpg"
                at = ["-ss", "%.3f" % (dur * (i + 0.5) / n), "-i", path, "-frames:v", "1", "-vf", "scale=-2:%d" % h,
                      "-q:v", "4", tmp]
                # keyframes only is quick, but finds none in some last stretches:
                # then every frame up to the spot is decoded
                for fast in (["-skip_frame", "nokey", "-noaccurate_seek"], []):
                    subprocess.run([FFMPEG, "-v", "error", "-y"] + fast + at, stdout=subprocess.DEVNULL,
                                   stderr=subprocess.DEVNULL, timeout=60)
                    if os.path.exists(tmp):
                        break
                if not os.path.exists(tmp):
                    return ""
                os.replace(tmp, dest)
            return dest

        with concurrent.futures.ThreadPoolExecutor(4) as ex:
            return {"frames": list(ex.map(one, range(n)))}

    def op_frame(self, req):
        """the frame at `at` seconds, at its full size: saved as a picture beside the
        video, or put on the clipboard"""
        path, at = req["path"], max(0.0, float(req.get("at", 0)))
        cmd = [FFMPEG, "-v", "error", "-y", "-ss", "%.3f" % at, "-i", path, "-frames:v", "1", "-vf",
               "scale=trunc(iw*sar/2)*2:ih,setsar=1"]
        if req.get("clipboard"):
            data = subprocess.run(cmd + ["-c:v", "png", "-f", "image2pipe", "-"], capture_output=True, timeout=60).stdout
            if not data:
                raise ValueError("Couldn't take that frame")
            p = subprocess.Popen(["wl-copy", "--type", "image/png"], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL, start_new_session=True)
            p.communicate(data, timeout=20)
            return {}
        folder = self.beside(path, {"fallback": GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_PICTURES)})
        i = os.path.basename(path).rfind(".")
        stem = os.path.basename(path)[:i] if i > 0 else os.path.basename(path)
        m, sec = divmod(int(at), 60)
        out = unique_name(folder, "%s at %dm%02ds" % (stem, m, sec), "jpg")
        tmp = os.path.join(folder, ".%s.lens-%d.jpg" % (os.path.basename(out), os.getpid()))
        try:
            res = subprocess.run(cmd + ["-q:v", "2", tmp], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
                                 timeout=60)
            if res.returncode != 0 or not os.path.exists(tmp):
                raise ValueError("Couldn't take that frame")
            os.replace(tmp, out)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
        st = os.stat(out)
        return {"path": out, "name": os.path.basename(out), "size": st.st_size, "mtime": int(st.st_mtime)}

    def op_copyFile(self, req):
        """the file itself, as a file manager copies one: it pastes into a chat or a folder"""
        subprocess.Popen(["wl-copy", "--type", "text/uri-list", uri_of(req["path"]) + "\r\n"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {}

    def op_undoSave(self, req):
        """the picture back as it was before that save. undoing the first one lets the
        kept original go: the picture is that original again"""
        backup, path = req["backup"], req["path"]
        put_back(backup, path)
        if req.get("first"):
            self.kept.drop(path)
        else:
            os.unlink(backup)
            self.kept.wrote(path)
        return self.finished(path, path)

    def op_revert(self, req):
        """the kept original back in its picture's place; what was there goes to the
        cache, where an undo finds it"""
        path = req["path"]
        e = self.kept.get(path)
        if not e:
            raise ValueError("Lens didn't keep an original of this picture")
        backup = self.backup_of(path)
        put_back(self.kept.file_of(e), path)
        self.kept.drop(path)
        res = self.finished(path, path)
        res.update({"backup": backup, "entry": e})
        return res

    def op_unrevert(self, req):
        """the edited picture back after a revert, and its original on file again"""
        path, backup = req["path"], req["backup"]
        self.kept.refile(path, req["entry"])
        put_back(backup, path)
        os.unlink(backup)
        self.kept.wrote(path)
        return self.finished(path, path)

    def op_forget(self, req):
        """the kept original let go, to the trash, to free its room; the picture
        stays as it is and can't be reverted after"""
        e = self.kept.get(req["path"])
        if not e:
            return {}
        Gio.File.new_for_path(self.kept.file_of(e)).trash(None)
        self.kept.drop(req["path"])
        return {"size": e.get("size", 0)}

    # -- the trash

    def op_trash(self, req):
        Gio.File.new_for_path(req["path"]).trash(None)
        return {}

    def op_restore(self, req):
        path = req["path"]
        if os.path.exists(path):
            raise ValueError("Something has taken its place")
        try:
            trash = Gio.File.new_for_uri("trash:///")
            best, when = None, ""
            en = trash.enumerate_children("standard::name,trash::orig-path,trash::deletion-date", Gio.FileQueryInfoFlags.NONE, None)
            for info in en:
                if info.get_attribute_byte_string("trash::orig-path") == path:
                    d = info.get_attribute_as_string("trash::deletion-date") or ""
                    if best is None or d > when:
                        best, when = trash.get_child(info.get_name()), d
            if best is not None:
                best.move(Gio.File.new_for_path(path), Gio.FileCopyFlags.NONE, None, None, None)
                return {"path": path}
        except GLib.Error:
            pass
        # no gvfs to read trash:// through: the trash folders themselves
        if self.restore_by_hand(path):
            return {"path": path}
        raise ValueError("It's no longer in the trash")

    def restore_by_hand(self, path):
        """the freedesktop trash: files/<name> beside info/<name>.trashinfo, in the
        home trash or the trash at the top of the drive the file was on"""
        dirs = [os.path.join(GLib.get_user_data_dir(), "Trash")]
        top = os.path.dirname(path)
        while top != "/" and not os.path.ismount(top):
            top = os.path.dirname(top)
        dirs += [os.path.join(top, ".Trash-%d" % os.getuid()), os.path.join(top, ".Trash", str(os.getuid()))]
        best = None
        for d in dirs:
            info = os.path.join(d, "info")
            try:
                names = os.listdir(info)
            except OSError:
                continue
            for n in names:
                if not n.endswith(".trashinfo"):
                    continue
                try:
                    with open(os.path.join(info, n), encoding="utf-8", errors="replace") as f:
                        text = f.read()
                except OSError:
                    continue
                m = re.search(r"^Path=(.*)$", text, re.M)
                when = (re.search(r"^DeletionDate=(.*)$", text, re.M) or [None, ""])[1]
                if not m:
                    continue
                orig = GLib.uri_unescape_string(m.group(1).strip(), None) or ""
                if not orig.startswith("/"):
                    orig = os.path.join(d.rsplit("/.Trash", 1)[0], orig)
                if orig == path and (best is None or when > best[2]):
                    best = (os.path.join(d, "files", n[:-len(".trashinfo")]), os.path.join(info, n), when)
        if best is None or not os.path.exists(best[0]):
            return False
        shutil.move(best[0], path)
        os.unlink(best[1])
        return True

    def op_rename(self, req):
        path, name = req["path"], req["name"].strip()
        if not name or "/" in name or name in (".", ".."):
            raise ValueError("That name can't be used")
        dest = os.path.join(os.path.dirname(path), name)
        if os.path.exists(dest):
            raise ValueError("Something here already has that name")
        os.rename(path, dest)
        # its kept original goes by the new name too
        try:
            self.kept.moved(path, dest)
        except (OSError, ValueError):
            pass
        return {"path": dest, "name": name}

    # -- the clipboard

    def op_copyImage(self, req):
        path = req["path"]
        if ext_of(path) == "png":
            with open(path, "rb") as f:
                data = f.read()
        else:
            im = open_any(path)
            if getattr(im, "n_frames", 1) > 1:
                im.seek(0)
            if im.mode not in ("RGB", "RGBA"):
                im = im.convert("RGBA")
            buf = io.BytesIO()
            im.save(buf, "PNG", compress_level=3)
            data = buf.getvalue()
        p = subprocess.Popen(["wl-copy", "--type", "image/png"], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        p.communicate(data, timeout=20)
        return {}

    def op_paste(self, req):
        types = subprocess.run(["wl-paste", "--list-types"], capture_output=True, text=True, timeout=5).stdout.split()
        pick = next((t for t in ("image/png", "image/jpeg", "image/webp", "image/gif", "image/bmp") if t in types), "")
        if not pick:
            uris = ""
            if "text/uri-list" in types:
                uris = subprocess.run(["wl-paste", "--type", "text/uri-list"], capture_output=True, text=True, timeout=5).stdout
            paths = [Gio.File.new_for_uri(u.strip()).get_path() for u in uris.splitlines() if u.strip() and not u.startswith("#")]
            paths = [p for p in paths if p and self.shows(os.path.basename(p))]
            if paths:
                return {"paths": paths}
            raise ValueError("There's no picture on the clipboard")
        data = subprocess.run(["wl-paste", "--type", pick, "--no-newline"], capture_output=True, timeout=10).stdout
        folder = os.path.join(CACHE, "pasted")
        os.makedirs(folder, exist_ok=True)
        stamp = time.strftime("%Y-%m-%d %H.%M.%S")
        out = unique_name(folder, "Pasted image " + stamp, pick.split("/")[1].replace("jpeg", "jpg"))
        with open(out, "wb") as f:
            f.write(data)
        return {"paths": [out], "pasted": True}

    def op_ocr(self, req):
        out = subprocess.run(["tesseract", req["path"], "-", "-l", req.get("lang") or "eng"], capture_output=True,
                             text=True, timeout=60).stdout
        text = "\n".join(l.rstrip() for l in out.splitlines()).strip()
        text = re.sub(r"\n{3,}", "\n\n", text)
        if text:
            p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                 start_new_session=True)
            p.communicate(text.encode(), timeout=10)
        return {"words": len(text.split()), "text": text[:2000]}

    def op_pixel(self, req):
        im = self.opened(req["path"])
        x = max(0, min(im.width - 1, int(req["x"])))
        y = max(0, min(im.height - 1, int(req["y"])))
        px = im.getpixel((x, y))
        if isinstance(px, int):
            px = (px, px, px)
        return {"hex": "#%02x%02x%02x" % tuple(px[:3]), "x": x, "y": y}

    _open = (None, None)

    def opened(self, path):
        st = os.stat(path)
        key = (path, st.st_mtime_ns)
        if self._open[0] != key:
            im = open_any(path)
            if im.mode != "RGB":
                im = im.convert("RGB")
            im.load()
            self._open = (key, im)
        return self._open[1]

    # -- elsewhere

    def op_wallpaper(self, req):
        prev = ""
        try:
            with open(os.path.join(HOME, ".cache", "current_wallpaper")) as f:
                prev = f.read().strip()
        except OSError:
            pass
        subprocess.Popen([WALLPAPER, req["path"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)
        return {"previous": prev}

    def apps(self):
        if self.dk is None:
            spec = importlib.util.spec_from_file_location("desk", os.path.join(HERE, "..", "luciddesktop", "desktop-icons.py"))
            self.dk = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(self.dk)
            self.icons = self.dk.Icons(self.dk.theme_or_system(""), 64)
        return self.dk

    def op_appsFor(self, req):
        dk = self.apps()
        ctype = Gio.content_type_guess(req["path"], None)[0] or "image/png"
        default = Gio.AppInfo.get_default_for_type(ctype, False)
        seen, out = set(), []
        for a in ([default] if default else []) + list(Gio.AppInfo.get_recommended_for_type(ctype)) + list(Gio.AppInfo.get_fallback_for_type(ctype)):
            if a is None or a.get_id() in seen or not a.should_show() or a.get_id() == "lucid.lens.desktop":
                continue
            seen.add(a.get_id())
            icon = self.icons.find(dk.icon_names(a.get_icon())) or self.icons.find(["application-x-executable"])
            out.append({"id": a.get_id(), "name": a.get_display_name() or a.get_name(), "icon": icon or "",
                        "default": default is not None and a.get_id() == default.get_id()})
            if len(out) >= 8:
                break
        return {"mime": ctype, "apps": out}

    def op_openWith(self, req):
        self.apps()
        app = self.dk.DesktopAppInfo.new(req["app"])
        if app is None:
            raise ValueError("That app is gone")
        if req.get("makeDefault") and req.get("mime"):
            app.set_as_default_for_type(req["mime"])
        app.launch_uris_async([uri_of(req["path"])], None, None, None)
        return {}

    def op_devices(self, req):
        if not shutil.which("kdeconnect-cli"):
            return {"devices": []}
        res = subprocess.run(["kdeconnect-cli", "-a", "--id-name-only"], capture_output=True, text=True, timeout=8)
        out = []
        for line in res.stdout.splitlines():
            if " " in line.strip():
                did, name = line.strip().split(" ", 1)
                out.append({"id": did, "name": name})
        return {"devices": out}

    def op_send(self, req):
        res = subprocess.run(["kdeconnect-cli", "-d", req["device"], "--share", req["path"]], capture_output=True,
                             text=True, timeout=30)
        if res.returncode != 0:
            raise ValueError((res.stderr or "Couldn't send it").strip().splitlines()[-1])
        return {}


def main():
    lens = Lens()
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
                lens.handle(req)
        return True

    GLib.io_add_watch(sys.stdin.fileno(), GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, readable)
    signal.signal(signal.SIGTERM, lambda *_: loop.quit())
    send({"ev": "ready", "pid": os.getpid()})
    loop.run()


if __name__ == "__main__":
    main()
