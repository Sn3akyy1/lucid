#!/usr/bin/env python3
# draws the sheet a lucid icon theme is made on: one cell per slot on the
# 48-unit grid (drawn at 2x), the keylines, and the tonal palette swatches the
# importer matches fills against. the colours come from lucid's brand seed,
# #d3bccc, nudged where two tones share a value so every swatch is a unique key. the cells come filled with gravity (tonal.py), the default
# set, so a theme can start as a remix of it; --blank leaves them empty
#   python3 support/icons/kit/build-sheet.py [--blank]
#       writes lucid-icon-sheet-{dark,light}.svg, or lucid-icon-sheet-blank-*.svg
import importlib.util
import math
import os
import sys
from xml.sax.saxutils import escape

HERE = os.path.dirname(os.path.abspath(__file__))
FORMAT = 1

sys.dont_write_bytecode = True
_spec = importlib.util.spec_from_file_location("tonal", os.path.join(HERE, "tonal.py"))
tonal = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tonal)
m3_shape = tonal.m3_shape

# the sheet's own surfaces and text: matugen color hex "#d3bccc", scheme-tonal-spot,
# lucid's brand seed
SCHEME = {
    "dark": {
        "primary": "#f1b3e6", "on_primary": "#4c1f49", "primary_container": "#653661",
        "on_primary_container": "#ffd7f5", "secondary": "#dabfd2", "on_secondary": "#3d2b3a",
        "secondary_container": "#554151", "on_secondary_container": "#f7daef", "tertiary": "#f5b8a7",
        "on_tertiary": "#4c261b", "tertiary_container": "#663c2f", "on_tertiary_container": "#ffdbd1",
        "error": "#ffb4ab", "on_error": "#690005", "error_container": "#93000a",
        "on_error_container": "#ffdad6", "surface": "#171216", "surface_container_lowest": "#120d11",
        "surface_container_low": "#201a1e", "surface_container": "#241e22", "surface_container_high": "#2f282d",
        "surface_container_highest": "#3a3338", "on_surface": "#ecdfe5", "on_surface_variant": "#d1c2cb",
        "outline": "#9a8d95", "outline_variant": "#4e444b",
    },
    "light": {
        "primary": "#804d7a", "on_primary": "#ffffff", "primary_container": "#ffd7f5",
        "on_primary_container": "#330832", "secondary": "#6d5869", "on_secondary": "#ffffff",
        "secondary_container": "#f7daef", "on_secondary_container": "#271624", "tertiary": "#825345",
        "on_tertiary": "#ffffff", "tertiary_container": "#ffdbd1", "on_tertiary_container": "#321208",
        "error": "#ba1a1a", "on_error": "#ffffff", "error_container": "#ffdad6",
        "on_error_container": "#410002", "surface": "#fff7f9", "surface_container_lowest": "#ffffff",
        "surface_container_low": "#fdf0f7", "surface_container": "#f7ebf1", "surface_container_high": "#f1e5eb",
        "surface_container_highest": "#ecdfe5", "on_surface": "#201a1e", "on_surface_variant": "#4e444b",
        "outline": "#80747c", "outline_variant": "#d1c2cb",
    },
}

# the tonal palettes an icon paints with: tonal spot on the same seed (primary at
# chroma 36, secondary 16, tertiary 60 degrees on at 24, neutral 6), the ramps the
# shell's own roles sit on. matugen's exported "palettes" are its louder core
# palettes and match none of those roles. a tone is the same in light and dark
# mode, so a folder looks like itself in both
TONES = [10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 99]
PALETTES = {
    "primary": ["#330832", "#4c1f49", "#653661", "#804d7a", "#9b6594", "#b77eae", "#d498ca", "#f1b3e6", "#ffd7f5", "#ffebf8", "#fffbff"],
    "secondary": ["#271624", "#3d2b3a", "#554151", "#6d5869", "#877082", "#a2899c", "#bea4b7", "#dabfd2", "#f7daef", "#ffebf8", "#fffbff"],
    "tertiary": ["#321208", "#4c261b", "#663c2f", "#825345", "#9d6b5c", "#ba8474", "#d79e8d", "#f5b8a7", "#ffdbd1", "#ffede8", "#fffbff"],
    "error": ["#410002", "#690005", "#93000a", "#ba1a1a", "#de3730", "#ff5449", "#ff897d", "#ffb4ab", "#ffdad6", "#ffedea", "#fffbff"],
    "neutral": ["#201a1e", "#352e33", "#4c454a", "#645c61", "#7e747a", "#988e94", "#b3a8ae", "#cfc3c9", "#ecdfe5", "#faedf4", "#fffbff"],
}

