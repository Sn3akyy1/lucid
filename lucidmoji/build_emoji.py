#!/usr/bin/env python3
"""Build lucidmoji/emoji.json from Unicode emoji-test.txt + CLDR annotations.

Output shape (kept terse on purpose - QML parses this on first panel open):
  { "v": "16.0",
    "groups": ["Smileys & Emotion", ...],
    "emoji": [ {"e": "\U0001f600", "n": "grinning face", "g": 0,
                "k": "face grin smile", "t": ["...5 tone variants..."]} ] }
"""
import json
import re
import os
import sys
import tempfile
import urllib.request
from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "emoji.json")
CACHE = os.path.join(tempfile.gettempdir(), "lucidmoji-emoji-src")

SOURCES = {
    "emoji-test.txt": "https://unicode.org/Public/emoji/16.0/emoji-test.txt",
    "annotations.json": "https://raw.githubusercontent.com/unicode-org/cldr-json/main/"
                        "cldr-json/cldr-annotations-full/annotations/en/annotations.json",
    "annotations-derived.json": "https://raw.githubusercontent.com/unicode-org/cldr-json/main/"
                                "cldr-json/cldr-annotations-derived-full/annotationsDerived/en/annotations.json",
}

os.makedirs(CACHE, exist_ok=True)
for name, url in SOURCES.items():
    dest = os.path.join(CACHE, name)
    if os.path.exists(dest):
        continue
    print(f"fetching {name}", file=sys.stderr)
    urllib.request.urlretrieve(url, dest)

TONES = ["\U0001F3FB", "\U0001F3FC", "\U0001F3FD", "\U0001F3FE", "\U0001F3FF"]
TONE_CPS = {ord(t) for t in TONES}
# glue codepoints a font renders via GSUB rather than a cmap entry
SKIP_CPS = {0xFE0F, 0xFE0E, 0x200D, 0xE0020}


def font_cmap(path):
    try:
        f = TTFont(path, fontNumber=0, lazy=True)
        cps = set()
        for table in f["cmap"].tables:
            cps.update(table.cmap.keys())
        return cps
    except Exception as exc:  # noqa: BLE001 - diagnostics only
        print(f"warn: could not read {path}: {exc}", file=sys.stderr)
        return set()


covered = font_cmap("/usr/share/fonts/noto/NotoColorEmoji.ttf")
covered |= font_cmap("/usr/share/fonts/twemoji/twemoji.ttf")
print(f"font covers {len(covered)} codepoints", file=sys.stderr)


def renderable(s):
    for ch in s:
        cp = ord(ch)
        if cp in SKIP_CPS or 0xE0000 <= cp <= 0xE007F:
            continue
        if cp not in covered:
            return False
    return True


# ---- CLDR keywords -------------------------------------------------------
keywords = {}
names = {}
for fn in ("annotations.json", "annotations-derived.json"):
    with open(f"{CACHE}/{fn}", encoding="utf-8") as fh:
        blob = json.load(fh)
    root = blob.get("annotations") or blob.get("annotationsDerived")
    ann = root["annotations"]
    for emo, data in ann.items():
        if "default" in data:
            keywords[emo] = data["default"]
        if "tts" in data:
            names[emo] = data["tts"][0] if isinstance(data["tts"], list) else data["tts"]

# ---- emoji-test.txt ------------------------------------------------------
line_re = re.compile(r"^([0-9A-F ]+);\s*(\S+)\s*#\s*(\S+)\s+E\d+\.\d+\s+(.+)$")

groups = []
entries = []          # ordered, one per fully-qualified emoji
by_seq = {}           # emoji string -> entry
group = None

with open(f"{CACHE}/emoji-test.txt", encoding="utf-8") as fh:
    for line in fh:
        if line.startswith("# group:"):
            group = line.split(":", 1)[1].strip()
            continue
        if line.startswith("#") or not line.strip():
            continue
        m = line_re.match(line.strip())
        if not m:
            continue
        cps, status, seq, name = m.groups()
        if status != "fully-qualified" or group == "Component":
            continue
        if group not in groups:
            groups.append(group)
        entry = {"e": seq, "n": name.lower(), "g": groups.index(group)}
        entries.append(entry)
        by_seq[seq] = entry

print(f"{len(entries)} fully-qualified emoji in {len(groups)} groups", file=sys.stderr)


# ---- fold skin-tone variants into their base entry ------------------------
def strip_tones(seq):
    return "".join(ch for ch in seq if ord(ch) not in TONE_CPS)


base_entries = []
for entry in entries:
    seq = entry["e"]
    used = {ch for ch in seq if ord(ch) in TONE_CPS}
    if not used:
        base_entries.append(entry)
        continue
    if len(used) != 1:
        # e.g. "people holding hands: light, dark" - a tone *pair*, which no
        # single global tone setting can express. Dropped rather than shown
        # as its own grid tile.
        continue
    stripped = strip_tones(seq)
    base = by_seq.get(stripped) or by_seq.get(stripped + "️")
    if base is None:
        # tone form exists but the toneless form isn't itself an emoji
        # (rare); keep it as a normal entry so it stays reachable
        base_entries.append(entry)
        continue
    base.setdefault("t", [""] * 5)[TONES.index(next(iter(used)))] = seq

# ---- keywords + font filter ----------------------------------------------
out = []
dropped = 0
for entry in base_entries:
    if not renderable(entry["e"]):
        dropped += 1
        continue
    words = []
    for w in keywords.get(entry["e"], []):
        w = w.lower().strip()
        # the name already carries these; keywords only need to add synonyms
        if w and w not in entry["n"] and w not in words:
            words.append(w)
    if words:
        entry["k"] = " ".join(words)
    if "t" in entry:
        # a base whose variants aren't all renderable loses the tone picker
        # rather than offering tofu
        if not all(v and renderable(v) for v in entry["t"]):
            del entry["t"]
    out.append(entry)

print(f"dropped {dropped} unrenderable, kept {len(out)}", file=sys.stderr)
print(f"{sum(1 for e in out if 't' in e)} have skin tones", file=sys.stderr)

with open(OUT, "w", encoding="utf-8") as fh:
    json.dump({"v": "16.0", "groups": groups, "emoji": out}, fh,
              ensure_ascii=False, separators=(",", ":"))
print(f"wrote {OUT}", file=sys.stderr)
