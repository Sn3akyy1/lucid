#!/usr/bin/env python3
# rebuilds lucidui/ShapeRadii.js: the material 3 expressive shapes, built the way
# androidx graphics-shapes builds them (MaterialShapes + RoundedPolygon's corner
# rounding, numbers from androidx via soramanew/m3shapes), then sampled as radii
# round the centre at fixed angles so lucidui/Shapes.js can morph any two point
# by point. the sddm theme cannot import the shell, so it gets a table of its own
# with only the shapes it names. run after changing a shape:
# python3 support/shapes/build-shapes.py
import math
import os
import re

EPS = 1e-4
# rays from the centre at fixed angles, in units of half the box; 144 keeps every
# shape within half a pixel of its exact outline at 120px
N = 144


class P:
    __slots__ = ("x", "y")

    def __init__(self, x, y):
        self.x, self.y = float(x), float(y)

    def __add__(s, o): return P(s.x + o.x, s.y + o.y)
    def __sub__(s, o): return P(s.x - o.x, s.y - o.y)
    def __mul__(s, k): return P(s.x * k, s.y * k)
    def __truediv__(s, k): return P(s.x / k, s.y / k)
    def dist(s): return math.hypot(s.x, s.y)
    def dot(s, o): return s.x * o.x + s.y * o.y
    def rot90(s): return P(-s.y, s.x)

    def dir(s):
        d = s.dist()
        return P(0, 0) if d <= 0 else P(s.x / d, s.y / d)


def lerp(a, b, t): return a * (1 - t) + b * t


def line(a, b): return [a, lerp(a, b, 1 / 3), lerp(a, b, 2 / 3), b]


def arc(c, p0, p1):
    d0 = (p0 - c).dir()
    d1 = (p1 - c).dir()
    r0, r1 = d0.rot90(), d1.rot90()
    cw = r0.dot(p1 - c) >= 0
    cosa = d0.dot(d1)
    if cosa > 0.999:
        return line(p0, p1)
    r = (p0 - c).dist()
    k = r * 4 / 3 * (math.sqrt(2 * (1 - cosa)) - math.sqrt(1 - cosa * cosa)) / (1 - cosa) * (1 if cw else -1)
    return [p0, p0 + r0 * k, p1 - r1 * k, p1]


def isect(p0, d0, p1, d1):
    rd1 = d1.rot90()
    den = d0.dot(rd1)
    if abs(den) < EPS:
        return None
    num = (p1 - p0).dot(rd1)
    if abs(den) < EPS * abs(num):
        return None
    return p0 + d0 * (num / den)


# androidx RoundedCorner: a circular arc flanked by two smoothing curves
class Corner:
    def __init__(self, p0, p1, p2, r):
        self.p0, self.p1, self.p2 = p0, p1, p2
        v01, v21 = p0 - p1, p2 - p1
        d01, d21 = v01.dist(), v21.dist()
        if d01 > 0 and d21 > 0:
            self.d1, self.d2 = v01 / d01, v21 / d21
            self.R, self.sm = r
            self.cos = self.d1.dot(self.d2)
            self.sin = math.sqrt(max(0.0, 1 - self.cos ** 2))
            self.erc = self.R * (self.cos + 1) / self.sin if self.sin > 1e-3 else 0.0
        else:
            self.d1 = self.d2 = P(0, 0)
            self.R = self.sm = self.cos = self.sin = self.erc = 0.0

    def ecut(self): return (1 + self.sm) * self.erc

    def smooth(self, allowed):
        if allowed > self.ecut():
            return self.sm
        if allowed > self.erc:
            return self.sm * (allowed - self.erc) / (self.ecut() - self.erc)
        return 0.0

    def flank(self, rc, sm, side, ci, oci, cc, R):
        sd = (side - self.p1).dir()
        start = self.p1 + sd * (rc * (1 + sm))
        p = lerp(ci, (ci + oci) / 2, sm)
        end = cc + (p - cc).dir() * R
        a_end = isect(side, sd, end, (end - cc).rot90()) or ci
        return [start, (start + a_end * 2) / 3, a_end, end]

    def cubics(self, a0, a1):
        allowed = min(a0, a1)
        if self.erc < EPS or allowed < EPS or self.R < EPS:
            return [line(self.p1, self.p1)]
        rc = min(allowed, self.erc)
        R = self.R * rc / self.erc
        cc = self.p1 + ((self.d1 + self.d2) / 2).dir() * math.sqrt(R * R + rc * rc)
        c0, c2 = self.p1 + self.d1 * rc, self.p1 + self.d2 * rc
        f0 = self.flank(rc, self.smooth(a0), self.p0, c0, c2, cc, R)
        f2 = self.flank(rc, self.smooth(a1), self.p2, c2, c0, cc, R)[::-1]
        return [f0, arc(cc, f0[3], f2[0]), f2]


