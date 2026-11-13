#!/usr/bin/env python3
"""Lucid's own pointer: Bibata Modern, drawn in the palette's colours.

Bibata (github.com/ful1e5/Bibata_Cursor, GPL-3.0) draws its cursors with
placeholder colours and recolours them when it builds a theme. This does the
same with Lucid's palette: its svg sources are fetched once into the cache, at
a pinned release whose content is checked, and the theme is written where both
kinds of reader find it:

  ~/.local/share/icons/lucid-cursors/
      manifest.hl, hyprcursors/   hyprcursor, which Hyprland draws from
      cursors/                    xcursor images, for GTK, XWayland and the rest
      index.theme, lucid.json     the theme's name, and what it was drawn with

  build '<json>'   draw the theme in these colours and point Hyprland at it
  fade '<json>'    walk Hyprland's pointer from "from" to "colours" over
                   "duration" ms, then build in the new colours
  retire           legacy cursors are on: hide the theme from hyprcursor
  nudge            shake to find's size changed: let the plugin load again now
  settle           Hyprland read its config again: hold the next setcursor
  probe            what is on disk: its colours, sizes and shadow

The json carries colours (see ROLES), size and shadow. Every command ends on
one JSON object. Before it come a {"step"} line for each fade step and a
{"swap"} line when Hyprland is pointed at the finished theme: Hyprland keeps
drawing the image it has until the shape asked for changes, so those are the
shell's cue to have its windows ask again. {"hires"} lines follow a reload of
the plugin's copy for shake to find, which it only takes up when a shape is
asked for, for the same cue.
"""

import hashlib
import io
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
import zipfile

NAME = "lucid-cursors"
TITLE = "Lucid"
# bump when the drawing changes, so a theme drawn by an older one is drawn again
DESIGN = 8

HOME = os.path.expanduser("~")
DATA = os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local", "share")
CACHEDIR = os.environ.get("XDG_CACHE_HOME") or os.path.join(HOME, ".cache")
THEME = os.path.join(DATA, "icons", NAME)
STAMP = os.path.join(THEME, "lucid.json")

BIBATA = "2.0.7"
BIBATA_URL = "https://github.com/ful1e5/Bibata_Cursor/archive/refs/tags/v%s.tar.gz" % BIBATA
# of the files kept, not the archive, which github may compress again any day
BIBATA_SHA256 = "2bb0e81ef60f6073492233a63fdd0c50caa3566cf5fffa7e141de79f97145aa8"
SOURCES = os.path.join(CACHEDIR, "lucid", "bibata-" + BIBATA)

# bibata's grid, and a pointer the same size as the cursor size it is drawn for
GRID = 256
NOMINAL = 1.0
DELAY = 40
# a soft shade under everything, on bibata's grid
SHADE = {"dx": 2.0, "dy": 7.0, "blur": 8.0, "alpha": 0.34}

# what each of bibata's colours becomes. the first three are its own
# placeholders; the rest it draws as they are, so they get the palette's
# accents: the busy ring's quarters, the corner marks, the badges
ROLES = {
    "#00FF00": "body", "#FF0000": "body", "#0000FF": "ink",
    "#FE0000": "error",
    "#32A0DA": "a1", "#F05024": "a2", "#7EBA41": "a3", "#FCB813": "a4",
    "#4FADDF": "a1", "#F1613A": "a2", "#96C865": "a3", "#FDBE2A": "a4",
    "#179DD8": "a1", "#5F3BE4": "a1", "#0A6857": "a1",
    "#06B231": "a2", "#F27400": "a2",
    "#2C2C2C": "raised", "#606060": "muted",
}
DEFAULTS = {"body": "#1b1b1f", "ink": "#f4f4f7", "error": "#e5484d", "a1": "#80d4dc", "a2": "#b7c7ea",
            "a3": "#a8cbbf", "a4": "#c8eef2", "raised": "#3a3a40", "muted": "#7a7a80", "shadow": "#000000"}

