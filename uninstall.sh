#!/usr/bin/env bash
# Lucid uninstaller — removes the shell and, optionally, the theming layer,
# and puts back what install.sh recorded from before it changed things.
# packages installed by install.sh are left alone.

set -euo pipefail

SHELL_DIR="$HOME/.config/quickshell"
LUCID_DIR="$HOME/.config/lucid"
HYPR_DIR="$HOME/.config/hypr"
WALL_SCRIPT="$HYPR_DIR/scripts/wallpaper/set-wallpaper.sh"
BEFORE="${XDG_STATE_HOME:-$HOME/.local/state}/lucid/before-install"
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

warn() { printf '%s warning:%s %s\n' "$ylw" "$r" "$*" >&2; }

# what install.sh wrote down the first time; empty for an install older than that
before() { { sed -n "s/^$1=//p" "$BEFORE" 2>/dev/null || true; } | head -1; }

dm_name() {
    local n=${1%%@*}; n=${n%.service}
    case $n in
        gdm|lxdm|xdm) echo "${n^^}" ;;
        lightdm)      echo LightDM ;;
        plasmalogin)  echo "Plasma Login" ;;
        ly)           echo Ly ;;
        *)            echo "$n" ;;
    esac
}

# stop only the instance running this config, never someone else's shell
qs kill -p "$SHELL_DIR" 2>/dev/null || true
qs kill -p "$SHELL_DIR/lumen.qml" 2>/dev/null || true
qs kill -p "$SHELL_DIR/lens.qml" 2>/dev/null || true
qs kill -p "$SHELL_DIR/clock.qml" 2>/dev/null || true

if [[ -d "$SHELL_DIR" ]]; then
    if ask "Move $SHELL_DIR to $SHELL_DIR.removed-$STAMP?"; then
        # file dialogs go back to gtk's or gnome's first: the portal would start lumen from there
        if [[ -x "$SHELL_DIR/lucidlumen/lumen" ]]; then
            "$SHELL_DIR/lucidlumen/lumen" --portal-off || true
        fi
        mv "$SHELL_DIR" "$SHELL_DIR.removed-$STAMP"
        # lumen's entry points into the folder that just moved
        rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/lucid.lumen.desktop"
        rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/lucid.lens.desktop"
        rm -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/lucid.clock.desktop"
        # the settings window's entry, which hands the name back to quickshell's own
        ENTRY="${XDG_DATA_HOME:-$HOME/.local/share}/applications/org.quickshell.desktop"
        if grep -qs '^Name=Lucid Settings$' "$ENTRY"; then
            rm -f "$ENTRY"
        fi
        echo "  moved (your settings and pins are still in there)"
    fi
fi

if [[ -d "$LUCID_DIR" ]] && ask "Remove the theming layer at $LUCID_DIR?"; then
    rm -rf "$LUCID_DIR"
    [[ -f "$WALL_SCRIPT" ]] && rm -f "$WALL_SCRIPT"
    echo "  removed"
fi

# a running Hyprland reloads on its own when the config changes under it
HYPR_BEFORE=$(before hypr)
HYPR_DONE=""
if [[ "$HYPR_BEFORE" == none && -d "$HYPR_DIR" ]]; then
    if ask "There was no Hyprland config before Lucid. Move Lucid's to $HYPR_DIR.removed-$STAMP, so Hyprland starts from its own default?"; then
        mv "$HYPR_DIR" "$HYPR_DIR.removed-$STAMP"
        echo "  moved (Hyprland writes a fresh config on its next start)"
        HYPR_DONE=default
    fi
elif [[ -n "$HYPR_BEFORE" && -d "$HYPR_BEFORE" ]]; then
    if ask "Put back the Hyprland config you had before Lucid, from $HYPR_BEFORE? (Lucid's goes to $HYPR_DIR.removed-$STAMP)"; then
        [[ -d "$HYPR_DIR" ]] && mv "$HYPR_DIR" "$HYPR_DIR.removed-$STAMP"
        cp -rT "$HYPR_BEFORE" "$HYPR_DIR"
        echo "  restored"
        HYPR_DONE=yours
    fi
elif [[ -n "$HYPR_BEFORE" ]]; then
    warn "your Hyprland config from before Lucid was backed up to $HYPR_BEFORE, which is gone"
fi

