#!/usr/bin/env python3
"""OCR a screen crop, keeping the emoji.

tesseract has no emoji in its character set, so it drops them or reads them as
junk letters. But emoji come from a font, so what they can look like is a small
known set: this renders every glyph once, caches it, and matches the leftovers.
Colour tells emoji from text -- a word is one flat colour, an emoji is many --
and emoji are square, which is what keeps a colourful run of code from matching.

Prints the text to stdout. Exits non-zero if it cannot run, so the caller can
fall back to plain tesseract.
"""
import hashlib
import os
import subprocess
import sys

import numpy as np
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFont

N = int(os.environ.get("EMOJI_OCR_N", 16))   # template edge used for matching
SAT_T = 0.05        # saturation spread above which a box is emoji, not text
SCORE_T = 0.80      # minimum correlation to accept a match
MARGIN_T = 0.04     # ...and it must beat the best other emoji by this much
AR_LO, AR_HI = 0.55, 1.8    # emoji are square; a wide box is a run of text
CACHE = os.path.expanduser("~/.cache/lucidshot-ocr")
LUMA = np.array([0.299, 0.587, 0.114], np.float32)

FONTS = [
    "/usr/share/fonts/noto/NotoColorEmoji.ttf",
    "/usr/share/fonts/noto-cjk/NotoColorEmoji.ttf",
    os.path.expanduser("~/.local/share/fonts/noto-mirror/NotoColorEmoji.ttf"),
    "/usr/share/fonts/twemoji/twemoji.ttf",
    "/usr/share/fonts/apple-color-emoji/apple-color-emoji.ttf",
    "/usr/share/fonts/joypixels/joypixels.ttf",
]