# windows-only in bibata's own config, drawn on the arrow
EXTRA = {"pin": (55, 17), "person": (55, 17)}
# lucid's own in place of bibata's: the text pointer as a plain rounded line,
# in bibata's placeholder colours and outline so it is drawn like the rest. the
# outline sits outside the line only: centred, it would cover a line this thin
OWN = {
    "xterm": '<svg width="256" height="256" viewBox="0 0 256 256" fill="none" xmlns="http://www.w3.org/2000/svg">'
             '<rect x="116" y="26" width="24" height="204" rx="12" fill="#00FF00" stroke="#0000FF" stroke-width="17" paint-order="stroke"/></svg>',
    "vertical-text": '<svg width="256" height="256" viewBox="0 0 256 256" fill="none" xmlns="http://www.w3.org/2000/svg">'
                     '<rect x="26" y="116" width="204" height="24" rx="12" fill="#00FF00" stroke="#0000FF" stroke-width="17" paint-order="stroke"/></svg>',
}
# the busy pointers are lucid's own: windows' ring rather than bibata's pie,
# an arc in the accent (bibata's ring blue, so it maps like the rest) inside
# an edge of the body colour, running ahead and catching up as it turns
SPIN_FRAMES = 48
SPIN_DELAY = 30
SVG_OPEN = '<svg width="256" height="256" viewBox="0 0 256 256" fill="none" xmlns="http://www.w3.org/2000/svg">'


def _arc(cx, cy, r, a0, a1):
    """an open arc, in degrees clockwise from twelve o'clock"""
    import math
    t0, t1 = math.radians(a0 - 90), math.radians(a1 - 90)
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return "M%.2f %.2fA%g %g 0 %d 1 %.2f %.2f" % (
        cx + r * math.cos(t0), cy + r * math.sin(t0), r, r, large, cx + r * math.cos(t1), cy + r * math.sin(t1))


def _spin(t, smin=30.0, smax=260.0):
    """the arc at t in [0, 1): the head runs ahead in the first half, the tail
    catches it up in the second, and the whole turns exactly once, so the last
    frame leads straight back into the first"""
    span = smax - smin
    base = 360.0 - span
    head = base * t + smin + span * _ease(min(1.0, t / 0.5), 0.4, 0.0, 0.2, 1.0)
    tail = base * t + span * _ease(max(0.0, (t - 0.5) / 0.5), 0.4, 0.0, 0.2, 1.0)
    return tail, head


def ring(cx, cy, r, w, t):
    d = _arc(cx, cy, r, *_spin(t))
    return ('<path d="%s" stroke="#00FF00" stroke-width="%g" stroke-linecap="round"/>'
            '<path d="%s" stroke="#32A0DA" stroke-width="%g" stroke-linecap="round"/>' % (d, w + 17, d, w))


def inner(src):
    """what an svg draws, without its own svg element"""
    return src[src.index(">", src.index("<svg")) + 1:src.rindex("</svg>")]


# cursor-shape names bibata's links leave out, and the shape that answers each
CSS = {
    "left_ptr": ["default", "arrow", "top_left_arrow"],
    "left_ptr_watch": ["progress", "half-busy"],
    "question_arrow": ["help", "whats_this", "left_ptr_help"],
    "hand2": ["pointer", "pointing_hand", "hand"],
    "hand1": ["grab", "openhand"],
    "grabbing": ["closedhand"],
    "crossed_circle": ["not-allowed", "forbidden"],
    "dnd_no_drop": ["no-drop", "dnd-no-drop"],
    "dnd-link": ["alias"],
    "copy": ["dnd-copy"],
    "move": ["all-scroll", "all-resize", "fleur", "size_all"],
    "sb_h_double_arrow": ["ew-resize", "col-resize"],
    "sb_v_double_arrow": ["ns-resize", "row-resize"],
    "fd_double_arrow": ["nesw-resize"],
    "bd_double_arrow": ["nwse-resize"],
    "top_side": ["n-resize"],
    "bottom_side": ["s-resize"],
    "left_side": ["w-resize"],
    "right_side": ["e-resize"],
    "top_left_corner": ["nw-resize"],
    "top_right_corner": ["ne-resize"],
    "bottom_left_corner": ["sw-resize"],
    "bottom_right_corner": ["se-resize"],
    "xterm": ["text", "ibeam"],
    "plus": ["cell"],
    "wait": ["watch"],
    "pencil": ["draft"],
}


# ------------------------------------------------------------------ sources

def _keep(rel):
    return rel.startswith("svg/") or rel in ("configs/normal/x.build.toml", "LICENSE")


