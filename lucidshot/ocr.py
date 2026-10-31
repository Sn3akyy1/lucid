#!/usr/bin/env python3
"""Read the text in a screen crop for LucidShot, as text rather than as lines.

usage: ocr.py <colour.png> <grey.png> <negated.png> [lang]

The shell has already blown small crops up to about 300 dpi and made a grey
copy and a negated one. tesseract reads both at once and the more confident
read wins, so light-on-dark text reads as well as dark-on-light.

tesseract hands back every line on the screen as a line of its own, but a
paragraph that wraps on screen is one line of text. Its word boxes say which
breaks were wraps: a line that stops near the right edge of its block, with no
room left for the first word of the next, wrapped there. A short line, a list
marker, an indent or a gap is a break that was meant, and it stays; a wide gap
between lines becomes a blank line.

Emoji come across too, when numpy, Pillow and fontTools are installed and so is
an emoji font: tesseract has none in its character set and either drops them or
reads them as junk letters, so anything colourful and square is matched against
the glyphs of the installed emoji fonts instead. Colour tells emoji from text
(a word is one flat colour, an emoji is many) and emoji are square, which keeps
a colourful run of code from matching.

Prints the text, and nothing when there is none.
"""
import hashlib
import os
import re
import subprocess
import sys

N = int(os.environ.get("EMOJI_OCR_N", 16))   # template edge used for matching
SAT_T = 0.05        # saturation spread above which a box is emoji, not text
SCORE_T = 0.80      # minimum correlation to accept a match
MARGIN_T = 0.04     # ...and it must beat the best other emoji by this much
AR_LO, AR_HI = 0.55, 1.8    # emoji are square; a wide box is a run of text
CACHE = os.path.expanduser("~/.cache/lucidshot-ocr")

FONTS = [
    "/usr/share/fonts/noto/NotoColorEmoji.ttf",
    "/usr/share/fonts/noto-cjk/NotoColorEmoji.ttf",
    os.path.expanduser("~/.local/share/fonts/noto-mirror/NotoColorEmoji.ttf"),
    "/usr/share/fonts/twemoji/twemoji.ttf",
    "/usr/share/fonts/apple-color-emoji/apple-color-emoji.ttf",
    "/usr/share/fonts/joypixels/joypixels.ttf",
]

# what starts a line that is an item of its own: bullets, dashes, checkboxes,
# "1." "2)" "a." "(b)"
LIST = re.compile(r"^(?:[-‐‑–—•∙●○◦▪▫■□‣⁃*+>»«©°→✓✔✗✘☐☑]|\(?\d{1,3}[.):]|\(?[A-Za-z][.)]|\[[ xX]?\])(?:\s|$)")
DASHES = "-‐‑–—"
# what tesseract reads a round bullet as, when it has to read it as something
BULLETISH = {"«", "»", "©", "°", "*", "+", "e", "o", "¢"}


def tesseract(path, lang):
    return subprocess.Popen(["tesseract", path, "stdout", "-l", lang, "--dpi", "300", "tsv"],
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)


def words_of(tsv):
    words = []
    for row in tsv.splitlines()[1:]:
        p = row.split("\t")
        if len(p) < 12 or not p[11].strip():
            continue
        try:
            conf = float(p[10])
        except ValueError:
            conf = -1.0
        words.append(dict(key=(int(p[2]), int(p[3]), int(p[4])), x=int(p[6]), y=int(p[7]),
                          w=int(p[8]), h=int(p[9]), conf=conf, t=p[11].strip()))
    return words


def read(grey, negated, lang):
    """Both polarities at once; the read tesseract is surer of wins."""
    runs = [tesseract(grey, lang), tesseract(negated, lang)]
    best, score = [], -1.0
    for run in runs:
        out, _ = run.communicate()
        ws = words_of(out)
        s = sum(len(w["t"]) * max(w["conf"], 0) for w in ws)
        if s > score:
            best, score = ws, s
    return best


# --- emoji ---------------------------------------------------------------

