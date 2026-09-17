#!/usr/bin/env python3
"""Turn pywal's 16-colour output into the 36-role Material 3 palette the
shell reads.

pywal emits a terminal palette (a background, a foreground and 16 ANSI
slots); Quickshell's Theme.qml wants M3 roles. The tone-space maths that
bridges the gap lives in lucid_palette.py, shared with add-theme.py.

`wal -l` already emits a light terminal palette, so light mode needs nothing
extra here beyond telling build_palette which direction the scheme runs.

Reads  ~/.cache/wal/colors.json
Writes ~/.config/lucid/themes/pywal/quickshell.json      (dark)
       ~/.config/lucid/themes/pywal/quickshell-light.json (light)
"""
import json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lucid_palette import build_palette, tone

HOME = os.path.expanduser('~')
src = json.load(open(f'{HOME}/.cache/wal/colors.json'))
bg, fg = src['special']['background'], src['special']['foreground']
slots = [src['colors'][f'color{i}'] for i in range(16)]

# pywal slots 1-6 are the image's hues; 9-14 are its bright variants. Ranking
# happens in build_palette, so the accent is whatever the wallpaper actually
# made vivid rather than a fixed slot index.
mode = sys.argv[1] if len(sys.argv) > 1 else 'dark'
if mode not in ('dark', 'light'):
    print(f'error: mode must be dark or light (got: {mode})', file=sys.stderr)
    sys.exit(1)

pal = build_palette(bg, fg, slots[1:7] + slots[9:15], mode=mode)

# each mode keeps its own file, so switching back does not have to re-run wal
name = 'quickshell.json' if mode == 'dark' else 'quickshell-light.json'
out = f'{HOME}/.config/lucid/themes/pywal/{name}'
os.makedirs(os.path.dirname(out), exist_ok=True)
json.dump(pal, open(out, 'w'), indent=2)
print(f"pywal -> M3 ({mode}): {len(pal)} roles  surface {pal['surface']} (tone {tone(bg):.1f})  primary {pal['primary']}")
