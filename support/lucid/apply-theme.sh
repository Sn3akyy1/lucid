#!/usr/bin/env bash
# apply-theme.sh <theme-id>
#
# copies a static theme's palette into the cache Lucid reads, and mirrors it
# into kitty and GTK if those are present. matugen and pywal don't go through
# here — they generate their own palette and write the cache directly.

set -euo pipefail

THEME="${1:?usage: apply-theme.sh <theme-id>}"
PALETTE="$HOME/.config/lucid/themes/$THEME/quickshell.json"

if [[ ! -f "$PALETTE" ]]; then
    echo "error: no palette at $PALETTE" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "error: jq is required" >&2
    exit 1
fi

c() { jq -r --arg k "$1" '.[$k] // empty' "$PALETTE"; }

PRIMARY=$(c primary)
ON_PRIMARY=$(c on_primary)
SECONDARY=$(c secondary)
SECONDARY_CONTAINER=$(c secondary_container)
TERTIARY=$(c tertiary)
ERROR=$(c error)
SURFACE=$(c surface)
ON_SURFACE=$(c on_surface)
SURFACE_VARIANT=$(c surface_variant)
SURFACE_DIM=$(c surface_dim)

# lucid — the only required output
mkdir -p "$HOME/.cache/quickshell"
cp "$PALETTE" "$HOME/.cache/quickshell/matugen.json"

# kitty — 16 ansi slots over fewer roles, so some slots repeat
if [[ -d "$HOME/.config/kitty" ]]; then
    cat > "$HOME/.config/kitty/matugen-colors.conf" <<EOF
foreground $ON_SURFACE
background $SURFACE
selection_foreground $ON_SURFACE
selection_background $SECONDARY_CONTAINER
cursor $ON_SURFACE
cursor_text_color $SURFACE
active_tab_foreground $SURFACE
active_tab_background $PRIMARY
inactive_tab_foreground $ON_SURFACE
inactive_tab_background $SURFACE_VARIANT
color0 $SURFACE
color8 $SURFACE_VARIANT
color1 $ERROR
color9 $ERROR
color2 $PRIMARY
color10 $PRIMARY
color3 $SECONDARY
color11 $SECONDARY
color4 $TERTIARY
color12 $TERTIARY
color5 $TERTIARY
color13 $TERTIARY
color6 $SECONDARY
color14 $SECONDARY
color7 $ON_SURFACE
color15 $ON_SURFACE
EOF
    killall -SIGUSR1 kitty 2>/dev/null || true
fi

# gtk — only where the app already has a config dir
for gtkdir in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"; do
    [[ -d "$gtkdir" ]] || continue
    cat > "$gtkdir/colors.css" <<EOF
@define-color accent_color $PRIMARY;
@define-color accent_fg_color $ON_PRIMARY;
@define-color accent_bg_color $PRIMARY;
@define-color window_bg_color $SURFACE_DIM;
@define-color window_fg_color $ON_SURFACE;
@define-color headerbar_bg_color $SURFACE_DIM;
@define-color headerbar_fg_color $ON_SURFACE;
@define-color popover_bg_color $SURFACE_DIM;
@define-color popover_fg_color $ON_SURFACE;
@define-color view_bg_color $SURFACE;
@define-color view_fg_color $ON_SURFACE;
@define-color card_bg_color $SURFACE;
@define-color card_fg_color $ON_SURFACE;
@define-color sidebar_bg_color @window_bg_color;
@define-color sidebar_fg_color @window_fg_color;
@define-color sidebar_border_color @window_bg_color;
@define-color sidebar_backdrop_color @window_bg_color;
EOF
done

echo "applied theme '$THEME'"
