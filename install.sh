#!/usr/bin/env bash
# Lucid installer — Arch Linux + Hyprland
#
# installs dependencies, places the shell at ~/.config/quickshell, and sets up
# the theming support layer. safe to re-run: existing config and personal state
# are backed up, never overwritten in place.

set -euo pipefail

VERSION="0.57"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_DIR="$HOME/.config/quickshell"
LUCID_DIR="$HOME/.config/lucid"
MATUGEN_DIR="$HOME/.config/matugen"
WALL_SCRIPT_DIR="$HOME/.config/hypr/scripts/wallpaper"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP=""

WITH_THEMING=1
ASSUME_YES=0
SKIP_DEPS=0

b=$'\e[1m'; dim=$'\e[2m'; red=$'\e[31m'; grn=$'\e[32m'; ylw=$'\e[33m'; r=$'\e[0m'
say()  { printf '%s\n' "$*"; }
step() { printf '\n%s==>%s %s%s\n' "$grn" "$r" "$b" "$*$r"; }
warn() { printf '%s warning:%s %s\n' "$ylw" "$r" "$*" >&2; }
die()  { printf '%s error:%s %s\n' "$red" "$r" "$*" >&2; exit 1; }

usage() {
    cat <<EOF
${b}Lucid $VERSION installer${r}

  ./install.sh [options]

  --no-theming   install the shell only; leave ~/.config/lucid,
                 ~/.config/matugen and ~/.config/hypr untouched
  --skip-deps    don't install packages, only check for them
  -y, --yes      don't prompt, accept every default
  -h, --help     this message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-theming) WITH_THEMING=0 ;;
        --skip-deps)  SKIP_DEPS=1 ;;
        -y|--yes)     ASSUME_YES=1 ;;
        -h|--help)    usage ;;
        *) die "unknown option: $1 (try --help)" ;;
    esac
    shift
done

ask() {
    [[ $ASSUME_YES -eq 1 ]] && return 0
    local reply
    read -rp "$1 [Y/n] " reply
    [[ -z "$reply" || "$reply" =~ ^[Yy] ]]
}

# ---------------------------------------------------------------- preflight

step "Checking the system"

[[ -f /etc/arch-release ]] || die "this installer is Arch-only. see the README for a manual install."
command -v pacman &>/dev/null || die "pacman not found"
[[ $EUID -ne 0 ]] || die "don't run this as root — it installs into your home directory"
[[ -f "$SRC/shell.qml" ]] || die "run this from inside the Lucid repo (no shell.qml next to install.sh)"

command -v Hyprland &>/dev/null || command -v hyprctl &>/dev/null \
    || warn "Hyprland not found. Lucid uses Hyprland-specific APIs and will not work under another compositor."

AUR=""
for helper in paru yay; do
    command -v "$helper" &>/dev/null && { AUR="$helper"; break; }
done

say "  arch linux      ${grn}ok${r}"
say "  aur helper      ${AUR:-${ylw}none${r}}"
say "  install target  $SHELL_DIR"
say "  theming layer   $([[ $WITH_THEMING -eq 1 ]] && echo yes || echo 'no (--no-theming)')"

# ------------------------------------------------------------- dependencies

# required — the shell will not start or will visibly break without these
PKG_REQUIRED=(quickshell qt6-5compat qt6-declarative qt6-multimedia)
# each of these backs one feature; missing ones degrade that feature only
PKG_FEATURES=(
    matugen jq imagemagick
    networkmanager bluez bluez-utils
    libpulse wireplumber brightnessctl upower
    grim wf-recorder ffmpeg wl-clipboard wtype
    cava songrec curl libnotify
    python-pywal ttf-noto-color-emoji
)
PKG_AUR=(awww)

missing_repo=()
missing_aur=()

step "Resolving dependencies"

for p in "${PKG_REQUIRED[@]}" "${PKG_FEATURES[@]}"; do
    pacman -Qq "$p" &>/dev/null || missing_repo+=("$p")
done
for p in "${PKG_AUR[@]}"; do
    pacman -Qq "$p" &>/dev/null || missing_aur+=("$p")
done

