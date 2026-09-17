#!/usr/bin/env bash
# set-mode.sh <dark|light>
#
# flips the desktop between light and dark, then rebuilds the palette the same
# way the theme that is active builds it normally:
#   matugen / pywal — wallpaper-derived, so the generator is re-run in the new
#                     mode and every template it owns is rewritten with it
#   anything else   — a static palette, so apply-theme.sh picks (or synthesises)
#                     the theme's light variant
#
# the mode itself lives in ~/.cache/current_mode, beside current_theme, because
# the shell and these scripts both have to agree on it.

set -euo pipefail

MODE="${1:?usage: set-mode.sh <dark|light>}"
CACHE_DIR="$HOME/.cache"
LUCID_DIR="$HOME/.config/lucid"

if [[ "$MODE" != "dark" && "$MODE" != "light" ]]; then
    echo "error: mode must be dark or light (got: $MODE)" >&2
    exit 1
fi

mkdir -p "$CACHE_DIR"
printf '%s' "$MODE" > "$CACHE_DIR/current_mode"

THEME="$(cat "$CACHE_DIR/current_theme" 2>/dev/null || echo matugen)"
WALLPAPER="$(cat "$CACHE_DIR/current_wallpaper" 2>/dev/null || true)"

case "$THEME" in
matugen | pywal)
    if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
        echo "error: $THEME derives its colours from the wallpaper, and none is set" >&2
        exit 1
    fi
    # re-setting the same image is a no-op on screen; the point is the
    # regeneration it drives
    "$HOME/.config/hypr/scripts/wallpaper/set-wallpaper.sh" "$WALLPAPER" "$MODE"
    ;;
*)
    "$LUCID_DIR/apply-theme.sh" "$THEME" "$MODE"
    ;;
esac

echo "mode: $MODE (theme: $THEME)"
