#!/usr/bin/env bash
# apply-theme.sh <theme-id>
#
# copies a theme's palette into the cache Lucid reads, then mirrors it into
# kitty, spicetify's Sleek theme, VSCodium, Vesktop, GTK, starship and Steam —
# each one only if it is actually installed. pywal comes through here once
# gen-pywal-palette.py has written its palette; matugen does not — it drives
# those same apps from its own templates.

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
strip() { echo "${1#\#}"; }

PRIMARY=$(c primary)
ON_PRIMARY=$(c on_primary)
PRIMARY_CONTAINER=$(c primary_container)
SECONDARY=$(c secondary)
SECONDARY_CONTAINER=$(c secondary_container)
TERTIARY=$(c tertiary)
ERROR=$(c error)
ERROR_CONTAINER=$(c error_container)
SURFACE=$(c surface)
ON_SURFACE=$(c on_surface)
SURFACE_VARIANT=$(c surface_variant)
ON_SURFACE_VARIANT=$(c on_surface_variant)
SURFACE_DIM=$(c surface_dim)
SURFACE_CONTAINER_LOW=$(c surface_container_low)
SURFACE_CONTAINER=$(c surface_container)
SURFACE_CONTAINER_HIGH=$(c surface_container_high)
SURFACE_CONTAINER_HIGHEST=$(c surface_container_highest)
OUTLINE=$(c outline)
OUTLINE_VARIANT=$(c outline_variant)
SHADOW=$(c shadow)

# roles the matugen templates want that the older palettes never defined; use
# the real one where a palette has it, otherwise the nearest role it does
INVERSE_PRIMARY=$(c inverse_primary); INVERSE_PRIMARY="${INVERSE_PRIMARY:-$SECONDARY}"
TERTIARY_CONTAINER=$(c tertiary_container); TERTIARY_CONTAINER="${TERTIARY_CONTAINER:-$SECONDARY_CONTAINER}"
SURFACE_BRIGHT=$(c surface_bright); SURFACE_BRIGHT="${SURFACE_BRIGHT:-$SURFACE_CONTAINER_HIGH}"
PRIMARY_FIXED_DIM=$(c primary_fixed_dim); PRIMARY_FIXED_DIM="${PRIMARY_FIXED_DIM:-$PRIMARY}"

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

# spotify — spicetify's Sleek theme reads color.ini, hex without the leading #
SLEEK_DIR="$HOME/.config/spicetify/Themes/Sleek"
if [[ -d "$SLEEK_DIR" ]]; then
    cat > "$SLEEK_DIR/color.ini" <<EOF
[matugen]
text                = $(strip "$ON_SURFACE")
subtext             = $(strip "$ON_SURFACE_VARIANT")
main                = $(strip "$SURFACE")
sidebar             = $(strip "$SURFACE_CONTAINER")
player              = $(strip "$SURFACE_CONTAINER_HIGH")
card                = $(strip "$SURFACE_CONTAINER_LOW")
shadow              = $(strip "$SHADOW")
selected-row        = $(strip "$SURFACE_CONTAINER_HIGHEST")
button              = $(strip "$PRIMARY")
button-active       = $(strip "$SECONDARY")
button-disabled     = $(strip "$OUTLINE")
tab-active          = $(strip "$SECONDARY_CONTAINER")
notification        = $(strip "$PRIMARY")
notification-error  = $(strip "$ERROR")
misc                = $(strip "$OUTLINE_VARIANT")
EOF
    spicetify apply --no-restart &>/dev/null &
fi

# vscodium — the matugen theme extension hashes the raw list to spot a change
# and reads it without a fallback, so it has to be written alongside the json
mkdir -p "$HOME/.cache/matugen"
cat > "$HOME/.cache/matugen/vscode-colors" <<EOF
$SURFACE
$ERROR
$PRIMARY
$TERTIARY
$SECONDARY
$INVERSE_PRIMARY
$OUTLINE
$ON_SURFACE
$SURFACE_CONTAINER_HIGHEST
$ERROR_CONTAINER
$PRIMARY_CONTAINER
$TERTIARY_CONTAINER
$SECONDARY_CONTAINER
$INVERSE_PRIMARY
$OUTLINE_VARIANT
$ON_SURFACE_VARIANT
EOF
cat > "$HOME/.cache/matugen/vscode-colors.json" <<EOF
{
  "workbench.colorCustomizations": {
    "editor.background": "$SURFACE",
    "editor.foreground": "$ON_SURFACE",
    "sideBar.background": "$SURFACE_CONTAINER",
    "sideBar.foreground": "$ON_SURFACE_VARIANT",
    "activityBar.background": "$SURFACE_CONTAINER_HIGH",
    "activityBar.foreground": "$PRIMARY",
    "statusBar.background": "$SURFACE_CONTAINER_LOW",
    "statusBar.foreground": "$ON_SURFACE",
    "titleBar.activeBackground": "$SURFACE",
    "titleBar.activeForeground": "$ON_SURFACE"
  }
}
EOF

# discord — vesktop watches its theme files and reloads them live
if [[ -d "$HOME/.config/vesktop/themes" ]]; then
    cat > "$HOME/.config/vesktop/themes/midnight-discord.css" <<EOF
