#!/usr/bin/env bash
# Lucid installer — Arch Linux + Hyprland
#
# installs dependencies, places the shell at ~/.config/quickshell, and sets up
# the full bundle: the Hyprland config (binds, window rules, blur, autostart),
# the theming layer, the Lucid look, and the apps the dock ships pinned.
# safe to re-run: existing config and personal state are backed up, never
# overwritten in place.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# the VERSION file ships inside the shell tree, so the installed copy can tell
# the update check which version it is. bump it to cut a release
VERSION="unknown"
if [[ -f "$SRC/VERSION" ]]; then
    VERSION="$(tr -d '[:space:]' < "$SRC/VERSION")"
fi
SHELL_DIR="$HOME/.config/quickshell"
LUCID_DIR="$HOME/.config/lucid"
MATUGEN_DIR="$HOME/.config/matugen"
WALL_SCRIPT_DIR="$HOME/.config/hypr/scripts/wallpaper"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP=""

WITH_THEMING=1
WITH_LOOK=1
WITH_HYPR=1
WITH_APPS=1
WITH_WALLPAPERS=1
HYPR_FORCE=0
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

  --no-theming   skip the palette layer; leave ~/.config/lucid
                 and ~/.config/matugen untouched
  --no-look      don't touch kitty.conf, starship.toml or VSCode
                 settings
  --no-hypr      keep your Hyprland config; Lucid's binds, window
                 rules and blur are not installed
  --no-apps      don't install the apps pinned to the dock by
                 default (Zen, VSCodium, Spotify, Steam, ...)
  --no-wallpapers
                 don't copy the bundled wallpapers to
                 ~/Pictures/wallpapers
  --with-hypr    reinstall Lucid's Hyprland config even when one
                 is already in place
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
        --no-hypr)    WITH_HYPR=0 ;;
        --no-apps)    WITH_APPS=0 ;;
        --no-wallpapers) WITH_WALLPAPERS=0 ;;
        --with-hypr)  WITH_HYPR=1; HYPR_FORCE=1 ;;
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
say "  hyprland config $([[ $WITH_HYPR   -eq 1 ]] && echo yes || echo 'no (--no-hypr)')"
say "  dock apps       $([[ $WITH_APPS   -eq 1 ]] && echo yes || echo 'no (--no-apps)')"
say "  wallpapers      $([[ $WITH_WALLPAPERS -eq 1 ]] && echo yes || echo 'no (--no-wallpapers)')"

# ------------------------------------------------------------- dependencies

# required — the shell will not start or will visibly break without these
PKG_REQUIRED=(quickshell qt6-5compat qt6-declarative qt6-multimedia)
# each of these backs one feature; missing ones degrade that feature only
PKG_FEATURES=(
    matugen jq imagemagick
    networkmanager bluez bluez-utils
    kdeconnect python-gobject
    libpulse wireplumber brightnessctl upower hypridle
    grim wf-recorder ffmpeg wl-clipboard wtype cliphist
    tesseract tesseract-data-eng hyprpicker
    python-pillow python-numpy python-fonttools
    cava songrec curl libnotify awww fastfetch
    python-pywal noto-fonts-emoji
    # the shell is the session's own polkit agent; polkitd and its setuid
    # helper are the backend it drives
    xdg-utils zenity swappy polkit
    # the accounts page reads and writes users through this, and asks the
    # shell's polkit dialog whenever a change needs an administrator
    accountsservice
    # the environment page writes the desktop's appearance through these, and
    # the file chooser kde connect sends files with comes from the gtk portal.
    # librsvg renders a cursor theme again when its shadow is turned off
    gsettings-desktop-schemas qt6ct xdg-desktop-portal-gtk librsvg
)
# invoked by the shipped Hyprland binds and the Lucid look. without these the
# config installs fine but its keys do nothing and the prompt renders as boxes
PKG_HYPR=(
    kitty nautilus playerctl gnome-calculator
    starship fish ttf-jetbrains-mono-nerd adw-gtk-theme papirus-icon-theme
)
# the dock's default pins. these are the apps Lucid ships pinned, so the dock
# is not a row of blank letter tiles on a fresh install. --no-apps skips them.
# order matches the dock; steam is filtered out below unless multilib is on
PKG_DOCK=(
    zen-browser-bin vscodium-bin vesktop
    spotify proton-vpn-gtk-app steam
)
# a package already covered by an equivalent one the user chose themselves.
# without this a re-run keeps trying to install vscodium-bin over vscodium
declare -A PKG_ALTS=(
    [vscodium-bin]="vscodium vscodium-git visual-studio-code-bin code"
    [zen-browser-bin]="zen-browser zen-browser-avx2-bin"
    [vesktop]="vesktop-bin discord"
    [spotify]="spotify-launcher"
    [ttf-jetbrains-mono-nerd]="nerd-fonts ttf-jetbrains-mono"
    [adw-gtk-theme]="adw-gtk3 adw-gtk3-git"
    [qt6ct]="qt6ct-kde"
    [xdg-desktop-portal-gtk]="xdg-desktop-portal-gnome xdg-desktop-portal-kde"
)

