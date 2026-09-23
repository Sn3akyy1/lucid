#!/usr/bin/env python3
"""slim-font.py — pin the flex font to the axes Lucid actually varies.

Qt builds one font engine per distinct variable-axis tuple and mmaps the whole
file for each, so the shell keeps ~77 mappings of GoogleSansFlex alive. Upstream
ships six axes and 3.6mb of the 4.2mb file is gvar (the per-axis deltas), so
pinning the axes nothing in Lucid ever moves cuts the file to ~0.6mb and the
shell's font rss with it, byte for byte identical on screen.

Theme.axes() only ever sends opsz, wght and ROND. wdth and slnt are never
touched, and GRAD is asked for as -10, below its own 0..100 range, so freetype
clamps it to the default anyway.

  ./slim-font.py                 # re-slim the shipped font in place
  ./slim-font.py IN.ttf OUT.ttf  # explicit paths
"""
import shutil
import sys
from pathlib import Path

KEEP = ("opsz", "wght", "ROND")
PIN = {"wdth": 100, "slnt": 0, "GRAD": 0}
DEFAULT = Path(__file__).resolve().parents[2] / "assets/fonts/GoogleSansFlex.ttf"


def main() -> int:
    try:
        from fontTools.ttLib import TTFont
        from fontTools.varLib import instancer
    except ImportError:
        print("needs fonttools: pacman -S python-fonttools", file=sys.stderr)
        return 1

    args = sys.argv[1:]
    src = Path(args[0]) if args else DEFAULT
    dst = Path(args[1]) if len(args) > 1 else src
    if not src.is_file():
        print(f"no font at {src}", file=sys.stderr)
        return 1

    font = TTFont(src)
    axes = {a.axisTag for a in font["fvar"].axes}
    pin = {k: v for k, v in PIN.items() if k in axes}
    if not pin:
        print(f"{src.name} is already pinned to {sorted(axes)}")
        return 0

    before = src.stat().st_size
    out = instancer.instantiateVariableFont(font, pin, updateFontNames=False)
    left = [a.axisTag for a in out["fvar"].axes]
    missing = [a for a in KEEP if a not in left]
    if missing:
        print(f"refusing to write, lost axes Lucid uses: {missing}", file=sys.stderr)
        return 1

    if dst == src:
        shutil.copy2(src, src.with_suffix(src.suffix + ".full"))
    out.save(dst)
    after = dst.stat().st_size
    print(f"{dst.name}: {before // 1024}k -> {after // 1024}k, axes {left}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
