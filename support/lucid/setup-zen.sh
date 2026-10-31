#!/usr/bin/env bash
# setup-zen.sh profile
# setup-zen.sh install
# setup-zen.sh program [--check]
#
# lets zen take lucid's colours. matugen renders them into the profile's
# chrome/lucid-zen.css (support/matugen/templates/zen-userchrome.css), and
# the websites' into lucid-sites.css (zen-sites.css). zen reads them when it
# starts, and with fx-autoconfig's loader in place lucid-zen.sys.mjs swaps in
# each new render while it runs.
#
#   profile   print the profile zen starts with: installs.ini's default, then
#             profiles.ini's. several folders can match *.Default*, and the
#             first of them is often an empty one zen never opens
#   install   wire that profile: the pref that lets zen read userChrome.css,
#             an @import of lucid-zen.css at the top of userChrome.css and of
#             lucid-sites.css at the top of userContent.css, and
#             fx-autoconfig's profile half with lucid-zen.sys.mjs. a
#             userChrome.css the old template rendered is replaced, anything
#             else in either is kept; the old file goes to <name>.lucid-backup
#   program   put fx-autoconfig's loader into zen's install folder, with sudo.
#             --check exits 0 when a loader is there, 1 when it is not, 2 when
#             zen's folder can't be found (a flatpak, say)
#
# the loader runs whatever lands in the profile's chrome/JS, with the
# browser's full rights. that is the price of live colours

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES="$HERE/zen"
[[ -d "$FILES" ]] || FILES="$HERE/../zen"

ROOT="${ZEN_ROOT:-$HOME/.config/zen}"
[[ -d "$ROOT" || ! -d "$HOME/.zen" ]] || ROOT="$HOME/.zen"

PREF='toolkit.legacyUserProfileCustomizations.stylesheets'
IMPORT='@import url("lucid-zen.css");'
SITES_IMPORT='@import url("lucid-sites.css");'

# what the old template rendered into userChrome.css, colours and whitespace out
OLD_RENDER=':root{--toolbar-bgcolor:X!important;--toolbar-color:X!important;--toolbar-field-background-color:X!important;--toolbar-field-color:X!important;--toolbar-field-border-color:X!important;--toolbar-field-focus-background-color:X!important;--lwt-toolbar-field-background-color:X!important;--lwt-toolbar-field-color:X!important;}#urlbar-background,#urlbar{background-color:X!important;color:X!important;}'

