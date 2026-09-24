#!/usr/bin/env python3
"""Shared colour maths for Lucid's theme generators.

Both generators reduce to the same problem: a background, a foreground and a
handful of accents -> the 36 roles Theme.qml reads. gen-pywal-palette.py gets
those from a wallpaper, add-theme.py from an imported scheme repo.

M3 "tone" is CIE L*, so re-toning in linear light lands a role at the
lightness the spec asks for while holding the hue it came in with.
"""
import colorsys


# ---- tone engine ----
def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gam(c):
    c = max(0.0, min(1.0, c))
    v = c * 12.92 if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055
    return max(0.0, min(1.0, v))


def P(h):
    """'#rrggbb' (or 'rrggbb', or '#rgb') -> 0-1 float triple."""
    h = h.strip().lstrip('#')
    if len(h) == 3:
        h = ''.join(ch * 2 for ch in h)
    h = h[:6]
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def hx(c):
    if isinstance(c, str):
        c = P(c)
    return '#' + ''.join(f'{round(x * 255):02x}' for x in c)


def _y(c):
    return 0.2126 * _lin(c[0]) + 0.7152 * _lin(c[1]) + 0.0722 * _lin(c[2])


def tone(c):
    if isinstance(c, str):
        c = P(c)
    y = _y(c)
    return y * 903.2963 if y <= 0.008856 else 116 * (y ** (1 / 3)) - 16


def _y_at(t):
    return t / 903.2963 if t <= 8 else ((t + 16) / 116) ** 3


def at_tone(c, t):
    """Re-tone a colour to an exact M3 tone, holding its hue. Scaling in
    linear light is what preserves the hue; the same scale on gamma-encoded
    channels would drag it."""
    if isinstance(c, str):
        c = P(c)
    target = _y_at(max(0, min(100, t)))
    y = _y(c)
    if y <= 0:
        g = _gam(target)
        return (g, g, g)
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


def hue_gap(a, b):
    d = abs(hue_sat(a)[0] - hue_sat(b)[0]) % 360
    return min(d, 360 - d)