# the theme, icons and dark mode GNOME apps (and GNOME itself) read
GS=(); GS_LIST=""
for key in gtk-theme icon-theme color-scheme; do
    v=$(before "gsettings.$key")
    [[ -n "$v" ]] || continue
    GS+=("$key" "$v"); GS_LIST+="${GS_LIST:+, }$key $v"
done
if [[ ${#GS[@]} -gt 0 ]] && command -v gsettings &>/dev/null \
    && ask "Put back the GTK settings from before Lucid ($GS_LIST)?"; then
    for ((i = 0; i < ${#GS[@]}; i += 2)); do
        gsettings set org.gnome.desktop.interface "${GS[i]}" "${GS[i+1]}" \
            || warn "could not set ${GS[i]} (run this from inside your session)"
    done
    echo "  done"
fi

# the login screen install.sh swapped for SDDM, if it did and SDDM is still it
DM_BEFORE=$(before dm)
DM_NOW=$(readlink /etc/systemd/system/display-manager.service 2>/dev/null || true)
if [[ -n "$DM_BEFORE" && "${DM_NOW##*/}" == sddm.service ]]; then
    if [[ "$DM_BEFORE" == none ]]; then
        if ask "Before Lucid no login screen started at boot. Turn SDDM off again? (from the next restart you log in on the console)"; then
            sudo systemctl disable sddm.service && echo "  done: log in there, then run start-hyprland"
        fi
    else
        DM_GONE=()
        for u in $DM_BEFORE; do systemctl cat "$u" &>/dev/null || DM_GONE+=("$u"); done
        DM_OLD=$(dm_name "${DM_BEFORE%% *}")
        if [[ ${#DM_GONE[@]} -gt 0 ]]; then
            warn "$DM_OLD was your login screen before Lucid, but it is not installed any more, so SDDM stays"
        elif ask "Bring back $DM_OLD as your login screen, in place of SDDM? (from the next restart)"; then
            # word splitting is the point: ly comes as an instance plus nothing else
            # shellcheck disable=SC2086
            sudo systemctl disable sddm.service && sudo systemctl enable -f $DM_BEFORE && echo "  done"
        fi
    fi
fi

# the one thing install.sh put outside $HOME. leaving it would hand sddm a
# theme directory with no palette behind it
SDDM_THEME_DIR=/usr/share/sddm/themes/lucid
SDDM_CONF=/etc/sddm.conf
if [[ -d "$SDDM_THEME_DIR" ]] && ask "Remove the sddm theme at $SDDM_THEME_DIR (needs sudo)?"; then
    # install-theme.sh --current points [Theme] in sddm.conf at lucid; back to
    # the theme from before it, or sddm's own when that one is gone too
    if sed -n '/^\[Theme\]/,/^\[/p' "$SDDM_CONF" 2>/dev/null | grep -qx 'Current=lucid'; then
        PREV=$(sed -n '/^\[Theme\]/,/^\[/s/^[[:space:]]*Current=//p' "$SDDM_CONF.lucid-backup" 2>/dev/null | tail -1)
        if [[ -n "$PREV" && "$PREV" != lucid && -d "/usr/share/sddm/themes/$PREV" ]]; then
            sudo sed -i "/^\[Theme\]/,/^\[/ s/^Current=lucid\$/Current=$PREV/" "$SDDM_CONF" && echo "  sddm back on $PREV"
        else
            sudo sed -i '/^\[Theme\]/,/^\[/ {/^Current=lucid$/d}' "$SDDM_CONF" && echo "  sddm back on its default theme"
        fi
    fi
    ACTIVE=$({ grep -rhE '^[[:space:]]*Current=' "$SDDM_CONF" /etc/sddm.conf.d/*.conf 2>/dev/null || true; } \
             | tail -1 | cut -d= -f2- | tr -d '[:space:]')
    if [[ "$ACTIVE" == "lucid" ]]; then
        printf '%s warning:%s sddm is still set to Current=lucid. point it at another\n' "$ylw" "$r" >&2
        printf '           theme first, or you will get sddm'"'"'s fallback greeter.\n' >&2
    fi
    sudo rm -rf "$SDDM_THEME_DIR" && echo "  removed"
    # the fingerprint lines install-theme.sh put in sddm's pam service
    if grep -q '^# >>> lucid: fingerprint login' /etc/pam.d/sddm 2>/dev/null; then
        sudo sed -i '/^# >>> lucid: fingerprint login/,/^# <<< lucid: fingerprint login/d' /etc/pam.d/sddm \
            && echo "  fingerprint login taken out of /etc/pam.d/sddm"
    fi
fi

printf '\n%sDone.%s Left in place, each with a timestamped backup beside it:\n' "$b" "$r"
printf '  ~/.config/matugen/config.toml   the [templates.*] blocks Lucid added\n'
[[ -n "$HYPR_DONE" ]] || \
printf '  ~/.config/hypr                  the lua config, binds and rules\n'
printf '  ~/.local/share/lucid/plugins    the tilting cursor plugin that config\n'
printf '                                  loads (scripts/cursor-plugin.sh remove)\n'
printf '  ~/.config/starship.toml         the prompt, and its init line in\n'
printf '                                  .bashrc / .zshrc / config.fish\n'
printf '  ~/.config/fish/config.fish      the line that keeps fish from greeting\n'
printf '                                  every new terminal\n'
printf '  ~/.config/fastfetch/config.jsonc  the fastfetch config, if Lucid put it there\n'
printf '  ~/.config/kitty/kitty.conf      the matugen-colors.conf and\n'
printf '                                  lucid-glass.conf includes\n'
printf '  ~/.config/gtk-{3,4}.0/settings.ini  the GTK theme and icons\n'
printf '  ~/Pictures/wallpapers           the wallpapers, yours and the\n'
printf '                                  bundled ones alike\n'
printf '  ~/.local/share/icons/*-noshadow  cursor themes rebuilt without\n'
printf '                                  their shadow, if you asked for that\n'
printf '  ~/.local/share/icons/lucid-cursors  Lucid'"'"'s pointer, still the cursor\n'
printf '                                  theme until you pick another one\n'
printf 'Installed packages are left alone too.\n'
printf '%sRestore from a .backup-* file, or undo these by hand.%s\n' "$ylw" "$r"

# ---------------------------------------------------- where to go from here

SESSIONS=(/usr/share/wayland-sessions/*.desktop /usr/share/xsessions/*.desktop)
# the session of the desktop Lucid was installed from: its DesktopNames first
# (GNOME Classic lists GNOME second), then its name
came_session() {
    local f
    for f in "${SESSIONS[@]}"; do
        [[ -f "$f" ]] && grep -qiE "^DesktopNames=$1(;|\$)" "$f" && { sed -n 's/^Name=//p' "$f" | head -1; return; }
    done
    for f in "${SESSIONS[@]}"; do
        [[ -f "$f" ]] && grep -qix "Name=$1" "$f" && { sed -n 's/^Name=//p' "$f" | head -1; return; }
    done
    return 0
}

CAME=$(before desktop)
[[ "$CAME" =~ ^[A-Za-z0-9._-]+$ ]] || CAME=""
[[ "${CAME,,}" != hyprland ]] || CAME=""
CAME_SESSION=""
[[ -z "$CAME" ]] || CAME_SESSION=$(came_session "$CAME")
mapfile -t OTHERS < <(for f in "${SESSIONS[@]}"; do
    [[ -f "$f" ]] && ! grep -qi hyprland "$f" && sed -n 's/^Name=//p' "$f" | head -1
done | sort -u)

printf '\n'
if [[ -n "$CAME_SESSION" ]]; then
    printf 'To go back, log out and choose %s%s%s on the login screen.\n' "$b" "$CAME_SESSION" "$r"
else
    [[ -z "$CAME" ]] || printf '%s, the desktop you installed Lucid from, is not installed any more.\n' "$CAME"
    if [[ ${#OTHERS[@]} -gt 0 ]]; then
        printf 'The login screen also offers: %s\n' "$(IFS=,; echo "${OTHERS[*]}" | sed 's/,/, /g')"
    elif [[ "$HYPR_DONE" == yours ]]; then
        printf 'Hyprland is the only desktop here, back on your own config.\n'
    elif [[ "$HYPR_DONE" == default ]]; then
        printf 'Hyprland is the only desktop here, now without Lucid. With its own\n'
        printf 'default config, SUPER+Q opens a terminal and SUPER+M logs out.\n'
    else
        printf 'Hyprland is the only desktop here, now without Lucid. Its binds are\n'
        printf 'still Lucid'"'"'s, and the ones that talk to the shell do nothing now:\n'
        printf 'F9 opens a terminal, unless you changed it. Move ~/.config/hypr\n'
        printf 'aside and Hyprland starts from its own default.\n'
    fi
fi