def unpack(data):
    """the files kept from bibata's archive: svg/modern with its links resolved
    to the files they point at, its build config and its licence. links are
    only followed to regular files inside svg/, and none are written"""
    import tarfile
    files, links = {}, {}
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as t:
        for m in t.getmembers():
            parts = m.name.split("/", 1)
            if len(parts) < 2 or not _keep(parts[1]):
                continue
            rel = os.path.normpath(parts[1])
            if rel.startswith("..") or os.path.isabs(rel):
                continue
            if m.isfile():
                files[rel] = t.extractfile(m).read()
            elif m.issym():
                links[rel] = os.path.normpath(os.path.join(os.path.dirname(rel), m.linkname))
    out = {}

    def resolve(rel):
        for _ in range(8):
            if rel not in links:
                break
            rel = links[rel]
        return rel

    def take(rel, target):
        if target in files:
            out[rel] = files[target]
            return
        # a link to a directory: everything beneath it, its own links followed
        for f in list(files) + list(links):
            if f.startswith(target + "/"):
                t = resolve(f)
                if t.startswith("svg/") and t in files:
                    out[rel + f[len(target):]] = files[t]

    for rel in ("configs/normal/x.build.toml", "LICENSE"):
        if rel in files:
            out[rel] = files[rel]
    for rel in sorted(set(files) | set(links)):
        if not rel.startswith("svg/modern/") or "/" in rel[len("svg/modern/"):] and rel.rsplit("/", 1)[0] in links:
            continue
        target = resolve(rel)
        if target.startswith("svg/"):
            take(rel, target)
    return out


def digest(found):
    h = hashlib.sha256()
    for rel in sorted(found):
        h.update(rel.encode() + b"\0" + found[rel] + b"\0")
    return h.hexdigest()


