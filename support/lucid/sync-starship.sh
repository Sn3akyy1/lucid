#!/usr/bin/env bash
# sync-starship.sh [palette.json]
#
# repaints the starship prompt with the active palette. only the colours in the
# table its `palette = '...'` line names are rewritten, so the prompt's format,
# modules and symbols stay whatever the user made them. every theme lands here:
# apply-theme.sh for pywal and the static palettes, set-wallpaper.sh after
# matugen. the slots are the ones support/look/starship.toml is drawn with.

set -euo pipefail

PALETTE="${1:-$HOME/.cache/quickshell/matugen.json}"
STARSHIP="${STARSHIP_CONFIG:-$HOME/.config/starship.toml}"

[[ -f "$STARSHIP" && -f "$PALETTE" ]] || exit 0

if ! command -v jq &>/dev/null; then
    echo "error: jq is required" >&2
    exit 1
fi

c() { jq -r --arg k "$1" '.[$k] // empty' "$PALETTE"; }

# a prompt without a palette table has nothing here to repaint
NAME=$(sed -n "s/^[[:space:]]*palette[[:space:]]*=[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p" "$STARSHIP" | head -1)
[[ -n "$NAME" ]] || exit 0
grep -q "^\[palettes\.$NAME\]" "$STARSHIP" || exit 0

PRIMARY=$(c primary)
ON_PRIMARY=$(c on_primary)
PRIMARY_FIXED_DIM=$(c primary_fixed_dim)
PRIMARY_FIXED_DIM="${PRIMARY_FIXED_DIM:-$PRIMARY}"
[[ -n "$PRIMARY" ]] || exit 0

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

awk -v table="[palettes.$NAME]" -v q="'" \
    -v c1="$PRIMARY_FIXED_DIM" \
    -v c2="$ON_PRIMARY" \
    -v c3="$(c on_surface_variant)" \
    -v c4="$(c surface_container)" \
    -v c5="$ON_PRIMARY" \
    -v c6="$(c surface_dim)" \
    -v c7="$(c surface)" \
    -v c8="$PRIMARY" \
    -v c9="$PRIMARY" '
    BEGIN {
        m["color1"] = c1; m["color2"] = c2; m["color3"] = c3
        m["color4"] = c4; m["color5"] = c5; m["color6"] = c6
        m["color7"] = c7; m["color8"] = c8; m["color9"] = c9
        re = "=[ \t]*[" q "\"][^" q "\"]*[" q "\"]"
    }
    {
        t = $0
        gsub(/^[ \t]+|[ \t]+$/, "", t)
        if (substr(t, 1, 1) == "[") { inside = (t == table); print; next }
        if (inside && match($0, /^[ \t]*color[1-9][ \t]*=/)) {
            k = t
            sub(/[ \t]*=.*/, "", k)
            if (k in m && m[k] != "")
                sub(re, "= " q m[k] q, $0)
        }
        print
    }' "$STARSHIP" > "$TMP"

# unchanged is the common case (a wallpaper that lands on the same accent)
cmp -s "$TMP" "$STARSHIP" && exit 0

# written through rather than renamed over, so a symlinked dotfile stays a link
cat "$TMP" > "$STARSHIP"

# repaint running shells so open terminals recolour without reopening.
# SIGWINCH is a redraw nudge, not fatal, so it is safe to broadcast.
for sh in fish bash zsh; do
    pkill -WINCH -x "$sh" 2>/dev/null || true
done
