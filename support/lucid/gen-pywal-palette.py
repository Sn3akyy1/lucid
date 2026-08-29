#!/usr/bin/env python3
"""Turn pywal's 16-colour output into the 36-role Material 3 palette the
shell reads.

pywal emits a terminal palette (a background, a foreground and 16 ANSI
slots); Quickshell's Theme.qml wants M3 roles. The gap is bridged the same
way the rest of this config does it - in tone space (M3 "tone" is CIE L*),
so a role lands at the lightness the spec asks for while keeping the hue
pywal pulled out of the wallpaper.

Reads  ~/.cache/wal/colors.json
Writes ~/.config/lucid/themes/pywal/quickshell.json
"""
import json, os, colorsys

# ---- tone engine (same maths as Theme.qml's) ----
def _lin(c):  return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
def _gam(c):
    c = max(0.0, min(1.0, c))
    v = c * 12.92 if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055
    return max(0.0, min(1.0, v))

def P(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

def hx(c):
    return '#' + ''.join(f'{round(x * 255):02x}' for x in c)

def _y(c):
    return 0.2126 * _lin(c[0]) + 0.7152 * _lin(c[1]) + 0.0722 * _lin(c[2])

def tone(c):
    if isinstance(c, str): c = P(c)
    y = _y(c)
    return y * 903.2963 if y <= 0.008856 else 116 * (y ** (1 / 3)) - 16

def _y_at(t):
    return t / 903.2963 if t <= 8 else ((t + 16) / 116) ** 3

def at_tone(c, t):
    """Re-tone a colour to an exact M3 tone, holding its hue. Scaling in
    linear light is what preserves the hue; the same scale on gamma-encoded
    channels would drag it."""
    if isinstance(c, str): c = P(c)
    target = _y_at(max(0, min(100, t)))
    y = _y(c)
    if y <= 0:
        g = _gam(target); return (g, g, g)
    l = [_lin(x) * (target / y) for x in c]
    peak = max(l)
    if peak > 1:
        # scaling alone would clip a channel and skew the hue, so desaturate
        # toward white instead - what a tonal palette does near tone 100
        l = [x / peak for x in l]
        yb = 0.2126 * l[0] + 0.7152 * l[1] + 0.0722 * l[2]
        w = 0 if yb >= 1 else max(0, min(1, (target - yb) / (1 - yb)))
        l = [x + (1 - x) * w for x in l]
    return tuple(_gam(x) for x in l)

def hue_sat(c):
    h, _, s = colorsys.rgb_to_hls(*(P(c) if isinstance(c, str) else c))
    return h * 360, s

HOME = os.path.expanduser('~')
src = json.load(open(f'{HOME}/.cache/wal/colors.json'))
bg, fg = src['special']['background'], src['special']['foreground']
slots = [src['colors'][f'color{i}'] for i in range(16)]
bt = tone(bg)

# --- accents -------------------------------------------------------------
# pywal slots 1-6 are the image's hues; 9-14 are its bright variants. Rank by
# chroma and take the strongest as primary, so the accent is whatever the
# wallpaper actually made vivid rather than a fixed slot index.
cand = [c for c in slots[1:7] + slots[9:15] if hue_sat(c)[1] > 0.05]
if not cand:
    cand = slots[1:7]
ranked = sorted(cand, key=lambda c: -hue_sat(c)[1])

def hue_gap(a, b):
    d = abs(hue_sat(a)[0] - hue_sat(b)[0]) % 360
    return min(d, 360 - d)

# Typical chroma of this wallpaper's palette, used when a role has to be
# synthesised so the invented colour still belongs to the scheme.
_sats = sorted(hue_sat(c)[1] for c in ranked)
BASE_SAT = max(0.30, min(0.70, _sats[len(_sats) // 2] if _sats else 0.4))

def synth(deg, t):
    return hx(at_tone(colorsys.hls_to_rgb(deg / 360, 0.55, BASE_SAT), t))

used = []
def take(pred, fallback):
    """Best remaining candidate matching pred that is not already doing
    another job. A desaturated wallpaper gives pywal six near-identical
    slots, and without this the same colour landed on both primary and
    error - an error state rendering in the accent colour."""
    for c in ranked:
        if pred(c) and all(hue_gap(c, u) > 25 for u in used):
            return c
    return fallback

primary = ranked[0]
# M3 puts primary at tone 80 in a dark scheme. pywal's can land far darker;
# lift only when it would not read against the background, so most palettes
# keep their colour exactly as pywal chose it.
if tone(primary) < bt + 45:
    primary = hx(at_tone(primary, min(80, bt + 55)))
used.append(primary)

PT = tone(primary)
secondary = take(lambda c: hue_sat(c)[1] > 0.05, synth(hue_sat(primary)[0] + 40, PT))
used.append(secondary)
# green-ish, so Theme.isGreenish() keeps `success` actually green
tertiary = take(lambda c: 55 <= hue_sat(c)[0] <= 175 and hue_sat(c)[1] > 0.15, synth(145, PT))
used.append(tertiary)
# red-ish (the range wraps through 0). Never allowed to collapse onto
# another role - a wrong-coloured error is worse than an invented one.
error = take(lambda c: (hue_sat(c)[0] >= 340 or hue_sat(c)[0] <= 20) and hue_sat(c)[1] > 0.15, synth(10, PT))

def role(c, t):  return hx(at_tone(c, t))

pal = {
    "source_color": primary,
    "primary": primary,
    "on_primary": role(primary, 20),
    "primary_container": role(primary, 30),
    "on_primary_container": role(primary, 90),
    "inverse_primary": role(primary, 40),
    "secondary": secondary,
    "on_secondary": role(secondary, 20),
    "secondary_container": role(secondary, 30),
    "on_secondary_container": role(secondary, 90),
    "tertiary": tertiary,
    "on_tertiary": role(tertiary, 20),
    "tertiary_container": role(tertiary, 30),
    "on_tertiary_container": role(tertiary, 90),
    "error": error,
    "on_error": role(error, 20),
    "error_container": role(error, 30),
    "on_error_container": role(error, 90),
    # pywal's own background stays `surface` - that is what kitty, VSCodium
    # and GTK use - with the container ladder spaced around it at M3's dark
    # intervals instead of pywal's flat single tone.
    "surface_container_lowest": role(bg, max(0, bt - 4)),
    "surface": bg,
    "surface_dim": bg,
    "surface_container_low": role(bg, bt + 5),
    "surface_container": role(bg, bt + 9),
    "surface_container_high": role(bg, bt + 14),
    "surface_container_highest": role(bg, bt + 19),
    "surface_bright": role(bg, bt + 22),
    "surface_tint": primary,
    "on_surface": fg,
    "on_surface_variant": role(fg, 80),
    "surface_variant": role(bg, bt + 14),
    "outline": role(fg, 60),
    "outline_variant": role(bg, bt + 19),
    "inverse_surface": fg,
    "inverse_on_surface": role(bg, 20),
    "shadow": "#000000",
    "scrim": "#000000",
}
out = f'{HOME}/.config/lucid/themes/pywal/quickshell.json'
os.makedirs(os.path.dirname(out), exist_ok=True)
json.dump(pal, open(out, 'w'), indent=2)
print(f"pywal -> M3: {len(pal)} roles  surface {pal['surface']} (tone {bt:.1f})  primary {pal['primary']}")
