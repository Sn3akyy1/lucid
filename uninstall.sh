#!/usr/bin/env bash
# Lucid uninstaller — removes the shell and, optionally, the theming layer.
# packages installed by install.sh are left alone.

set -euo pipefail

SHELL_DIR="$HOME/.config/quickshell"
LUCID_DIR="$HOME/.config/lucid"
WALL_SCRIPT="$HOME/.config/hypr/scripts/wallpaper/set-wallpaper.sh"
STAMP="$(date +%Y%m%d-%H%M%S)"

b=$'\e[1m'; ylw=$'\e[33m'; r=$'\e[0m'
ASSUME_YES=0
[[ "${1:-}" =~ ^(-y|--yes)$ ]] && ASSUME_YES=1

ask() {
    [[ $ASSUME_YES -eq 1 ]] && return 0
    local reply
    read -rp "$1 [y/N] " reply
    [[ "$reply" =~ ^[Yy] ]]
}

# stop only the instance running this config, never someone else's shell
qs kill -p "$SHELL_DIR" 2>/dev/null || true

if [[ -d "$SHELL_DIR" ]]; then
    if ask "Move $SHELL_DIR to $SHELL_DIR.removed-$STAMP?"; then
        mv "$SHELL_DIR" "$SHELL_DIR.removed-$STAMP"
        echo "  moved (your settings and pins are still in there)"
    fi
fi

if [[ -d "$LUCID_DIR" ]] && ask "Remove the theming layer at $LUCID_DIR?"; then
    rm -rf "$LUCID_DIR"
    [[ -f "$WALL_SCRIPT" ]] && rm -f "$WALL_SCRIPT"
    echo "  removed"
fi

# the one thing install.sh put outside $HOME. leaving it would hand sddm a
# theme directory with no palette behind it
SDDM_THEME_DIR=/usr/share/sddm/themes/lucid
if [[ -d "$SDDM_THEME_DIR" ]] && ask "Remove the sddm theme at $SDDM_THEME_DIR (needs sudo)?"; then
    ACTIVE=$({ grep -rhE '^[[:space:]]*Current=' /etc/sddm.conf /etc/sddm.conf.d/*.conf 2>/dev/null || true; } \
             | tail -1 | cut -d= -f2- | tr -d '[:space:]')
    if [[ "$ACTIVE" == "lucid" ]]; then
        printf '%s warning:%s sddm is still set to Current=lucid. point it at another\n' "$ylw" "$r" >&2
        printf '           theme first, or you will get sddm'"'"'s fallback greeter.\n' >&2
    fi
    sudo rm -rf "$SDDM_THEME_DIR" && echo "  removed"
fi

printf '\n%sDone.%s Left in place, each with a timestamped backup beside it:\n' "$b" "$r"
printf '  ~/.config/matugen/config.toml   the [templates.*] blocks Lucid added\n'
printf '  ~/.config/hypr                  the lua config, binds and rules\n'
printf '  ~/.config/starship.toml         the prompt, and its init line in\n'
printf '                                  .bashrc / .zshrc / config.fish\n'
printf '  ~/.config/kitty/kitty.conf      the matugen-colors.conf and\n'
printf '                                  lucid-glass.conf includes\n'
printf '  ~/Pictures/wallpapers           the wallpapers, yours and the\n'
printf '                                  bundled ones alike\n'
printf '  ~/.local/share/icons/*-noshadow  cursor themes rebuilt without\n'
printf '                                  their shadow, if you asked for that\n'
printf 'Installed packages are left alone too.\n'
printf '%sRestore from a .backup-* file, or undo these by hand.%s\n' "$ylw" "$r"