/**
 * @name midnight
 * @description A dark, rounded discord theme.
 * @author refact0r
 * @version 1.6.2
 * @source https://github.com/refact0r/midnight-discord/blob/master/midnight.theme.css
*/

@import url('https://refact0r.github.io/midnight-discord/build/midnight.css');

:root {
	--font: 'figtree';
	--corner-text: 'Midnight';

    --online-indicator: $INVERSE_PRIMARY;
	--dnd-indicator: $ERROR;
	--idle-indicator: $TERTIARY_CONTAINER;
	--streaming-indicator: $ON_PRIMARY;

    --accent-1: $TERTIARY;
	--accent-2: $PRIMARY;
	--accent-3: $PRIMARY;
	--accent-4: $SURFACE_BRIGHT;
	--accent-5: $PRIMARY_FIXED_DIM;
    --accent-new: $INVERSE_PRIMARY;
	--mention: $SURFACE;
	--mention-hover: $SURFACE_BRIGHT;

	--text-0: $SURFACE;
	--text-1: $ON_SURFACE;
	--text-2: $ON_SURFACE;
	--text-3: $ON_SURFACE_VARIANT;
	--text-4: $ON_SURFACE_VARIANT;
	--text-5: $OUTLINE;

    --bg-1: $SURFACE_VARIANT;
	--bg-2: $SURFACE_CONTAINER_HIGH;
	--bg-3: $SURFACE_CONTAINER_LOW;
	--bg-4: $SURFACE;
	--hover: $SURFACE_BRIGHT;
	--active: $SURFACE_BRIGHT;
	--message-hover: $SURFACE_BRIGHT;

	--spacing: 12px;
	--list-item-transition: 0.2s ease;
	--unread-bar-transition: 0.2s ease;
	--moon-spin-transition: 0.4s ease;
	--icon-spin-transition: 1s ease;

	--roundness-xl: 22px;
	--roundness-l: 20px;
	--roundness-m: 16px;
	--roundness-s: 12px;
	--roundness-xs: 10px;
	--roundness-xxs: 8px;

	--discord-icon: none;
	--moon-icon: block;
	--moon-icon-url: url('https://upload.wikimedia.org/wikipedia/commons/c/c4/Font_Awesome_5_solid_moon.svg');
	--moon-icon-size: auto;

	--login-bg-filter: saturate(0.3) hue-rotate(-15deg) brightness(0.4);
	--green-to-accent-3-filter: hue-rotate(56deg) saturate(1.43);
	--blurple-to-accent-3-filter: hue-rotate(304deg) saturate(0.84) brightness(1.2);
}

.selected_f5eb4b,
.selected_f6f816 .link_d8bfb3 {
  color: var(--text-0) !important;
  background: var(--accent-3) !important;
}

.selected_f6f816 .link_d8bfb3 * {
  color: var(--text-0) !important;
  fill: var(--text-0) !important;
}
EOF
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

# gtk apps only repaint when the theme name changes, so toggle it off and back
if [[ "$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null)" != "" ]]; then
    GTK_THEME_NAME=$(gsettings get org.gnome.desktop.interface gtk-theme)
    gsettings set org.gnome.desktop.interface gtk-theme "" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme "${GTK_THEME_NAME//\'/}" 2>/dev/null || true
fi

# starship — only the palette is rewritten, the prompt format stays the user's.
# roles mirror matugen's starship template so both paths land on the same look.
STARSHIP="$HOME/.config/starship.toml"
if [[ -f "$STARSHIP" ]]; then
    SP_NAME=$(sed -n "s/^[[:space:]]*palette[[:space:]]*=[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p" "$STARSHIP" | head -1)
    if [[ -n "$SP_NAME" ]] && grep -q "^\[palettes\.$SP_NAME\]" "$STARSHIP"; then
        awk -v table="[palettes.$SP_NAME]" -v q="'" \
            -v c1="$PRIMARY_FIXED_DIM" \
            -v c2="$ON_PRIMARY" \
            -v c3="$(c on_surface_variant)" \
            -v c4="$(c surface_container)" \
            -v c5="$ON_PRIMARY" \
            -v c6="$SURFACE_DIM" \
            -v c7="$SURFACE" \
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
            }' "$STARSHIP" > "$STARSHIP.lucid-tmp" && mv "$STARSHIP.lucid-tmp" "$STARSHIP"

        # repaint running shells so open terminals recolour without reopening.
        # SIGWINCH is a redraw nudge, not fatal, so it is safe to broadcast.
        for sh in fish bash zsh; do
            pkill -WINCH -x "$sh" 2>/dev/null || true
        done
    fi
fi

# steam — millennium's material theme has its own matugen config
if command -v matugen &>/dev/null && [[ -f "$HOME/.config/matugen-steam/config.toml" ]]; then
    matugen -c "$HOME/.config/matugen-steam/config.toml" color hex "$PRIMARY" -m dark &>/dev/null &
fi

# sddm — the login screen cannot read a per-user palette, so paint the theme.
# a no-op unless the theme file is writable by whoever is applying.
"$HOME/.config/lucid/sync-sddm.sh" "$PALETTE" 2>/dev/null || true

echo "applied theme '$THEME'"