# a couple of the dock's AUR packages need something in place before the build
# will even start. without this the package silently drops out of the install
# with a warning, and the dock is left drawing a blank letter tile for it.
SPOTIFY_KEY=E1096BCBFF6D418796DE78515384CE82BA52C83A
aur_prepare() {
    # the spotify PKGBUILD verifies its .deb against Spotify's own signing
    # key. that key ships in nobody's keyring, so a fresh machine fails with
    # "unknown public key" every time. import it first; the download server is
    # the PKGBUILD's own, with a keyserver as the fallback
    [[ "$1" == spotify ]] || return 0
    gpg --list-keys "$SPOTIFY_KEY" &>/dev/null && return 0
    say "  importing Spotify's package signing key"
    if curl -sS https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.gpg 2>/dev/null \
         | gpg --import - &>/dev/null; then
        return 0
    fi
    gpg --keyserver keyserver.ubuntu.com --recv-keys "$SPOTIFY_KEY" &>/dev/null \
        || warn "  could not import Spotify's signing key — the build may fail"
}

# true when the package, or anything standing in for it, is installed
have_pkg() {
    pacman -Qq "$1" &>/dev/null && return 0
    local alt
    for alt in ${PKG_ALTS[$1]:-}; do
        pacman -Qq "$alt" &>/dev/null && return 0
    done
    return 1
}

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

WANTED=("${PKG_REQUIRED[@]}" "${PKG_FEATURES[@]}")
[[ $WITH_HYPR -eq 1 || $WITH_LOOK -eq 1 ]] && WANTED+=("${PKG_HYPR[@]}")

if [[ $WITH_APPS -eq 1 ]]; then
    for p in "${PKG_DOCK[@]}"; do
        # steam lives in multilib. with that repo off the lookup fails, the
        # name gets misread as an AUR package and the build fails much later
        if [[ "$p" == steam ]] && ! grep -q '^\[multilib\]' /etc/pacman.conf 2>/dev/null; then
            say "  ${dim}skipping steam — the multilib repo is not enabled${r}"
            continue
        fi
        WANTED+=("$p")
    done
fi

