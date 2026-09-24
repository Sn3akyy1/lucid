#!/usr/bin/env bash
# apply-colour.sh [dark|light]
#
# the "colour" theme: a whole palette that matugen builds from one colour, the
# one picked in Settings -> Theme, with the scheme type and contrast the
# wallpaper uses too. every template renders from it through
# render-templates.sh, Lucid's own palette included, exactly as it does for the
# wallpaper. templates that name the wallpaper ({{image}}) get the one on
# screen. see matugen-options.sh for where the settings come from.

set -euo pipefail

LUCID_DIR="$HOME/.config/lucid"
MODE="${1:-$(cat "$HOME/.cache/current_mode" 2>/dev/null || echo dark)}"

if [[ "$MODE" != "dark" && "$MODE" != "light" ]]; then
    echo "error: mode must be dark or light (got: $MODE)" >&2
    exit 1
fi
for tool in matugen jq; do
    command -v "$tool" &>/dev/null || { echo "error: $tool is required" >&2; exit 1; }
done

# shellcheck source=matugen-options.sh
. "$LUCID_DIR/matugen-options.sh"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

matugen color hex "$THEME_COLOUR" -m "$MODE" -t "$MATUGEN_SCHEME" --contrast "$MATUGEN_CONTRAST" \
    --dry-run --json hex -q > "$WORK/scheme.json"
jq --arg image "$(cat "$HOME/.cache/current_wallpaper" 2>/dev/null || true)" '.image = $image' \
    "$WORK/scheme.json" > "$WORK/colours.json"

"$LUCID_DIR/render-templates.sh" "$WORK/colours.json" "$MODE" colour || true
# the login screen cannot read a per-user palette, so paint the theme
"$LUCID_DIR/sync-sddm.sh" 2>/dev/null || true

echo "applied colour $THEME_COLOUR ($MATUGEN_SCHEME, contrast $MATUGEN_CONTRAST, $MODE)"