# androidx RoundedPolygon: corners cut back so neighbours share each side
def polygon(verts, rounds):
    n = len(verts)
    cs = [Corner(verts[(i - 1) % n], verts[i], verts[(i + 1) % n], rounds[i]) for i in range(n)]
    adj = []
    for i in range(n):
        erc = cs[i].erc + cs[(i + 1) % n].erc
        ec = cs[i].ecut() + cs[(i + 1) % n].ecut()
        side = (verts[i] - verts[(i + 1) % n]).dist()
        if erc > side:
            adj.append((side / erc, 0.0))
        elif ec > side:
            adj.append((1.0, (side - erc) / (ec - erc)))
        else:
            adj.append((1.0, 1.0))
    corners = []
    for i in range(n):
        cuts = []
        for d in (0, 1):
            rr, cr = adj[(i + n - 1 + d) % n]
            cuts.append(cs[i].erc * rr + (cs[i].ecut() - cs[i].erc) * cr)
        corners.append(cs[i].cubics(cuts[0], cuts[1]))
    out = []
    for i in range(n):
        out += corners[i]
        out.append(line(corners[i][-1][3], corners[(i + 1) % n][0][0]))
    return out


def transformed(cubics, f): return [[f(p) for p in c] for c in cubics]


def rotated(cubics, deg):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    return transformed(cubics, lambda p: P(p.x * ca - p.y * sa, p.x * sa + p.y * ca))


def scaled_y(cubics, k): return transformed(cubics, lambda p: P(p.x, p.y * k))


def point(c, t):
    u = 1 - t
    return c[0] * (u ** 3) + c[1] * (3 * u * u * t) + c[2] * (3 * u * t * t) + c[3] * (t ** 3)


# fitted to the unit box and centred in it, as androidx's normalized()
def normalized(cubics):
    pts = [point(c, k / 64) for c in cubics for k in range(65)]
    x0, x1 = min(p.x for p in pts), max(p.x for p in pts)
    y0, y1 = min(p.y for p in pts), max(p.y for p in pts)
    w, h = x1 - x0, y1 - y0
    side = max(w, h)
    ox, oy = (side - w) / 2 - x0, (side - h) / 2 - y0
    return transformed(cubics, lambda p: P((p.x + ox) / side, (p.y + oy) / side))


U = (0.0, 0.0)


def R(r, s=0.0): return (r, s)


def regular(n, radius, rounds):
    verts = [P(radius * math.cos(2 * math.pi / n * i), radius * math.sin(2 * math.pi / n * i)) for i in range(n)]
    return polygon(verts, rounds if isinstance(rounds, list) else [rounds] * n)


def circle(n=10):
    return regular(n, 1 / math.cos(math.pi / n), R(1.0))


def rectangle(w, h, rounds):
    verts = [P(w / 2, h / 2), P(-w / 2, h / 2), P(-w / 2, -h / 2), P(w / 2, -h / 2)]
    return polygon(verts, rounds if isinstance(rounds, list) else [rounds] * 4)


def star(n, radius, inner, rounding):
    verts = [P((radius if i % 2 == 0 else inner) * math.cos(math.pi / n * i), (radius if i % 2 == 0 else inner) * math.sin(math.pi / n * i)) for i in range(n * 2)]
    return polygon(verts, [rounding] * (n * 2))