for p in "${WANTED[@]}"; do
    have_pkg "$p" || missing+=("$p")
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

    # the dock apps are the bulk of the download and the part people are most
    # likely to want out of, so name them rather than burying them in the list
    dock_missing=()
    for p in "${PKG_DOCK[@]}"; do
        for m in "${missing[@]}"; do [[ "$m" == "$p" ]] && dock_missing+=("$p") && break; done
    done
    if (( ${#dock_missing[@]} )); then
        say "  ${dim}of those, the dock's default apps: ${dock_missing[*]}${r}"
        say "  ${dim}(several GB, mostly from the aur — pass --no-apps to skip them)${r}"
    fi

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
                    aur_prepare "$p"
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
        --exclude='support' --exclude='defaults' --exclude='__pycache__' \
        --exclude='wallpapers' \
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
        --exclude='./lucidkeys/state.json' \
        --exclude='./lucidwidgets/widgets.json' \
        . | tar -C "$SHELL_DIR" -xf -
    say "  shell files -> $SHELL_DIR"
fi

# the launcher sits outside the shell tree so autostart can reach it whether or
# not the Hyprland config was installed. it picks the Qt scene graph backend
# before exec'ing quickshell — see support/lucid/launch-shell.sh
if [[ -f "$SRC/support/lucid/launch-shell.sh" ]]; then
    mkdir -p "$LUCID_DIR"
    install -m755 "$SRC/support/lucid/launch-shell.sh" "$LUCID_DIR/launch-shell.sh"
    say "  shell launcher -> $LUCID_DIR/launch-shell.sh"
else
    warn "support/lucid/launch-shell.sh missing, autostart will run quickshell directly"
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
    # the shipped dock lineup, in dock order. one entry per slot and first
    # match wins, so a machine without Lucid's default app still gets that
    # slot filled by whatever equivalent it does have
    local slots=(
        "zen zen-browser app.zen_browser.zen firefox librewolf chromium brave-browser google-chrome-stable"
        "vscodium codium code code-oss com.visualstudio.code zed dev.zed.Zed"
        "spotify com.spotify.Client spotify-launcher"
        "vesktop dev.vencord.Vesktop discord com.discordapp.Discord webcord"
        "org.gnome.Nautilus nautilus org.kde.dolphin dolphin thunar nemo pcmanfm-qt pcmanfm"
        "steam com.valvesoftware.Steam"
        "proton.vpn.app.gtk protonvpn-app"
        "kitty alacritty foot org.wezfurlong.wezterm Alacritty com.mitchellh.ghostty"
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
            # strip desktop field codes, then drop any option left holding
            # nothing (Exec=spotify --uri=%u would otherwise pin "--uri=")
            exec=$(sed -n 's/^Exec=//p' "$f" | head -n1 \
                | sed -E 's/%[fFuUdDnNickvm]//g; s/ +-[^ ]*=( |$)/\1/g; s/  +/ /g; s/ +$//')
            wm=$(  sed -n 's/^StartupWMClass=//p' "$f" | head -n1)
            [[ -n "$name" && -n "$exec" ]] || continue
            # StartupWMClass is an X11 hint. a wayland-native app reports its
            # application-id instead, which is the reverse-dns desktop name -
            # trusting the hint there pins an id no window ever matches
            if [[ "$cand" == *.*.* ]]; then
                wm="$cand"
            else
                [[ -n "$wm" ]] || wm="$cand"
            fi
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
seed keys-state.json       lucidkeys/state.json
seed widgets.json          lucidwidgets/widgets.json

# the media visualiser runs `cava -p ~/.config/cava/quickshell.conf`. without
# that file cava falls back to its own defaults, which emit ncurses output
# instead of the raw ascii frames the bar strip parses - the strip then reads
# one enormous bar and draws it as a circle across the whole popup. not part of
# --no-look: this backs a shell feature, it is not a taste preference.
CAVA_CFG="$HOME/.config/cava/quickshell.conf"
mkdir -p "$(dirname "$CAVA_CFG")"
if [[ ! -f "$CAVA_CFG" ]]; then
    cp "$SRC/support/cava/quickshell.conf" "$CAVA_CFG"
    say "  cava visualiser config -> ~/.config/cava/quickshell.conf"
elif cmp -s "$SRC/support/cava/quickshell.conf" "$CAVA_CFG"; then
    say "  ${dim}keeping cava/quickshell.conf${r}"
else
    cp "$CAVA_CFG" "$CAVA_CFG.backup-$STAMP"
    cp "$SRC/support/cava/quickshell.conf" "$CAVA_CFG"
    say "  cava/quickshell.conf refreshed (yours -> quickshell.conf.backup-$STAMP)"
fi

# the Environment page writes the Qt half of the appearance - style, icon theme
# and fonts - into qt6ct.conf, and the shipped modules/env.lua exports
# QT_QPA_PLATFORMTHEME=qt6ct so Qt apps read it. envtool.py deliberately never
# creates that file: it refuses to conjure a config for a toolkit the machine
# does not use. so on a fresh machine the page's Qt switch is a silent no-op
# until something writes one. minimal on purpose - the page fills in the style,
# icons and fonts itself on the first apply.
QT6CT_CFG="$HOME/.config/qt6ct/qt6ct.conf"
if ! command -v qt6ct &>/dev/null; then
    say "  ${dim}qt6ct is not installed - the Environment page will skip Qt${r}"
elif [[ -f "$QT6CT_CFG" ]]; then
    say "  ${dim}keeping qt6ct/qt6ct.conf${r}"
else
    mkdir -p "$(dirname "$QT6CT_CFG")"
    printf '[Appearance]\nstyle=Fusion\n' > "$QT6CT_CFG"
    say "  qt6ct.conf -> ~/.config/qt6ct/qt6ct.conf"
fi

# --------------------------------------------------- notification ownership

# org.freedesktop.Notifications is a single-owner D-Bus name and Lucid's bar
# serves it. Any other notification daemon that is merely *installed* can be
# D-Bus-activated the moment something posts a notification - it does not have
# to be autostarted - and whoever claims the name first keeps it for the whole
# session. Lose that race and Lucid's toasts silently never appear: you get the
# other daemon's notification instead, while the bar looks perfectly fine.

step "Checking who serves notifications"

NOTIFY_RIVALS=()
for f in /usr/share/dbus-1/services/*.service "$HOME/.local/share/dbus-1/services/"*.service; do
    [[ -f "$f" ]] || continue
    grep -q '^Name=org.freedesktop.Notifications' "$f" || continue
    grep -qi 'quickshell' "$f" && continue
    NOTIFY_RIVALS+=("$f")
done

if [[ ${#NOTIFY_RIVALS[@]} -eq 0 ]]; then
    say "  ${dim}nothing else claims the name — Lucid's notifications win${r}"
else
    for f in "${NOTIFY_RIVALS[@]}"; do
        unit=$(sed -n 's/^SystemdService=//p' "$f" | head -n1)
        exe=$(sed -n 's/^Exec=//p' "$f" | head -n1 | awk '{print $1}')
        say "  ${ylw}$(basename "$exe")${r} also claims org.freedesktop.Notifications"
        say "  ${dim}($f)${r}"
    done
    say "  D-Bus starts it on the first notification, and it then keeps the"
    say "  name for the session — Lucid's own notifications never show."

    if ask "  Stop it taking over?"; then
        for f in "${NOTIFY_RIVALS[@]}"; do
            unit=$(sed -n 's/^SystemdService=//p' "$f" | head -n1)
            exe=$(sed -n 's/^Exec=//p' "$f" | head -n1 | awk '{print $1}')
            base=$(basename "$exe")
            if [[ -n "$unit" ]] && command -v systemctl &>/dev/null; then
                systemctl --user mask "$unit" &>/dev/null \
                    && say "  masked $unit (undo: systemctl --user unmask $unit)" \
                    || warn "  could not mask $unit — uninstall $base instead"
            else
                warn "  $base has no systemd unit to mask — uninstall it to be rid of it"
            fi
            # it may already hold the name in this session; the mask only
            # stops the next activation, so drop the running one too
            if pgrep -x "$base" &>/dev/null; then
                pkill -x "$base" &>/dev/null || true
                say "  stopped the running $base"
            fi
        done
        say "  ${dim}restart Lucid (or log back in) so it claims the name${r}"
    else
        warn "  left alone — expect its notifications instead of Lucid's"
    fi
fi

# ------------------------------------------------------------------ hyprland

# binds, window rules, blur, animations and autostart. this is a whole session
# config, so an existing one is always backed up first and replacing it is a
# question - except when it is Lucid's own from an earlier run, which is just
# refreshed. kept out of the theming step: the modules read no palette, so
# --no-theming should not cost you the binds.
HYPR_DIR="$HOME/.config/hypr"
HYPR_LUA_INSTALLED=0

if [[ $WITH_HYPR -eq 1 ]]; then
    step "Setting up Hyprland"

    HAS_HYPR_CFG=0
    [[ -f "$HYPR_DIR/hyprland.lua" || -f "$HYPR_DIR/hyprland.conf" ]] && HAS_HYPR_CFG=1

    # a config we installed on an earlier run is not "someone else's config":
    # without telling them apart, a re-run asks to replace Lucid's own setup and
    # then tells you to add binds you already have
    HYPR_IS_LUCID=0
    if [[ -f "$HYPR_DIR/modules/binds.lua" ]] && grep -q 'qs ipc call' "$HYPR_DIR/modules/binds.lua" 2>/dev/null; then
        HYPR_IS_LUCID=1
    fi

    DO_HYPR=1
    if [[ $HYPR_IS_LUCID -eq 1 ]]; then
        say "  ${dim}already Lucid's — refreshing it${r}"
    elif [[ $HAS_HYPR_CFG -eq 1 && $HYPR_FORCE -eq 0 ]]; then
        say "  you already have a Hyprland config. Lucid's brings the binds,"
        say "  window rules, blur and animations, and yours is backed up first."
        if ! ask "  Replace it with Lucid's?"; then
            DO_HYPR=0
            say "  ${dim}left alone — re-run with --with-hypr to change your mind${r}"
        fi
    fi

    # the lua config only exists from Hyprland 0.55. an older one reads
    # hyprland.conf and ignores hyprland.lua, so replacing the config would
    # leave it with nothing but its own defaults - worth asking first.
    # `hyprctl version` prints "Hyprland 0.54.0 built from ..." with no v,
    # so the number is taken bare and compared as a number
    if [[ $DO_HYPR -eq 1 ]] && command -v hyprctl &>/dev/null; then
        HYPR_VER=$(hyprctl version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
        if [[ -n "$HYPR_VER" ]]; then
            IFS=. read -r hv_major hv_minor _ <<< "$HYPR_VER"
            if (( hv_major == 0 && hv_minor < 55 )); then
                warn "  Hyprland $HYPR_VER predates the lua config (0.55+) — it will ignore hyprland.lua"
                if ! ask "  Install it anyway?"; then
                    DO_HYPR=0
                    say "  ${dim}left alone — update Hyprland, then re-run with --with-hypr${r}"
                fi
            fi
        fi
    fi

    if [[ $DO_HYPR -eq 1 ]]; then
        if [[ $HAS_HYPR_CFG -eq 1 ]]; then
            cp -r "$HYPR_DIR" "$HYPR_DIR.backup-$STAMP"
            say "  your hypr config -> $HYPR_DIR.backup-$STAMP"
        fi
        mkdir -p "$HYPR_DIR/modules" "$HYPR_DIR/scripts"
        cp "$SRC/support/hypr/hyprland.lua" "$HYPR_DIR/hyprland.lua"
        cp "$SRC/support/hypr/modules/"*.lua "$HYPR_DIR/modules/"
        install -m755 "$SRC/support/hypr/scripts/reload.sh" "$HYPR_DIR/scripts/reload.sh"
        # a hyprland.conf left beside hyprland.lua is ambiguous - Hyprland
        # reads one of them and you cannot tell which, so the install looks
        # like it did nothing. the full directory is already backed up above
        if [[ -f "$HYPR_DIR/hyprland.conf" ]]; then
            mv "$HYPR_DIR/hyprland.conf" "$HYPR_DIR/hyprland.conf.replaced-$STAMP"
            say "  hyprland.conf -> hyprland.conf.replaced-$STAMP (lua config wins now)"
            # a lua config cannot source a .conf, so whatever the old config
            # pulled in - hyprmod's hyprland-gui.conf, a file of your own -
            # stops being read here. name them, so the settings that vanish
            # with them are not a mystery: each needs a lua module in its
            # place (hyprmod adds require("hyprland-gui") when re-run)
            sourced=()
            while IFS= read -r f; do
                [[ -n "$f" ]] && sourced+=("$f")
            done < <(sed -nE 's/^[[:space:]]*source[[:space:]]*=[[:space:]]*//p' \
                        "$HYPR_DIR/hyprland.conf.replaced-$STAMP" \
                     | sed -E 's/[[:space:]]*#.*$//; s/[[:space:]]+$//' || true)
            if (( ${#sourced[@]} )); then
                warn "  it sourced ${#sourced[@]} file(s) that hyprland.lua will not read:"
                for f in "${sourced[@]}"; do
                    say "    $f"
                done
                say "  ${dim}a lua config cannot source .conf files. whatever wrote those needs a lua module instead — hyprmod: re-run it and accept its require(\"hyprland-gui\") line${r}"
            fi
        fi
        HYPR_LUA_INSTALLED=1
        say "  hyprland.lua + $(ls "$SRC/support/hypr/modules" | wc -l) modules -> $HYPR_DIR"
        say "  ${dim}binds, window rules, blur, animations and autostart come with it${r}"
        # a refresh replaces hyprland.lua whole, but a require added to it
        # since the last run - hyprmod's require("hyprland-gui"), a module
        # of your own - is not Lucid's to drop. those lines go back in,
        # after Lucid's, so what they set still wins. only on a refresh:
        # a config replaced on request was meant to go
        if [[ $HYPR_IS_LUCID -eq 1 && -f "$HYPR_DIR.backup-$STAMP/hyprland.lua" ]]; then
            carried=()
            while IFS= read -r line; do
                grep -qxF -- "$line" "$HYPR_DIR/hyprland.lua" && continue
                printf '%s\n' "${carried[@]:-}" | grep -qxF -- "$line" && continue
                carried+=("$line")
            done < <(grep -E '^[[:space:]]*(pcall[[:space:]]*\([[:space:]]*)?(require|dofile)[[:space:]]*[(,]' \
                        "$HYPR_DIR.backup-$STAMP/hyprland.lua" || true)
            if (( ${#carried[@]} )); then
                {
                    printf '\n-- kept by the Lucid installer: these were added to hyprland.lua after it was installed\n'
                    printf '%s\n' "${carried[@]}"
                } >> "$HYPR_DIR/hyprland.lua"
                say "  kept ${#carried[@]} require line(s) added to hyprland.lua since the last install"
            fi
        fi

        # modules/binds.lua binds from this list, which Settings -> Keybinds
        # edits. an existing one is yours and survives the refresh
        mkdir -p "$LUCID_DIR"
        if [[ -s "$LUCID_DIR/keybinds.json" ]]; then
            say "  ${dim}keeping existing $LUCID_DIR/keybinds.json${r}"
        else
            cp "$SRC/support/hypr/keybinds.json" "$LUCID_DIR/keybinds.json"
            say "  keybinds -> $LUCID_DIR/keybinds.json"
        fi

        # the binds shell out to these, so a missing one is a dead key rather
        # than a visible error. worth saying now, not after the first F-key
        for c in kitty nautilus playerctl gnome-calculator wpctl brightnessctl; do
            command -v "$c" &>/dev/null || warn "  $c is missing — the binds that use it will do nothing"
        done

    fi
else
    step "Skipping the Hyprland config (--no-hypr)"
    say "  ${dim}the Lucid binds and window rules are not installed${r}"
fi

# ------------------------------------------------------------------ theming

if [[ $WITH_THEMING -eq 1 ]]; then
    step "Installing the theming layer"

    mkdir -p "$LUCID_DIR/themes" "$MATUGEN_DIR/templates" "$WALL_SCRIPT_DIR" "$HOME/.cache/quickshell"

    cp -r "$SRC/support/lucid/themes/." "$LUCID_DIR/themes/"
    install -m755 "$SRC/support/lucid/apply-theme.sh"      "$LUCID_DIR/apply-theme.sh"
    install -m755 "$SRC/support/lucid/gen-pywal-palette.py" "$LUCID_DIR/gen-pywal-palette.py"
    install -m755 "$SRC/support/lucid/add-theme.py"        "$LUCID_DIR/add-theme.py"
    install -m755 "$SRC/support/lucid/gen-light-palette.py" "$LUCID_DIR/gen-light-palette.py"
    install -m755 "$SRC/support/lucid/set-mode.sh"         "$LUCID_DIR/set-mode.sh"
    install -m755 "$SRC/support/lucid/sync-sddm.sh"        "$LUCID_DIR/sync-sddm.sh"
    install -m644 "$SRC/support/lucid/lucid_palette.py"    "$LUCID_DIR/lucid_palette.py"
    install -m755 "$SRC/support/wallpaper/set-wallpaper.sh" "$WALL_SCRIPT_DIR/set-wallpaper.sh"
    # rules you wrote are yours: only ever placed when there are none
    [[ -f "$LUCID_DIR/wallpaper-outputs.conf" ]] || install -m644 "$SRC/support/lucid/wallpaper-outputs.conf" "$LUCID_DIR/wallpaper-outputs.conf"
    # the sddm theme lives outside $HOME, so it is the one thing here that
    # needs root. skipped entirely when sddm is not installed, and it never
    # switches the active theme - that stays the user's call
    if [[ -d /usr/share/sddm/themes ]]; then
        SDDM_THEME_DIR=/usr/share/sddm/themes/lucid
        if sudo install -d -m755 "$SDDM_THEME_DIR" 2>/dev/null \
           && sudo cp -r "$SRC/support/sddm/lucid/." "$SDDM_THEME_DIR/"; then
            # sync-sddm.sh repaints this on every theme change, and it must be
            # able to do that without asking for a password every time
            sudo chown -R "$USER" "$SDDM_THEME_DIR"
            say "  sddm theme      -> $SDDM_THEME_DIR"
            # /etc/sddm.conf outranks /etc/sddm.conf.d, so point at the file
            # that actually wins rather than at the tidier-looking drop-in
            say "    enable it with: Current=lucid under [Theme] in /etc/sddm.conf"
        else
            warn "could not install the sddm theme (needs sudo); skipping"
        fi
    fi

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
    # no dir: guard on these two. gtk only creates ~/.config/gtk-{3,4}.0 once
    # an app writes a setting there, so on a fresh machine the guard skipped
    # both templates, matugen never wrote colors.css, and nautilus kept its
    # stock colours forever. add_template creates the directory itself.
    add_template gtk3           "$TPL/gtk-colors.css"          '~/.config/gtk-3.0/colors.css'
    add_template gtk4           "$TPL/gtk-colors.css"          '~/.config/gtk-4.0/colors.css'
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
        mkdir -p "$gtkdir"
        if [[ -f "$gtkdir/gtk.css" ]] && grep -q "colors.css" "$gtkdir/gtk.css"; then
            say "  ${dim}gtk-$gtkver already imports colors.css${r}"
        else
            [[ -f "$gtkdir/gtk.css" ]] && cp "$gtkdir/gtk.css" "$gtkdir/gtk.css.backup-$STAMP"
            printf "@import url('colors.css');\n" >> "$gtkdir/gtk.css"
            say "  gtk-$gtkver now imports colors.css"
        fi
    done

    # --- the look: terminal + prompt + blur -------------------------------
    # each piece is additive and backed up first, because these are files the
    # user owns and may already have tuned
    if [[ $WITH_LOOK -eq 1 ]] && ask "  Apply the Lucid look (kitty, starship prompt, VSCode theme, GTK theme + icons)?"; then

        # --- gtk theme + icons --------------------------------------------
        # gtk reads three places and they disagree happily. under hyprland
        # there is no xsettings daemon, so gtk3/gtk4 take settings.ini as the
        # source of truth while gnome apps and portals read gsettings - set
        # both or half your apps stay light. settings.ini is merged key by
        # key: it also carries the user's font, cursor and hinting choices.
        GTK_THEME_NAME=adw-gtk3-dark
        ICON_THEME_NAME=FairyWren_Dark

        # replace the key if it is there, insert it under [Settings] if not
        ini_set() {
            local f=$1 k=$2 v=$3
            mkdir -p "$(dirname "$f")"
            if [[ ! -f "$f" ]]; then
                printf '[Settings]\n%s=%s\n' "$k" "$v" > "$f"
                return 0
            fi
            grep -q '^\[Settings\]' "$f" || printf '\n[Settings]\n' >> "$f"
            if grep -q "^$k=" "$f"; then
                sed -i "s|^$k=.*|$k=$v|" "$f"
            else
                sed -i "0,/^\[Settings\]/s|^\[Settings\]|[Settings]\n$k=$v|" "$f"
            fi
        }

        # FairyWren is not in the repos and the AUR build slices it into 52
        # per-colour themes with different names, so take it from upstream:
        # the two directories there are exactly the theme names set below
        ICONS_DIR="$HOME/.local/share/icons"
        if [[ -d "$ICONS_DIR/$ICON_THEME_NAME" ]]; then
            say "  ${dim}keeping the FairyWren icons already in $ICONS_DIR${r}"
        elif ! command -v git &>/dev/null; then
            warn "  git is not installed — skipping the FairyWren icon theme"
            ICON_THEME_NAME=""
        else
            say "  fetching the FairyWren icon theme (~140MB, one-time)"
            FW_TMP=$(mktemp -d)
            if git clone --depth 1 https://gitlab.com/FreshDoctor/FairyWren-Icons.git \
                 "$FW_TMP/fw" &>/dev/null \
               && [[ -d "$FW_TMP/fw/FairyWren_Dark" && -d "$FW_TMP/fw/FairyWren_Light" ]]; then
                mkdir -p "$ICONS_DIR"
                cp -r "$FW_TMP/fw/FairyWren_Dark" "$FW_TMP/fw/FairyWren_Light" "$ICONS_DIR/"
                say "  FairyWren icons -> $ICONS_DIR"
            else
                warn "  could not fetch the FairyWren icons — leaving the icon theme alone"
                ICON_THEME_NAME=""
            fi
            rm -rf "$FW_TMP"
        fi

        # the loader only rescans a theme once its cache is rebuilt
        if [[ -n "$ICON_THEME_NAME" ]] && command -v gtk-update-icon-cache &>/dev/null; then
            for v in Dark Light; do
                [[ -d "$ICONS_DIR/FairyWren_$v" ]] || continue
                gtk-update-icon-cache -qtf "$ICONS_DIR/FairyWren_$v" &>/dev/null || true
            done
        fi

        # adw-gtk3-dark ships inside adw-gtk-theme rather than as its own
        # package, so check the theme directory, not the package name
        if [[ ! -d /usr/share/themes/$GTK_THEME_NAME && ! -d "$HOME/.themes/$GTK_THEME_NAME" ]]; then
            warn "  $GTK_THEME_NAME is not installed — install adw-gtk-theme"
        fi

        for gtkver in 3.0 4.0; do
            gtkini="$HOME/.config/gtk-$gtkver/settings.ini"
            [[ -f "$gtkini" ]] && cp "$gtkini" "$gtkini.backup-$STAMP"
            ini_set "$gtkini" gtk-theme-name "$GTK_THEME_NAME"
            ini_set "$gtkini" gtk-application-prefer-dark-theme 1
            [[ -n "$ICON_THEME_NAME" ]] && ini_set "$gtkini" gtk-icon-theme-name "$ICON_THEME_NAME"
        done
        say "  gtk-3.0 and gtk-4.0 settings.ini -> $GTK_THEME_NAME${ICON_THEME_NAME:+ + $ICON_THEME_NAME}"

        # gnome apps, portals and anything reading dconf take these instead
        if command -v gsettings &>/dev/null; then
            gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_NAME" 2>/dev/null || true
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
            [[ -n "$ICON_THEME_NAME" ]] && \
                gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME_NAME" 2>/dev/null || true
            say "  gsettings -> $GTK_THEME_NAME, prefer-dark${ICON_THEME_NAME:+, $ICON_THEME_NAME}"
        else
            warn "  gsettings not found — GNOME apps may ignore the theme"
        fi

        # kitty - the include is what makes matugen's colours apply at all
        KITTY_CFG="$HOME/.config/kitty/kitty.conf"
        KITTY_EXISTED=0; [[ -f "$KITTY_CFG" ]] && KITTY_EXISTED=1
        if [[ -f "$HOME/.config/kitty/kitty.conf" ]]; then
            if grep -q "matugen-colors.conf" "$HOME/.config/kitty/kitty.conf"; then
                say "  ${dim}kitty.conf already includes matugen-colors.conf${r}"
            else
                cp "$HOME/.config/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf.backup-$STAMP"
                printf '\n# added by Lucid — colours follow the active theme\ninclude ./matugen-colors.conf\n' \
                    >> "$HOME/.config/kitty/kitty.conf"
                say "  kitty.conf now includes matugen-colors.conf"
            fi
        else
            mkdir -p "$HOME/.config/kitty"
            cp "$SRC/support/look/kitty.conf" "$HOME/.config/kitty/kitty.conf"
            say "  kitty.conf -> ~/.config/kitty/kitty.conf"
        fi

        # background_opacity follows the Glass slider, out of a file the shell
        # rewrites. seed it first: kitty warns about an include it cannot find,
        # and the shell only writes once the value differs from what is there
        if [[ ! -f "$HOME/.config/kitty/lucid-glass.conf" ]]; then
            printf '# generated by lucid settings\ndynamic_background_opacity yes\nbackground_opacity 1.00\n' \
                > "$HOME/.config/kitty/lucid-glass.conf"
            say "  lucid-glass.conf -> ~/.config/kitty/lucid-glass.conf"
        fi
        if grep -q "lucid-glass.conf" "$KITTY_CFG"; then
            say "  ${dim}kitty.conf already includes lucid-glass.conf${r}"
        else
            [[ $KITTY_EXISTED -eq 1 && ! -f "$KITTY_CFG.backup-$STAMP" ]] \
                && cp "$KITTY_CFG" "$KITTY_CFG.backup-$STAMP"
            printf '\n# added by Lucid — opacity follows the Glass slider\ninclude ./lucid-glass.conf\n' \
                >> "$KITTY_CFG"
            say "  kitty.conf now follows the Glass slider"
        fi

        # kitty opens fish rather than the login shell. only wired when fish is
        # really there: kitty fails to open a window at all on a shell it cannot
        # exec, and that reads as "the terminal keybind is broken"
        if command -v fish &>/dev/null; then
            if grep -qE '^[[:space:]]*shell[[:space:]]+' "$KITTY_CFG"; then
                say "  ${dim}kitty.conf already sets a shell${r}"
            else
                [[ $KITTY_EXISTED -eq 1 && ! -f "$KITTY_CFG.backup-$STAMP" ]] \
                    && cp "$KITTY_CFG" "$KITTY_CFG.backup-$STAMP"
                printf '\n# added by Lucid\nshell fish\n' >> "$KITTY_CFG"
                say "  kitty.conf now opens fish"
            fi
        else
            sed -i '/^# kitty opens fish rather than the login shell$/d; /^shell fish$/d' "$KITTY_CFG"
            warn "  fish is not installed — kitty will use your login shell"
        fi

        # vscode / vscodium - matugen writes the colour files, but they do
        # nothing until the Matugen theme extension is installed and selected
        vscode_wire() {
            local cli=$1 cfg=$2
            command -v "$cli" &>/dev/null || return 0
            if "$cli" --list-extensions 2>/dev/null | grep -i "matugen-theme" >/dev/null; then
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

        # starship - the prompt shape ships here; matugen and apply-theme.sh
        # rewrite only its [palettes.colors] block on every theme change, so
        # this file is what makes the prompt look like Lucid's
        STARSHIP_CFG="$HOME/.config/starship.toml"
        if [[ ! -f "$STARSHIP_CFG" ]]; then
            cp "$SRC/support/look/starship.toml" "$STARSHIP_CFG"
            say "  starship.toml -> ~/.config/starship.toml"
        elif grep -q '^\[palettes.colors\]' "$STARSHIP_CFG"; then
            # already the Lucid prompt. its colours are whatever the current
            # theme painted, so re-copying would only reset them to the seed
            say "  ${dim}keeping your starship.toml (already the Lucid prompt)${r}"
        else
            cp "$STARSHIP_CFG" "$STARSHIP_CFG.backup-$STAMP"
            cp "$SRC/support/look/starship.toml" "$STARSHIP_CFG"
            say "  your starship.toml -> starship.toml.backup-$STAMP"
            say "  starship.toml -> ~/.config/starship.toml"
        fi
        command -v starship &>/dev/null \
            || warn "  starship is not installed — the prompt config is in place but unused"

        # the config does nothing until the shell actually calls starship, and
        # the init line differs per shell. only ever appended, never rewritten.
        # a missing rc is created for your login shell only - writing a .zshrc
        # for someone who does not use zsh is just litter
        LOGIN_SH=$(basename "${SHELL:-}")
        starship_init() {
            local rc=$1 line=$2 shname=$3 always=${4:-0}
            if [[ ! -f "$rc" ]]; then
                [[ "$shname" == "$LOGIN_SH" || $always -eq 1 ]] || return 0
                mkdir -p "$(dirname "$rc")"
                printf '# added by Lucid\n%s\n' "$line" > "$rc"
                say "  created $(basename "$rc") to start starship"
                return 0
            fi
            if grep -F 'starship init' "$rc" >/dev/null; then
                say "  ${dim}$(basename "$rc") already starts starship${r}"
            else
                cp "$rc" "$rc.backup-$STAMP"
                printf '\n# added by Lucid\n%s\n' "$line" >> "$rc"
                say "  $(basename "$rc") now starts starship"
            fi
        }
        starship_init "$HOME/.bashrc"                  'eval "$(starship init bash)"'   bash
        # zsh redraws on SIGWINCH but does not re-run precmd, so the prompt keeps
        # the old colours until you press enter. reset-prompt re-runs starship.
        # bash has no equivalent - its prompt updates on the next prompt instead
        starship_init "$HOME/.zshrc" 'eval "$(starship init zsh)"
TRAPWINCH() { zle && { zle reset-prompt; zle -R } }'    zsh
        # always for fish, whatever the login shell is - kitty opens it
        starship_init "$HOME/.config/fish/config.fish" 'starship init fish | source'    fish 1

        # the prompt and kitty.conf are drawn with nerd font glyphs; without
        # the font every segment renders as a replacement box
        fc-list 2>/dev/null | grep -i 'JetBrainsMono Nerd Font' >/dev/null \
            || warn "  JetBrainsMono Nerd Font is missing — the prompt will show boxes"

        # hyprland blur - skipped when the lua config went in above, since its
        # decorations module already carries the same blur
        if [[ $HYPR_LUA_INSTALLED -eq 1 ]]; then
            say "  ${dim}blur comes from modules/decorations.lua${r}"
        elif [[ -f "$HYPR_DIR/hyprland.lua" ]]; then
            mkdir -p "$HYPR_DIR/modules"
            cp "$SRC/support/look/lucid-look.lua" "$HYPR_DIR/modules/lucid-look.lua"
            # per-app glass rides along: Settings > Glass writes lucid-glass.lua
            # and this is the module that reads it
            cp "$SRC/support/hypr/modules/glass.lua" "$HYPR_DIR/modules/glass.lua"
            if grep -q 'require("modules.lucid-look")' "$HYPR_DIR/hyprland.lua"; then
                say "  ${dim}hyprland.lua already requires modules.lucid-look${r}"
            else
                cp "$HYPR_DIR/hyprland.lua" "$HYPR_DIR/hyprland.lua.backup-$STAMP"
                printf '\nrequire("modules.lucid-look")\n' >> "$HYPR_DIR/hyprland.lua"
                say "  hyprland.lua now requires modules.lucid-look"
            fi
            if grep -q 'require("modules.glass")' "$HYPR_DIR/hyprland.lua"; then
                say "  ${dim}hyprland.lua already requires modules.glass${r}"
            else
                [[ -f "$HYPR_DIR/hyprland.lua.backup-$STAMP" ]] \
                    || cp "$HYPR_DIR/hyprland.lua" "$HYPR_DIR/hyprland.lua.backup-$STAMP"
                printf '\nrequire("modules.glass")\n' >> "$HYPR_DIR/hyprland.lua"
                say "  hyprland.lua now requires modules.glass"
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

# -------------------------------------------------------------- wallpapers

# one folder per theme, which is where the wallpaper strip looks:
# ~/Pictures/wallpapers/<theme>. yours are never overwritten or removed
PICTURES_DIR="$HOME/Pictures/wallpapers"
if [[ $WITH_WALLPAPERS -eq 1 && -d "$SRC/wallpapers" ]]; then
    step "Installing the wallpapers"

    WALL_NEW=0
    WALL_KEPT=0
    for dir in "$SRC"/wallpapers/*/; do
        [[ -d "$dir" ]] || continue
        theme="$(basename "$dir")"
        mkdir -p "$PICTURES_DIR/$theme"
        for pic in "$dir"*; do
            [[ -f "$pic" ]] || continue
            dest="$PICTURES_DIR/$theme/$(basename "$pic")"
            if [[ -e "$dest" ]]; then
                WALL_KEPT=$((WALL_KEPT + 1))
            else
                cp "$pic" "$dest"
                WALL_NEW=$((WALL_NEW + 1))
            fi
        done
    done

    say "  $WALL_NEW wallpapers -> $PICTURES_DIR"
    [[ $WALL_KEPT -gt 0 ]] && say "  ${dim}$WALL_KEPT were already there, left as they are${r}"
    say "  ${dim}the strip shows the folder for the theme you are on; SUPER+B opens it${r}"
elif [[ $WITH_WALLPAPERS -eq 0 ]]; then
    step "Skipping the wallpapers (--no-wallpapers)"
    say "  ${dim}$PICTURES_DIR is left alone; the strip shows whatever is in it${r}"
fi

# ---------------------------------------------------------------------- done

step "Done"

# a running instance is still on the old files, so offer the restart that
# actually puts the new version on screen
# no grep -q here: it would close the pipe, and pipefail would then read the
# producer's SIGPIPE as "not running"
if qs list 2>/dev/null | grep -F "$SHELL_DIR/shell.qml" >/dev/null; then
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
  Hyprland is configured: modules/binds.lua carries the binds, the window
  and layer rules are in place, and modules/autostart.lua starts the shell
  on login.

    SUPER            launcher        SUPER+W      workspaces
    SUPER+S          settings        SUPER+T      theme picker
    SUPER+period     emoji           SUPER+B      wallpaper
    SUPER+P          commands        SUPER+E      files
    SUPER+C          close window    SUPER+V      float
    SUPER+D / Print  screenshot      F10          lock
    SUPER+R          reload hypr     F9           terminal

  Special workspaces slide over whatever you are on; the same keys hide them:

    SUPER+SHIFT+S    scratchpad      SUPER+ALT+S  stash a window
    SUPER+SHIFT+M    music           SUPER+SHIFT+D  comms
    SUPER+SHIFT+R    to-do           CTRL+SHIFT+ESC system monitor

  ${b}The new binds are not live yet${r} — run ${b}hyprctl reload${r}, or log out
  and back in to pick up the autostart too.

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
  Or run ${b}./install.sh --with-hypr${r} to take Lucid's config wholesale.

EOF
fi

if [[ $DEPS_OK -eq 0 ]]; then
    warn "some dependencies are missing — the shell is installed, but the"
    warn "features they back will not work until you install them."
fi