# slot id, name, optional; kinds pick the keyline a cell shows
SECTIONS = [
    ("folders", "Folders", "landscape", "landscape keyline 40 × 32", [
        ("folder", "Folder", 0), ("folder-home", "Home", 0), ("folder-desktop", "Desktop", 0),
        ("folder-documents", "Documents", 0), ("folder-download", "Downloads", 0),
        ("folder-music", "Music", 0), ("folder-pictures", "Pictures", 0), ("folder-videos", "Videos", 0),
        ("folder-open", "Open folder", 1), ("folder-templates", "Templates", 1),
        ("folder-public", "Public", 1), ("folder-remote", "Network folder", 1),
    ]),
    ("files", "Files", "portrait", "portrait keyline 32 × 40", [
        ("file", "File", 0), ("text", "Text", 0), ("document", "Document", 0), ("pdf", "PDF", 0),
        ("spreadsheet", "Spreadsheet", 0), ("presentation", "Slides", 0), ("image", "Image", 0),
        ("video", "Video", 0), ("audio", "Audio", 0), ("archive", "Archive", 0), ("code", "Code", 0),
        ("script", "Script", 0), ("font", "Font", 0), ("disk-image", "Disk image", 1),
        ("package", "Package", 1), ("ebook", "E-book", 1),
    ]),
    ("places", "Places & devices", "square", "square 36 · circle 40", [
        ("trash", "Trash", 0), ("trash-full", "Trash, full", 0), ("recent", "Recent", 0),
        ("starred", "Starred", 0), ("computer", "Computer", 0), ("drive", "Drive", 0),
        ("drive-usb", "USB drive", 0), ("phone", "Phone", 0), ("network", "Network", 0),
        ("drive-optical", "Disc", 1), ("cloud", "Cloud", 1),
    ]),
    ("apps", "Apps", "glyph", "tile 44 · a picture per app, the plate for the rest", [
        ("app-plate", "App plate", 0), ("app-files", "Files", 0), ("app-terminal", "Terminal", 0),
        ("app-browser", "Browser", 0), ("app-settings", "Settings", 0),
        ("app-editor", "Text editor", 1), ("app-code", "Code editor", 1), ("app-music", "Music", 1),
        ("app-video", "Video player", 1), ("app-photos", "Photos", 1), ("app-mail", "Mail", 1),
        ("app-chat", "Chat", 1), ("app-calendar", "Calendar", 1), ("app-calculator", "Calculator", 1),
        ("app-monitor", "System monitor", 1), ("app-software", "Software", 1), ("app-games", "Games", 1),
        ("custom-1", "Your app", 2), ("custom-2", "Your app", 2), ("custom-3", "Your app", 2),
    ]),
    ("badges", "Badges", "badge", "circle 40 · shown at 16 on the corner", [
        ("badge-link", "Link", 0), ("badge-locked", "Read-only", 0),
        ("badge-shared", "Shared", 1), ("badge-synced", "Synced", 1),
    ]),
]

RULES = [
    ("Paint with the swatches", ["Fills are matched by exact colour. Any other",
                                 "colour needs its own line in theme.json."]),
    ("Depth from tone, not lines", ["No outlines. A gradient is fine when both its",
                                    "ends are swatches, lit from the top like the rest."]),
    ("Outline your strokes", ["Inkscape: Path, Stroke to Path. Figma: Outline",
                              "stroke. Lucid only reads filled shapes."]),
    ("Name what moves", ["Group a piece and name it, like front or emblem,",
                         "and it can animate on hover."]),
    ("Stay inside the cell", ["Everything in a cell belongs to that icon. Dashed",
                              "cells are optional; empty ones use Lucid's own."]),
    ("Round the corners", ["Nothing sharper than 2 units. Soft corners are",
                           "what makes a set feel like Lucid."]),
]