# MaterialShapes.customPolygon: a few points, repeated round the centre
def custom(pnr, reps, cx=0.5, cy=0.5, mirror=False):
    pnr = [(p[0], p[1], p[2] if len(p) > 2 else U) for p in pnr]
    out = []
    if mirror:
        ang = [math.degrees(math.atan2(y - cy, x - cx)) for x, y, _ in pnr]
        dist = [math.hypot(x - cx, y - cy) for x, y, _ in pnr]
        sec = 360 / (reps * 2)
        for rep in range(reps * 2):
            for idx in range(len(pnr)):
                i = idx if rep % 2 == 0 else len(pnr) - 1 - idx
                if i > 0 or rep % 2 == 0:
                    a = sec * rep + ang[i] if rep % 2 == 0 else sec * rep + sec - ang[i] + 2 * ang[0]
                    out.append((math.cos(math.radians(a)) * dist[i] + cx, math.sin(math.radians(a)) * dist[i] + cy, pnr[i][2]))
    else:
        for rep in range(reps):
            a = math.radians(360 / reps * rep)
            for x, y, r in pnr:
                dx, dy = x - cx, y - cy
                out.append((dx * math.cos(a) - dy * math.sin(a) + cx, dx * math.sin(a) + dy * math.cos(a) + cy, r))
    return polygon([P(x, y) for x, y, _ in out], [r for _, _, r in out])


# lucid's names for androidx's MaterialShapes
SHAPES = {
    "circle": lambda: circle(10),
    "square": lambda: rectangle(1, 1, R(0.3)),
    "slanted": lambda: custom([(0.926, 0.970, R(0.189, 0.811)), (-0.021, 0.967, R(0.187, 0.057))], 2),
    "arch": lambda: rotated(regular(4, 1.0, [R(1), R(1), R(0.2), R(0.2)]), -135),
    "fan": lambda: custom([(1.004, 1.000, R(0.148, 0.417)), (0.000, 1.000, R(0.151)), (0.000, -0.003, R(0.148)), (0.978, 0.020, R(0.803))], 1),
    "arrow": lambda: custom([(0.500, 0.892, R(0.313)), (-0.216, 1.050, R(0.207)), (0.499, -0.160, R(0.215, 1.0)), (1.225, 1.060, R(0.211))], 1),
    "semiCircle": lambda: rectangle(1.6, 1.0, [R(0.2), R(0.2), R(1), R(1)]),
    "oval": lambda: rotated(scaled_y(circle(8), 0.64), -45),
    "pill": lambda: custom([(0.961, 0.039, R(0.426)), (1.001, 0.428), (1.000, 0.609, R(1.0))], 2, 0.5, 0.5, True),
    "triangle": lambda: rotated(regular(3, 1.0, R(0.2)), -90),
    "diamond": lambda: custom([(0.500, 1.096, R(0.151, 0.524)), (0.040, 0.500, R(0.159))], 2),
    "clamShell": lambda: custom([(0.171, 0.841, R(0.159)), (-0.020, 0.500, R(0.140)), (0.170, 0.159, R(0.159))], 2),
    "pentagon": lambda: custom([(0.500, -0.009, R(0.172)), (1.030, 0.365, R(0.164)), (0.828, 0.970, R(0.169))], 1, 0.5, 0.5, True),
    "gem": lambda: custom([(0.499, 1.023, R(0.241, 0.778)), (-0.005, 0.792, R(0.208)), (0.073, 0.258, R(0.228)), (0.433, -0.000, R(0.491))], 1, 0.5, 0.5, True),
    "sunny": lambda: star(8, 1.0, 0.8, R(0.15)),
    "verySunny": lambda: custom([(0.500, 1.080, R(0.085)), (0.358, 0.843, R(0.085))], 8),
    "cookie4": lambda: custom([(1.237, 1.236, R(0.258)), (0.500, 0.918, R(0.233))], 4),
    "cookie6": lambda: custom([(0.723, 0.884, R(0.394)), (0.500, 1.099, R(0.398))], 6),
    "cookie7": lambda: rotated(star(7, 1.0, 0.75, R(0.5)), -90),
    "cookie9": lambda: rotated(star(9, 1.0, 0.8, R(0.5)), -90),
    "cookie12": lambda: rotated(star(12, 1.0, 0.8, R(0.5)), -90),
    "ghostish": lambda: custom([(0.500, 0.0, R(1.0)), (1.0, 0.0, R(1.0)), (1.0, 1.140, R(0.254, 0.106)), (0.575, 0.906, R(0.253))], 1, 0.5, 0.5, True),
    "clover4": lambda: custom([(0.500, 0.074), (0.725, -0.099, R(0.476))], 4, 0.5, 0.5, True),
    "clover8": lambda: custom([(0.500, 0.036), (0.758, -0.101, R(0.209))], 8),
    "burst": lambda: custom([(0.500, -0.006, R(0.006)), (0.592, 0.158, R(0.006))], 12),
    "softBurst": lambda: custom([(0.193, 0.277, R(0.053)), (0.176, 0.055, R(0.053))], 10),
    "flower": lambda: custom([(0.370, 0.187), (0.416, 0.049, R(0.381)), (0.479, 0.001, R(0.095))], 8, 0.5, 0.5, True),
    "puffy": lambda: scaled_y(custom([(0.500, 0.053), (0.545, -0.040, R(0.405)), (0.670, -0.035, R(0.426)), (0.717, 0.066, R(0.574)), (0.722, 0.128), (0.777, 0.002, R(0.360)), (0.914, 0.149, R(0.660)), (0.926, 0.289, R(0.660)), (0.881, 0.346), (0.940, 0.344, R(0.126)), (1.003, 0.437, R(0.255))], 2, 0.5, 0.5, True), 0.742),
}