def emoji(colour, grey, words):
    """The emoji in the crop, and the words they stand where. Both empty when
    the libraries or the fonts are not there."""
    try:
        import numpy as np
        from fontTools.ttLib import TTFont
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return [], set()

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
            return None, None
        return np.stack(tiles), np.array(cps, np.int32)

    def atlas():
        paths = [p for p in FONTS if os.path.exists(p)]
        if not paths:
            return None, None
        key = "|".join("%s:%d" % (p, os.path.getmtime(p)) for p in paths)
        stamp = hashlib.md5(key.encode()).hexdigest()[:12]
        cache = os.path.join(CACHE, "atlas-%s-n%d.npz" % (stamp, N))
        if os.path.exists(cache):
            z = np.load(cache)
            return z["tiles"], z["cps"]
        tiles, cps = build_atlas(paths)
        if tiles is None:
            return None, None
        os.makedirs(CACHE, exist_ok=True)
        np.savez_compressed(cache, tiles=tiles, cps=cps)
        return tiles, cps

    tiles, cps = atlas()
    if tiles is None:
        return [], set()

    im = Image.open(colour).convert("RGB")
    # the grey copy was blown up for tesseract; the boxes are in its pixels
    gw = Image.open(grey).width
    scale = gw / max(1, im.width)
    if abs(scale - 1) > 0.01:
        im = im.resize((gw, round(im.height * scale)), Image.LANCZOS)
    rgb = np.asarray(im)
    arr = rgb.astype(np.float32)
    H, W, _ = arr.shape

    # background = modal colour, so templates can be composited onto the same ground
    q = (arr // 16).astype(np.int32).reshape(-1, 3)
    bgk = np.bincount(q[:, 0] * 4096 + q[:, 1] * 64 + q[:, 2]).argmax()
    bg = np.array([(bgk // 4096) * 16 + 8, ((bgk // 64) % 64) * 16 + 8,
                   (bgk % 64) * 16 + 8], np.float32)
    ink = np.abs(arr - bg).max(2) > 40

    a = tiles[..., 3:4].astype(np.float32) / 255.0
    comp = tiles[..., :3].astype(np.float32) * a + bg * (1 - a)
    T = comp.reshape(len(tiles), -1)
    tm = T - T.mean(1, keepdims=True)
    tn = np.sqrt((tm ** 2).sum(1)) + 1e-6

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
        sub = ink[y:y + h, x:x + w]
        if sub.size == 0 or not sub.any():
            return None
        ys = np.where(sub.any(1))[0]
        xs = np.where(sub.any(0))[0]
        return x + xs[0], y + ys[0], xs[-1] - xs[0] + 1, ys[-1] - ys[0] + 1

    def match(x, y, w, h):
        b = ink_box(x, y, w, h)
        if b is None:
            return None
        bx, by, bw, bh = b
        box = rgb[by:by + bh, bx:bx + bw]
        if box.size == 0:
            return None
        cand = square(Image.fromarray(box).convert("RGBA")).resize((N, N), Image.LANCZOS)
        cg = np.asarray(cand, np.float32)[..., :3].ravel()
        cm = cg - cg.mean()
        sc = (tm @ cm) / (tn * (np.sqrt((cm ** 2).sum()) + 1e-6))
        i = int(sc.argmax())
        top = int(cps[i])
        # a near-tie between two different emoji means neither is trustworthy
        other = sc[cps != top]
        margin = float(sc[i] - other.max()) if other.size else 1.0
        if float(sc[i]) < SCORE_T or margin < MARGIN_T:
            return None
        return chr(top)

    # every compact blob of ink is an emoji candidate, whether or not tesseract
    # claimed it. letters survive this scan too, but they are one flat colour and
    # so fail the saturation gate; runs of text fail the aspect gate for being wide
    found, blocked = [], []
    rows = ink.any(1)
    y = 0
    k = round(scale)
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
                bx, by, bw, bh = x, y + ys[0], x1 - x, ys[-1] - ys[0] + 1
                if bw >= 7 * k and bh >= 7 * k and AR_LO <= bw / max(bh, 1) <= AR_HI \
                        and sat_spread(bx, by, bw, bh) > SAT_T:
                    # colourful and square is enough to call it an emoji even
                    # when the atlas cannot name it; the junk letter tesseract
                    # read it as is worse than nothing
                    blocked.append((bx, by, bw, bh))
                    ch = match(bx, by, bw, bh)
                    if ch:
                        found.append(dict(x=bx, y=by, w=bw, h=bh, t=ch))
            x = x1
        y = y1

    eaten = set()
    for i, wd in enumerate(words):
        wa = max(wd["w"] * wd["h"], 1)
        for bx, by, bw, bh in blocked:
            ox = max(0, min(wd["x"] + wd["w"], bx + bw) - max(wd["x"], bx))
            oy = max(0, min(wd["y"] + wd["h"], by + bh) - max(wd["y"], by))
            if ox * oy > 0.35 * wa:
                eaten.add(i)
                break
    return found, eaten


# --- lines and paragraphs -----------------------------------------------

def lines_of(words, found, eaten):
    """tesseract's lines in its own reading order, each with its box, and the
    emoji put into whichever line they sit in."""
    lines, order = {}, []

    def add(line, item):
        line["items"].append(item)
        line["left"] = min(line["left"], item["x"])
        line["right"] = max(line["right"], item["x"] + item["w"])
        line["top"] = min(line["top"], item["y"])
        line["bottom"] = max(line["bottom"], item["y"] + item["h"])

    for i, wd in enumerate(words):
        if i in eaten:
            continue
        k = wd["key"]
        if k not in lines:
            lines[k] = dict(key=k, items=[], left=wd["x"], right=wd["x"], top=wd["y"], bottom=wd["y"])
            order.append(k)
        add(lines[k], wd)

    for e in found:
        mid = e["y"] + e["h"] / 2
        near = [lines[k] for k in order if lines[k]["top"] <= mid <= lines[k]["bottom"]]
        if near:
            line = min(near, key=lambda l: 0 if l["left"] <= e["x"] <= l["right"]
                       else min(abs(e["x"] - l["left"]), abs(e["x"] - l["right"])))
        else:
            # a line of nothing but emoji: one of its own, where it sits
            k = (10 ** 6 + len(order), 0, 0)
            line = dict(key=k, items=[], left=e["x"], right=e["x"], top=e["y"], bottom=e["y"])
            lines[k] = line
            at = len([o for o in order if lines[o]["top"] <= e["y"]])
            order.insert(at, k)
        add(line, e)

    out = []
    for k in order:
        line = lines[k]
        if not line["items"]:
            continue
        line["items"].sort(key=lambda it: it["x"])
        line["text"] = " ".join(it["t"] for it in line["items"])
        line["first"] = line["items"][0]["w"]
        out.append(line)
    return out


def joined(text, more):
    # a line that ends on a hyphen or a dash fixed to a word (a compound, a range)
    # carries on without a space: screens break lines after hyphens, not inside words
    if len(text) > 1 and text[-1] in DASHES and text[-2].isalnum() and more[:1].isalnum():
        return text + more
    return text + " " + more


def median(values, default):
    v = sorted(values)
    return v[len(v) // 2] if v else default


def reflow(lines):
    if not lines:
        return ""
    lh = max(1, median([l["bottom"] - l["top"] for l in lines], 1))
    cw = median([it["w"] / len(it["t"]) for l in lines for it in l["items"] if len(it["t"]) >= 3], lh * 0.45)
    space = max(cw * 0.5, lh * 0.2)
    pairs = list(zip(lines, lines[1:]))

    # bullets tesseract has no glyph for come back as these; they were bullets
    for l in lines:
        first = l["items"][0]
        if len(lines) > 1 and first["t"] in BULLETISH and first["w"] <= 1.6 * cw and len(l["items"]) > 1:
            first["t"] = "•"
            l["text"] = " ".join(it["t"] for it in l["items"])

    # what plain line spacing looks like here, top to top: screens space lines
    # well apart, so the gap under the letters says nothing on its own
    usual = median([b["top"] - a["top"] for a, b in pairs
                    if b["top"] > a["top"] and abs(b["left"] - a["left"]) <= 4 * cw], lh * 1.6)

    # runs of lines that read straight on: each just below the last and under
    # it. tesseract's own blocks cannot be trusted for this; it often hands a
    # paragraph's last line, or every line, a block of its own
    runs, cur = [], [lines[0]]
    for a, b in pairs:
        d = b["top"] - a["top"]
        if 0 < d <= 1.45 * usual and b["left"] < a["right"] and b["right"] > a["left"]:
            cur.append(b)
        else:
            runs.append(cur)
            cur = [b]
    runs.append(cur)

    # code and terminals are set in a monospace font, every letter as wide as
    # the next; their lines are meant as written, so nothing there is joined
    adv = [it["w"] / len(it["t"]) for l in lines for it in l["items"] if len(it["t"]) >= 3 and it["t"].isalnum()]
    mean = sum(adv) / len(adv) if adv else 0
    spread = (sum((v - mean) ** 2 for v in adv) / len(adv)) ** 0.5 / mean if len(adv) >= 4 and mean > 0 else 1
    mono = spread < 0.06

    def prose(run, right):
        # the right edge is a margin the text wrapped at, not just the longest
        # of some short lines: two lines run up to it, or the lines are long
        if mono or len(run) < 2:
            return False
        reach = sum(1 for l in run[:-1] if right - l["right"] <= 6 * cw)
        return reach >= 2 or max(len(l["text"]) for l in run) >= 45

    def starts(l):
        # where a wrapped line of this one would start: past a list marker, under its text
        if LIST.match(l["text"]) and len(l["items"]) > 1:
            return l["items"][1]["x"]
        return l["left"]

    out = []
    for run in runs:
        right = max(l["right"] for l in run)
        wraps = prose(run, right)
        text = run[0]["text"]
        for a, b in zip(run, run[1:]):
            wrapped = (wraps and not LIST.match(b["text"])
                       and abs(b["left"] - starts(a)) <= 1.5 * cw
                       # the next line's first word would not have fitted on this one
                       and right - a["right"] <= b["first"] + space + 1.5 * cw)
            text = joined(text, b["text"]) if wrapped else text + "\n" + b["text"]
        out.append((run, text))

    # runs further apart than plain line spacing are paragraphs of their own
    result = out[0][1]
    for (ra, _), (rb, tb) in zip(out, out[1:]):
        a, b = ra[-1], rb[0]
        close = 0 < b["top"] - a["top"] <= 1.45 * usual
        result += ("\n" if close else "\n\n") + tb
    return result


def main():
    if len(sys.argv) < 4:
        raise SystemExit("usage: ocr.py <colour.png> <grey.png> <negated.png> [lang]")
    colour, grey, negated = sys.argv[1:4]
    lang = sys.argv[4] if len(sys.argv) > 4 else "eng"
    os.makedirs(CACHE, exist_ok=True)
    words = read(grey, negated, lang)
    try:
        found, eaten = emoji(colour, grey, words)
    except Exception:
        found, eaten = [], set()
    sys.stdout.write(reflow(lines_of(words, found, eaten)))


if __name__ == "__main__":
    main()
