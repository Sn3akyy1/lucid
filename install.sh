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
WITH_LOOK=1
WITH_HYPR=0
HYPR_LUA_INSTALLED=0
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
  --no-look      don't touch kitty.conf, starship.toml, VSCode
                 settings or the Hyprland blur snippet
  --with-hypr    replace an existing Hyprland config with Lucid's
                 lua config (binds, blur, animations, rules).
                 Installed automatically when there is none.
  --skip-deps    don't install packages, only check for them
  -y, --yes      don't prompt, accept every default
  -h, --help     this message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-theming) WITH_THEMING=0 ;;
        --no-look)    WITH_LOOK=0 ;;
        --with-hypr)  WITH_HYPR=1 ;;
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
    cava songrec curl libnotify awww
    python-pywal noto-fonts-emoji
)

missing=()
DEPS_OK=1

step "Resolving dependencies"

# a never-synced pacman database makes every -Si lookup fail, so real repo
# packages get misread as AUR and nothing installs. check against a package
# that is guaranteed present rather than trusting the db exists.
if ! pacman -Si bash &>/dev/null; then
    warn "your pacman database is empty or stale — package lookups will fail."
    warn "run this first, then re-run the installer:"
    warn "    sudo pacman -Syu"
    if ! ask "  Continue anyway (dependencies will likely be skipped)?"; then
        die "stopped. run 'sudo pacman -Syu' and try again."
    fi
fi

for p in "${PKG_REQUIRED[@]}" "${PKG_FEATURES[@]}"; do
    pacman -Qq "$p" &>/dev/null || missing+=("$p")
done