if [[ ${#missing_repo[@]} -eq 0 && ${#missing_aur[@]} -eq 0 ]]; then
    say "  everything is already installed"
elif [[ $SKIP_DEPS -eq 1 ]]; then
    say "  ${ylw}missing (--skip-deps, not installing):${r}"
    printf '    %s\n' "${missing_repo[@]}" "${missing_aur[@]}"
else
    [[ ${#missing_repo[@]} -gt 0 ]] && say "  to install: ${missing_repo[*]}"
    [[ ${#missing_aur[@]} -gt 0 ]] && say "  from the aur: ${missing_aur[*]}"

    if ask "  install these now?"; then
        if [[ ${#missing_repo[@]} -gt 0 ]]; then
            if [[ -n "$AUR" ]]; then
                "$AUR" -S --needed --noconfirm "${missing_repo[@]}"
            else
                sudo pacman -S --needed --noconfirm "${missing_repo[@]}"
            fi
        fi
        if [[ ${#missing_aur[@]} -gt 0 ]]; then
            if [[ -n "$AUR" ]]; then
                "$AUR" -S --needed --noconfirm "${missing_aur[@]}"
            else
                warn "no AUR helper — install manually: ${missing_aur[*]}"
                warn "without a wallpaper daemon the wallpaper picker will not work"
            fi
        fi
    else
        warn "skipping. features backed by the missing packages will not work."
    fi
fi

# --------------------------------------------------------------- the shell

step "Installing the shell"

if [[ "$SRC" == "$SHELL_DIR" ]]; then
    say "  already at $SHELL_DIR, installing in place"
else
    if [[ -e "$SHELL_DIR" ]]; then
        BACKUP="$SHELL_DIR.backup-$STAMP"
        say "  existing config found, moving it to ${dim}$BACKUP${r}"
        mv "$SHELL_DIR" "$BACKUP"
    fi
    mkdir -p "$SHELL_DIR"
    # everything but the repo's own scaffolding. runtime state is excluded
    # too, so the copy can never carry another machine's settings, pins or
    # api keys — those come from defaults/ in the seed step below
    tar -C "$SRC" -cf - \
        --exclude='.git' --exclude='.github' --exclude='.claude' \
        --exclude='support' --exclude='defaults' \
        --exclude='install.sh' --exclude='uninstall.sh' \
        --exclude='README.md' --exclude='LICENSE' --exclude='.gitignore' \
        --exclude='./lucidprefs/prefs.json' \
        --exclude='./lucidbar/blur.json' \
        --exclude='./lucidbar/clock_reminders.json' \
        --exclude='./lucidbar/mpris_shazam.json' \
        --exclude='./luciddocks/pinned.json' \
        --exclude='./luciddocks/usage.json' \
        --exclude='./luciddocks/wallpaper.json' \
        --exclude='./lucidmoji/config.json' \
        --exclude='./lucidmoji/state.json' \
        . | tar -C "$SHELL_DIR" -xf -
    say "  shell files -> $SHELL_DIR"
fi

# state files. a re-run keeps your settings: anything already in place wins,
# then whatever the previous install left in the backup, and only failing both
# does the shipped default get written
seed() {
    local src="$SRC/defaults/$1" dest="$SHELL_DIR/$2"
    mkdir -p "$(dirname "$dest")"
    if [[ -s "$dest" ]]; then
        say "  ${dim}keeping existing $2${r}"
    elif [[ -n "$BACKUP" && -s "$BACKUP/$2" ]]; then
        cp "$BACKUP/$2" "$dest"
        say "  carried over $2"
    else
        cp "$src" "$dest"
        say "  seeded $2"
    fi
}

seed prefs.json            lucidprefs/prefs.json
seed blur.json             lucidbar/blur.json
seed clock_reminders.json  lucidbar/clock_reminders.json
seed mpris_shazam.json     lucidbar/mpris_shazam.json
seed pinned.json           luciddocks/pinned.json
seed usage.json            luciddocks/usage.json
seed wallpaper.json        luciddocks/wallpaper.json
seed moji-config.json      lucidmoji/config.json
seed moji-state.json       lucidmoji/state.json

# ------------------------------------------------------------------ theming

if [[ $WITH_THEMING -eq 1 ]]; then
    step "Installing the theming layer"

    mkdir -p "$LUCID_DIR/themes" "$MATUGEN_DIR/templates" "$WALL_SCRIPT_DIR" "$HOME/.cache/quickshell"

    cp -r "$SRC/support/lucid/themes/." "$LUCID_DIR/themes/"
    install -m755 "$SRC/support/lucid/apply-theme.sh"      "$LUCID_DIR/apply-theme.sh"
    install -m755 "$SRC/support/lucid/gen-pywal-palette.py" "$LUCID_DIR/gen-pywal-palette.py"
    install -m755 "$SRC/support/wallpaper/set-wallpaper.sh" "$WALL_SCRIPT_DIR/set-wallpaper.sh"
    say "  theme palettes  -> $LUCID_DIR/themes"
    say "  theme scripts   -> $LUCID_DIR"
    say "  wallpaper hook  -> $WALL_SCRIPT_DIR/set-wallpaper.sh"

    cp "$SRC/support/matugen/quickshell-colors.json" "$MATUGEN_DIR/templates/"
    say "  matugen template -> $MATUGEN_DIR/templates/quickshell-colors.json"

    # append the quickshell template block only if it isn't already there,
    # so an existing matugen config keeps all of its own templates
    MATUGEN_CFG="$MATUGEN_DIR/config.toml"
    if [[ -f "$MATUGEN_CFG" ]] && grep -q '^\[templates\.quickshell\]' "$MATUGEN_CFG"; then
        say "  ${dim}matugen config already has [templates.quickshell]${r}"
    else
        [[ -f "$MATUGEN_CFG" ]] && cp "$MATUGEN_CFG" "$MATUGEN_CFG.backup-$STAMP"
        [[ -f "$MATUGEN_CFG" ]] || printf '[config]\n' > "$MATUGEN_CFG"
        printf '\n' >> "$MATUGEN_CFG"
        cat "$SRC/support/matugen/config-snippet.toml" >> "$MATUGEN_CFG"
        say "  added [templates.quickshell] to matugen config.toml"
    fi

    # first-run palette, so the shell has colours before any wallpaper is set
    [[ -f "$HOME/.cache/current_theme" ]] || printf 'matugen' > "$HOME/.cache/current_theme"
    if [[ ! -s "$HOME/.cache/quickshell/matugen.json" ]]; then
        cp "$SRC/support/lucid/themes/nord/quickshell.json" "$HOME/.cache/quickshell/matugen.json"
        say "  seeded a starter palette (nord) — pick a theme in Settings to change it"
    fi
else
    step "Skipping the theming layer (--no-theming)"
    say "  the theme picker and wallpaper strip will not work until it is installed"
fi

# ---------------------------------------------------------------------- done

step "Done"

# a running instance is still on the old files, so offer the restart that
# actually puts the new version on screen
if qs list 2>/dev/null | grep -q "$SHELL_DIR/shell.qml"; then
    if ask "  Lucid is running on the old files. Restart it now?"; then
        qs kill -p "$SHELL_DIR" 2>/dev/null || true
        sleep 1
        (setsid qs -d >/dev/null 2>&1 &) || true
        say "  restarted"
    fi
fi

cat <<EOF

  ${b}Lucid $VERSION${r} is installed.

  Start it:      ${b}qs${r}
  Autostart:     add ${b}exec-once = qs${r} to ~/.config/hypr/hyprland.conf
  Settings:      ${b}qs ipc call -- settings open${r}

  Suggested Hyprland binds:

    bind = SUPER, SPACE,  exec, qs ipc call -- launcher toggle
    bind = SUPER, E,      exec, qs ipc call -- moji toggle
    bind = SUPER, L,      exec, qs ipc call -- lock lock
    bind = SUPER, S,      exec, qs ipc call -- snap toggle
    bind = SUPER, comma,  exec, qs ipc call -- settings open

  Keep the double dash: it is required whenever a call takes an argument.

EOF

if [[ ${#missing_repo[@]} -gt 0 || ${#missing_aur[@]} -gt 0 ]] && [[ $SKIP_DEPS -eq 1 ]]; then
    warn "dependencies were not installed — see the list above"
fi
