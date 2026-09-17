#!/usr/bin/env python3
"""Rebuilds an XCursor theme from its SVG sources with the drop shadow removed.

Hyprland has no cursor-shadow option -- the shade is painted into the theme's
own images -- so the only way to drop it is to render the theme again without
the shadow layer. Two modes, both printing one JSON object:

  probe [theme...]   whether each theme can be rebuilt, and whether it already has been
  build <theme>      writes <theme>-noshadow next to it

The rebuild copies the original's geometry exactly: nominal sizes, pixel sizes,
hotspots and frame delays are read back out of the theme's own cursor files
rather than recomputed, so the variant differs only by the missing shade.
"""

import json
import os
import re
import shutil
import struct
import subprocess
import sys
import xml.etree.ElementTree as ET

HOME = os.path.expanduser("~")
ICON_DIRS = [f"{HOME}/.icons", f"{HOME}/.local/share/icons", "/usr/share/icons"]
OUT_DIR = f"{HOME}/.local/share/icons"
SUFFIX = "-noshadow"

SVG_NS = "http://www.w3.org/2000/svg"
CHUNK_IMAGE = 0xFFFD0002
SHADOW_ID = re.compile(r"shadow|drop", re.I)


def local(tag):
    return tag.rsplit("}", 1)[-1]
SVG_DIRS = ("cursors_scalable", "svgs", "src")


def have(cmd):
    return shutil.which(cmd) is not None


# ------------------------------------------------------------------ locating

def theme_dir(name):
    for d in ICON_DIRS:
        p = os.path.join(d, name)
        if os.path.isdir(os.path.join(p, "cursors")):
            return p
    return None


def svg_dir(base):
    for sub in SVG_DIRS:
        p = os.path.join(base, sub)
        if os.path.isdir(p):
            return p
    return None


def is_variant(name):
    return name.endswith(SUFFIX)


# ------------------------------------------------------------- svg surgery

def strip_shadow(data):
    """Drop every element painted through a blur/shadow filter.

    Returns the rewritten svg, or None when there was nothing to strip or the
    strip would have emptied the drawing.
    """
    ET.register_namespace("", SVG_NS)
    try:
        root = ET.fromstring(data)
    except ET.ParseError:
        return None

    shadows = set()
    for f in root.iter(f"{{{SVG_NS}}}filter"):
        fid = f.get("id")
        if not fid:
            continue
        prims = [local(c.tag) for c in f]
        blurs = {"feGaussianBlur", "feDropShadow", "feOffset"}
        if prims and set(prims) <= blurs or SHADOW_ID.search(fid):
            shadows.add(fid)
    if not shadows:
        return None

    refs = {f"url(#{i})" for i in shadows}
    drawn = 0
    hit = 0
    for parent in root.iter():
        for child in list(parent):
            tag = local(child.tag)
            if tag in ("defs", "filter", "metadata", "title", "desc"):
                continue
            if (child.get("filter") or "").strip() in refs:
                parent.remove(child)
                hit += 1
            elif tag in ("path", "rect", "circle", "ellipse", "polygon",
                         "polyline", "line", "image", "use", "text"):
                drawn += 1
    if not hit or not drawn:
        return None
    return ET.tostring(root, encoding="unicode")


# -------------------------------------------------------------- rendering

def render(svg, w, h):
    """svg bytes -> w*h premultiplied ARGB pixels, as a bytes object."""
    if have("rsvg-convert"):
        p = subprocess.run(["rsvg-convert", "-w", str(w), "-h", str(h),
                            "-f", "png"], input=svg, capture_output=True)
        if p.returncode != 0 or not p.stdout:
            raise RuntimeError(p.stderr.decode("utf-8", "replace")[:200])
        png = p.stdout
    elif have("magick"):
        p = subprocess.run(["magick", "-background", "none", "svg:-",
                            "-resize", f"{w}x{h}!", "png:-"],
                           input=svg, capture_output=True)
        if p.returncode != 0 or not p.stdout:
            raise RuntimeError(p.stderr.decode("utf-8", "replace")[:200])
        png = p.stdout
    else:
        raise RuntimeError("neither rsvg-convert nor magick is installed")
    return premultiply(decode(png, w, h), w, h)