SANS = "'Google Sans Flex','Google Sans',Roboto,system-ui,sans-serif"
MONO = "'Noto Sans Mono','JetBrains Mono',ui-monospace,monospace"
ROUND = "font-variation-settings:'ROND' 100"

W = 1440
M = 56
CW = W - 2 * M
CARD_W, CARD_H, GAP, PER_ROW = 152, 184, 16, 8


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def unique(h, taken):
    if h not in taken:
        return h
    r, g, b = rgb(h)
    for d in range(1, 9):
        for c in ((r, g, b + d), (r, g, b - d), (r, g + d, b), (r, g - d, b), (r + d, g, b), (r - d, g, b)):
            if all(0 <= v <= 255 for v in c) and "#%02x%02x%02x" % c not in taken:
                return "#%02x%02x%02x" % c
    raise ValueError(h)


def all_keys():
    return ["%s-%d" % (p, t) for p in PALETTES for t in TONES]


# one key per tone, never shared: palettes meet at the top, where 99 is white in all
def make_keys():
    taken = set()
    keys = {}
    for p, hexes in PALETTES.items():
        for t, h in zip(TONES, hexes):
            k = unique(h, taken)
            taken.add(k)
            keys["%s-%d" % (p, t)] = k
    return keys, taken


KEYS, TAKEN = make_keys()


