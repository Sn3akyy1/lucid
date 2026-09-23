#!/usr/bin/env python3
# rebuilds lucidui/SymbolPaths.js: the official material symbols rounded svgs
# (outline and filled) for every string literal in the shell's qml that names
# one, moved from their 960-unit y-flipped grid onto the shell's 24-unit one.
# run after adding an icon: python3 support/icons/build-icons.py
import json
import os
import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NAMES = os.path.join(ROOT, "support", "icons", "symbols.txt")
CACHE = os.path.expanduser("~/.cache/lucid/symbols")
OUT = os.path.join(ROOT, "lucidui", "SymbolPaths.js")
URL = "https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/{n}/materialsymbolsrounded/{n}{v}_24px.svg"
BASE = {"help", "error", "check", "close", "add", "remove", "search", "settings",
        "chevron_right", "chevron_left", "expand_more", "expand_less", "more_vert"}
SKIP_DIRS = {".git", "wallpapers", "assets", "sddm"}

NUM = re.compile(r"-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")
ARGS = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "T": 2, "A": 7, "Z": 0}


def tokens(d):
    i = 0
    while i < len(d):
        c = d[i]
        if c.isalpha():
            yield c
            i += 1
        elif c in " ,\t\n":
            i += 1
        else:
            m = NUM.match(d, i)
            if not m:
                raise ValueError("bad path near %r" % d[i:i + 12])
            yield float(m.group(0))
            i = m.end()


def fmt(v):
    s = ("%.3f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


# from the file's viewBox onto 0 0 24 24: absolute coordinates are shifted and
# scaled, relative ones only scaled
def convert(d, box):
    mx, my, bw = box[0], box[1], box[2]
    k = 24.0 / bw
    out = []
    toks = list(tokens(d))
    i = 0
    cmd = None
    first = True
    while i < len(toks):
        t = toks[i]
        if isinstance(t, str):
            cmd = t
            i += 1
            if cmd in "Zz":
                out.append("Z")
                continue
        elif cmd is None:
            raise ValueError("path starts with a number")
        up = cmd.upper()
        n = ARGS[up]
        vals = toks[i:i + n]
        i += n
        lower = cmd.islower()
        rel = lower
        # svg: a leading relative moveto is absolute, but the pairs after it stay relative
        if first and up == "M":
            rel = False
        first = False
        conv = []
        for j, v in enumerate(vals):
            if up == "A" and j in (2, 3, 4):
                conv.append(v)
                continue
            if up == "A" and j in (0, 1):
                conv.append(v * k)
                continue
            if up == "H":
                axis = "x"
            elif up == "V":
                axis = "y"
            else:
                axis = "x" if j % 2 == 0 else "y"
            if rel:
                conv.append(v * k)
            else:
                conv.append((v - mx) * k if axis == "x" else (v - my) * k)
        letter = cmd if rel else up
        out.append(letter + " ".join(fmt(v) for v in conv))
        # an implicit repeat of moveto is a lineto
        if up == "M":
            cmd = "l" if lower else "L"
    return "".join(out)


def scan(names):
    lit = re.compile(r'"([a-z0-9_]{2,})"')
    used = set(BASE)
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if not (name.endswith(".qml") or name.endswith(".js")) or name == "SymbolPaths.js":
                continue
            with open(os.path.join(dirpath, name), encoding="utf-8", errors="replace") as f:
                for m in lit.finditer(f.read()):
                    if m.group(1) in names:
                        used.add(m.group(1))
    return sorted(used)


def fetch(name, variant):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name + variant + ".svg")
    if not os.path.exists(path):
        try:
            with urllib.request.urlopen(URL.format(n=name, v=variant), timeout=30) as r:
                data = r.read()
        except Exception:
            return None
        with open(path, "wb") as f:
            f.write(data)
    with open(path, encoding="utf-8") as f:
        svg = f.read()
    ds = re.findall(r'<path[^>]*\sd="([^"]+)"', svg)
    vb = re.search(r'viewBox="([^"]+)"', svg)
    box = [float(x) for x in vb.group(1).replace(",", " ").split()] if vb else [0, 0, 24, 24]
    return (" ".join(ds), box) if ds else None


def main():
    with open(NAMES) as f:
        names = {l.split()[0] for l in f if l.strip()}
    used = scan(names)
    jobs = [(n, v) for n in used for v in ("", "_fill1")]
    with ThreadPoolExecutor(16) as ex:
        got = dict(zip(jobs, ex.map(lambda j: fetch(*j), jobs)))
    table = {}
    missing = []
    for n in used:
        outline, filled = got[(n, "")], got[(n, "_fill1")]
        if outline is None:
            missing.append(n)
            continue
        filled = filled if filled else outline
        table[n] = [convert(*outline), convert(*filled)]
    with open(OUT, "w") as f:
        f.write(".pragma library\n")
        f.write("// generated by support/icons/build-icons.py from google/material-design-icons — do not edit\n")
        f.write("var p = " + json.dumps(table, separators=(",", ":")) + ";\n")
    print("%d icons -> %s (%d KB)%s" % (len(table), os.path.relpath(OUT, ROOT), os.path.getsize(OUT) // 1024,
                                       ("; not found: " + ", ".join(missing)) if missing else ""))


if __name__ == "__main__":
    sys.exit(main())