def decode(png, w, h):
    try:
        from PIL import Image
        import io
        im = Image.open(io.BytesIO(png)).convert("RGBA")
        if im.size != (w, h):
            im = im.resize((w, h), Image.LANCZOS)
        return im.tobytes()
    except ImportError:
        pass
    p = subprocess.run(["magick", "png:-", "-depth", "8", "rgba:-"],
                       input=png, capture_output=True)
    if p.returncode != 0 or len(p.stdout) != w * h * 4:
        raise RuntimeError("could not decode a rendered frame")
    return p.stdout


def premultiply(rgba, w, h):
    out = bytearray(w * h * 4)
    for i in range(0, w * h * 4, 4):
        r, g, b, a = rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]
        if a != 255:
            r = (r * a + 127) // 255
            g = (g * a + 127) // 255
            b = (b * a + 127) // 255
        # xcursor stores argb32 little-endian, so b,g,r,a on disk
        out[i] = b
        out[i + 1] = g
        out[i + 2] = r
        out[i + 3] = a
    return bytes(out)


# ------------------------------------------------------------ xcursor files

def read_geometry(path):
    """The (nominal, w, h, xhot, yhot, delay) of every image in a cursor file."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"Xcur":
        return None
    _, _, _, ntoc = struct.unpack_from("<4sIII", data, 0)
    out = []
    for i in range(ntoc):
        kind, _, pos = struct.unpack_from("<III", data, 16 + 12 * i)
        if kind != CHUNK_IMAGE:
            continue
        _, _, nominal, _, w, h, xh, yh, delay = struct.unpack_from(
            "<IIIIIIIII", data, pos)
        out.append((nominal, w, h, xh, yh, delay))
    return out


def write_xcursor(path, images):
    """images: list of (nominal, w, h, xhot, yhot, delay, pixels)."""
    ntoc = len(images)
    pos = 16 + 12 * ntoc
    toc = bytearray()
    body = bytearray()
    for nominal, w, h, xh, yh, delay, px in images:
        toc += struct.pack("<III", CHUNK_IMAGE, nominal, pos + len(body))
        body += struct.pack("<IIIIIIIII", 36, CHUNK_IMAGE, nominal, 1,
                            w, h, xh, yh, delay)
        body += px
    tmp = path + ".lucid-tmp"
    with open(tmp, "wb") as f:
        f.write(struct.pack("<4sIII", b"Xcur", 16, 0x10000, ntoc))
        f.write(toc)
        f.write(body)
    os.replace(tmp, path)


# --------------------------------------------------------------- the build

def frames_for(sdir, name):
    """The svg frames of one cursor, in order, as (bytes, had_shadow)."""
    d = os.path.join(sdir, name)
    if not os.path.isdir(d):
        return None
    meta = os.path.join(d, "metadata.json")
    names = []
    if os.path.isfile(meta):
        try:
            with open(meta, encoding="utf-8") as f:
                names = [e["filename"] for e in json.load(f)]
        except (OSError, ValueError, KeyError, TypeError):
            names = []
    if not names:
        names = sorted(n for n in os.listdir(d) if n.endswith(".svg"))
    frames = []
    for n in names:
        p = os.path.join(d, n)
        if not os.path.isfile(p):
            return None
        with open(p, "rb") as f:
            raw = f.read()
        stripped = strip_shadow(raw)
        frames.append((stripped.encode("utf-8") if stripped else raw,
                       stripped is not None))
    return frames


def capability(name):
    """Why this theme can or cannot be rebuilt without its shadow."""
    base = theme_dir(name)
    if not base:
        return False, "that theme is not installed"
    sdir = svg_dir(base)
    if not sdir:
        return False, "this theme ships only rendered images, with no vector sources to rebuild from"
    for entry in sorted(os.listdir(sdir)):
        d = os.path.join(sdir, entry)
        if not os.path.isdir(d):
            continue
        for n in sorted(os.listdir(d)):
            if not n.endswith(".svg"):
                continue
            with open(os.path.join(d, n), "rb") as f:
                if strip_shadow(f.read()):
                    return True, ""
            break
    return False, "this theme's pointer is drawn without a shadow already"


def build(name):
    if is_variant(name):
        name = name[:-len(SUFFIX)]
    ok, why = capability(name)
    if not ok:
        return {"ok": False, "error": why}
    base = theme_dir(name)
    sdir = svg_dir(base)
    src = os.path.join(base, "cursors")
    out = os.path.join(OUT_DIR, name + SUFFIX)
    dest = os.path.join(out, "cursors")
    staging = out + ".lucid-tmp"
    shutil.rmtree(staging, ignore_errors=True)
    os.makedirs(os.path.join(staging, "cursors"), exist_ok=True)

    built = skipped = 0
    for entry in sorted(os.listdir(src)):
        p = os.path.join(src, entry)
        target = os.path.join(staging, "cursors", entry)
        if os.path.islink(p):
            os.symlink(os.readlink(p), target)
            continue
        geom = read_geometry(p)
        frames = frames_for(sdir, entry)
        if not geom or not frames or len(geom) % len(frames):
            shutil.copy2(p, target)
            skipped += 1
            continue
        # the file holds every frame of one nominal size before the next
        images = []
        try:
            for i, (nominal, w, h, xh, yh, delay) in enumerate(geom):
                svg, _ = frames[i % len(frames)]
                images.append((nominal, w, h, xh, yh, delay,
                               render(svg, w, h)))
        except (RuntimeError, OSError) as e:
            shutil.rmtree(staging, ignore_errors=True)
            return {"ok": False, "error": str(e)}
        write_xcursor(target, images)
        built += 1

    label = read_name(base) or name
    with open(os.path.join(staging, "index.theme"), "w", encoding="utf-8") as f:
        f.write("[Icon Theme]\n"
                f"Name={label} (no shadow)\n"
                "Comment=Rebuilt by Lucid from the theme's vector sources\n"
                f"Inherits={name}\n")

    shutil.rmtree(out, ignore_errors=True)
    os.replace(staging, out)
    return {"ok": True, "theme": name + SUFFIX, "built": built,
            "copied": skipped}


def read_name(base):
    try:
        with open(os.path.join(base, "index.theme"), encoding="utf-8") as f:
            for line in f:
                if line.startswith("Name="):
                    return line.split("=", 1)[1].strip()
    except OSError:
        pass
    return None


def probe(names):
    if not names:
        seen = set()
        for d in ICON_DIRS:
            try:
                entries = os.listdir(d)
            except OSError:
                continue
            for n in entries:
                if not is_variant(n) and os.path.isdir(os.path.join(d, n, "cursors")):
                    seen.add(n)
        names = sorted(seen, key=str.lower)
    out = {}
    for n in names:
        n = n[:-len(SUFFIX)] if is_variant(n) else n
        ok, why = capability(n)
        out[n] = {"capable": ok, "reason": why,
                  "variant": n + SUFFIX,
                  "built": theme_dir(n + SUFFIX) is not None}
    return {"ok": True, "themes": out,
            "renderer": bool(have("rsvg-convert") or have("magick"))}


def main():
    args = sys.argv[1:]
    mode = args[0] if args else "probe"
    if mode == "probe":
        print(json.dumps(probe(args[1:])))
    elif mode == "build" and len(args) > 1:
        print(json.dumps(build(args[1])))
    else:
        print(json.dumps({"ok": False, "error": "usage: probe [theme...] | build <theme>"}))
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