def n(v):
    s = ("%.2f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def attrs(kw):
    out = []
    for k, v in kw.items():
        if v is None:
            continue
        k = k.rstrip("_").replace("__", ":").replace("_", "-")
        if isinstance(v, float):
            v = n(v)
        out.append('%s="%s"' % (k, escape(str(v), {'"': "&quot;"})))
    return " ".join(out)


def el(tag, **kw):
    return "<%s %s/>" % (tag, attrs(kw))


def rect(x, y, w, h, r=0, **kw):
    return el("rect", x=float(x), y=float(y), width=float(w), height=float(h), rx=float(r) if r else None, **kw)


def corners(x, y, w, h, tl, tr, br, bl):
    return ("M%s %sH%sA%s %s 0 0 1 %s %sV%sA%s %s 0 0 1 %s %sH%sA%s %s 0 0 1 %s %sV%sA%s %s 0 0 1 %s %sZ" % (
        n(x + tl), n(y), n(x + w - tr), n(tr), n(tr), n(x + w), n(y + tr), n(y + h - br), n(br), n(br),
        n(x + w - br), n(y + h), n(x + bl), n(bl), n(bl), n(x), n(y + h - bl), n(y + tl), n(tl), n(tl),
        n(x + tl), n(y)))


def text(x, y, s, size, fill, weight=None, mono=False, anchor=None, rond=False, ls=None, opacity=None, **kw):
    return "<text %s>%s</text>" % (attrs(dict(
        x=float(x), y=float(y), font_family=MONO if mono else SANS, font_size=float(size),
        font_weight=weight, fill=fill, text_anchor=anchor, letter_spacing=ls, opacity=opacity,
        style=ROUND if rond else None, **kw)), s if s.startswith("<tspan") else escape(s))


# the lucida mark, as lucidprefs/LucidaMark.qml rests: ring, sparkle, companion
def mark(x, y, size, ring, star):
    def pt(a):
        return 12 + 7.4 * math.cos(math.radians(a)), 12 - 7.4 * math.sin(math.radians(a))

    (x0, y0), (x1, y1) = pt(58), pt(340)
    s, k, j = 4.6, 4.6 * 0.3, 4.6 * 0.13

    def p(dx, dy):
        return "%s,%s" % (n(12 + dx), n(12 + dy))

    spark = "M%s C%s %s %s C%s %s %s C%s %s %s C%s %s %s Z" % (
        p(0, -s), p(j, -k), p(k, -j), p(s, 0), p(k, j), p(j, k), p(0, s),
        p(-j, k), p(-k, j), p(-s, 0), p(-k, -j), p(-j, -k), p(0, -s))
    return ('<g transform="translate(%s %s) scale(%s)">' % (n(x), n(y), n(size / 24)) +
            el("path", d="M%s,%s A7.4,7.4 0 1 0 %s,%s" % (n(x0), n(y0), n(x1), n(y1)),
               fill="none", stroke=ring, stroke_width=3, stroke_linecap="round") +
            el("path", d=spark, fill=star) +
            el("circle", cx=21, cy=9.4, r=1, fill=ring) + "</g>")


class Sheet:
    def __init__(self, mode, blank=False):
        self.mode = mode
        self.radii = tonal.RAD
        self.blank = blank
        self.keys = KEYS
        sc = SCHEME[mode]

        # sheet colours are never keys, so a stray guide copied into a cell is ignored
        def c(role):
            return unique(sc[role], TAKEN)

        self.page = c("surface")
        self.panel = c("surface_container_low")
        self.card = c("surface_container_low")
        self.well = c("surface_container_lowest")
        self.field = c("surface_container_high")
        self.ink = c("on_surface")
        self.muted = c("on_surface_variant")
        self.faint = c("outline")
        self.line = c("outline_variant")
        self.accent = c("primary")
        self.second = c("secondary")
        self.third = c("tertiary")
        self.badge = c("primary_container")
        self.on_badge = c("on_primary_container")
        # the tile an app glyph lands on, previewed under every app cell
        self.tile_base = unique(PALETTES["neutral"][TONES.index(80)], TAKEN)
        self.tile_face = unique(PALETTES["neutral"][TONES.index(90)], TAKEN)
        self.guides = []
        self.icons = []
        self.meta = []
        self.defs = []

    def number(self, x, y, label, shape, size=44):
        g = self.guides
        g.append(el("path", d=m3_shape(shape, size, x, y, self.radii), fill=self.badge))
        g.append(text(x + size / 2, y + size / 2 + 5.5, label, 15, self.on_badge, weight=600,
                      anchor="middle", rond=True))

    def header(self):
        g = self.guides
        g.append(mark(M, 52, 40, self.accent, self.ink))
        g.append(text(M + 52, 80, '<tspan>Lucid</tspan><tspan fill="%s" font-weight="400">  ·  Icon kit</tspan>' % self.muted,
                      19, self.ink, weight=500, rond=True))
        g.append(text(W - M, 79, "format %d · 48-unit grid · cells at 2×" % FORMAT, 13, self.faint,
                      mono=True, anchor="end"))
        g.append(text(M, 214, "Icon theme sheet", 76, self.ink, weight=500, rond=True, ls=-1.5))
        intro = ["Draw one icon per cell, painting with the swatches below.",
                 "Lucid recolours them from your wallpaper and animates",
                 "the parts you name."] if self.blank else [
                 "One icon per cell, painted with the swatches below. Lucid",
                 "recolours them from your wallpaper and animates the parts",
                 "you name. This copy starts as Gravity, the default set."]
        for i, line in enumerate(intro):
            g.append(text(M, 262 + i * 28, line, 18, self.muted))
        meta = ("Untitled", "Your name", "CC-BY-4.0") if self.blank else ("Gravity", "Lucid", "Apache-2.0")
        fields = [("Theme name", meta[0], "meta-name"), ("Author", meta[1], "meta-author"),
                  ("Version", "1.0.0", "meta-version"), ("Licence", meta[2], "meta-licence")]
        for i, (label, value, fid) in enumerate(fields):
            fx, fy = M + (i % 2) * 308, 356 + (i // 2) * 76
            g.append(rect(fx, fy, 292, 60, 18, fill=self.field))
            g.append(text(fx + 20, fy + 23, label, 12.5, self.muted))
            self.meta.append(text(fx + 20, fy + 46, value, 17, self.ink, id=fid))
        g.append(text(M, 540, "When you're done", 16, self.ink, weight=500))
        for i, line in enumerate(["Save as plain SVG and drop it into Icon Studio on the Lucid website.",
                                  "It checks every cell, previews the set in a few palettes and packs",
                                  "the .lucidicons file you share or install."]):
            g.append(text(M, 566 + i * 24, line, 15, self.muted))

    def grid_panel(self):
        g = self.guides
        px, py, pw, ph = 688, 128, 696, 536
        g.append(rect(px, py, pw, ph, 36, fill=self.panel))
        self.number(px + 32, py + 32, "01", "cookie4")
        g.append(text(px + 92, py + 63, "Grid", 26, self.ink, weight=500, rond=True))
        g.append(text(px + 92, py + 89, "48 units, 4 of them padding. Keylines keep sizes even.", 15, self.muted))
        k = 8
        gx, gy, S = px + 32, py + 120, 48 * k
        self.defs.append('<clipPath id="grid-clip">%s</clipPath>' % rect(gx, gy, S, S, 20))
        g.append(rect(gx, gy, S, S, 20, fill=self.well))
        g.append(el("path", d=corners(gx, gy, S, S, 20, 20, 20, 20) + corners(gx + 4 * k, gy + 4 * k, 40 * k, 40 * k, 0, 0, 0, 0),
                    fill=self.accent, fill_opacity=0.1, fill_rule="evenodd"))
        lines = []
        for u in range(1, 48):
            major = u % 4 == 0
            a = 0.75 if major else 0.25
            w = 1 if major else 0.5
            lines.append(el("line", x1=float(gx + u * k), y1=float(gy), x2=float(gx + u * k), y2=float(gy + S),
                            stroke=self.line, stroke_opacity=a, stroke_width=w))
            lines.append(el("line", x1=float(gx), y1=float(gy + u * k), x2=float(gx + S), y2=float(gy + u * k),
                            stroke=self.line, stroke_opacity=a, stroke_width=w))
        lines.append(el("line", x1=float(gx), y1=float(gy), x2=float(gx + S), y2=float(gy + S), stroke=self.line, stroke_width=1))
        lines.append(el("line", x1=float(gx + S), y1=float(gy), x2=float(gx), y2=float(gy + S), stroke=self.line, stroke_width=1))
        g.append('<g clip-path="url(#grid-clip)">%s</g>' % "".join(lines))
        key = dict(fill="none", stroke=self.accent, stroke_width=1.5)
        g.append(el("circle", cx=float(gx + 24 * k), cy=float(gy + 24 * k), r=float(20 * k), **key))
        g.append(rect(gx + 6 * k, gy + 6 * k, 36 * k, 36 * k, 6 * k, **key))
        g.append(rect(gx + 8 * k, gy + 4 * k, 32 * k, 40 * k, 5 * k, **key))
        g.append(rect(gx + 4 * k, gy + 8 * k, 40 * k, 32 * k, 5 * k, **key))
        g.append(el("circle", cx=float(gx + 24 * k), cy=float(gy + 24 * k), r=float(22 * k), fill="none",
                    stroke=self.second, stroke_width=1.5, stroke_dasharray="0.1 5", stroke_linecap="round"))
        g.append(rect(gx + 30 * k, gy + 30 * k, 16 * k, 16 * k, 5 * k, fill="none", stroke=self.third,
                      stroke_width=1.5, stroke_dasharray="6 4"))
        lx = gx + S + 32
        legend = [("circle", "Circle", "40"), ("square", "Square", "36 × 36"),
                  ("portrait", "Portrait · files", "32 × 40"), ("landscape", "Landscape · folders", "40 × 32"),
                  ("plate", "App plate", "44"), ("badge", "Badge", "16, bottom right"), ("padding", "Padding", "4")]
        for i, (kind, label, dims) in enumerate(legend):
            ry = gy + 14 + i * 54
            g.append(self.mini(kind, lx, ry))
            g.append(text(lx + 36, ry + 9, label, 15, self.ink))
            g.append(text(lx + 36, ry + 28, dims, 12.5, self.muted, mono=True))

    def mini(self, kind, x, y):
        key = dict(fill="none", stroke=self.accent, stroke_width=1.5)
        cx, cy = x + 11, y + 11
        if kind == "circle":
            return el("circle", cx=float(cx), cy=float(cy), r=10.0, **key)
        if kind == "square":
            return rect(x + 2, y + 2, 18, 18, 4, **key)
        if kind == "portrait":
            return rect(x + 4, y + 1, 14, 20, 3.5, **key)
        if kind == "landscape":
            return rect(x + 1, y + 4, 20, 14, 3.5, **key)
        if kind == "plate":
            return el("circle", cx=float(cx), cy=float(cy), r=10.0, fill="none", stroke=self.second,
                      stroke_width=1.5, stroke_dasharray="0.1 3.6", stroke_linecap="round")
        if kind == "badge":
            return rect(x + 3, y + 3, 16, 16, 5, fill="none", stroke=self.third, stroke_width=1.5, stroke_dasharray="4 3")
        return el("path", d=corners(x, y, 22, 22, 5, 5, 5, 5) + corners(x + 4, y + 4, 14, 14, 0, 0, 0, 0),
                  fill=self.accent, fill_opacity=0.22, fill_rule="evenodd")

    def colours_panel(self, y):
        g = self.guides
        g.append(rect(M, y, CW, 488, 36, fill=self.panel))
        self.number(M + 32, y + 32, "02", "clover4")
        g.append(text(M + 92, y + 63, "Colours", 26, self.ink, weight=500, rond=True))
        g.append(text(M + 92, y + 89, "Paint only with these tones. Each is a key that Lucid swaps for the same tone of the wallpaper's palette.",
                      15, self.muted))
        sw, gap = 98, 3
        for ri, (pal, hexes) in enumerate(PALETTES.items()):
            ry = y + 124 + ri * 66
            g.append(text(M + 32, ry + 25, pal.capitalize(), 15, self.ink, weight=500))
            g.append(text(M + 32, ry + 44, "%s-10 … 99" % pal, 11.5, self.muted, mono=True))
            for ti, tone in enumerate(TONES):
                sx = M + 188 + ti * (sw + gap)
                left = 18 if ti == 0 else 4
                right = 18 if ti == len(TONES) - 1 else 4
                key = "%s-%d" % (pal, tone)
                fill = self.keys[key]
                ink = unique(hexes[TONES.index(10)] if tone >= 60 else hexes[TONES.index(95)], TAKEN)
                g.append('<g class="lucid-key" data-key="%s">' % key)
                g.append(el("path", d=corners(sx, ry, sw, 56, left, right, right, left), fill=fill))
                g.append(text(sx + 12, ry + 23, str(tone), 14, ink, weight=500))
                g.append(text(sx + 12, ry + 43, fill, 11, ink, mono=True, opacity=0.8))
                g.append("</g>")
        g.append(text(M + 32, y + 460, "A tone stays the same in light and dark mode, so an icon looks like itself in both; the light sheet shows these same keys on light surfaces.",
                      14.5, self.muted))

    def rules_panel(self, y):
        g = self.guides
        g.append(rect(M, y, CW, 318, 36, fill=self.panel))
        self.number(M + 32, y + 32, "03", "sunny")
        g.append(text(M + 92, y + 63, "Rules", 26, self.ink, weight=500, rond=True))
        g.append(text(M + 92, y + 89, "What Lucid checks when it imports a sheet.", 15, self.muted))
        for i, (title, detail) in enumerate(RULES):
            rx = M + 32 + (i % 3) * 432
            ry = y + 134 + (i // 3) * 104
            g.append(text(rx, ry, str(i + 1), 14, self.accent, mono=True, weight=600))
            g.append(text(rx + 28, ry, title, 17, self.ink, weight=500))
            for j, line in enumerate(detail):
                g.append(text(rx + 28, ry + 26 + j * 22, line, 14.5, self.muted))

    def section(self, y, index, sid, title, kind, meta, slots, shape):
        g = self.guides
        self.number(M, y, "%02d" % index, shape)
        g.append(text(M + 60, y + 31, title, 26, self.ink, weight=500, rond=True))
        opt = sum(1 for s in slots if s[2] == 1)
        if sid != "apps":
            count = "%d cells, %d optional" % (len(slots), opt)
        else:
            count = "duplicate %s for any app id" % ("“Your app”" if self.blank else "a brand cell")
        g.append(text(W - M, y + 29, "%s  ·  %s" % (meta, count), 13, self.faint, mono=True, anchor="end"))
        self.icons.append('<g id="icons-%s" inkscape:groupmode="layer" inkscape:label="%s">' % (sid, escape(title)))
        for i, (slot, name, optional) in enumerate(slots):
            cx = M + (i % PER_ROW) * (CARD_W + GAP)
            cy = y + 72 + (i // PER_ROW) * (CARD_H + GAP)
            self.cell(cx, cy, slot, name, optional, kind)
        self.icons.append("</g>")
        rows = (len(slots) + PER_ROW - 1) // PER_ROW
        return y + 72 + rows * (CARD_H + GAP) - GAP

    # the slot's own art, in the 48-unit space its layer is already scaled into
    def icon(self, slot):
        if self.blank:
            return ""
        defs, body = tonal.render(tonal.draw(slot), lambda key: self.keys[key], slot)
        self.defs += defs
        return "".join('<g id="%s.%s" inkscape:label="%s">%s</g>' % (slot, part, part, path) for part, path in body)

    def cell(self, x, y, slot, name, optional, kind):
        g = self.guides
        fx, fy = x + 28, y + 24
        app_id = "app-id"
        if optional == 2 and not self.blank and slot in tonal.BRAND_CELLS:
            name, app_id = tonal.BRAND_CELLS[slot][1:]
        g.append('<g id="cell-%s" class="lucid-cell" data-slot="%s">' % (slot, "" if optional == 2 else slot))
        if optional:
            g.append(rect(x + 0.75, y + 0.75, CARD_W - 1.5, CARD_H - 1.5, 27.25, fill="none", stroke=self.line,
                          stroke_width=1.5, stroke_dasharray="6 5"))
        else:
            g.append(rect(x, y, CARD_W, CARD_H, 28, fill=self.card))
        g.append(rect(fx, fy, 96, 96, 16, fill=self.well if optional else self.page, class_="lucid-frame"))
        art = self.icon(slot)
        lines = []
        for u in range(4, 48, 4):
            lines.append(el("line", x1=float(fx + u * 2), y1=float(fy + 8), x2=float(fx + u * 2), y2=float(fy + 88)))
            lines.append(el("line", x1=float(fx + 8), y1=float(fy + u * 2), x2=float(fx + 88), y2=float(fy + u * 2)))
        grid = '<g stroke="%s" stroke-opacity="%s" stroke-width="0.6">%s</g>' % (self.line, "0.3" if art else "0.45", "".join(lines))
        # under art the grid sits below everything and the keylines step aside,
        # so nothing reads as an outline; an empty cell keeps them all on top
        if art:
            g.append(grid)
        if kind == "glyph" and slot != "app-plate":
            g.append(el("path", d=m3_shape("square", 88, fx + 4, fy + 6.4, self.radii), fill=self.tile_base))
            g.append(el("path", d=m3_shape("square", 88, fx + 4, fy + 4, self.radii), fill=self.tile_face))
        if not art:
            g.append(grid)
            key = dict(fill="none", stroke=self.accent, stroke_opacity=0.7, stroke_width=1)
            if kind == "landscape":
                g.append(rect(fx + 8, fy + 16, 80, 64, 10, **key))
            elif kind == "portrait":
                g.append(rect(fx + 16, fy + 8, 64, 80, 10, **key))
            elif kind == "square":
                g.append(rect(fx + 12, fy + 12, 72, 72, 12, **key))
                g.append(el("circle", cx=float(fx + 48), cy=float(fy + 48), r=40.0, **key))
            elif kind == "badge":
                g.append(el("circle", cx=float(fx + 48), cy=float(fy + 48), r=40.0, **key))
            elif slot == "app-plate":
                g.append(el("circle", cx=float(fx + 48), cy=float(fy + 48), r=44.0, **key))
                g.append(rect(fx + 4, fy + 4, 88, 88, 26, **key))
            else:
                g.append(rect(fx + 24, fy + 24, 48, 48, 8, fill="none", stroke=self.on_badge, stroke_opacity=0.6,
                              stroke_width=1, stroke_dasharray="4 3"))
        g.append(text(x + CARD_W / 2, y + 150, name, 14.5, self.ink, weight=500, anchor="middle"))
        if optional == 2:
            self.meta.append(text(x + CARD_W / 2, y + 169, app_id, 11.5, self.muted, mono=True, anchor="middle",
                                  id="%s-id" % slot))
        else:
            g.append(text(x + CARD_W / 2, y + 169, slot, 11.5, self.muted, mono=True, anchor="middle"))
        g.append("</g>")
        self.icons.append('<g id="%s" inkscape:groupmode="layer" inkscape:label="%s" transform="translate(%s %s) scale(2)"%s'
                          % (slot, slot, n(fx), n(fy), ">%s</g>" % art if art else "/>"))

    def build(self):
        self.header()
        self.grid_panel()
        self.colours_panel(704)
        self.rules_panel(1232)
        y = 1622
        shapes = ["cookie9", "flower", "puffy", "softBurst", "cookie12"]
        for i, (sid, title, kind, meta, slots) in enumerate(SECTIONS):
            y = self.section(y, i + 4, sid, title, kind, meta, slots, shapes[i]) + 72
        foot = y + 8
        self.guides.append(text(M, foot, "Lucid icon kit · sheet format %d · October 2026" % FORMAT, 12.5, self.faint, mono=True))
        self.guides.append(text(W - M, foot, "sn3akyy1.github.io/lucid", 12.5, self.faint, mono=True, anchor="end"))
        H = foot + 56
        keys = " ".join("%s=%s" % (k_, self.keys[k_]) for k_ in all_keys())
        out = [
            '<?xml version="1.0" encoding="UTF-8"?>',
            "<!--",
            "  lucid icon theme sheet, format %d, %s scheme. made by support/icons/kit/build-sheet.py" % (FORMAT, self.mode),
            "  cells:  #guides .lucid-cell[data-slot] holds a .lucid-frame, the 48-unit box (96 px, so 2 px a unit)",
            "  icons:  draw in the #icons/<slot> layer (already in units), or anywhere inside a frame",
            "  keys:   fills are matched to tones by exact hex, the same in every sheet: " + keys,
            "  meta:   #meta-name #meta-author #meta-version #meta-licence; custom cells read #custom-N-id",
            "-->",
            '<svg xmlns="http://www.w3.org/2000/svg" xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" '
            'xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd" width="%d" height="%d" viewBox="0 0 %d %d" '
            'data-lucid-sheet="%d" data-scheme="%s">' % (W, H, W, H, FORMAT, self.mode),
            "<title>Lucid icon theme sheet</title>",
            '<sodipodi:namedview pagecolor="%s" inkscape:pagecheckerboard="false" inkscape:deskcolor="%s" showgrid="false">'
            '<inkscape:grid id="units" type="xygrid" units="px" spacingx="2" spacingy="2" empspacing="4" '
            'visible="false" enabled="true"/></sodipodi:namedview>' % (self.page, self.well),
            "<defs>%s</defs>" % "".join(self.defs),
            '<g id="guides" inkscape:groupmode="layer" inkscape:label="Guides (locked)" sodipodi:insensitive="true">',
            rect(0, 0, W, H, 0, fill=self.page),
        ]
        out += self.guides
        out.append("</g>")
        out.append('<g id="icons" inkscape:groupmode="layer" inkscape:label="Icons">')
        out += self.icons
        out.append("</g>")
        out.append('<g id="meta" inkscape:groupmode="layer" inkscape:label="Theme info">')
        out += self.meta
        out.append("</g>")
        out.append("</svg>")
        return "\n".join(out) + "\n"


def main():
    blank = "--blank" in sys.argv[1:]
    for mode in ("dark", "light"):
        path = os.path.join(HERE, "lucid-icon-sheet-%s%s.svg" % ("blank-" if blank else "", mode))
        with open(path, "w") as f:
            f.write(Sheet(mode, blank).build())
        print(path)


if __name__ == "__main__":
    sys.exit(main())