def build_palette(bg, fg, accents, hints=None, reserve_red_for_error=False,
                  mode='dark'):
    """bg/fg/accents (hex strings) -> the 36-role dict Theme.qml reads.

    `hints` names roles the caller already knows - a base16 scheme says which
    slot is red, so `error` should not be guessed. Anything unhinted falls
    back to ranking the accents by chroma, which is all a harvested repo or a
    wallpaper can offer.

    `reserve_red_for_error` keeps red out of `primary`, and places an invented
    error as far from primary as the red band allows. Reds saturate hardest, so
    chroma ranking reaches for them first, and a red accent leaves nothing to
    tell an error state apart. Off by default: a wallpaper's own strongest
    colour should still win, red or not.

    `mode` flips every direction the scheme has: the container ladder walks down
    from the background instead of up, accents land dark instead of light, and
    each on-role swaps to the far end of its tone range. bg/fg are expected to
    already suit the mode - a light scheme wants a light bg and a dark fg.
    """
    hints = hints or {}
    light = mode == 'light'
    # +1 dark, -1 light: the sign of "more elevated means lighter"
    sgn = -1 if light else 1
    bt = tone(bg)

    cand = [c for c in accents if hue_sat(c)[1] > 0.05] or list(accents)
    if not cand:
        cand = [fg]
    ranked = sorted(cand, key=lambda c: -hue_sat(c)[1])

    _sats = sorted(hue_sat(c)[1] for c in ranked)
    BASE_SAT = max(0.30, min(0.70, _sats[len(_sats) // 2] if _sats else 0.4))

    def synth(deg, t):
        return hx(at_tone(colorsys.hls_to_rgb(deg / 360, 0.55, BASE_SAT), t))

    used = []

    def take(pred, fallback):
        """Best remaining candidate matching pred that is not already doing
        another job. A desaturated source gives near-identical slots, and
        without this the same colour landed on both primary and error - an
        error state rendering in the accent colour."""
        for c in ranked:
            if pred(c) and all(hue_gap(c, u) > 25 for u in used):
                return c
        return fallback

    def reddish(c):
        h, sat = hue_sat(c)
        return (h >= 340 or h <= 20) and sat > 0.15

    primary = hints.get('primary')
    if not primary:
        pool = [c for c in ranked if not reddish(c)] if reserve_red_for_error else []
        primary = (pool or ranked)[0]
    # M3 puts primary at tone 80 in a dark scheme and tone 40 in a light one.
    # A scheme's own can land far the wrong side; move it only when it would not
    # read against the background, so most palettes keep the colour their author
    # actually chose.
    if sgn * (tone(primary) - bt) < 45:
        primary = hx(at_tone(primary, min(80, bt + 55) if not light
                             else max(40, bt - 55)))
    used.append(primary)

    PT = tone(primary)
    # secondary has to honour the reservation too - it once took gruvbox's dark
    # red, which left nothing red for `error` and forced an invented one
    secondary = hints.get('secondary') or take(
        lambda c: hue_sat(c)[1] > 0.05 and not (reserve_red_for_error and reddish(c)),
        synth(hue_sat(primary)[0] + 40, PT))
    used.append(secondary)
    # green-ish, so Theme.isGreenish() keeps `success` actually green
    tertiary = hints.get('tertiary') or take(
        lambda c: 55 <= hue_sat(c)[0] <= 175 and hue_sat(c)[1] > 0.15, synth(145, PT))
    used.append(tertiary)
    # red-ish (the range wraps through 0). Never allowed to collapse onto
    # another role - a wrong-coloured error is worse than an invented one.
    # Nothing red left free means the red has to be invented, and `synth` is not
    # subject to the gap check above - a fixed hue once landed 9 degrees off a
    # red primary, making errors indistinguishable from the accent. Callers that
    # reserve red pick the corner of the band furthest from primary instead.
    if reserve_red_for_error:
        ph = hue_sat(primary)[0]
        far = max((350, 10, 20),
                  key=lambda d: min(abs(d - ph) % 360, 360 - abs(d - ph) % 360))
    else:
        far = 10
    error = hints.get('error') or take(lambda c: reddish(c), synth(far, PT))

    def role(c, t):
        return hx(at_tone(c, t))

    # A scheme that ships its own surface ladder keeps it; anything missing is
    # spaced around bg at M3's dark intervals. The ladder is walked in order
    # with a running floor because the two sources mix: Catppuccin names
    # surface0-2 but its overlay1 is too light to pass as a dark rung, and a
    # derived fallback that ignored the hinted rungs below it would sink under
    # them - an elevated surface rendering darker than the one it sits on.
    surf = hints.get('surfaces') or {}
    # a light ladder is tighter than a dark one - the same spread that reads as
    # depth on black reads as dirt on white
    if light:
        rungs = [('low', bt - 3), ('container', bt - 6), ('high', bt - 9),
                 ('highest', bt - 12)]
    else:
        rungs = [('low', bt + 5), ('container', bt + 9), ('high', bt + 14),
                 ('highest', bt + 19), ('bright', bt + 22)]
    ladder, edge = {}, bt
    for key, dt in rungs:
        c = surf.get(key)
        if c and sgn * (tone(c) - edge) > 0:
            ladder[key] = hx(c)
            edge = tone(c)
        else:
            t = dt if sgn * (dt - edge) >= 3 else edge + sgn * 3
            ladder[key] = role(bg, t)
            edge = t
    low = surf.get('lowest')
    if light:
        # in a light scheme `bright` is the near-white floor beside `surface`,
        # not the top of the ladder, and `lowest` is the brightest rung
        b = surf.get('bright')
        ladder['bright'] = hx(b) if (b and tone(b) > bt) else role(bg, min(100, bt + 1))
        ladder['lowest'] = hx(low) if (low and tone(low) > bt) else role(bg, min(100, bt + 3))
    else:
        ladder['lowest'] = hx(low) if (low and tone(low) < bt) else role(bg, max(0, bt - 4))

    def layer(key, t):
        return ladder[key]

    # on-roles sit at the far end of their range from the mode's background
    ON_ACCENT = 100 if light else 20
    ACCENT_CONTAINER = 90 if light else 30
    ON_ACCENT_CONTAINER = 10 if light else 90
    INVERSE_PRIMARY = 80 if light else 40
    ON_SURFACE_VARIANT = 30 if light else 80
    OUTLINE = 50 if light else 60
    INVERSE_ON_SURFACE = 95 if light else 20

    return {
        "source_color": primary,
        "primary": primary,
        "on_primary": role(primary, ON_ACCENT),
        "primary_container": role(primary, ACCENT_CONTAINER),
        "on_primary_container": role(primary, ON_ACCENT_CONTAINER),
        "inverse_primary": role(primary, INVERSE_PRIMARY),
        "secondary": secondary,
        "on_secondary": role(secondary, ON_ACCENT),
        "secondary_container": role(secondary, ACCENT_CONTAINER),
        "on_secondary_container": role(secondary, ON_ACCENT_CONTAINER),
        "tertiary": tertiary,
        "on_tertiary": role(tertiary, ON_ACCENT),
        "tertiary_container": role(tertiary, ACCENT_CONTAINER),
        "on_tertiary_container": role(tertiary, ON_ACCENT_CONTAINER),
        "error": error,
        "on_error": role(error, ON_ACCENT),
        "error_container": role(error, ACCENT_CONTAINER),
        "on_error_container": role(error, ON_ACCENT_CONTAINER),
        "surface_container_lowest": layer("lowest", max(0, bt - 4)),
        "surface": bg,
        "surface_dim": bg,
        "surface_container_low": layer("low", bt + 5),
        "surface_container": layer("container", bt + 9),
        "surface_container_high": layer("high", bt + 14),
        "surface_container_highest": layer("highest", bt + 19),
        "surface_bright": layer("bright", bt + 22),
        "surface_tint": primary,
        "on_surface": fg,
        "on_surface_variant": role(fg, ON_SURFACE_VARIANT),
        "surface_variant": layer("high", bt + 14),
        "outline": role(fg, OUTLINE),
        "outline_variant": layer("highest", bt + 19),
        "inverse_surface": fg,
        "inverse_on_surface": role(bg, INVERSE_ON_SURFACE),
        "shadow": "#000000",
        "scrim": "#000000",
    }


# a dark scheme's ground and ink, and the tone M3 puts an accent at on top of
# it: gen-light-palette.py's window for a light scheme, mirrored. The ink gets
# a window too, where the text of Lucid's dark themes sits; a light ground
# taken whole would glare
DARK_SURFACE_MIN, DARK_SURFACE_MAX = 6.0, 12.0
DARK_INK_MIN, DARK_INK_MAX = 85.0, 90.0
DARK_ACCENT_TONE = 80.0


def dark_side(pal):
    """A light palette (the 36 roles) -> the same palette as a dark scheme.

    gen-light-palette.py the other way round, for a scheme authored light:
    its ink becomes the ground and its ground the ink, each clamped into the
    window Lucid's dark themes sit in, which keeps the neutral hues that make
    the scheme recognisable. The accents keep their hue and chroma and move to
    the tone M3 gives them on a dark ground.
    """
    light_bg, light_fg = pal["surface"], pal["on_surface"]
    bg = hx(at_tone(light_fg, min(DARK_SURFACE_MAX, max(DARK_SURFACE_MIN, tone(light_fg)))))
    fg = hx(at_tone(light_bg, min(DARK_INK_MAX, max(DARK_INK_MIN, tone(light_bg)))))
    hints = {role: hx(at_tone(pal[role], DARK_ACCENT_TONE))
             for role in ("primary", "secondary", "tertiary", "error") if pal.get(role)}
    return build_palette(bg, fg, list(hints.values()), hints, mode="dark")


# hue bands, named the way a theme author would
_HUE_NAMES = [(15, "red"), (40, "orange"), (62, "amber"), (85, "olive"),
              (160, "green"), (188, "teal"), (205, "cyan"), (225, "blue"),
              (250, "indigo"), (280, "violet"), (315, "purple"),
              (340, "magenta"), (352, "pink"), (361, "red")]


def hue_name(h):
    for edge, name in _HUE_NAMES:
        if h < edge:
            return name
    return "red"


def _surface_word(c):
    t, (h, s) = tone(c), hue_sat(c)
    if t >= 50:
        # a light scheme's ground
        if s < 0.10:
            return "white" if t >= 95 else "light grey"
        return f"{'pale' if t >= 90 else 'light'} {hue_name(h)}"
    if s < 0.10:
        return "near-black" if t < 8 else ("charcoal" if t < 16 else "slate")
    shade = "deep" if t < 12 else ("dark" if t < 22 else "dim")
    return f"{shade} {hue_name(h)}"


def _accent_word(c):
    h, s = hue_sat(c)
    n = hue_name(h)
    if s < 0.35:
        return f"muted {n}"
    return f"vivid {n}" if s > 0.85 else n


def describe(pal):
    """A one-line description in the same voice as the shipped themes.

    An imported scheme has no blurb of its own, and the palette is the only
    thing that reliably says what it looks like. Naming a second accent was
    tried and dropped: tertiary is forced green-ish for `success` so it says
    nothing, and neither it nor secondary told any two schemes apart that the
    surface and primary had not already separated.
    """
    surf = _surface_word(pal["surface"])
    acc = _accent_word(pal["primary"])
    # "dark blue with blue accents" says nothing; name the lift instead
    if hue_name(hue_sat(pal["surface"])[0]) in acc and hue_sat(pal["surface"])[1] >= 0.10:
        lift = tone(pal["primary"]) - tone(pal["surface"])
        # on a light ground the accent sits below it
        if lift < 0:
            acc = "deeper " + acc.split()[-1]
        else:
            acc = ("brighter " if lift > 45 else "lifted ") + acc.split()[-1]
    return f"{surf.capitalize()} with {acc} accents"