def radii(cubics):
    pts = [point(c, j / 96) for c in cubics for j in range(96)]
    pts = [(p.x, p.y) for p in pts]
    out = []
    for i in range(N):
        th = i / N * 2 * math.pi
        dx, dy = math.cos(th), math.sin(th)
        far = 0.0
        for a in range(len(pts)):
            x1, y1 = pts[a]
            x2, y2 = pts[(a + 1) % len(pts)]
            ex, ey = x2 - x1, y2 - y1
            den = dx * ey - dy * ex
            if abs(den) < 1e-12:
                continue
            ox, oy = x1 - 0.5, y1 - 0.5
            t = (ox * ey - oy * ex) / den
            u = (ox * dy - oy * dx) / den
            if t > 0 and -1e-9 <= u <= 1 + 1e-9:
                far = max(far, t)
        out.append(far / 0.5)
    return out


def table(names):
    rows = ['"%s":[%s]' % (n, ",".join(("%.4f" % v).rstrip("0").rstrip(".") for v in radii(normalized(SHAPES[n]())))) for n in names]
    return (".pragma library\n// generated by support/shapes/build-shapes.py from androidx graphics-shapes — do not edit\n"
            "\nvar N = %d;\nvar r = {\n%s\n};\n" % (N, ",\n".join(rows)))


def named_in(root, skip):
    seen = set()
    for d, _, files in os.walk(root):
        for f in files:
            if f.endswith((".qml", ".js")) and f not in skip:
                with open(os.path.join(d, f), encoding="utf-8") as fh:
                    seen |= set(re.findall(r'"(\w+)"', fh.read()))
    return [n for n in SHAPES if n in seen or n == "circle"]


if __name__ == "__main__":
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    with open(os.path.join(root, "lucidui", "ShapeRadii.js"), "w") as f:
        f.write(table(list(SHAPES)))
    sddm = os.path.join(root, "support", "sddm", "lucid")
    picked = named_in(sddm, {"ShapeRadii.js", "Shapes.js", "SymbolPaths.js"})
    with open(os.path.join(sddm, "components", "ShapeRadii.js"), "w") as f:
        f.write(table(picked))
    print("shell %d shapes, sddm %d: %s" % (len(SHAPES), len(picked), " ".join(picked)))