if [[ ${#missing[@]} -eq 0 ]]; then
    say "  everything is already installed"
elif [[ $SKIP_DEPS -eq 1 ]]; then
    DEPS_OK=0
    say "  ${ylw}missing (--skip-deps, not installing):${r}"
    printf '    %s\n' "${missing[@]}"
else
    # split by what the configured repos actually carry, so one unresolvable
    # name can never take the whole batch down with it
    from_repo=(); from_aur=()
    for p in "${missing[@]}"; do
        if pacman -Si "$p" &>/dev/null; then from_repo+=("$p"); else from_aur+=("$p"); fi
    done

    [[ ${#from_repo[@]} -gt 0 ]] && say "  from the repos: ${from_repo[*]}"
    [[ ${#from_aur[@]}  -gt 0 ]] && say "  not in your repos, will try the aur: ${from_aur[*]}"

    if ask "  install these now?"; then
        if [[ ${#from_repo[@]} -gt 0 ]]; then
            if sudo pacman -S --needed --noconfirm "${from_repo[@]}"; then
                say "  repo packages installed"
            else
                DEPS_OK=0
                warn "some repo packages failed to install — continuing anyway"
            fi
        fi
        if [[ ${#from_aur[@]} -gt 0 ]]; then
            if [[ -n "$AUR" ]]; then
                # one at a time: a single bad name shouldn't block the rest
                for p in "${from_aur[@]}"; do
                    "$AUR" -S --needed --noconfirm "$p" || {
                        DEPS_OK=0; warn "could not install $p"
                    }
                done
            else
                DEPS_OK=0
                warn "no AUR helper (paru/yay) — install manually: ${from_aur[*]}"
            fi
        fi
    else
        DEPS_OK=0
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

# pinned dock apps are detected rather than shipped: a fixed list pins apps the
# machine does not have, and the dock can only draw a letter tile for those
detect_pinned() {
    local dirs=(
        /usr/share/applications
        "$HOME/.local/share/applications"
        /var/lib/flatpak/exports/share/applications
        "$HOME/.local/share/flatpak/exports/share/applications"
    )
    # one entry per slot, first match wins, so the dock gets variety not five browsers
    local slots=(
        "org.gnome.Nautilus nautilus dolphin thunar nemo pcmanfm-qt pcmanfm"
        "firefox zen-browser zen chromium brave-browser google-chrome-stable librewolf"
        "kitty alacritty foot org.wezfurlong.wezterm Alacritty com.mitchellh.ghostty"
        "code codium code-oss zed dev.zed.Zed"
        "spotify com.spotify.Client vesktop discord"
    )
    local out="" found=0
    for slot in "${slots[@]}"; do
        for cand in $slot; do
            local f=""
            for d in "${dirs[@]}"; do
                [[ -f "$d/$cand.desktop" ]] && { f="$d/$cand.desktop"; break; }
            done
            [[ -n "$f" ]] || continue

            local name icon exec wm
            name=$(sed -n 's/^Name=//p'           "$f" | head -n1)
            icon=$(sed -n 's/^Icon=//p'           "$f" | head -n1)
            exec=$(sed -n 's/^Exec=//p'           "$f" | head -n1 | sed 's/ *%[a-zA-Z]//g')
            wm=$(  sed -n 's/^StartupWMClass=//p' "$f" | head -n1)
            [[ -n "$name" && -n "$exec" ]] || continue
            [[ -n "$wm" ]] || wm="$cand"
            [[ -n "$icon" ]] || icon="$cand"
            # escape for json
            esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
            [[ $found -eq 1 ]] && out+=","
            out+=$(printf '\n        {\n            "appId": "%s",\n            "appKey": "%s",\n            "command": "%s",\n            "iconName": "%s",\n            "name": "%s"\n        }' \
                "$(esc "$wm")" "$(esc "$cand")" "$(esc "$exec")" "$(esc "$icon")" "$(esc "$name")")
            found=1
            break
        done
    done
    [[ $found -eq 1 ]] || return 1
    printf '{\n    "pinnedApps": [%s\n    ]\n}\n' "$out"
}

seed_pinned() {
    local dest="$SHELL_DIR/luciddocks/pinned.json"
    mkdir -p "$(dirname "$dest")"
    if [[ -s "$dest" ]]; then
        say "  ${dim}keeping existing luciddocks/pinned.json${r}"
    elif [[ -n "$BACKUP" && -s "$BACKUP/luciddocks/pinned.json" ]]; then
        cp "$BACKUP/luciddocks/pinned.json" "$dest"
        say "  carried over luciddocks/pinned.json"
    elif detect_pinned > "$dest.tmp" 2>/dev/null && [[ -s "$dest.tmp" ]]; then
        mv "$dest.tmp" "$dest"
        say "  pinned $(grep -c '"appId"' "$dest") installed apps to the dock"
    else
        rm -f "$dest.tmp"
        cp "$SRC/defaults/pinned.json" "$dest"
        say "  seeded luciddocks/pinned.json (defaults)"
    fi
}

seed prefs.json            lucidprefs/prefs.json
seed blur.json             lucidbar/blur.json
seed clock_reminders.json  lucidbar/clock_reminders.json
seed mpris_shazam.json     lucidbar/mpris_shazam.json
seed_pinned
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

    cp -r "$SRC/support/matugen/templates/." "$MATUGEN_DIR/templates/"
    say "  matugen templates -> $MATUGEN_DIR/templates/"

    MATUGEN_CFG="$MATUGEN_DIR/config.toml"
    [[ -f "$MATUGEN_CFG" ]] && cp "$MATUGEN_CFG" "$MATUGEN_CFG.backup-$STAMP"
    [[ -f "$MATUGEN_CFG" ]] || printf '[config]\n' > "$MATUGEN_CFG"

    TPL='~/.config/matugen/templates'
    MG_ADDED=(); MG_KEPT=(); MG_SKIPPED=()

    # a block is only added when the app it themes is actually present, so
    # matugen never writes colours into a config directory that isn't there.
    # an existing block is always left alone - this config is the user's.
    add_template() {
        local name=$1 input=$2 output=$3 guard=${4:-always} hook=${5:-}
        case "$guard" in
            always) ;;
            dir:*)  [[ -d "${guard#dir:}" ]] || { MG_SKIPPED+=("$name"); return 0; } ;;
            file:*) [[ -f "${guard#file:}" ]] || { MG_SKIPPED+=("$name"); return 0; } ;;
            cmd:*)  command -v "${guard#cmd:}" &>/dev/null || { MG_SKIPPED+=("$name"); return 0; } ;;
        esac
        if grep -q "^\[templates\.$name\]" "$MATUGEN_CFG"; then
            MG_KEPT+=("$name"); return 0
        fi
        mkdir -p "$(dirname "${output/#\~/$HOME}")"
        {
            printf '\n[templates.%s]\n' "$name"
            printf "input_path = '%s'\n" "$input"
            printf "output_path = '%s'\n" "$output"
            [[ -n "$hook" ]] && printf "post_hook = '%s'\n" "$hook" || true
        } >> "$MATUGEN_CFG"
        MG_ADDED+=("$name")
    }

    STARSHIP_HOOK='for sh in fish bash zsh; do pkill -WINCH -x "$sh" 2>/dev/null; done; true'

    add_template quickshell     "$TPL/quickshell-colors.json"  '~/.cache/quickshell/matugen.json'
    add_template vscode-raw     "$TPL/vscode-colors"           '~/.cache/matugen/vscode-colors'
    add_template vscode-json    "$TPL/vscode-colors.json"      '~/.cache/matugen/vscode-colors.json'
    add_template hyprland       "$TPL/hyprland-colors.lua"     '~/.config/hypr/colors.conf'    "dir:$HOME/.config/hypr"
    add_template kitty          "$TPL/kitty.conf"              '~/.config/kitty/matugen-colors.conf' "cmd:kitty" 'killall -SIGUSR1 kitty 2>/dev/null || true'
    add_template starship       "$TPL/starship-colors.toml"    '~/.config/starship.toml'       "cmd:starship" "$STARSHIP_HOOK"
    add_template gtk3           "$TPL/gtk-colors.css"          '~/.config/gtk-3.0/colors.css'  "dir:$HOME/.config/gtk-3.0"
    add_template gtk4           "$TPL/gtk-colors.css"          '~/.config/gtk-4.0/colors.css'  "dir:$HOME/.config/gtk-4.0"
    add_template rofi           "$TPL/rofi-colors.rasi"        '~/.config/rofi/colors.rasi'    "dir:$HOME/.config/rofi"
    add_template waybar         "$TPL/colors.css"              '~/.config/waybar/colors.css'   "dir:$HOME/.config/waybar"
    add_template swaync         "$TPL/colors.css"              '~/.config/swaync/colors.css'   "dir:$HOME/.config/swaync"
    add_template wlogout        "$TPL/colors.css"              '~/.config/wlogout/colors.css'  "dir:$HOME/.config/wlogout"
    add_template ags            "$TPL/ags-colors.scss"         '~/.config/ags/style/_colors.scss' "dir:$HOME/.config/ags"
    add_template vesktop        "$TPL/midnight-discord.css"    '~/.config/vesktop/themes/midnight-discord.css' "dir:$HOME/.config/vesktop"
    add_template pywalfox       "$TPL/pywalfox-colors.json"    '~/.cache/wal/colors.json'      "cmd:pywalfox" 'pywalfox update'
    add_template steam-material "$TPL/steam-material.css"      '~/.local/share/Steam/millennium/themes/Material-Theme/css/main/colors/matugen.css' \
                                "dir:$HOME/.local/share/Steam/millennium/themes/Material-Theme"

    # firefox and zen keep their chrome css inside a generated profile dir, so
    # the path has to be discovered rather than assumed
    FF_PROFILE=$(find "$HOME/.mozilla/firefox" -maxdepth 1 -type d -name '*.default-release' 2>/dev/null | head -1 || true)
    ZEN_PROFILE=$(find "$HOME/.config/zen" -maxdepth 1 -type d -name '*.Default*' 2>/dev/null | head -1 || true)
    if [[ -n "$FF_PROFILE" ]]; then
        add_template firefox-website-colors "$TPL/firefox-colors.css" "$FF_PROFILE/chrome/colors.css"
    else
        MG_SKIPPED+=(firefox-website-colors)
    fi
    if [[ -n "$ZEN_PROFILE" ]]; then
        add_template zen "$TPL/zen-userchrome.css" "$ZEN_PROFILE/chrome/userChrome.css"
    else
        MG_SKIPPED+=(zen)
    fi

    (( ${#MG_ADDED[@]} ))   && say "  matugen added:   ${MG_ADDED[*]}"                                || true
    (( ${#MG_KEPT[@]} ))    && say "  ${dim}matugen kept:    ${MG_KEPT[*]}${r}"                       || true
    (( ${#MG_SKIPPED[@]} )) && say "  ${dim}matugen skipped: ${MG_SKIPPED[*]} (not installed)${r}"    || true

    # GTK apps - Nautilus included - only read colors.css if gtk.css imports it
    for gtkver in 3.0 4.0; do
        gtkdir="$HOME/.config/gtk-$gtkver"
        [[ -d "$gtkdir" ]] || continue
        if [[ -f "$gtkdir/gtk.css" ]] && grep -q "colors.css" "$gtkdir/gtk.css"; then
            say "  ${dim}gtk-$gtkver already imports colors.css${r}"
        else
            [[ -f "$gtkdir/gtk.css" ]] && cp "$gtkdir/gtk.css" "$gtkdir/gtk.css.backup-$STAMP"
            printf "@import url('colors.css');\n" >> "$gtkdir/gtk.css"
            say "  gtk-$gtkver now imports colors.css"
        fi
    done

    # --- hyprland config --------------------------------------------------
    # the lua config format needs a recent Hyprland. replacing an existing
    # config is opt-in, because it is the user's whole session.
    HYPR_DIR="$HOME/.config/hypr"
    HYPR_LUA_INSTALLED=0
    HAS_HYPR_CFG=0
    [[ -f "$HYPR_DIR/hyprland.lua" || -f "$HYPR_DIR/hyprland.conf" ]] && HAS_HYPR_CFG=1

    # a config we installed on an earlier run is not "someone else's config":
    # without telling them apart, a re-run asks to replace Lucid's own setup and
    # then tells you to add binds you already have
    HYPR_IS_LUCID=0
    if [[ -f "$HYPR_DIR/modules/binds.lua" ]] && grep -q 'qs ipc call' "$HYPR_DIR/modules/binds.lua" 2>/dev/null; then
        HYPR_IS_LUCID=1
    fi

    if [[ $HYPR_IS_LUCID -eq 1 && $WITH_HYPR -eq 0 ]]; then
        HYPR_LUA_INSTALLED=1
        say "  ${dim}Hyprland already set up for Lucid — pass --with-hypr to refresh it${r}"
    elif [[ $HAS_HYPR_CFG -eq 1 && $WITH_HYPR -eq 0 ]]; then
        say "  ${dim}existing Hyprland config kept — pass --with-hypr to replace it${r}"
    elif [[ $HAS_HYPR_CFG -eq 1 ]] && ! ask "  Replace your Hyprland config with Lucid's? (yours is backed up)"; then
        say "  ${dim}Hyprland config left alone${r}"
    else
        if [[ $HAS_HYPR_CFG -eq 1 ]]; then
            cp -r "$HYPR_DIR" "$HYPR_DIR.backup-$STAMP"
            say "  your hypr config -> $HYPR_DIR.backup-$STAMP"
        fi
        mkdir -p "$HYPR_DIR/modules" "$HYPR_DIR/scripts"
        cp "$SRC/support/hypr/hyprland.lua" "$HYPR_DIR/hyprland.lua"
        cp "$SRC/support/hypr/modules/"*.lua "$HYPR_DIR/modules/"
        install -m755 "$SRC/support/hypr/scripts/reload.sh" "$HYPR_DIR/scripts/reload.sh"
        HYPR_LUA_INSTALLED=1
        say "  hyprland.lua + $(ls "$SRC/support/hypr/modules" | wc -l) modules -> $HYPR_DIR"
        say "  ${dim}binds, blur, animations and the Lucid window rules come with it${r}"
        if command -v hyprctl &>/dev/null; then
            HYPR_VER=$(hyprctl version 2>/dev/null | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
            case "$HYPR_VER" in
                v0.4*|v0.3*|v0.2*|v0.1*) warn "  Hyprland $HYPR_VER predates the lua config format — expect errors" ;;
            esac
        fi
    fi

    # --- the look: terminal + prompt + blur -------------------------------
    # each piece is additive and backed up first, because these are files the
    # user owns and may already have tuned
    if [[ $WITH_LOOK -eq 1 ]] && ask "  Apply the Lucid look (kitty, starship, VSCode, Hyprland blur)?"; then

        # kitty - the include is what makes matugen's colours apply at all
        if [[ -f "$HOME/.config/kitty/kitty.conf" ]]; then
            if grep -q "matugen-colors.conf" "$HOME/.config/kitty/kitty.conf"; then
                say "  ${dim}kitty.conf already includes matugen-colors.conf${r}"
            else
                cp "$HOME/.config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf.backup-$STAMP"
                printf '\n# added by Lucid — colours follow the active theme\ninclude ./matugen-colors.conf\n' \
                    >> "$HOME/.config/kitty/kitty.conf"
                say "  kitty.conf now includes matugen-colors.conf"
            fi
            grep -q "background_opacity" "$HOME/.config/kitty/kitty.conf" \
                || say "  ${dim}tip: set background_opacity 0.7 in kitty.conf for the glass look${r}"
        else
            mkdir -p "$HOME/.config/kitty"
            cp "$SRC/support/look/kitty.conf" "$HOME/.config/kitty/kitty.conf"
            say "  kitty.conf -> ~/.config/kitty/kitty.conf"
        fi

        # vscode / vscodium - matugen writes the colour files, but they do
        # nothing until the Matugen theme extension is installed and selected
        vscode_wire() {
            local cli=$1 cfg=$2
            command -v "$cli" &>/dev/null || return 0
            if "$cli" --list-extensions 2>/dev/null | grep -qi "matugen-theme"; then
                say "  ${dim}$cli already has the Matugen theme${r}"
            elif "$cli" --install-extension haikalllp.matugen-theme &>/dev/null; then
                say "  installed the Matugen theme extension for $cli"
            else
                warn "  could not install the Matugen theme for $cli — do it by hand"
            fi

            mkdir -p "$(dirname "$cfg")"
            if [[ ! -f "$cfg" ]]; then
                printf '{\n  "workbench.colorTheme": "Matugen"\n}\n' > "$cfg"
                say "  $cli settings.json -> Matugen theme"
            elif grep -q '"workbench.colorTheme"' "$cfg"; then
                say "  ${dim}$cli already sets workbench.colorTheme${r}"
            else
                cp "$cfg" "$cfg.backup-$STAMP"
                # settings.json is jsonc - trailing commas are legal there - so
                # insert as text rather than reparsing and reformatting it
                awk 'ins != 1 && /\{/ { print; print "  \"workbench.colorTheme\": \"Matugen\","; ins = 1; next } 1' \
                    "$cfg" > "$cfg.lucid-tmp" && mv "$cfg.lucid-tmp" "$cfg"
                if grep -q '"workbench.colorTheme"' "$cfg"; then
                    say "  $cli now uses the Matugen theme"
                else
                    cp "$cfg.backup-$STAMP" "$cfg"
                    warn "  couldn't edit $cli settings.json — set the Matugen theme by hand"
                fi
            fi
        }

        vscode_wire codium   "$HOME/.config/VSCodium/User/settings.json"
        vscode_wire code     "$HOME/.config/Code/User/settings.json"
        vscode_wire code-oss "$HOME/.config/Code - OSS/User/settings.json"

        # starship - matugen and apply-theme.sh both rewrite its palette later
        if [[ -f "$HOME/.config/starship.toml" ]]; then
            say "  ${dim}keeping your starship.toml${r}"
        elif command -v starship &>/dev/null; then
            cp "$SRC/support/look/starship.toml" "$HOME/.config/starship.toml"
            say "  starship.toml -> ~/.config/starship.toml"
        else
            say "  ${dim}starship not installed, skipping its config${r}"
        fi

        # hyprland blur - skipped when the lua config went in above, since its
        # decorations module already carries the same blur
        if [[ $HYPR_LUA_INSTALLED -eq 1 ]]; then
            say "  ${dim}blur comes from modules/decorations.lua${r}"
        elif [[ -f "$HYPR_DIR/hyprland.lua" ]]; then
            mkdir -p "$HYPR_DIR/modules"
            cp "$SRC/support/look/lucid-look.lua" "$HYPR_DIR/modules/lucid-look.lua"
            if grep -q 'require("modules.lucid-look")' "$HYPR_DIR/hyprland.lua"; then
                say "  ${dim}hyprland.lua already requires modules.lucid-look${r}"
            else
                cp "$HYPR_DIR/hyprland.lua" "$HYPR_DIR/hyprland.lua.backup-$STAMP"
                printf '\nrequire("modules.lucid-look")\n' >> "$HYPR_DIR/hyprland.lua"
                say "  hyprland.lua now requires modules.lucid-look"
            fi
        elif [[ -f "$HYPR_DIR/hyprland.conf" ]]; then
            cp "$SRC/support/look/lucid-look.conf" "$HYPR_DIR/lucid-look.conf"
            if grep -q "lucid-look.conf" "$HYPR_DIR/hyprland.conf"; then
                say "  ${dim}hyprland.conf already sources lucid-look.conf${r}"
            else
                cp "$HYPR_DIR/hyprland.conf" "$HYPR_DIR/hyprland.conf.backup-$STAMP"
                printf '\nsource = ~/.config/hypr/lucid-look.conf\n' >> "$HYPR_DIR/hyprland.conf"
                say "  hyprland.conf now sources lucid-look.conf"
            fi
        else
            mkdir -p "$HYPR_DIR"
            cp "$SRC/support/look/lucid-look.conf" "$HYPR_DIR/lucid-look.conf"
            warn "  no hyprland config found — source lucid-look.conf yourself"
        fi
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
  Settings:      ${b}qs ipc call -- settings open${r}

EOF

if [[ $HYPR_LUA_INSTALLED -eq 1 ]]; then
    cat <<EOF
  Hyprland is configured: modules/binds.lua has the Lucid binds and
  modules/autostart.lua already launches the shell on login.

    SUPER            launcher        SUPER+W      workspaces
    SUPER+S          settings        SUPER+T      theme picker
    SUPER+period     emoji           SUPER+B      wallpaper
    SUPER+D / Print  screenshot      F10          lock

EOF
else
    cat <<EOF
  Autostart:     add ${b}exec-once = qs${r} to your Hyprland config

  Suggested Hyprland binds:

    bind = SUPER, SPACE,  exec, qs ipc call -- launcher toggle
    bind = SUPER, E,      exec, qs ipc call -- moji toggle
    bind = SUPER, L,      exec, qs ipc call -- lock lock
    bind = SUPER, S,      exec, qs ipc call -- snap toggle
    bind = SUPER, comma,  exec, qs ipc call -- settings open

  Keep the double dash: it is required whenever a call takes an argument.

EOF
fi

if [[ $DEPS_OK -eq 0 ]]; then
    warn "some dependencies are missing — the shell is installed, but the"
    warn "features they back will not work until you install them."
fi