def sources():
    """bibata's sources in the cache, fetched the first time"""
    if os.path.isfile(os.path.join(SOURCES, ".complete")):
        return SOURCES
    import tempfile
    import urllib.request
    try:
        with urllib.request.urlopen(BIBATA_URL, timeout=60) as r:
            data = r.read()
    except Exception as e:
        raise OSError("could not fetch Bibata's sources (%s), which the pointer is drawn from" % e)
    found = unpack(data)
    if digest(found) != BIBATA_SHA256:
        raise OSError("Bibata's sources did not match what this version of Lucid expects")
    parent = os.path.dirname(SOURCES)
    os.makedirs(parent, exist_ok=True)
    tmp = tempfile.mkdtemp(dir=parent, prefix=".bibata-")
    for rel, b in found.items():
        dst = os.path.join(tmp, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        with open(dst, "wb") as fh:
            fh.write(b)
    open(os.path.join(tmp, ".complete"), "w").close()
    shutil.rmtree(SOURCES, ignore_errors=True)
    os.replace(tmp, SOURCES)
    return SOURCES


def shapes():
    """bibata's cursors as {name: {hot, frames, aliases, delay}}, frames being
    svg texts, from the config its own builds read"""
    import tomllib
    src = sources()
    with open(os.path.join(src, "configs/normal/x.build.toml"), "rb") as fh:
        conf = tomllib.load(fh)["cursors"]
    fallback = conf.get("fallback_settings", {})
    entries = {}
    for key, c in conf.items():
        if key == "fallback_settings":
            continue
        entries[c["x11_name"]] = c
    for name, (x, y) in EXTRA.items():
        entries.setdefault(name, {"png": name + ".png", "x_hotspot": x, "y_hotspot": y, "x11_name": name})
    taken = set(entries)
    for c in entries.values():
        taken.update(c.get("x11_symlinks", []))
    S = {}
    for name, c in entries.items():
        png = c["png"]
        if "*" in png:
            d = os.path.join(src, "svg/modern", png.split("-*")[0])
            paths = sorted(os.path.join(d, f) for f in os.listdir(d) if f.endswith(".svg"))
        else:
            paths = [os.path.join(src, "svg/modern", png[:-4] + ".svg")]
        if not paths or not all(os.path.isfile(p) for p in paths):
            continue
        aliases = list(c.get("x11_symlinks", []))
        for a in CSS.get(name, []):
            if a not in taken:
                aliases.append(a)
                taken.add(a)
        S[name] = {
            "hot": (c.get("x_hotspot", fallback.get("x_hotspot", 128)), c.get("y_hotspot", fallback.get("y_hotspot", 128))),
            "frames": [OWN[name]] if name in OWN else [open(p, encoding="utf-8").read() for p in paths],
            "aliases": aliases,
            "delay": int(c.get("x11_delay", fallback.get("x11_delay", DELAY))),
        }
    steps = [i / SPIN_FRAMES for i in range(SPIN_FRAMES)]
    if "wait" in S:
        S["wait"].update(frames=[SVG_OPEN + ring(128, 128, 84, 38, t) + "</svg>" for t in steps], delay=SPIN_DELAY)
    # the arrow as it is everywhere else, the ring beside it, so nothing jumps
    # when an app goes busy
    if "left_ptr_watch" in S and "left_ptr" in S:
        arrow = inner(S["left_ptr"]["frames"][0])
        S["left_ptr_watch"].update(frames=[SVG_OPEN + arrow + ring(203, 203, 31, 22, t) + "</svg>" for t in steps],
                                   hot=S["left_ptr"]["hot"], delay=SPIN_DELAY)
    return S


# ------------------------------------------------------------------ drawing

HEX = re.compile(r"#[0-9A-Fa-f]{6}\b")


def colours(spec):
    out = {}
    for k, v in DEFAULTS.items():
        c = str((spec or {}).get(k) or v).strip()
        ok = len(c) == 7 and c[0] == "#" and all(ch in "0123456789abcdefABCDEF" for ch in c[1:])
        out[k] = c.lower() if ok else v
    return out


def mix(a, b, t):
    out = {}
    for k in a:
        x = [int(a[k][i:i + 2], 16) for i in (1, 3, 5)]
        y = [int(b[k][i:i + 2], 16) for i in (1, 3, 5)]
        out[k] = "#%02x%02x%02x" % tuple(int(round(p + (q - p) * t)) for p, q in zip(x, y))
    return out


def svg(src, cols, shadow):
    """one of bibata's frames in these colours, with the shade under it"""
    s = HEX.sub(lambda m: cols.get(ROLES.get(m.group(0).upper(), ""), m.group(0)), src)
    if not shadow:
        return s
    i = s.index(">", s.index("<svg")) + 1
    j = s.rindex("</svg>")
    defs = ('<defs><filter id="lucid-shade" filterUnits="userSpaceOnUse" x="-32" y="-32" width="320" '
            'height="320"><feDropShadow dx="%g" dy="%g" stdDeviation="%g" flood-color="%s" '
            'flood-opacity="%g"/></filter></defs>' % (SHADE["dx"], SHADE["dy"], SHADE["blur"],
                                                      cols["shadow"], SHADE["alpha"]))
    return s[:i] + defs + '<g filter="url(#lucid-shade)">' + s[i:j] + "</g>" + s[j:]


_rsvg = None


def raster(doc, side):
    """an svg at side x side: cairo's argb32, premultiplied and little-endian,
    which is byte for byte what an xcursor image holds"""
    global _rsvg
    if _rsvg is None:
        import gi
        gi.require_version("Rsvg", "2.0")
        from gi.repository import Rsvg
        import cairo
        _rsvg = (Rsvg, cairo)
    Rsvg, cairo = _rsvg
    h = Rsvg.Handle.new_from_data(doc.encode())
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, side, side)
    r = Rsvg.Rectangle()
    r.x = r.y = 0
    r.width = r.height = side
    h.render_document(cairo.Context(s), r)
    s.flush()
    return s


def png(surface):
    buf = io.BytesIO()
    surface.write_to_png(buf)
    return buf.getvalue()


# ------------------------------------------------------------------ writing

def write(path, data):
    tmp = path + ".lucid-tmp"
    with open(tmp, "wb") as fh:
        fh.write(data)
    os.replace(tmp, path)


def link(path, target):
    try:
        if os.readlink(path) == target:
            return
    except OSError:
        pass
    tmp = path + ".lucid-tmp"
    try:
        os.remove(tmp)
    except OSError:
        pass
    os.symlink(target, tmp)
    os.replace(tmp, path)


def xcursor(images):
    """images as (nominal, side, xhot, yhot, delay, pixels), every frame of one
    nominal size together and the sizes ascending, as libXcursor expects"""
    import struct
    head = struct.pack("<4sIII", b"Xcur", 16, 0x10000, len(images))
    pos = 16 + 12 * len(images)
    toc, chunks = [], []
    for nominal, side, xh, yh, delay, px in images:
        toc.append(struct.pack("<III", 0xFFFD0002, nominal, pos))
        chunk = struct.pack("<IIIIIIIII", 36, 0xFFFD0002, nominal, 1, side, side, xh, yh, delay) + px
        chunks.append(chunk)
        pos += len(chunk)
    return head + b"".join(toc) + b"".join(chunks)


