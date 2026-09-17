#!/usr/bin/env python3
"""Synthesise a light palette from a theme's own dark one.

The five shipped themes (and anything add-theme.py imports) are authored dark
only, so light mode has nothing to switch to. Rather than invent a neutral
white scheme and lose the theme, this inverts it in tone space: a theme's
foreground is already the light surface its author chose - Nord's #eceff4 is
Snow Storm, Gruvbox's #ebdbb2 is its own cream - so swapping ground and ink
keeps the neutral hue that makes the theme recognisable. The accents keep
their hue and chroma and are re-toned to where M3 puts them in a light scheme.

Reads  themes/<id>/quickshell.json
Writes themes/<id>/quickshell-light.json
"""
import json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lucid_palette import build_palette, tone, at_tone, hx, P

# a light scheme's ground, and the tone M3 puts an accent at on top of it
SURFACE_MIN, SURFACE_MAX = 92.0, 98.0
INK_MAX = 20.0
ACCENT_TONE = 40.0


def invert(pal):
    """The 36-role dark dict -> the same palette as a light scheme."""
    dark_bg, dark_fg = P(pal['surface']), P(pal['on_surface'])

    # the theme's own ink becomes the ground, clamped into a window that still
    # reads as a light theme; its ground becomes the ink
    bg = hx(at_tone(dark_fg, min(SURFACE_MAX, max(SURFACE_MIN, tone(dark_fg)))))
    fg = hx(at_tone(dark_bg, min(INK_MAX, tone(dark_bg))))

    # accents keep hue and chroma, and move to where they read on a light ground.
    # hinted, because these are the colours the theme is actually known for and
    # ranking them again would just re-derive what we already know
    hints = {}
    for role in ('primary', 'secondary', 'tertiary', 'error'):
        c = pal.get(role)
        if c:
            hints[role] = hx(at_tone(P(c), ACCENT_TONE))

    return build_palette(bg, fg, list(hints.values()), hints, mode='light')


def main():
    if len(sys.argv) != 2:
        print('usage: gen-light-palette.py <theme-dir|theme-id>', file=sys.stderr)
        return 2
    arg = sys.argv[1]
    d = arg if os.path.isdir(arg) else os.path.expanduser(f'~/.config/lucid/themes/{arg}')
    src = os.path.join(d, 'quickshell.json')
    if not os.path.isfile(src):
        print(f'error: no palette at {src}', file=sys.stderr)
        return 1

    pal = invert(json.load(open(src)))
    out = os.path.join(d, 'quickshell-light.json')
    json.dump(pal, open(out, 'w'), indent=2)
    print(f"light: surface {pal['surface']} (tone {tone(P(pal['surface'])):.1f})  "
          f"primary {pal['primary']}  -> {out}")
    return 0


if __name__ == '__main__':
    sys.exit(main())