profile() {
    local path=""
    if [[ -f "$ROOT/installs.ini" ]]; then
        path=$(awk '/^Default=/ { print substr($0, 9); exit }' "$ROOT/installs.ini")
    fi
    if [[ -z "$path" && -f "$ROOT/profiles.ini" ]]; then
        # an [Install...] section's default, else the profile marked Default=1
        path=$(awk '
            function flush() { if (prof && def && p != "" && marked == "") marked = p }
            /^\[/ { flush(); inst = /^\[Install/; prof = /^\[Profile/; p = ""; def = 0; next }
            inst && /^Default=/ && installed == "" { installed = substr($0, 9) }
            prof && /^Path=/ { p = substr($0, 6) }
            prof && /^Default=1/ { def = 1 }
            END { flush(); print (installed != "" ? installed : marked) }
        ' "$ROOT/profiles.ini")
    fi
    [[ -n "$path" ]] || return 1
    [[ "$path" == /* ]] || path="$ROOT/$path"
    [[ -d "$path" ]] || return 1
    printf '%s\n' "$path"
}

# zen holds a lock symlink in the profile, pointing at host:+pid, while it runs
running() {
    local target pid
    target=$(readlink "$1/lock" 2>/dev/null) || return 1
    pid=${target##*+}
    [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null
}

install_profile() {
    local dir chrome uc f changed=0 fresh=1
    dir=$(profile) || { echo "error: no zen profile yet; start zen once" >&2; exit 1; }
    chrome="$dir/chrome"
    uc="$chrome/userChrome.css"
    mkdir -p "$chrome"

    # zen ignores userChrome.css until this is on. a user.js that turns it off
    # is the user's choice and stays
    if ! grep -qs "\"$PREF\"" "$dir/user.js"; then
        printf 'user_pref("%s", true);\n' "$PREF" >> "$dir/user.js"
    elif grep -qs "\"$PREF\", *false" "$dir/user.js"; then
        echo "warning: $dir/user.js turns $PREF off, so zen won't read the colours" >&2
    fi

    # open and save dialogs through the portal, which is lumen (lumen --portal):
    # outside a flatpak zen only asks it when told to always. a value set already stays
    if ! grep -qs '"widget.use-xdg-desktop-portal.file-picker"' "$dir/user.js"; then
        printf 'user_pref("widget.use-xdg-desktop-portal.file-picker", 1);\n' >> "$dir/user.js"
    fi

    if [[ ! -f "$uc" ]]; then
        printf '%s\n' "$IMPORT" > "$uc"
    elif ! grep -qF 'lucid-zen.css' "$uc"; then
        cp "$uc" "$uc.lucid-backup"
        # written through, not renamed, so a symlinked userChrome.css survives
        if [[ "$(sed -E 's/#[0-9a-fA-F]{6,8}/X/g' "$uc" | tr -d ' \t\n')" == "$OLD_RENDER" ]]; then
            printf '%s\n' "$IMPORT" > "$uc"
        else
            { printf '%s\n\n' "$IMPORT"; cat "$uc.lucid-backup"; } > "$uc"
        fi
    fi

    # the same for web pages (zen-sites.css), which read userContent.css
    uc="$chrome/userContent.css"
    if [[ ! -f "$uc" ]]; then
        printf '%s\n' "$SITES_IMPORT" > "$uc"
    elif ! grep -qF 'lucid-sites.css' "$uc"; then
        cp "$uc" "$uc.lucid-backup"
        { printf '%s\n\n' "$SITES_IMPORT"; cat "$uc.lucid-backup"; } > "$uc"
    fi

    # fx-autoconfig's profile half starts JS/lucid-zen.sys.mjs. a utils/ that
    # isn't lucid's (the user's own fx-autoconfig, or sine's) loads JS/ the
    # same way and is left alone
    [[ -e "$chrome/JS/lucid-zen.sys.mjs" ]] && fresh=0
    mkdir -p "$chrome/JS" "$chrome/CSS" "$chrome/resources"
    if [[ ! -e "$chrome/utils/boot.sys.mjs" || -f "$chrome/utils/.lucid" ]]; then
        mkdir -p "$chrome/utils"
        for f in "$FILES/fx-autoconfig/utils/"*; do
            cmp -s "$f" "$chrome/utils/${f##*/}" || { cp "$f" "$chrome/utils/"; changed=1; }
        done
        : > "$chrome/utils/.lucid"
    fi
    if ! cmp -s "$FILES/lucid-zen.sys.mjs" "$chrome/JS/lucid-zen.sys.mjs"; then
        cp "$FILES/lucid-zen.sys.mjs" "$chrome/JS/lucid-zen.sys.mjs"
        changed=1
    fi

    # zen keeps compiled scripts in its startup cache and keeps running an old
    # copy until that is cleared, which only sticks while zen is closed
    if (( changed )); then
        if ! running "$dir"; then
            rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/zen/${dir##*/}/startupCache"
        elif (( ! fresh )); then
            echo "note: restart zen, then about:support -> Clear startup cache, to load the new lucid-zen.sys.mjs" >&2
        fi
    fi
}

# zen's install folder, from the launcher on PATH (the arch packages start
# zen-bin through a small shell script), else the usual places
zen_dir() {
    local bin dir
    for bin in zen-browser zen; do
        bin=$(command -v "$bin") || continue
        if [[ "$(head -c 2 "$bin")" == '#!' ]]; then
            dir=$(grep -m1 -o '/[^ "]*/zen-bin' "$bin" || true)
            dir=${dir%/zen-bin}
        else
            dir=$(dirname "$(readlink -f "$bin")")
        fi
        if [[ -n "$dir" ]] && grep -qs '^Name=Zen' "$dir/application.ini"; then
            printf '%s\n' "$dir"
            return 0
        fi
    done
    for dir in /opt/zen-browser-bin /opt/zen-browser /usr/lib/zen-browser; do
        if grep -qs '^Name=Zen' "$dir/application.ini"; then
            printf '%s\n' "$dir"
            return 0
        fi
    done
    return 1
}

program() {
    local dir cfg prefs
    dir=$(zen_dir) || { [[ "${1:-}" == --check ]] || echo "error: can't find zen's install folder" >&2; return 2; }
    cfg="$dir/config.js"
    prefs="$dir/defaults/pref/config-prefs.js"
    # fx-autoconfig's loader, or another that starts utils/boot.sys.mjs the same way
    if grep -qs 'chrome://userchromejs/content/boot.sys.mjs' "$cfg" \
        && grep -qs 'general.config.filename", *"config.js"' "$prefs"; then
        return 0
    fi
    [[ "${1:-}" == --check ]] && return 1
    if [[ -e "$cfg" ]] && ! grep -qs 'boot.sys.mjs' "$cfg"; then
        echo "error: $cfg is another autoconfig script; leaving it" >&2
        return 3
    fi
    sudo install -m644 "$FILES/fx-autoconfig/program/config.js" "$cfg"
    sudo install -Dm644 "$FILES/fx-autoconfig/program/defaults/pref/config-prefs.js" "$prefs"
}

case "${1:-}" in
    profile) profile || exit 1 ;;
    install) install_profile ;;
    program) program "${2:-}" ;;
    *)
        sed -n '2,4p' "$0" | sed 's/^# /usage: /' >&2
        exit 2
        ;;
esac
