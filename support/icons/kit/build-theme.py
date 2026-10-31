#!/usr/bin/env python3
# compiles gravity (tonal.py) into the json themes lucid draws from: every slot
# as parts, each a path on the 48 grid with a palette key or a two-key gradient
# and an optional opacity. keys stay keys, so the shell resolves them against the
# live wallpaper palette instead of baking in one seed's colours
# the app tables go along, so the shell knows which tile an app gets
#   python3 support/icons/kit/build-theme.py [--dir path]   (default lucidicons/themes/)
# writes gravity.json and gravity-simplified.json, the same icons in flat tones
import importlib.util
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.dont_write_bytecode = True
_spec = importlib.util.spec_from_file_location("tonal", os.path.join(HERE, "tonal.py"))
tonal = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tonal)


def bounds(d):
    """the box of a path's points, control points included: near enough for an origin"""
    xs, ys = [], []
    toks = re.findall(r"[MmLlHhVvCcSsQqTtAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?", d)
    i, cmd, x, y, sx, sy = 0, "M", 0.0, 0.0, 0.0, 0.0
    sizes = {"M": 2, "L": 2, "T": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "A": 7, "Z": 0}
    while i < len(toks):
        if toks[i].isalpha():
            cmd = toks[i]
            i += 1
            if cmd in "Zz":
                x, y = sx, sy
                continue
        n = sizes[cmd.upper()]
        if i + n > len(toks):
            break
        v = [float(t) for t in toks[i:i + n]]
        i += n
        rel = cmd.islower()
        up = cmd.upper()
        if up == "H":
            x = x + v[0] if rel else v[0]
        elif up == "V":
            y = y + v[0] if rel else v[0]
        elif up == "A":
            x, y = (x + v[5], y + v[6]) if rel else (v[5], v[6])
        else:
            pts = [(v[k] + (x if rel else 0), v[k + 1] + (y if rel else 0)) for k in range(0, n, 2)]
            for px, py in pts[:-1]:
                xs.append(px)
                ys.append(py)
            x, y = pts[-1]
        xs.append(x)
        ys.append(y)
        if up == "M":
            sx, sy = x, y
            # more pairs after an M are line-tos
            cmd = "l" if rel else "L"
    return (min(xs), min(ys), max(xs), max(ys)) if xs else (0, 0, 48, 48)


def hover_of(spec, box):
    def at(v, lo, hi):
        if isinstance(v, (int, float)):
            return v
        return {"min": lo, "max": hi, "c": (lo + hi) / 2}[v]
    x0, y0, x1, y1 = box
    return {"dx": spec.get("dx", 0), "dy": spec.get("dy", 0), "sx": spec.get("sx", 1), "sy": spec.get("sy", 1),
            "rot": spec.get("rot", 0), "ox": round(at(spec.get("ox", 24), x0, x1), 2), "oy": round(at(spec.get("oy", 24), y0, y1), 2)}


# the sets this kit builds, as a picker lists them: id, name, and whether each
# gradient becomes one flat tone
SETS = [("gravity", "Gravity", False), ("gravity-simplified", "Gravity (Simplified)", True)]

# a flat tone starts at the gradient's lit top, a quarter back down on a wide one,
# then moves as little as its range allows to keep clear of m3's light surface
# container (tone 94, every palette) and of the shapes touching it
LIGHT_SURFACE, SURFACE_GAP, DETAIL_GAP, DARK_FLOOR, WIDE = 94, 4, 6, 22, 15


def tone_of(key):
    return int(key.rsplit("-", 1)[1])


def overlap(a, b):
    return not (a[2] <= b[0] or b[2] <= a[0] or a[3] <= b[1] or b[3] <= a[1])


