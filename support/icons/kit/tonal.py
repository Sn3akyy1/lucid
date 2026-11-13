# gravity, the default icon set, as path data on the 48-unit grid. the shapes
# are drawn here; every pictogram on them is a material symbol (rounded) and the
# brand glyphs come from simple icons (cc0). no outlines: depth comes from tone
# alone, a lighter lip along a top edge and a darker base under a raised shape.
# colours are tonal palette keys like "primary-70", the same in light and dark
import importlib.util
import math
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
RADII = os.path.join(ROOT, "lucidui", "ShapeRadii.js")
BRANDS = os.path.expanduser("~/.cache/lucid/simple-icons")
BRAND_URL = "https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/{n}.svg"


def load_icons():
    # no __pycache__ left beside it in the repo
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("build_icons", os.path.join(HERE, "..", "build-icons.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ICONS = load_icons()


def n(v):
    s = ("%.2f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


# a symbol's path moved onto the 48 grid: its 24-unit box becomes size units at ox, oy
def symbol(name, ox, oy, size, filled=True, bold=False):
    variant = ("_wght700" if bold else "") + ("fill1" if bold and filled else "_fill1" if filled else "")
    got = ICONS.fetch(name, variant) or ICONS.fetch(name, "_fill1" if filled else "") or ICONS.fetch(name, "")
    if got is None:
        raise SystemExit("material symbol not found: " + name)
    return placed(*got, ox, oy, size)


def placed(d, box, ox, oy, size):
    k = size / box[2]
    return ICONS.despike(ICONS.convert(d, [box[0] - ox / k, box[1] - oy / k, 24.0 / k]))


def brand(name, ox, oy, size):
    os.makedirs(BRANDS, exist_ok=True)
    path = os.path.join(BRANDS, name + ".svg")
    if not os.path.exists(path):
        with urllib.request.urlopen(BRAND_URL.format(n=name), timeout=30) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    svg = open(path, encoding="utf-8").read()
    d = " ".join(re.findall(r'<path[^>]*\sd="([^"]+)"', svg))
    vb = re.search(r'viewBox="([^"]+)"', svg)
    box = [float(x) for x in vb.group(1).replace(",", " ").split()] if vb else [0, 0, 24, 24]
    return placed(d, box, ox, oy, size)


def load_radii():
    s = open(RADII).read()
    body = s[s.index("var r = ") + len("var r = "):].strip().rstrip(";")
    return {k: [float(x) for x in v.split(",")] for k, v in re.findall(r'"(\w+)":\[([^\]]*)\]', body)}


RAD = load_radii()


# one of androidx's m3 shapes through its own samples, as lucidui/Shapes.js draws it
def m3_shape(name, size, x, y, radii=None):
    r = (radii or RAD)[name]
    count = len(r)
    c = size / 2
    pts = [(x + c + c * r[i] * math.cos(i / count * 2 * math.pi), y + c + c * r[i] * math.sin(i / count * 2 * math.pi))
           for i in range(count)]
    d = "M%s %s" % (n(pts[0][0]), n(pts[0][1]))
    for j in range(count):
        p0, p1, p2, p3 = pts[j - 1], pts[j], pts[(j + 1) % count], pts[(j + 2) % count]
        d += "C%s %s %s %s %s %s" % (
            n(p1[0] + (p2[0] - p0[0]) / 6), n(p1[1] + (p2[1] - p0[1]) / 6),
            n(p2[0] - (p3[0] - p1[0]) / 6), n(p2[1] - (p3[1] - p1[1]) / 6), n(p2[0]), n(p2[1]))
    return d + "Z"


# a polygon whose every corner is a true arc of its own radius. every shape here
# winds clockwise on screen, so overlapping parts of one path add up instead of
# cancelling into holes; only a hole winds the other way
def rpoly(pts, radii):
    count = len(pts)
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * count
    if sum(pts[i][0] * pts[(i + 1) % count][1] - pts[(i + 1) % count][0] * pts[i][1] for i in range(count)) < 0:
        pts, radii = pts[::-1], list(radii)[::-1]
    corners = []
    for i in range(count):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % count]
        v1 = (p0[0] - p1[0], p0[1] - p1[1])
        v2 = (p2[0] - p1[0], p2[1] - p1[1])
        l1, l2 = math.hypot(*v1), math.hypot(*v2)
        u1, u2 = (v1[0] / l1, v1[1] / l1), (v2[0] / l2, v2[1] / l2)
        ang = math.acos(max(-1.0, min(1.0, u1[0] * u2[0] + u1[1] * u2[1])))
        r = radii[i]
        if r <= 0 or ang < 1e-6 or abs(ang - math.pi) < 1e-6:
            corners.append((p1, p1, 0, 0))
            continue
        t = min(r / math.tan(ang / 2), l1 / 2, l2 / 2)
        cross = (p1[0] - p0[0]) * (p2[1] - p1[1]) - (p1[1] - p0[1]) * (p2[0] - p1[0])
        corners.append(((p1[0] + u1[0] * t, p1[1] + u1[1] * t), (p1[0] + u2[0] * t, p1[1] + u2[1] * t),
                        t * math.tan(ang / 2), 1 if cross > 0 else 0))
    d = "M%s %s" % (n(corners[0][0][0]), n(corners[0][0][1]))
    for i, (a, b, re_, sw) in enumerate(corners):
        if i:
            d += "L%s %s" % (n(a[0]), n(a[1]))
        if re_ > 0:
            d += "A%s %s 0 0 %d %s %s" % (n(re_), n(re_), sw, n(b[0]), n(b[1]))
    return d + "Z"


def rr(x, y, w, h, r, tr=None, br=None, bl=None):
    return rpoly([(x, y), (x + w, y), (x + w, y + h), (x, y + h)],
                 [r, r if tr is None else tr, r if br is None else br, r if bl is None else bl])


def circle(cx, cy, r, hole=False):
    s = 0 if hole else 1
    return "M%s %sa%s %s 0 1 %d %s 0a%s %s 0 1 %d %s 0Z" % (n(cx - r), n(cy), n(r), n(r), s, n(2 * r), n(r), n(r), s, n(-2 * r))


def ellipse(cx, cy, rx, ry, hole=False):
    s = 0 if hole else 1
    return "M%s %sa%s %s 0 1 %d %s 0a%s %s 0 1 %d %s 0Z" % (n(cx - rx), n(cy), n(rx), n(ry), s, n(2 * rx), n(rx), n(ry), s, n(-2 * rx))


def ring(cx, cy, ro, ri):
    return circle(cx, cy, ro) + circle(cx, cy, ri, hole=True)


# a capsule from one point to another, w across
def pill(x1, y1, x2, y2, w):
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy) or 1e-6
    nx, ny = -dy / length * w / 2, dx / length * w / 2
    r = w / 2
    return "M%s %sL%s %sA%s %s 0 0 1 %s %sL%s %sA%s %s 0 0 1 %s %sZ" % (
        n(x1 - nx), n(y1 - ny), n(x2 - nx), n(y2 - ny), n(r), n(r), n(x2 + nx), n(y2 + ny),
        n(x1 + nx), n(y1 + ny), n(r), n(r), n(x1 - nx), n(y1 - ny))


def polar(cx, cy, r, deg):
    return cx + r * math.cos(math.radians(deg)), cy + r * math.sin(math.radians(deg))


def rotate(pts, cx, cy, deg):
    c, s_ = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [(cx + (x - cx) * c - (y - cy) * s_, cy + (x - cx) * s_ + (y - cy) * c) for x, y in pts]


def box(x, y, w, h):
    return [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]


# a pie slice, clockwise from a0 to a1 degrees (0 is east, 90 is south)
def wedge(cx, cy, r, a0, a1):
    x0, y0 = polar(cx, cy, r, a0)
    x1, y1 = polar(cx, cy, r, a1)
    return "M%s %sL%s %sA%s %s 0 %d 1 %s %sZ" % (n(cx), n(cy), n(x0), n(y0), n(r), n(r), 1 if a1 - a0 > 180 else 0, n(x1), n(y1))


# a band of a ring, clockwise from a0 to a1
def sector(cx, cy, ro, ri, a0, a1):
    large = 1 if a1 - a0 > 180 else 0
    o0, o1, i1, i0 = polar(cx, cy, ro, a0), polar(cx, cy, ro, a1), polar(cx, cy, ri, a1), polar(cx, cy, ri, a0)
    return "M%s %sA%s %s 0 %d 1 %s %sL%s %sA%s %s 0 %d 0 %s %sZ" % (
        n(o0[0]), n(o0[1]), n(ro), n(ro), large, n(o1[0]), n(o1[1]), n(i1[0]), n(i1[1]), n(ri), n(ri), large, n(i0[0]), n(i0[1]))


# a drawing of this set, scaled by s about the grid's origin and moved to ox, oy
def shrink(d, s, ox, oy):
    return placed(d, [0, 0, 48], ox, oy, 48 * s)


# a fill is a swatch key, or a gentle top-to-bottom gradient between two of them:
# lit from above like the themes this set sits beside, and still made only of keys
def grad(top, bottom, y1, y2, x1=24, x2=24):
    return ("lin", x1, y1, x2, y2, [(0, top), (1, bottom)])


def keys_of(fill):
    return [fill] if isinstance(fill, str) else [key for _, key in fill[5]]


# svg for a list of parts: (defs, body). a part is (name, path, fill[, opacity]);
# gradients use the part's own 48-unit space, so they travel with the layer
def render(parts, hexof, prefix):
    defs, body = [], []
    for part in parts:
        name, d, fill = part[:3]
        opacity = part[3] if len(part) > 3 else None
        if isinstance(fill, str):
            paint = hexof(fill)
        else:
            gid = "g-%s-%s" % (prefix, name)
            _, x1, y1, x2, y2, stops = fill
            defs.append('<linearGradient id="%s" gradientUnits="userSpaceOnUse" x1="%s" y1="%s" x2="%s" y2="%s">%s</linearGradient>' % (
                gid, n(x1), n(y1), n(x2), n(y2), "".join('<stop offset="%s" stop-color="%s"/>' % (n(o), hexof(key)) for o, key in stops)))
            paint = "url(#%s)" % gid
        body.append((name, '<path d="%s" fill="%s"%s/>' % (d, paint, ' fill-opacity="%s"' % n(opacity) if opacity is not None else "")))
    return defs, body


# "container" is the shell's own card colour, where neutral is near grey on any palette
PAL = {"p": "primary", "s": "secondary", "t": "tertiary", "e": "error", "n": "neutral", "c": "container"}


def k(fam, tone):
    return "%s-%d" % (PAL[fam], tone)


# ---- objects

def folder(emblem=None, fam="p"):
    out = [("back", rpoly([(4, 8), (15, 8), (19, 11.6), (44, 11.6), (44, 40), (4, 40)], [4, 2.6, 2.6, 5.5, 6, 6]),
            grad(k(fam, 40), k(fam, 30), 8, 40)),
           ("paper", rr(7, 12.8, 34, 22, 3, 6, 3, 3), grad(k("n", 99), k("n", 95), 12.8, 20)),
           ("front", rpoly([(4, 17.8), (15.5, 17.8), (22, 14.2), (44, 14.2), (44, 40), (4, 40)], [4.5, 3.4, 3.4, 5.5, 6, 6]),
            grad(k(fam, 70), k(fam, 50), 14.2, 40, 10, 38))]
    if emblem:
        out.append(("emblem", symbol(emblem, 26.4, 22.6, 16, bold=True), k("n", 10), 0.36))
    return out


def folder_open(fam="p"):
    return [("back", rpoly([(4, 8), (15, 8), (19, 11.6), (44, 11.6), (44, 40), (4, 40)], [4, 2.6, 2.6, 5.5, 6, 6]),
             grad(k(fam, 40), k(fam, 30), 8, 40)),
            ("paper", rr(8, 10.6, 31, 22, 3, 6, 3, 3), k("n", 95)),
            ("sheet", rr(10.5, 13.2, 30, 20, 3, 6, 3, 3), grad(k("n", 99), k("n", 95), 13.2, 22)),
            ("front", rpoly([(9, 20.4), (46, 20.4), (43.2, 40), (4, 40)], [4, 4, 6, 6]), grad(k(fam, 70), k(fam, 50), 20.4, 40, 12, 38))]


# one accent and neutrals, as the icon themes this set sits beside do it: most
# pages are white with the accent on their emblem, media pages are the accent
# with a white emblem, and pdf keeps its red
PAGE_STYLES = {"doc": ((("n", 95), ("n", 90)), ("n", 99), ("n", 80), ("p", 60)),
               "media": ((("p", 70), ("p", 50)), ("p", 90), ("p", 40), ("n", 99)),
               "pdf": ((("e", 70), ("e", 50)), ("e", 90), ("e", 40), ("n", 99))}


def page(emblem=None, style="doc", lines=0):
    sheet, flap, shade, ink = PAGE_STYLES[style]
    out = [("page", rpoly([(9, 4), (28, 4), (39, 15), (39, 44), (9, 44)], [4.5, 2, 2, 4.5, 4.5]), grad(k(*sheet[0]), k(*sheet[1]), 4, 44, 16, 32)),
           ("shadow", rpoly([(28, 4), (39, 15), (26.8, 16.2)], [1.2, 1.2, 3.4]), k(*shade)),
           ("flap", rpoly([(28, 4), (39, 15), (28, 15)], [1.2, 1.2, 3]), k(*flap))]
    if lines:
        widths = [16, 16, 16, 10][:lines]
        out.append(("lines", "".join(pill(15.5, 23 + i * 5.4, 15.5 + w, 23 + i * 5.4, 2.6) for i, w in enumerate(widths)), k("n", 60)))
    if emblem:
        out.append(("emblem", symbol(emblem, 15, 21.5, 18, bold=True), k(*ink)))
    return out


# an archive is an accent page zipped shut, as the themes this set sits beside draw
# one: a checker of teeth down from the top edge, the slider, and a white pull with
# its hole. left of centre, clear of the fold. the track runs on under the slider,
# so sliding it down on hover opens the zip rather than a gap
def zipped(cx=22, sq=2.6, n=8):
    x0, b = cx - sq, 4 + n * sq
    teeth = "".join(rr(x0 + sq * (i % 2), 4 + i * sq, sq, sq, 0.35) for i in range(n))
    return page(None, "media") + [
        ("track", rr(x0, 4, sq * 2, n * sq + 3, 0.6), k("p", 30)),
        ("teeth", teeth, k("n", 99)),
        ("slider", rpoly([(cx - 3.6, b - 0.8), (cx + 3.6, b - 0.8), (cx + 2.4, b + 4.6), (cx - 2.4, b + 4.6)], [1.4, 1.4, 1.6, 1.6]),
         grad(k("p", 30), k("p", 20), b - 0.8, b + 4.6)),
        ("pull", rr(cx - 2.7, b + 3.4, 5.4, 9, 2.7), grad(k("n", 99), k("n", 90), b + 3.4, b + 12.4)),
        ("hole", rr(cx - 0.95, b + 6, 1.9, 4, 0.95), k("p", 40))]


# ---- places and devices: neutral objects, the accent on what lights up

def trash(full=False):
    can = [("can", rpoly([(11, 16.5), (37, 16.5), (34.6, 43), (13.4, 43)], [1.5, 1.5, 4.5, 4.5]), grad(k("n", 70), k("n", 50), 16.5, 43)),
           ("slots", pill(18.4, 22, 18.8, 37.5, 2.8) + pill(24, 22, 24, 37.5, 2.8) + pill(29.6, 22, 29.2, 37.5, 2.8), k("n", 40))]
    lid = [box(8, 10, 32, 5.4), box(19, 6, 10, 5)]
    papers = []
    if full:
        # the lid tips open on its left end over what spills out
        papers = [("paper", rpoly([(12.5, 17.5), (14.5, 9.8), (19.5, 12), (24, 6.6), (29.5, 10.8), (34.2, 8.6), (36, 17.5)],
                                  [1, 2, 2, 2.2, 2, 2, 1]), k("n", 99)),
                  ("scrap", rpoly([(18.5, 17.5), (22.8, 11.2), (28.5, 17.5)], [1, 1.8, 1]), k("p", 60))]
        lid = [[(x - 0.6, y - 1.2) for x, y in rotate(b, 8.4, 16, -14)] for b in lid]
    return papers + can + [("handle", rpoly(lid[1], 2.2), k("n", 60)), ("lid", rpoly(lid[0], 2.7), grad(k("n", 80), k("n", 60), 9, 16))]


def recent():
    c = (24, 24)
    return [("face", circle(*c, 19), grad(k("p", 70), k("p", 50), 5, 43, 16, 32)),
            ("ticks", "".join(circle(*polar(*c, 15.2, a), 1.3) for a in (-90, 0, 90, 180)), k("p", 80)),
            ("hands", pill(*c, *polar(*c, 9.4, -90), 3.6) + pill(*c, *polar(*c, 11.6, 30), 3.6) + circle(*c, 3), k("n", 99))]


def starred():
    return [("star", symbol("star", -1, -1, 50), grad(k("p", 70), k("p", 50), 4, 44))]


def computer():
    return [("neck", rr(20.5, 31, 7, 8.5, 1), k("n", 40)),
            ("foot", rr(14, 38.4, 20, 4, 2), k("n", 50)),
            ("bezel", rr(4, 7, 40, 27, 5), grad(k("n", 30), k("n", 10), 7, 34)),
            ("screen", rr(6.6, 9.6, 34.8, 21.8, 2.8), grad(k("p", 70), k("p", 40), 9.6, 31.4, 14, 34))]


def drive():
    return [("body", rr(4, 13, 40, 22, 6), grad(k("n", 95), k("n", 80), 13, 27)),
            ("front", rr(4, 27, 40, 8, 0, 0, 6, 6), grad(k("n", 70), k("n", 60), 27, 35)),
            ("slot", pill(10, 31, 21, 31, 2.2), k("n", 50)),
            ("light", circle(37.5, 31, 2), k("p", 60))]


def usb():
    return [("plug", rr(17.5, 4, 13, 12, 2.4), k("n", 80)),
            ("pins", rr(20.3, 8, 2.8, 2.8, 0.7) + rr(24.9, 8, 2.8, 2.8, 0.7), k("n", 60)),
            ("body", rr(13.5, 14, 21, 30, 6.5), grad(k("n", 70), k("n", 50), 14, 44)),
            ("emblem", symbol("usb", 16.5, 21, 15), k("n", 99)),
            ("light", circle(24, 39.2, 1.7), k("p", 60))]


def phone():
    return [("body", rr(12.5, 3.5, 23, 41, 6.5), grad(k("n", 30), k("n", 10), 3.5, 44.5)),
            ("screen", rr(14.7, 6.4, 18.6, 35.2, 4.6), grad(k("p", 70), k("p", 40), 6.4, 41.6, 18, 30)),
            ("camera", pill(22.3, 9.4, 25.7, 9.4, 2.2), k("n", 20))]


def network():
    # the lighter sea sits under the globe's own disc, so no ring shows round it
    return [("sea", circle(24, 24, 18.6), k("p", 80)),
            ("globe", symbol("public", 0, 0, 48), grad(k("p", 70), k("p", 50), 5, 43)),
            ("node", circle(38.2, 38.2, 6.2), k("n", 30)),
            ("link", symbol("lan", 32.6, 32.6, 11.2), k("n", 99))]


def disc():
    return [("disc", ring(24, 24, 20, 3.2), grad(k("n", 90), k("n", 70), 4, 44, 12, 36)),
            ("groove", ring(24, 24, 15, 13.8), k("n", 90)),
            ("hub", ring(24, 24, 8.4, 3.2), k("p", 60))]


def cloud():
    return [("back", symbol("cloud", 17, 3, 28), k("p", 80)),
            ("front", symbol("cloud", 2, 10, 40), grad(k("p", 70), k("p", 50), 14, 42))]


# ---- apps: one squircle tile each, in the accent, the dark card colour or a light neutral,
# with a bold white, accent or dark mark on it; the plate alone is the fallback

def tile(fam, tone):
    top = min(99, tone + 10)
    return [("lift", m3_shape("square", 44, 2, 3.2), k(fam, tone - 10)),
            ("tile", m3_shape("square", 44, 2, 2), grad(k(fam, top), k(fam, tone), 2, 46, 12, 36))]


def plate():
    return tile("n", 90)


def along(tip, deg, pts):
    u = (math.cos(math.radians(deg)), math.sin(math.radians(deg)))
    v = (-u[1], u[0])
    return [(tip[0] + a * u[0] + c * v[0], tip[1] + a * u[1] + c * v[1]) for a, c in pts]


# a part scaled with shrink(): its gradient has to land where its shape does
def shrink_part(part, s, ox, oy):
    name, d, fill = part[:3]
    if not isinstance(fill, str):
        kind, x1, y1, x2, y2, stops = fill
        fill = (kind, x1 * s + ox, y1 * s + oy, x2 * s + ox, y2 * s + oy, stops)
    return (name, shrink(d, s, ox, oy), fill) + tuple(part[3:])


def app_files():
    return tile("c", 15) + [shrink_part(p, 0.74, 6.24, 7.2) for p in folder()]


def app_terminal():
    return tile("c", 15) + [("prompt", pill(13, 17, 21, 23.5, 4) + pill(21, 23.5, 13, 30, 4), k("n", 99)),
                            ("cursor", pill(25, 31.5, 34, 31.5, 4), k("p", 60))]


def app_browser():
    return tile("p", 60) + [("globe", symbol("public", 8, 8, 32), k("n", 99))]


def app_settings():
    knobs = ((15.5, 28), (24, 18.5), (32.5, 26))
    return tile("p", 60) + [
        ("tracks", "".join(pill(x, 12.5, x, 35.5, 3.2) for x, _ in knobs), k("p", 80)),
        ("knobs", "".join(circle(x, y, 4.2) for x, y in knobs), k("n", 99))]


def app_editor():
    tip = (17.5, 37.5)
    return tile("n", 90) + [
        ("lines", pill(11.5, 13, 27, 13, 2.8) + pill(11.5, 19, 31, 19, 2.8) + pill(11.5, 25, 20, 25, 2.8), k("n", 70)),
        ("pencil", rpoly(along(tip, -45, [(0, 0), (5.2, -3.4), (22, -3.4), (22, 3.4), (5.2, 3.4)]), [1, 0.6, 2, 2, 0.6]), k("p", 60)),
        ("lead", rpoly(along(tip, -45, [(0, 0), (5.2, -3.4), (5.2, 3.4)]), [1, 0.4, 0.4]), k("p", 40))]


def app_code():
    return tile("c", 15) + [("code", symbol("code", 9, 9, 30), k("p", 60))]


def app_music():
    return tile("p", 60) + [("note", symbol("music_note", 9, 8, 30), k("n", 99))]


def app_video():
    return tile("p", 60) + [("play", rpoly([(18, 14), (34, 24), (18, 34)], [3, 3, 3]), k("n", 99))]


def app_photos():
    return tile("n", 90) + [
        ("sun", circle(30.5, 16.5, 3.6), k("p", 80)),
        ("hills", rpoly([(9, 35), (19, 20), (25.5, 28.5), (29.5, 24), (39, 35)], [2, 3, 2, 3, 2]), k("p", 60))]


def app_mail():
    return tile("p", 60) + [
        ("envelope", rr(10, 14, 28, 20, 3.6), k("n", 99)),
        ("flap", rpoly([(11.6, 15.6), (36.4, 15.6), (24, 26)], [1.4, 1.4, 2.4]), k("p", 80))]


def app_chat():
    return tile("p", 60) + [
        ("bubble", rr(10, 12, 28, 20, 8) + rpoly([(14.5, 28), (13.6, 37.4), (22, 30.6)], [1, 1.2, 1]), k("n", 99)),
        ("dots", circle(18, 22, 2) + circle(24, 22, 2) + circle(30, 22, 2), k("p", 60))]


def app_calendar():
    dots = "".join(circle(x, y, 1.9) for x in (16.5, 24, 31.5) for y in (26.4, 32.8) if (x, y) != (31.5, 32.8))
    return tile("n", 90) + [
        ("page", rr(9, 11, 30, 28, 4.4), k("n", 99)),
        ("header", rr(9, 11, 30, 9, 4.4, 4.4, 0, 0), k("p", 60)),
        ("rings", pill(17, 8.6, 17, 13.4, 3) + pill(31, 8.6, 31, 13.4, 3), k("n", 40)),
        ("days", dots, k("n", 70)),
        ("today", circle(31.5, 32.8, 2.8), k("p", 60))]


def app_calculator():
    keys = ""
    for row, y in enumerate((21.5, 28, 34.5)):
        for col, x in enumerate((11, 18, 25, 32)):
            if (row, col) != (2, 3):
                keys += rr(x, y, 5.6, 4.6, 1.6)
    return tile("n", 90) + [
        ("display", rr(11, 10.5, 26.6, 7.6, 2.4), k("n", 40)),
        ("keys", keys, k("n", 60)),
        ("equals", rr(32, 34.5, 5.6, 4.6, 1.6), k("p", 60))]


def app_monitor():
    pts = [(9, 26), (16, 26), (19.5, 17), (25, 33), (28.5, 22), (31, 26), (39, 26)]
    line = "".join(pill(*pts[i], *pts[i + 1], 3.4) for i in range(len(pts) - 1))
    return tile("c", 15) + [("pulse", line, k("p", 60))]


def app_software():
    return tile("p", 60) + [("bag", symbol("shopping_bag", 9, 8, 30), k("n", 99))]


def app_games():
    return tile("c", 15) + [("pad", symbol("sports_esports", 7, 7, 34), k("p", 60))]


def brand_glyph(name):
    return tile("p", 60) + [("glyph", brand(name, 11, 11, 26), k("n", 99))]


def badge(name):
    return [("base", circle(24, 25, 19), k("p", 20)), ("face", circle(24, 23.8, 19), grad(k("p", 40), k("p", 30), 5, 43)),
            ("glyph", symbol(name, 11, 10.8, 26), k("n", 99))]


FOLDERS = {"folder": None, "folder-home": "home", "folder-desktop": "desktop_windows", "folder-documents": "description",
           "folder-download": "download", "folder-music": "music_note", "folder-pictures": "image", "folder-videos": "movie",
           "folder-templates": "content_copy", "folder-public": "share", "folder-remote": "lan"}
FILES = {"file": (None, "doc"), "text": (None, "doc", 4), "document": ("format_paragraph", "doc"), "pdf": ("picture_as_pdf", "pdf"),
         "spreadsheet": ("table", "doc"), "presentation": ("slideshow", "doc"), "image": ("image", "media"),
         "video": ("movie", "media"), "audio": ("music_note", "media"), "archive": (None, "media"), "code": ("code", "doc"),
         "script": ("terminal", "doc"), "font": ("match_case", "doc"), "disk-image": ("album", "doc"),
         "package": ("deployed_code", "doc"), "ebook": ("menu_book", "doc")}
PLACES = {"trash": lambda: trash(), "trash-full": lambda: trash(True), "recent": recent, "starred": starred,
          "computer": computer, "drive": drive, "drive-usb": usb, "phone": phone, "network": network,
          "drive-optical": disc, "cloud": cloud}
# a place as one bold symbol, for rows too small for the whole icon (lumen's sidebar
# and tabs). a folder's is its own emblem, so the row and the folder read as one
PLACE_GLYPHS = {"folder-open": "folder_open", "recent": "schedule", "trash": "delete", "trash-full": "delete",
                "starred": "star", "computer": "computer", "drive": "hard_drive", "drive-usb": "usb",
                "phone": "smartphone", "network": "lan", "drive-optical": "album", "cloud": "cloud", "search": "search"}


def glyph_symbols():
    out = {slot: emblem or "folder" for slot, emblem in FOLDERS.items()}
    out.update(PLACE_GLYPHS)
    return out
APPS = {"app-files": app_files, "app-terminal": app_terminal, "app-browser": app_browser, "app-settings": app_settings,
        "app-editor": app_editor, "app-code": app_code, "app-music": app_music, "app-video": app_video,
        "app-photos": app_photos, "app-mail": app_mail, "app-chat": app_chat, "app-calendar": app_calendar,
        "app-calculator": app_calculator, "app-monitor": app_monitor, "app-software": app_software, "app-games": app_games}
# the brand cells, from the dock's own pins: simple icons name, label, app id
BRAND_CELLS = {"custom-1": ("vscodium", "VSCodium", "codium"), "custom-2": ("spotify", "Spotify", "spotify"),
               "custom-3": ("steam", "Steam", "steam")}
BADGES = {"badge-link": "link", "badge-locked": "lock", "badge-shared": "group", "badge-synced": "sync"}


# ---- apps past the sheet: brand glyphs from simple icons and material symbols,
# each on a tile in one of three looks, so a dock of them is not one colour.
# the tables after them tell the shell which app is which; a theme carries its
# own, so another can cover more

def look(kind, name, d):
    if kind == "dark":
        return tile("c", 15) + [(name, d, k("p", 70))]
    if kind == "light":
        return tile("n", 90) + [(name, d, k("p", 50))]
    return tile("p", 60) + [(name, d, k("n", 99))]


def app_lumen():
    return tile("c", 15) + [shrink_part(p, 0.74, 6.24, 7.2) for p in folder("explore")]


# lens's picture: a print behind, and in front a white-bordered photo of hills
# under a sun, with the emblem at its foot as a folder wears one
def photo_print(emblem=None, fam="p"):
    out = [("back", rr(12, 6, 30, 24, 4.5), grad(k(fam, 50), k(fam, 40), 6, 30)),
           ("paper", rr(5, 11, 34, 30, 5), grad(k("n", 99), k("n", 95), 11, 41)),
           ("sky", rr(8.2, 14.2, 27.6, 23.6, 2.8), grad(k(fam, 80), k(fam, 70), 14.2, 37.8)),
           ("hills", rpoly([(8.2, 37.8), (8.2, 31), (15, 23.5), (21, 30.5), (25, 26.5), (35.8, 36.8), (35.8, 37.8)],
                           [2.8, 0, 2.2, 1.6, 1.6, 0, 2.8]), k(fam, 50)),
           ("sun", circle(29.4, 20.4, 2.6), k("n", 99))]
    if emblem:
        out.append(("emblem", symbol(emblem, 25.6, 24.6, 17, bold=True), k("n", 10), 0.36))
    return out


def app_lens():
    return tile("n", 90) + [shrink_part(p, 0.78, 5.3, 5.6) for p in photo_print("search")]


# lucid's broken orbit as a fill, on the logo's own angles: outer arc, round cap,
# inner arc, round cap
def orbit(cx, cy, r, w, a0=58, a1=340):
    def at(rad, deg):
        return "%s %s" % (n(cx + rad * math.cos(math.radians(deg))), n(cy - rad * math.sin(math.radians(deg))))
    ro, ri, cap = r + w / 2, r - w / 2, n(w / 2)
    return "M%s A%s %s 0 1 0 %s A%s %s 0 0 0 %s A%s %s 0 1 1 %s A%s %s 0 0 0 %sZ" % (
        at(ro, a0), n(ro), n(ro), at(ro, a1), cap, cap, at(ri, a1), n(ri), n(ri), at(ri, a0), cap, cap, at(ro, a0))


# lucid settings' picture: the logo's orbit and companion dot, the gear where its
# star sits
def lucid_gear(ring_fill, gear_fill, dot_fill, s=1.56, cx=24, cy=24):
    g = 5.2 * s
    return [("ring", orbit(cx, cy, 7.4 * s, 3 * s), ring_fill),
            ("gear", symbol("settings", cx - g, cy - g, 2 * g, bold=True), gear_fill),
            ("dot", circle(cx + 9 * s, cy - 2.6 * s, s), dot_fill)]


def app_lucid_settings():
    return tile("c", 15) + lucid_gear(grad(k("p", 80), k("p", 60), 6, 42), k("n", 99), k("p", 70))


BRAND_APPS = {  # slot: (simple icons slug, look)
    "brand-firefox": ("firefoxbrowser", "accent"), "brand-brave": ("brave", "dark"),
    "brand-chrome": ("googlechrome", "light"), "brand-zen": ("zenbrowser", "dark"),
    "brand-librewolf": ("librewolf", "light"), "brand-vivaldi": ("vivaldi", "accent"),
    "brand-opera": ("opera", "light"), "brand-tor": ("torbrowser", "dark"), "brand-floorp": ("floorp", "accent"),
    "brand-vscodium": ("vscodium", "accent"), "brand-zed": ("zedindustries", "dark"),
    "brand-github": ("github", "dark"), "brand-neovim": ("neovim", "dark"), "brand-vim": ("vim", "light"),
    "brand-godot": ("godotengine", "accent"), "brand-spotify": ("spotify", "dark"), "brand-mpv": ("mpv", "dark"),
    "brand-vlc": ("vlcmediaplayer", "light"), "brand-obs": ("obsstudio", "dark"),
    "brand-kdenlive": ("kdenlive", "accent"), "brand-audacity": ("audacity", "light"),
    "brand-discord": ("discord", "accent"), "brand-telegram": ("telegram", "accent"),
    "brand-signal": ("signal", "accent"), "brand-element": ("element", "light"),
    "brand-whatsapp": ("whatsapp", "light"), "brand-thunderbird": ("thunderbird", "accent"),
    "brand-gimp": ("gimp", "light"), "brand-inkscape": ("inkscape", "dark"), "brand-blender": ("blender", "dark"),
    "brand-krita": ("krita", "light"), "brand-libreoffice": ("libreoffice", "light"),
    "brand-obsidian": ("obsidian", "dark"), "brand-todoist": ("todoist", "accent"),
    "brand-bitwarden": ("bitwarden", "accent"), "brand-protonvpn": ("protonvpn", "dark"),
    "brand-qbittorrent": ("qbittorrent", "light"), "brand-virtualbox": ("virtualbox", "light"),
    "brand-steam": ("steam", "dark"), "brand-lutris": ("lutris", "light"),
    "brand-heroic": ("heroicgameslauncher", "dark"), "brand-retroarch": ("retroarch", "dark"),
    "brand-roblox": ("roblox", "light"), "brand-qt": ("qt", "light"), "brand-kde": ("kde", "accent"),
    "brand-gnome": ("gnome", "light"),
}
GLYPH_APPS = {  # slot: (material symbol, look)
    "app-volume": ("volume_up", "accent"), "app-bluetooth": ("bluetooth", "accent"), "app-network": ("lan", "light"),
    "app-disk": ("donut_large", "light"), "app-vm": ("computer", "dark"), "app-phone": ("smartphone", "accent"),
    "app-camera": ("photo_camera", "dark"), "app-notes": ("sticky_note_2", "light"), "app-clock": ("schedule", "dark"),
    "app-maps": ("map", "light"), "app-recorder": ("mic", "accent"), "app-printer": ("print", "light"),
    "app-archive": ("folder_zip", "light"), "app-fonts": ("match_case", "light"), "app-help": ("help", "accent"),
    "app-weather": ("partly_cloudy_day", "accent"),
}
MORE_APPS = {"app-lumen": app_lumen, "app-lens": app_lens, "app-lucid-settings": app_lucid_settings}


def _ids(slot, *keys):
    return {key: slot for key in keys}


# desktop ids, window classes, icon names and short names, lowercased, to slots.
# the shell also tries a key's last dotted part and drops a -bin/-browser/-desktop tail
APP_IDS = {}
for _slot, _keys in (
        ("app-files", ("org.gnome.nautilus", "nautilus", "org.kde.dolphin", "dolphin", "thunar", "nemo", "pcmanfm",
                       "pcmanfm-qt", "caja", "files", "system-file-manager", "org.xfce.thunar")),
        ("app-lumen", ("lucid.lumen", "lumen")),
        ("app-lens", ("lucid.lens", "lens")),
        # the shell's own process, so the settings window goes by quickshell's id
        ("app-lucid-settings", ("org.quickshell", "quickshell")),
        ("app-terminal", ("kitty", "foot", "footclient", "alacritty", "wezterm", "org.wezfurlong.wezterm", "ghostty",
                          "com.mitchellh.ghostty", "gnome-terminal", "org.gnome.terminal", "org.gnome.ptyxis", "ptyxis",
                          "konsole", "org.kde.konsole", "xterm", "terminal", "utilities-terminal", "tilix", "terminator",
                          "xfce4-terminal", "blackbox", "com.raggesilver.blackbox")),
        ("brand-firefox", ("firefox", "org.mozilla.firefox", "firefox-esr", "firefox-developer-edition")),
        ("brand-brave", ("brave-browser", "brave", "com.brave.browser")),
        ("brand-chrome", ("google-chrome", "google-chrome-stable", "com.google.chrome")),
        ("app-browser", ("chromium", "chromium-browser", "org.chromium.chromium", "epiphany", "org.gnome.epiphany",
                         "falkon", "org.kde.falkon", "qutebrowser")),
        ("brand-zen", ("zen", "zen-browser", "zen-bin", "app.zen_browser.zen", "zen-alpha", "zen-twilight")),
        ("brand-librewolf", ("librewolf", "io.gitlab.librewolf-community")),
        ("brand-vivaldi", ("vivaldi", "vivaldi-stable")),
        ("brand-opera", ("opera",)),
        ("brand-tor", ("torbrowser", "torbrowser-launcher", "org.torproject.torbrowser-launcher", "tor-browser")),
        ("brand-floorp", ("floorp", "one.ablaze.floorp")),
        ("brand-vscodium", ("codium", "vscodium", "com.vscodium.codium")),
        ("app-code", ("code-oss", "code", "visual-studio-code", "com.visualstudio.code", "cursor")),
        ("brand-zed", ("dev.zed.zed", "zed", "zeditor", "zed-preview")),
        ("brand-github", ("github-desktop", "io.github.shiftey.desktop")),
        ("brand-neovim", ("nvim", "neovim")),
        ("brand-vim", ("vim", "gvim")),
        ("brand-godot", ("godot", "org.godotengine.godot")),
        ("app-editor", ("org.gnome.texteditor", "gnome-text-editor", "org.gnome.gedit", "gedit", "org.kde.kate",
                        "kate", "org.kde.kwrite", "kwrite", "mousepad", "org.xfce.mousepad", "micro")),
        ("brand-spotify", ("spotify", "spotify-client", "com.spotify.client")),
        ("brand-mpv", ("mpv", "io.mpv.mpv")),
        ("brand-vlc", ("vlc", "org.videolan.vlc")),
        ("app-video", ("celluloid", "io.github.celluloid_player.celluloid", "totem", "org.gnome.totem",
                       "org.gnome.showtime", "haruna", "org.kde.haruna")),
        ("app-music", ("rhythmbox", "org.gnome.rhythmbox3", "elisa", "org.kde.elisa", "amberol", "io.bassi.amberol",
                       "lollypop", "org.gnome.lollypop", "re.fossplant.songrec", "songrec")),
        ("brand-obs", ("obs", "com.obsproject.studio", "obs-studio")),
        ("brand-kdenlive", ("kdenlive", "org.kde.kdenlive")),
        ("brand-audacity", ("audacity", "org.audacityteam.audacity")),
        ("brand-discord", ("discord", "com.discordapp.discord", "vesktop", "dev.vencord.vesktop", "equibop",
                           "io.github.equicord.equibop", "webcord", "legcord", "armcord", "discord-canary")),
        ("brand-telegram", ("telegram-desktop", "org.telegram.desktop", "telegram", "telegramdesktop")),
        ("brand-signal", ("signal-desktop", "org.signal.signal", "signal")),
        ("brand-element", ("element", "element-desktop", "im.riot.riot")),
        ("brand-whatsapp", ("whatsapp", "whatsapp-for-linux", "com.github.eneshecan.whatsappforlinux", "zapzap",
                            "com.rtosta.zapzap")),
        ("brand-thunderbird", ("thunderbird", "org.mozilla.thunderbird", "net.thunderbird.thunderbird")),
        ("app-mail", ("geary", "org.gnome.geary", "evolution", "org.gnome.evolution")),
        ("brand-gimp", ("gimp", "org.gimp.gimp")),
        ("brand-inkscape", ("inkscape", "org.inkscape.inkscape")),
        ("brand-blender", ("blender", "org.blender.blender")),
        ("brand-krita", ("krita", "org.kde.krita")),
        ("app-photos", ("org.gnome.loupe", "loupe", "eog", "org.gnome.eog", "gwenview", "org.kde.gwenview", "imv",
                        "shotwell", "org.gnome.shotwell", "feh")),
        ("brand-libreoffice", ("libreoffice", "libreoffice-startcenter", "libreoffice-writer", "libreoffice-calc",
                               "libreoffice-impress", "libreoffice-draw", "libreoffice-math", "libreoffice-base")),
        ("brand-obsidian", ("obsidian", "md.obsidian.obsidian")),
        ("brand-todoist", ("todoist", "com.todoist.todoist")),
        ("brand-bitwarden", ("bitwarden", "com.bitwarden.desktop")),
        ("brand-protonvpn", ("proton.vpn.app.gtk", "protonvpn", "protonvpn-app", "proton-vpn")),
        ("brand-qbittorrent", ("qbittorrent", "org.qbittorrent.qbittorrent")),
        ("brand-virtualbox", ("virtualbox", "org.virtualbox.virtualbox")),
        ("app-vm", ("virt-manager", "remote-viewer", "gnome-boxes", "org.gnome.boxes")),
        ("brand-steam", ("steam", "com.valvesoftware.steam", "steam-native", "steam-runtime")),
        ("brand-lutris", ("lutris", "net.lutris.lutris")),
        ("brand-heroic", ("heroic", "com.heroicgameslauncher.hgl")),
        ("brand-retroarch", ("retroarch", "org.libretro.retroarch")),
        ("brand-roblox", ("org.vinegarhq.sober", "sober", "org.vinegarhq.vinegar")),
        ("brand-qt", ("assistant", "designer", "linguist", "qdbusviewer", "org.qt-project.qtcreator", "qtcreator")),
        ("app-monitor", ("btop", "htop", "gnome-system-monitor", "org.gnome.systemmonitor",
                         "io.missioncenter.missioncenter", "org.kde.plasma-systemmonitor", "lstopo", "nvtop")),
        ("app-calculator", ("org.gnome.calculator", "gnome-calculator", "qalculate-gtk", "qalculate-qt", "kcalc",
                            "org.kde.kcalc", "galculator")),
        ("app-calendar", ("org.gnome.calendar", "gnome-calendar")),
        ("app-volume", ("org.pulseaudio.pavucontrol", "pavucontrol", "pavucontrol-qt", "com.saivert.pwvucontrol",
                        "pwvucontrol", "helvum", "org.pipewire.helvum", "qpwgraph")),
        ("app-bluetooth", ("blueman-manager", "blueman-adapters", "blueberry", "overskride")),
        ("app-network", ("nm-connection-editor",)),
        ("app-disk", ("org.gnome.baobab", "baobab", "filelight", "org.kde.filelight", "gparted", "org.gnome.diskutility",
                      "gnome-disks")),
        ("app-phone", ("org.kde.kdeconnect.app", "kdeconnect-app", "org.kde.kdeconnect.sms", "kdeconnect-sms",
                       "org.kde.kdeconnect.nonplasma", "kdeconnect-indicator")),
        ("app-settings", ("systemsettings", "kdesystemsettings", "org.kde.systemsettings", "nwg-look", "qt6ct", "qt5ct",
                          "org.gnome.settings", "gnome-control-center", "appimagelaunchersettings", "wcm", "uuctl",
                          "lxappearance", "kvantummanager")),
        ("app-software", ("org.gnome.software", "gnome-software", "org.kde.discover", "plasma-discover",
                          "pamac-manager", "io.github.flattool.warehouse", "com.github.tchx84.flatseal", "bauh")),
        ("app-camera", ("org.gnome.snapshot", "snapshot", "cheese", "org.gnome.cheese", "guvcview")),
        ("app-notes", ("org.gnome.notes", "bijiben", "xournalpp", "com.github.xournalpp.xournalpp")),
        ("app-clock", ("org.gnome.clocks", "gnome-clocks")),
        ("app-maps", ("org.gnome.maps", "gnome-maps")),
        ("app-recorder", ("org.gnome.soundrecorder", "gnome-sound-recorder")),
        ("app-printer", ("system-config-printer",)),
        ("app-archive", ("org.gnome.fileroller", "file-roller", "org.kde.ark", "ark", "xarchiver", "engrampa")),
        ("app-fonts", ("org.gnome.font-viewer", "gnome-font-viewer", "font-manager", "org.gnome.fontmanager")),
        ("app-weather", ("org.gnome.weather", "gnome-weather")),
        ("app-help", ("yelp", "org.gnome.yelp")),
):
    APP_IDS.update(_ids(_slot, *_keys))

# what an app no table knows gets, by its first desktop category the theme draws.
# games and anything broad (Development, Network, Utility) keep their own icons
KINDS = [["TerminalEmulator", "app-terminal"], ["FileManager", "app-files"], ["WebBrowser", "app-browser"],
         ["Calculator", "app-calculator"], ["Calendar", "app-calendar"], ["Email", "app-mail"],
         ["InstantMessaging", "app-chat"], ["Chat", "app-chat"], ["IDE", "app-code"], ["TextEditor", "app-editor"],
         ["Monitor", "app-monitor"], ["PackageManager", "app-software"], ["Photography", "app-photos"],
         ["RasterGraphics", "app-photos"], ["Mixer", "app-volume"], ["Music", "app-music"], ["Video", "app-video"],
         ["Audio", "app-music"], ["HardwareSettings", "app-settings"], ["DesktopSettings", "app-settings"],
         ["Settings", "app-settings"]]


# [(part, path, key)] for a slot, or [] when gravity has nothing there
def draw(slot):
    if slot in FOLDERS:
        return folder(FOLDERS[slot])
    if slot == "folder-open":
        return folder_open()
    if slot == "archive":
        return zipped()
    if slot in FILES:
        return page(*FILES[slot])
    if slot in PLACES:
        return PLACES[slot]()
    if slot == "app-plate":
        return plate()
    if slot in APPS:
        return APPS[slot]()
    if slot in BRAND_CELLS:
        return brand_glyph(BRAND_CELLS[slot][0])
    if slot in BADGES:
        return badge(BADGES[slot])
    if slot in BRAND_APPS:
        slug, kind = BRAND_APPS[slot]
        return look(kind, "glyph", brand(slug, 11, 11, 26))
    if slot in GLYPH_APPS:
        name, kind = GLYPH_APPS[slot]
        return look(kind, "glyph", symbol(name, 9, 9, 30))
    if slot in MORE_APPS:
        return MORE_APPS[slot]()
    return []


# ---- motion: how parts move while the pointer is over the icon (or a drag is
# over a folder). a hover is {dx, dy, sx, sy, rot, ox, oy} on the 48 grid: scale
# and turn about (ox, oy), then shift. an origin may be "min", "max" or "c" of a
# part's box, its own or the one "box" names. lumen eases both ways on m3's fast
# spatial curve, so small numbers go a long way

def motion(slot, names):
    def each(spec, skip=()):
        return {n: dict(spec) for n in names if n not in skip}

    if slot.startswith("folder"):
        # the paper slides up out of it and the front flap opens towards you
        front = {"sy": 0.9, "ox": 24, "oy": 40}
        return {"paper": {"dy": -3.2}, "sheet": {"dy": -2.2}, "front": front, "emblem": dict(front)}
    if slot in FILES:
        # the page lifts and its corner peels
        out = each({"dy": -1.6})
        peel = {"dy": -1.6, "sx": 1.16, "sy": 1.16, "ox": "max", "oy": "min", "box": "flap"}
        out.update({"flap": peel, "shadow": dict(peel)})
        if "emblem" in names:
            out["emblem"] = {"dy": -1.6, "sx": 1.08, "sy": 1.08, "ox": "c", "oy": "c"}
        # an archive unzips a little: the slider and its pull slide down the track
        for part in ("slider", "pull", "hole"):
            if part in names:
                out[part] = {"dy": 0.4}
        return out
    if slot.startswith("trash"):
        lid = {"dy": -1.2, "rot": -14, "ox": "min", "oy": "max", "box": "lid"}
        return {"lid": lid, "handle": dict(lid), "paper": {"dy": -1.6}, "scrap": {"dy": -2.2}}
    if slot == "recent":
        return {"hands": {"rot": 50, "ox": "c", "oy": "c", "box": "face"}}
    if slot == "starred":
        return {"star": {"rot": 14, "sx": 1.1, "sy": 1.1, "ox": "c", "oy": "c"}}
    if slot == "computer":
        return each({"dy": -1.2}, skip=("foot",))
    if slot == "drive":
        out = each({"dy": -1.2})
        out["light"] = {"dy": -1.2, "sx": 1.5, "sy": 1.5, "ox": "c", "oy": "c"}
        return out
    if slot == "drive-usb":
        out = each({"dy": -0.8})
        out.update({"plug": {"dy": -2.2}, "pins": {"dy": -2.2}})
        return out
    if slot == "phone":
        return each({"rot": -8, "ox": "c", "oy": "c", "box": "body"})
    if slot == "network":
        return each({"dy": -1.2})
    if slot == "drive-optical":
        return each({"rot": 70, "ox": "c", "oy": "c", "box": "disc"})
    if slot == "cloud":
        return {"back": {"dx": -1.2, "dy": -0.4}, "front": {"dx": 0.9}}
    if slot.startswith(("app-", "custom-", "brand-")) or slot in BRAND_CELLS:
        # the tile rises off its base, what is on it grows a touch
        out = each({"dy": -1.6, "sx": 1.06, "sy": 1.06, "ox": "c", "oy": "c", "box": "tile"}, skip=("lift", "tile"))
        if "tile" in names:
            out["tile"] = {"dy": -1.6}
        return out
    return {}