def square(im):
    w, h = im.size
    s = max(w, h)
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    out.paste(im, ((s - w) // 2, (s - h) // 2))
    return out


def strike_size(path):
    """Bitmap emoji faces only render at their baked-in ppem."""
    try:
        f = TTFont(path, fontNumber=0, lazy=True)
        if "CBLC" in f:
            return max(s.bitmapSizeTable.ppemX for s in f["CBLC"].strikes)
        if "sbix" in f:
            return max(f["sbix"].strikes.keys())
        return 96
    except Exception:
        return None


def font_files():
    return [p for p in FONTS if os.path.exists(p)]


def build_atlas(paths):
    tiles, cps = [], []
    for path in paths:
        size = strike_size(path)
        if not size:
            continue
        try:
            fnt = ImageFont.truetype(path, size)
            face = TTFont(path, fontNumber=0, lazy=True)
        except Exception:
            continue
        codes = set()
        for t in face["cmap"].tables:
            codes.update(t.cmap.keys())
        pad = size + 40
        for cp in sorted(codes):
            if cp < 0x200D or cp in (0x20, 0xA0):
                continue
            img = Image.new("RGBA", (pad, pad), (0, 0, 0, 0))
            try:
                ImageDraw.Draw(img).text((10, 10), chr(cp), font=fnt, embedded_color=True)
            except Exception:
                continue
            bb = img.getbbox()
            if not bb or bb[2] - bb[0] < 4 or bb[3] - bb[1] < 4:
                continue
            tile = square(img.crop(bb)).resize((N, N), Image.LANCZOS)
            tiles.append(np.asarray(tile, np.uint8))
            cps.append(cp)
    if not tiles:
        raise SystemExit("no emoji glyphs could be rendered")
    return np.stack(tiles), np.array(cps, np.int32)


def atlas():
    paths = font_files()
    if not paths:
        raise SystemExit("no emoji font installed")
    key = "|".join("%s:%d" % (p, os.path.getmtime(p)) for p in paths)
    stamp = hashlib.md5(key.encode()).hexdigest()[:12]
    cache = os.path.join(CACHE, "atlas-%s-n%d.npz" % (stamp, N))
    if os.path.exists(cache):
        z = np.load(cache)
        return z["tiles"], z["cps"]
    tiles, cps = build_atlas(paths)
    os.makedirs(CACHE, exist_ok=True)
    np.savez_compressed(cache, tiles=tiles, cps=cps)
    return tiles, cps


def ncc(templates, cand):
    """Zero-mean unit-variance correlation, so brightness and contrast drop out."""
    tm = templates - templates.mean(1, keepdims=True)
    cm = cand - cand.mean()
    tn = np.sqrt((tm ** 2).sum(1)) + 1e-6
    cn = np.sqrt((cm ** 2).sum()) + 1e-6
    return (tm @ cm) / (tn * cn)


def tsv_words(img, invert):
    src = Image.eval(img, lambda v: 255 - v) if invert else img
    tmp = os.path.join(CACHE, "pass-%d.png" % int(invert))
    src.save(tmp)
    out = subprocess.run(["tesseract", tmp, "stdout", "-l", "eng", "--dpi", "300", "tsv"],
                         capture_output=True, text=True).stdout.splitlines()
    words = []
    for line in out[1:]:
        p = line.split("\t")
        if len(p) < 12 or not p[11].strip():
            continue
        words.append(dict(line=(int(p[2]), int(p[3]), int(p[4])), x=int(p[6]),
                          y=int(p[7]), w=int(p[8]), h=int(p[9]),
                          conf=float(p[10]), t=p[11]))
    return words


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: emoji-ocr.py <image> | --atlas")
    if sys.argv[1] == "--atlas":
        tiles, _ = atlas()
        sys.stderr.write("emoji atlas ready: %d templates\n" % len(tiles))
        return
    os.makedirs(CACHE, exist_ok=True)
    im = Image.open(sys.argv[1]).convert("RGB")

    # upscale small crops the same way the shell path does; tesseract wants ~300dpi
    scale = 3 if im.width < 1200 else 1
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.LANCZOS)
    rgb = np.asarray(im)
    arr = rgb.astype(np.float32)
    H, W, _ = arr.shape

    gray = im.convert("L")
    # run both polarities and keep whichever tesseract was more confident about
    best, score = [], -1.0
    for inv in (False, True):
        ws = tsv_words(gray, inv)
        s = sum(len(w["t"]) * max(w["conf"], 0) for w in ws)
        if s > score:
            best, score = ws, s
    words = best

    # background = modal colour, so templates can be composited onto the same ground
    q = (arr // 16).astype(np.int32).reshape(-1, 3)
    bgk = np.bincount(q[:, 0] * 4096 + q[:, 1] * 64 + q[:, 2]).argmax()
    bg = np.array([(bgk // 4096) * 16 + 8, ((bgk // 64) % 64) * 16 + 8,
                   (bgk % 64) * 16 + 8], np.float32)
    ink = np.abs(arr - bg).max(2) > 40

    tiles, cps = atlas()
    a = tiles[..., 3:4].astype(np.float32) / 255.0
    comp = tiles[..., :3].astype(np.float32) * a + bg * (1 - a)
    T = comp.reshape(len(tiles), -1)

    def sat_spread(x, y, w, h):
        sub = arr[max(0, y):y + h, max(0, x):x + w]
        if sub.size == 0:
            return 0.0
        mx, mn = sub.max(2), sub.min(2)
        sat = np.where(mx > 1, (mx - mn) / np.maximum(mx, 1), 0)
        lit = mx > 60
        return float(sat[lit].std()) if lit.sum() > 4 else 0.0

    def ink_box(x, y, w, h):
        """Tighten a box to the pixels that actually differ from the background."""
        x, y = max(0, x), max(0, y)
        sub_ink = ink[y:y + h, x:x + w]
        if sub_ink.size == 0 or not sub_ink.any():
            return None
        ys = np.where(sub_ink.any(1))[0]
        xs = np.where(sub_ink.any(0))[0]
        return x + xs[0], y + ys[0], xs[-1] - xs[0] + 1, ys[-1] - ys[0] + 1

    def ink_aspect(x, y, w, h):
        b = ink_box(x, y, w, h)
        return 99.0 if b is None else b[2] / max(b[3], 1)

    def match(x, y, w, h):
        b = ink_box(x, y, w, h)
        if b is None:
            return None, 0.0
        bx, by, bw, bh = b
        box = rgb[by:by + bh, bx:bx + bw]
        if box.size == 0:
            return None, 0.0
        cand = square(Image.fromarray(box).convert("RGBA")).resize((N, N), Image.LANCZOS)
        cg = np.asarray(cand, np.float32)[..., :3].ravel()
        sc = ncc(T, cg)
        i = int(sc.argmax())
        top = int(cps[i])
        # a near-tie between two different emoji means neither is trustworthy
        other = sc[cps != top]
        margin = float(sc[i] - other.max()) if other.size else 1.0
        if float(sc[i]) < SCORE_T or margin < MARGIN_T:
            return None, float(sc[i])
        return chr(top), float(sc[i])

    dbg = os.environ.get("EMOJI_OCR_DEBUG")

    # Every compact blob of ink is an emoji candidate, whether or not tesseract
    # claimed it. Letters survive this scan too, but they are one flat colour and
    # so fail the saturation gate; runs of text fail the aspect gate for being wide.
    def blobs():
        out = []
        rows = ink.any(1)
        y = 0
        while y < H:
            if not rows[y]:
                y += 1
                continue
            y1 = y
            while y1 < H and rows[y1]:
                y1 += 1
            band = ink[y:y1]
            cols = band.any(0)
            x = 0
            while x < W:
                if not cols[x]:
                    x += 1
                    continue
                x1 = x
                while x1 < W and cols[x1]:
                    x1 += 1
                ys = np.where(band[:, x:x1].any(1))[0]
                if len(ys):
                    out.append((x, y + ys[0], x1 - x, ys[-1] - ys[0] + 1))
                x = x1
            y = y1
        return out

    found, blocked = [], []
    for bx, by, bw, bh in blobs():
        if bw < 7 * scale or bh < 7 * scale:
            continue
        ar = bw / max(bh, 1)
        ss = sat_spread(bx, by, bw, bh)
        if not (AR_LO <= ar <= AR_HI) or ss <= SAT_T:
            continue
        ch, sc = match(bx, by, bw, bh)
        if dbg:
            sys.stderr.write("BLOB %dx%d ar=%.2f sat=%.3f best=%s score=%.2f\n"
                             % (bw, bh, ar, ss, ch, sc))
        # colourful and square is enough to call it an emoji even when the atlas
        # cannot name it; the junk letter tesseract read it as is worse than nothing
        blocked.append((bx, by, bw, bh))
        if ch:
            found.append((bx, by, bw, bh, ch))

    def eaten(wd):
        """True if an accepted emoji already covers most of this word's box."""
        wa = max(wd["w"] * wd["h"], 1)
        for bx, by, bw, bh in blocked:
            ox = max(0, min(wd["x"] + wd["w"], bx + bw) - max(wd["x"], bx))
            oy = max(0, min(wd["y"] + wd["h"], by + bh) - max(wd["y"], by))
            if ox * oy > 0.35 * wa:
                return True
        return False

    lines_y = {}
    for wd in words:
        lo, hi = lines_y.get(wd["line"], (wd["y"], wd["y"] + wd["h"]))
        lines_y[wd["line"]] = (min(lo, wd["y"]), max(hi, wd["y"] + wd["h"]))

    items = []
    for wd in words:
        if dbg:
            sys.stderr.write("WORD %-14r eaten=%s\n" % (wd["t"], eaten(wd)))
        if not eaten(wd):
            items.append((wd["line"], wd["x"], wd["t"]))

    for bx, by, bw, bh, ch in found:
        mid = by + bh // 2
        ln = next((k for k, (lo, hi) in lines_y.items() if lo <= mid <= hi), (9999, 0, by))
        items.append((ln, bx, ch))

    # order lines by where they sit on screen; tesseract's line ids restart per block
    order = {k: lo for k, (lo, hi) in lines_y.items()}
    items.sort(key=lambda t: (order.get(t[0], t[0][2] if t[0][0] == 9999 else 0), t[1]))
    out, cur, ln = [], [], None
    for line, _, text in items:
        if ln is not None and line != ln:
            out.append(" ".join(cur))
            cur = []
        cur.append(text)
        ln = line
    if cur:
        out.append(" ".join(cur))
    sys.stdout.write("\n".join(out))


if __name__ == "__main__":
    main()