def flatten(parts):
    boxes = [bounds(p["d"]) for p in parts]
    tones = [None if "grad" in p else tone_of(p["fill"]) for p in parts]
    for i, p in enumerate(parts):
        if "grad" in p:
            hi, lo = tone_of(p["stops"][0][1]), tone_of(p["stops"][1][1])
            tones[i] = hi - ((hi - lo) / 4 if hi - lo >= WIDE else 0)
    for i, p in enumerate(parts):
        if "grad" not in p:
            continue
        top, bottom = p["stops"][0][1], p["stops"][1][1]
        fam = top.rsplit("-", 1)[0]
        if fam != bottom.rsplit("-", 1)[0]:
            raise SystemExit("a gradient across two palettes has no one tone: %s -> %s" % (top, bottom))
        hi, lo = tone_of(top), tone_of(bottom)
        target = round(tones[i])
        near = [tones[j] for j in range(len(parts)) if j != i and tones[j] is not None
                and parts[j].get("opacity", 1) >= 1 and overlap(boxes[i], boxes[j])]
        allowed = [t for t in range(lo, hi + 1) if abs(t - LIGHT_SURFACE) >= SURFACE_GAP and t >= DARK_FLOOR
                   and all(abs(t - v) >= DETAIL_GAP for v in near)]
        if not allowed:
            allowed = [t for t in range(lo, hi + 1) if abs(t - LIGHT_SURFACE) >= SURFACE_GAP] or [target]
        tones[i] = min(allowed, key=lambda v: (abs(v - target), -v))
        del p["grad"], p["stops"]
        p["fill"] = "%s-%d" % (fam, tones[i])


def slots(flat=False):
    names = (list(tonal.FOLDERS) + ["folder-open"] + list(tonal.FILES) + list(tonal.PLACES) + ["app-plate"]
             + list(tonal.APPS) + list(tonal.BRAND_CELLS) + list(tonal.BADGES) + list(tonal.BRAND_APPS)
             + list(tonal.GLYPH_APPS) + list(tonal.MORE_APPS))
    out = {}
    for slot in names:
        parts = []
        for part in tonal.draw(slot):
            name, d, fill = part[:3]
            p = {"part": name, "d": d}
            if isinstance(fill, str):
                p["fill"] = fill
            else:
                _, x1, y1, x2, y2, stops = fill
                p["grad"] = [round(x1, 2), round(y1, 2), round(x2, 2), round(y2, 2)]
                p["stops"] = [[o, key] for o, key in stops]
            if len(part) > 3 and part[3] is not None:
                p["opacity"] = part[3]
            parts.append(p)
        moves = tonal.motion(slot, [p["part"] for p in parts])
        boxes = {p["part"]: bounds(p["d"]) for p in parts}
        for p in parts:
            spec = moves.get(p["part"])
            if spec:
                p["hover"] = hover_of(spec, boxes.get(spec.get("box", p["part"]), boxes[p["part"]]))
        if flat:
            flatten(parts)
        out[slot] = parts
    return out


# each place's glyph as its emblem is drawn, on its own: the outline and the
# filled form, bold, on the symbols' 24-unit grid
def glyphs():
    return {slot: [tonal.symbol(name, 0, 0, 24, filled=False, bold=True), tonal.symbol(name, 0, 0, 24, filled=True, bold=True)]
            for slot, name in tonal.glyph_symbols().items()}


def shared(data):
    # a long path more than one part draws (every app's tile and its lift) is
    # written once under "paths", and those parts name it with "ref", not "d"
    seen = {}
    for parts in data["slots"].values():
        for p in parts:
            if len(p["d"]) >= 200:
                seen[p["d"]] = seen.get(p["d"], 0) + 1
    ids = {d: str(i) for i, d in enumerate(d for d, n in seen.items() if n > 1)}
    for parts in data["slots"].values():
        for p in parts:
            if p["d"] in ids:
                p["ref"] = ids[p.pop("d")]
    data["paths"] = {i: d for d, i in ids.items()}


def main():
    out_dir = os.path.join(ROOT, "lucidicons", "themes")
    if "--dir" in sys.argv:
        out_dir = sys.argv[sys.argv.index("--dir") + 1]
    os.makedirs(out_dir, exist_ok=True)
    for set_id, name, flat in SETS:
        data = {"format": 1, "id": "lucid." + set_id, "name": name, "grid": 48, "slots": slots(flat),
                "apps": tonal.APP_IDS, "kinds": tonal.KINDS, "glyphs": glyphs()}
        shared(data)
        out = os.path.join(out_dir, set_id + ".json")
        with open(out, "w") as f:
            json.dump(data, f, separators=(",", ":"))
        print("%s: %d slots -> %s (%d KB)" % (name, len(data["slots"]), out, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    sys.exit(main())