def hlc(sp, files):
    """one hyprcursor shape: its meta and its images as (side, file, data),
    zipped. side 0 is an svg"""
    hx, hy = sp["hot"]
    meta = ["resize_algorithm = bilinear",
            "hotspot_x = %g" % (hx / GRID),
            "hotspot_y = %g" % (hy / GRID),
            "nominal_size = %g" % NOMINAL]
    meta += ["define_override = %s" % a for a in sp["aliases"]]
    anim = len(sp["frames"]) > 1
    for side, fn, _ in files:
        meta.append("define_size = %d, %s%s" % (side, fn, ", %d" % sp["delay"] if anim else ""))
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as z:
        z.writestr("meta.hl", "\n".join(meta) + "\n", zipfile.ZIP_DEFLATED)
        for _, fn, data in files:
            z.writestr(fn, data, zipfile.ZIP_DEFLATED if fn.endswith(".svg") else zipfile.ZIP_STORED)
    return buf.getvalue()


def write_hyprcursors(S, cols, shadow, spin, step=None, every=1):
    """svgs, which Hyprland renders at whatever size it is asked for, except
    for what moves: dozens of frames to render is a stall Hyprland would show,
    so those are pngs at the sides in spin. a fade step gives sides for every
    shape, and Hyprland loads the whole set without rendering anything; it
    keeps every nth frame of the busy pointers too, each shown that much longer"""
    d = os.path.join(THEME, "hyprcursors")
    os.makedirs(d, exist_ok=True)
    for name, sp in S.items():
        frames = sp["frames"]
        anim = len(frames) > 1
        if step or anim:
            kept = frames[::every] if anim else frames
            shown = dict(sp, delay=sp["delay"] * (every if anim else 1), frames=kept)
            files = []
            for side in step or spin:
                for i, fr in enumerate(kept):
                    fn = "%s-%d%s.png" % (name, side, "-%02d" % i if anim else "")
                    files.append((side, fn, png(raster(svg(fr, cols, shadow), side))))
        else:
            shown = sp
            files = [(0, name + ".svg", svg(frames[0], cols, shadow).encode())]
        write(os.path.join(d, name + ".hlc"), hlc(shown, files))
    write(os.path.join(THEME, "manifest.hl"), (
        "name = %s\ndescription = Bibata Modern in the palette's colours, for %s\n"
        "version = %d\ncursors_directory = hyprcursors\n" % (NAME, TITLE, DESIGN)).encode())


def xsizes(size):
    """what clients that load the theme themselves get to choose from: the size
    Lucid sets, twice it for scaled outputs, and the sizes toolkits default to"""
    return sorted({n for n in (size, size * 2, 24, 32, 48) if 8 <= n <= 128})


def write_xcursors(S, cols, shadow, sizes):
    d = os.path.join(THEME, "cursors")
    os.makedirs(d, exist_ok=True)
    want = set()
    for name, sp in S.items():
        docs = [svg(fr, cols, shadow) for fr in sp["frames"]]
        delay = sp["delay"] if len(docs) > 1 else 50
        hx, hy = sp["hot"]
        images = []
        for n in sizes:
            side = int(round(n / NOMINAL))
            xh = min(side - 1, int(hx * side / GRID))
            yh = min(side - 1, int(hy * side / GRID))
            for doc in docs:
                s = raster(doc, side)
                images.append((n, side, xh, yh, delay, bytes(s.get_data())[:side * side * 4]))
        write(os.path.join(d, name), xcursor(images))
        want.add(name)
        for a in sp["aliases"]:
            if a not in S:
                link(os.path.join(d, a), name)
                want.add(a)
    return want


PREVIEW = ("left_ptr", "hand2", "xterm", "wait", "crossed_circle", "bd_double_arrow")
# the names qt asks for (by cursor shape, see PointerPictures.qml), whose pictures the
# shell draws the pointer from where whatever a drag moves has to stay under it
DRAWN = ("default", "pointer", "text", "crosshair", "grab", "grabbing", "move", "all-scroll", "copy", "alias",
         "not-allowed", "help", "ew-resize", "ns-resize", "nesw-resize", "nwse-resize", "col-resize",
         "row-resize", "n-resize")


