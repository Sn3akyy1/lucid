#!/usr/bin/env bash
# wallpaper-colours.sh <image> [dark|light]
#
# the dominant colours matugen finds in an image, most dominant first, and the
# accent (primary) each would give with the current scheme type and contrast,
# as json: [{"index": 0, "source": "#rrggbb", "primary": "#rrggbb"}, ...].
# Settings -> Theme shows them to pick from. matugen offers up to four (its
# help says five, but index 4 is refused); an image with fewer stops early.
# nothing is rendered.

set -uo pipefail

IMAGE="${1:?usage: wallpaper-colours.sh <image> [dark|light]}"
MODE="${2:-$(cat "$HOME/.cache/current_mode" 2>/dev/null || echo dark)}"
[[ "$MODE" == "light" ]] || MODE=dark
[[ -f "$IMAGE" ]] || { echo "error: no image at $IMAGE" >&2; exit 1; }

# shellcheck source=matugen-options.sh
. "$HOME/.config/lucid/matugen-options.sh"

for i in 0 1 2 3; do
    out=$(matugen image "$IMAGE" -m "$MODE" -t "$MATUGEN_SCHEME" --contrast "$MATUGEN_CONTRAST" \
        --source-color-index "$i" --dry-run --json hex -q 2>/dev/null) || break
    jq -c --argjson i "$i" \
        '{index: $i, source: .colors.source_color.default.color, primary: .colors.primary.default.color}' <<< "$out"
done | jq -s -c .
