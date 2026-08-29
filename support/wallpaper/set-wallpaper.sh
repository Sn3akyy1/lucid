#!/usr/bin/env bash
# set-wallpaper.sh <path-to-image> [dark|light]
#
# sets the wallpaper, then regenerates colours if the active theme derives
# them from the image. ~/.cache/current_theme decides:
#   matugen  — matugen regenerates every template it is configured for
#   pywal    — wal extracts, gen-pywal-palette.py maps it to material roles
#   anything else — a static theme owns its palette, so colours are left alone
#
# the wallpaper is set first because it is the only step you actually see.

set -euo pipefail

WALLPAPER="${1:-}"
MODE="${2:-dark}"
CACHE_DIR="$HOME/.cache"
CURRENT_WALL_FILE="$CACHE_DIR/current_wallpaper"
CURRENT_THEME_FILE="$CACHE_DIR/current_theme"
LUCID_DIR="$HOME/.config/lucid"

CURRENT_THEME="$(cat "$CURRENT_THEME_FILE" 2>/dev/null || echo matugen)"

usage() {
    echo "usage: $(basename "$0") <path-to-image> [dark|light]"
    exit 1
}

[[ -z "$WALLPAPER" ]] && { echo "error: no wallpaper path given" >&2; usage; }

WALLPAPER="${WALLPAPER/#\~/$HOME}"

[[ -f "$WALLPAPER" ]] || { echo "error: file not found: $WALLPAPER" >&2; exit 1; }

if [[ "$MODE" != "dark" && "$MODE" != "light" ]]; then
    echo "error: mode must be dark or light (got: $MODE)" >&2
    usage
fi

# wallpaper daemon: awww, falling back to swww
if command -v awww &>/dev/null; then
    WP_CLI=awww; WP_DAEMON=awww-daemon
elif command -v swww &>/dev/null; then
    WP_CLI=swww; WP_DAEMON="swww-daemon"
else
    echo "error: neither awww nor swww is installed" >&2
    exit 1
fi

if ! "$WP_CLI" query &>/dev/null; then
    "$WP_DAEMON" &>/dev/null &
    sleep 0.5
fi

"$WP_CLI" img "$WALLPAPER" \
    --transition-type fade \
    --transition-duration 1 \
    --transition-fps 60

mkdir -p "$CACHE_DIR"
printf '%s' "$WALLPAPER" > "$CURRENT_WALL_FILE"

case "$CURRENT_THEME" in
matugen)
    if ! command -v matugen &>/dev/null; then
        echo "warning: matugen not installed, colours unchanged" >&2
        exit 0
    fi
    # --source-color-index keeps it non-interactive, so it can't hang on a
    # picker prompt it will never receive from a keybind
    matugen image "$WALLPAPER" -m "$MODE" --source-color-index 0
    hyprctl reload &>/dev/null || true
    ;;
pywal)
    if ! command -v wal &>/dev/null; then
        echo "warning: pywal not installed, colours unchanged" >&2
        exit 0
    fi
    # -n leaves the wallpaper alone, it is already set above
    wal -i "$WALLPAPER" -n -s -t -e -q || echo "warning: wal failed" >&2
    if "$LUCID_DIR/gen-pywal-palette.py"; then
        "$LUCID_DIR/apply-theme.sh" pywal
    else
        echo "warning: pywal palette generation failed" >&2
    fi
    hyprctl reload &>/dev/null || true
    ;;
*)
    echo "static theme ($CURRENT_THEME) — colours unchanged"
    ;;
esac

echo "done: $WALLPAPER ($MODE, theme: $CURRENT_THEME)"