def drawn(S):
    """each name in DRAWN, and the shape hyprcursor answers it with"""
    out = {}
    for css in DRAWN:
        for name, sp in S.items():
            if name == css or css in sp["aliases"]:
                out[css] = name
                break
    return out


def write_previews(S, cols, shadow):
    """shapes as pngs: a few for the Environment page to show the pointer in, and the
    ones the shell draws the pointer from"""
    d = os.path.join(THEME, "preview")
    os.makedirs(d, exist_ok=True)
    keep = set()
    for name in sorted(set(PREVIEW) | set(drawn(S).values())):
        if name in S:
            frames = S[name]["frames"]
            # 192: the shell draws them as big as shake to find grows the pointer
            write(os.path.join(d, name + ".png"), png(raster(svg(frames[len(frames) // 3], cols, shadow), 192)))
            keep.add(name + ".png")
    tidy(d, keep)


def tidy(d, keep):
    """files a previous design wrote and this one does not"""
    try:
        names = os.listdir(d)
    except OSError:
        return
    for n in names:
        if n not in keep:
            try:
                os.remove(os.path.join(d, n))
            except OSError:
                pass


# ------------------------------------------------------------------ hyprland

def run(args, timeout=5):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except Exception:
        return None


def hyprland():
    return bool(os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")) and shutil.which("hyprctl") is not None


def option(name):
    r = run(["hyprctl", "-j", "getoption", name])
    if not r or r.returncode != 0:
        return None
    try:
        o = json.loads(r.stdout)
    except ValueError:
        return None
    for k in ("int", "float", "str", "bool"):
        if k in o:
            return o[k]
    return None


def max_scale():
    r = run(["hyprctl", "-j", "monitors"])
    try:
        return max(float(m.get("scale") or 1) for m in json.loads(r.stdout)) or 1.0
    except Exception:
        return 1.0


# the cursor plugin keeps a large copy of the theme for shake to find, and
# loads it on a thread of its own whenever the theme's name or size changes,
# when it is loaded, and when the size it grows to changes. hyprcursor cannot
# read two themes at once, and a setcursor reads one on Hyprland's own thread:
# landing while that load reads its theme, it takes Hyprland down. so every
# setcursor of Lucid's takes this lock, and after one that sets a load off the
# next waits SETTLE, which is many times what the load spends reading: only
# the reading touches what hyprcursor shares (meta.cpp's currentMeta), ~13 ms
# for this theme, then ~45 ms drawing it at 144 px, which shares nothing.
# cursor-plugin.sh takes the same lock to load the plugin
RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
LOCK = os.path.join(RUNTIME, "lucid-cursor.lock")
CHANGED = os.path.join(RUNTIME, "lucid-cursor.changed")
LAST = os.path.join(RUNTIME, "lucid-cursor.last")
SETTLE = 0.5


class _locked:
    def __enter__(self):
        import fcntl
        self.fh = open(LOCK, "a")
        fcntl.flock(self.fh, fcntl.LOCK_EX)
        try:
            left = os.path.getmtime(CHANGED) + SETTLE - time.time()
        except OSError:
            left = 0
        if left > 0:
            time.sleep(min(left, SETTLE))
        return self

    def __exit__(self, *exc):
        self.fh.close()

    def changed(self):
        with open(CHANGED, "a"):
            pass
        os.utime(CHANGED)


# the same theme drawn again in other colours is no new name or size, so the
# plugin would keep its copy in the old ones until Hyprland restarts. switched
# off, with a setcursor to make it let the copy go, then on, the setcursor after
# loads it afresh. (a size a pixel off would also do, but a load it cannot start
# at once, it starts later on a pointer shape change, outside the lock)
HIRES = "plugin.dynamic_cursors.hyprcursor.enabled"
# a kill between off and on would leave the copy off for good
STOPS = {signal.SIGTERM, signal.SIGINT, signal.SIGHUP}


def _hires_on():
    """the plugin is loaded and keeps a copy: shake to find and hyprcursor on"""
    return (option(HIRES) is True and option("plugin.dynamic_cursors.shake.enabled") is True
            and option("cursor.enable_hyprcursor") is True)


def _set_hires(on):
    r = run(["hyprctl", "eval", 'hl.config({ ["%s"] = %s })' % (HIRES, "true" if on else "false")])
    return r is not None and r.returncode == 0 and not r.stdout.lstrip().startswith("error")


def setcursor_safely(name, size, recolour=False):
    """hyprctl setcursor, under the lock. a new name or size sets the plugin's
    load off, so the time is noted for whoever comes next. recolour: the theme
    was drawn again under the same name, have the plugin load its copy again"""
    with _locked() as lk:
        try:
            with open(LAST, encoding="utf-8") as fh:
                last = fh.read().strip()
        except OSError:
            last = ""
        now = "%s %d" % (name, int(size))
        moved = now != last
        reload = recolour and not moved and _hires_on()
        held = signal.pthread_sigmask(signal.SIG_BLOCK, STOPS) if reload else None
        try:
            if reload:
                reload = _set_hires(False)
                if reload:
                    run(["hyprctl", "setcursor", name, str(size)])
                    _set_hires(True)
            run(["hyprctl", "setcursor", name, str(size)])
            if moved:
                with open(LAST, "w", encoding="utf-8") as fh:
                    fh.write(now + "\n")
            if moved or reload:
                lk.changed()
        finally:
            if held is not None:
                signal.pthread_sigmask(signal.SIG_SETMASK, held)
    return reload


def setcursor(size, recolour=False):
    return setcursor_safely(NAME, size, recolour)


# the copy loads in ~60 ms, and the plugin takes it up at the next shape asked
# for: over a window a move does that, over the shell only a poke
HIRES_POKES = (0.15, 0.5)


def nudge():
    """the size shake to find grows to has changed: the plugin loads its copy
    again at the next setcursor, so make that one now, under the lock"""
    try:
        with open(LAST, encoding="utf-8") as fh:
            name, size = fh.read().split()
    except (OSError, ValueError):
        return {"ok": True, "nudged": False}
    with _locked() as lk:
        run(["hyprctl", "setcursor", name, size])
        lk.changed()
    return {"ok": True, "nudged": True}


def settle():
    """Hyprland has read its config again, which may have set a load off"""
    with _locked() as lk:
        lk.changed()
    return {"ok": True}


def nudge_gtk():
    """gtk loads the theme itself and only again when its name changes, so
    clear the name and put it back"""
    if not shutil.which("gsettings"):
        return
    r = run(["gsettings", "get", "org.gnome.desktop.interface", "cursor-theme"])
    if not r or r.stdout.strip().strip("'") != NAME:
        return
    run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", ""])
    run(["gsettings", "set", "org.gnome.desktop.interface", "cursor-theme", NAME])


# ------------------------------------------------------------------ commands

def stamp():
    try:
        with open(STAMP, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def side_of(size, scale):
    return int(round(size * scale / NOMINAL))


def say(**kw):
    print(json.dumps(kw), flush=True)


def build(spec, apply=True, settle=0.0, S=None):
    """the whole theme in these colours. settle holds back pointing Hyprland at
    the svgs, which it takes a moment to render, until the desktop has stopped
    moving: a fade has already put the same colours on screen as pngs"""
    t0 = time.monotonic()
    cols = colours(spec.get("colours"))
    shadow = spec.get("shadow", True) is not False
    size = max(8, min(256, int(spec.get("size") or 24)))
    live = apply and hyprland()
    scale = max_scale() if live else 1.0
    S = S or shapes()
    os.makedirs(THEME, exist_ok=True)
    side = side_of(size, scale)
    write_hyprcursors(S, cols, shadow, sorted({side, side * 2}))
    tidy(os.path.join(THEME, "hyprcursors"), {n + ".hlc" for n in S})
    reloaded = None
    if live and settle <= 0:
        if setcursor(size, recolour=True):
            reloaded = time.monotonic()
        say(swap=True)
    sizes = xsizes(size)
    keep = write_xcursors(S, cols, shadow, sizes)
    tidy(os.path.join(THEME, "cursors"), keep)
    write_previews(S, cols, shadow)
    write(os.path.join(THEME, "index.theme"), (
        "[Icon Theme]\nName=%s\nComment=Bibata Modern (GPL-3.0, github.com/ful1e5/Bibata_Cursor), "
        "drawn in the palette's colours\n" % TITLE).encode())
    pics = drawn(S)
    # each drawn picture's hotspot, as a fraction of its side
    hot = {n: [round(S[n]["hot"][0] / GRID, 4), round(S[n]["hot"][1] / GRID, 4)] for n in set(pics.values())}
    st = {"design": DESIGN, "colours": cols, "shadow": shadow, "size": size, "sizes": sizes, "pictures": pics,
          "hotspots": hot}
    write(STAMP, (json.dumps(st, indent=1) + "\n").encode())
    if live:
        nudge_gtk()
        if settle > 0:
            left = t0 + settle - time.monotonic()
            if left > 0:
                time.sleep(left)
            if setcursor(size, recolour=True):
                reloaded = time.monotonic()
            say(swap=True)
        for at in HIRES_POKES if reloaded is not None else ():
            left = reloaded + at - time.monotonic()
            if left > 0:
                time.sleep(left)
            say(hires=True)
    return {"ok": True, "theme": NAME, "stamp": st, "ms": int((time.monotonic() - t0) * 1000)}


def fade(spec):
    """steps Hyprland's pointer through the colours in between, each step pngs
    at the very size it draws, so it loads them without rendering anything;
    then builds the theme in the new colours"""
    old = stamp()
    to = colours(spec.get("colours"))
    fr = colours(spec.get("from") or (old or {}).get("colours") or spec.get("colours"))
    ms = max(0, int(spec.get("duration", 1000)))
    shadow = spec.get("shadow", True) is not False
    size = max(8, min(256, int(spec.get("size") or 24)))
    if (old is None or old.get("design") != DESIGN or not os.path.isfile(os.path.join(THEME, "manifest.hl"))
            or ms == 0 or fr == to or not hyprland()):
        return build(spec)
    S = shapes()
    side = side_of(size, max_scale())
    steps = max(2, int(round(ms / 85.0)))
    t0 = time.monotonic()
    for k in range(1, steps + 1):
        cols = to if k == steps else mix(fr, to, _ease(k / steps, 0.54, 0.0, 0.34, 0.99))
        write_hyprcursors(S, cols, shadow, None, [side], every=3)
        setcursor(size)
        say(step=k, of=steps, colours=cols)
        left = t0 + ms / 1000.0 * k / steps - time.monotonic()
        if left > 0 and k < steps:
            time.sleep(left)
    # the desktop's fade runs as long as this one, so it has all but stopped
    return build(spec, settle=0.3, S=S)


def _ease(t, x1, y1, x2, y2):
    """a css cubic-bezier at t"""
    lo, hi = 0.0, 1.0
    for _ in range(48):
        u = (lo + hi) / 2
        x = 3 * (1 - u) ** 2 * u * x1 + 3 * (1 - u) * u * u * x2 + u ** 3
        lo, hi = (u, hi) if x < t else (lo, u)
    u = (lo + hi) / 2
    return 3 * (1 - u) ** 2 * u * y1 + 3 * (1 - u) * u * u * y2 + u ** 3


def retire():
    """legacy cursors are on: take away what hyprcursor finds, or Hyprland
    would pick this theme up at login as the first one it comes across"""
    try:
        os.remove(os.path.join(THEME, "manifest.hl"))
    except OSError:
        pass
    shutil.rmtree(os.path.join(THEME, "hyprcursors"), ignore_errors=True)
    return {"ok": True, "theme": NAME}


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "probe"
    raw = (sys.argv[2] if len(sys.argv) > 2 else "").strip() or "{}"
    try:
        spec = json.loads(raw)
    except ValueError as e:
        print(json.dumps({"ok": False, "error": "bad json: %s" % e}))
        return 1
    try:
        if cmd == "probe":
            out = {"ok": True, "theme": NAME, "stamp": stamp(), "design": DESIGN,
                   "live": os.path.isfile(os.path.join(THEME, "manifest.hl"))}
        elif cmd == "build":
            out = build(spec)
        elif cmd == "fade":
            out = fade(spec)
        elif cmd == "retire":
            out = retire()
        elif cmd == "nudge":
            out = nudge()
        elif cmd == "settle":
            out = settle()
        else:
            out = {"ok": False, "error": "unknown command %s" % cmd}
    except ImportError as e:
        out = {"ok": False, "error": "drawing the pointer needs python-gobject, librsvg and python-cairo (%s)" % e}
    except OSError as e:
        out = {"ok": False, "error": str(e)}
    print(json.dumps(out))
    return 0 if out.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
