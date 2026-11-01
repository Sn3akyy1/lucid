#!/usr/bin/env python3
# build-app-icon.py: lumen's launcher icon, the gravity folder with a compass
# on it, lens's, a photo print with a magnifier, and lucid settings', a sheet of
# sliders with a gear, in the brand palette
# (#d3bccc's tonal-spot ramps). the launcher and dock read a plain svg, so these
# do not follow matugen.
# writes <repo>/lucidlumen/lumen.svg, <repo>/lucidlens/lens.svg and
# <repo>/lucidprefs/settings.svg, or one to --out <file> (--lens for lens's)
import importlib.util
import os
import sys

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, file))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    tonal = load("tonal", "tonal.py")
    sheet = load("build_sheet", "build-sheet.py")

    def hexof(key):
        fam, tone = key.rsplit("-", 1)
        return sheet.PALETTES[fam][sheet.TONES.index(int(tone))]

    icons = [("lumen", os.path.join(ROOT, "lucidlumen", "lumen.svg"), tonal.folder(emblem="explore")),
             ("lens", os.path.join(ROOT, "lucidlens", "lens.svg"), tonal.photo_print(emblem="search")),
             ("settings", os.path.join(ROOT, "lucidprefs", "settings.svg"), tonal.settings_sheet())]
    if "--out" in sys.argv:
        pick = icons[1] if "--lens" in sys.argv else icons[0]
        icons = [(pick[0], sys.argv[sys.argv.index("--out") + 1], pick[2])]
    for prefix, out, parts in icons:
        defs, body = tonal.render(parts, hexof, prefix)
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 48 48">'
               "<defs>%s</defs>%s</svg>\n") % ("".join(defs), "".join(p for _, p in body))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "w") as f:
            f.write(svg)
        print(out)


if __name__ == "__main__":
    main()
