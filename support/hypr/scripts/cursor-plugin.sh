#!/usr/bin/env bash
# the cursor that tilts as it moves: hypr-dynamic-cursors, built here against
# the headers the hyprland package itself installs, so the build always matches
# the Hyprland it is for. no hyprpm, no root, no second copy of the headers to
# go stale when a library under Hyprland is updated.
#
#   cursor-plugin.sh build    compile it (again) for the installed Hyprland
#   cursor-plugin.sh load     put the built plugin into the running Hyprland
#   cursor-plugin.sh ensure   what autostart runs: rebuild if Hyprland changed
#                             since the last build, then load. does nothing at
#                             all until the plugin has been built once
#   cursor-plugin.sh status   say what is built, for what, and if it is loaded
#   cursor-plugin.sh remove   unload it and delete the build

set -euo pipefail

URL=https://github.com/virtcode/hypr-dynamic-cursors
NAME=dynamic-cursors
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/lucid/plugins"
SO="$DIR/$NAME.so"
STAMP="$DIR/$NAME.abi"

say()  { printf '%s\n' "$*"; }
die()  { printf 'cursor-plugin: %s\n' "$*" >&2; exit 1; }

# the hyprland package's own version.h, found through its pkg-config entry
version_h() {
    local flag d f
    for flag in $(pkg-config --cflags-only-I hyprland 2>/dev/null); do
        d="${flag#-I}"
        for f in "$d/version.h" "$d/src/version.h" "$d/hyprland/src/version.h"; do
            [[ -f "$f" ]] && { printf '%s\n' "$f"; return 0; }
        done
    done
    return 1
}

# the string a plugin built from these headers identifies itself with: the
# commit, then major.minor of each library. PluginAPI.hpp builds the same one
header_abi() {
    local vh
    vh=$(version_h) || return 1
    awk -F'"' '
        function mm(v) { sub(/\.[^.]*$/, "", v); return v }
        /define GIT_COMMIT_HASH/      { c = $2 }
        /define AQUAMARINE_VERSION /  { aq = mm($2) }
        /define HYPRUTILS_VERSION/    { hu = mm($2) }
        /define HYPRGRAPHICS_VERSION/ { hg = mm($2) }
        /define HYPRCURSOR_VERSION/   { hc = mm($2) }
        /define HYPRLANG_VERSION/     { hlg = mm($2) }
        END { print c "_aq_" aq "_hu_" hu "_hg_" hg "_hc_" hc "_hlg_" hlg }' "$vh"
}

# what the running Hyprland will accept; empty when there is none, or when it
# is too old to say
running_abi() {
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return 0
    hyprctl version 2>/dev/null | sed -n 's/^Version ABI string: //p' || true
}

is_loaded() {
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return 1
    # no grep -q: under pipefail the producer's SIGPIPE would read as "no"
    hyprctl plugin list 2>/dev/null | grep -F "$NAME" >/dev/null
}

notify() {
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return 0
    hyprctl notify 3 9000 "rgb(ff6666)" "$1" >/dev/null 2>&1 || true
}

build() {
    local c missing=()
    for c in git make g++ pkg-config; do
        command -v "$c" >/dev/null 2>&1 || missing+=("$c")
    done
    (( ${#missing[@]} == 0 )) || die "needs ${missing[*]} (pacman -S --needed base-devel git)"
    version_h >/dev/null || die "Hyprland's headers are not installed (no pkg-config entry for hyprland)"

    # not a local: the trap runs after this function has returned
    local commit pin
    TMP=$(mktemp -d)
    trap 'rm -rf "$TMP"' EXIT

    say "fetching $URL"
    git clone -q "$URL" "$TMP/src" || die "could not fetch the plugin"

    # the plugin pins a commit of its own to each Hyprland release; past the
    # newest release it lists, its main branch is the one that fits
    commit=$(sed -n 's/^#define GIT_COMMIT_HASH *"\(.*\)".*/\1/p' "$(version_h)")
    pin=$(awk -F'"' -v c="$commit" '$2 == c { p = $4 } END { print p }' "$TMP/src/hyprpm.toml" 2>/dev/null || true)
    if [[ -n "$pin" ]]; then
        git -C "$TMP/src" checkout -q "$pin" || die "the plugin has no commit $pin"
    fi

    say "building for Hyprland ${commit:0:9} (about a minute)"
    if ! nice -n 19 make -C "$TMP/src" -j"$(nproc)" all >"$TMP/build.log" 2>&1; then
        tail -n 25 "$TMP/build.log" >&2
        die "the build failed — the plugin may not support this Hyprland yet"
    fi

    # install replaces the file rather than writing into it, so a copy that is
    # loaded right now keeps running until the next load
    install -Dm755 "$TMP/src/out/$NAME.so" "$SO" || die "could not write $SO"
    header_abi > "$STAMP" || die "could not write $STAMP"
    say "built -> $SO"
}

load() {
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || die "not inside Hyprland — it is loaded on the next login"
    [[ -f "$SO" ]] || die "not built yet (cursor-plugin.sh build)"
    is_loaded && { say "already loaded"; return 0; }

    # built for the package on disk, but the session is still the Hyprland
    # from before an upgrade: it would refuse this, so don't hand it over
    local run
    run=$(running_abi)
    if [[ -n "$run" && -f "$STAMP" && "$(cat "$STAMP")" != "$run" ]]; then
        die "built for a newer Hyprland than the one running — log out and back in"
    fi

    local out
    out=$(hyprctl plugin load "$SO" 2>&1) || true
    # the plugin reloads the config itself once it is in, which is when the
    # settings in modules/plugins.lua take hold
    sleep 0.5
    is_loaded || die "Hyprland would not load it: ${out:-no reason given}"
    say "loaded"
}

ensure() {
    # never built: nobody asked for it, and autostart must not start compiling
    [[ -f "$SO" ]] || return 0
    local want
    want=$(header_abi) || return 0
    # subshells: a die in there has to come back here, not end the script
    if [[ ! -f "$STAMP" || "$(cat "$STAMP")" != "$want" ]]; then
        ( build ) >/dev/null 2>&1 || {
            notify "Lucid: the cursor plugin could not be rebuilt for this Hyprland (cursor-plugin.sh build)"
            return 1
        }
    fi
    ( load ) >/dev/null 2>&1 || {
        notify "Lucid: the cursor plugin did not load (cursor-plugin.sh status)"
        return 1
    }
}

status() {
    local built="not built" run
    [[ -f "$SO" ]] && built="$(cat "$STAMP" 2>/dev/null || echo 'built, for an unknown Hyprland')"
    run=$(running_abi)
    say "built for : $built"
    say "installed : $(header_abi 2>/dev/null || echo 'no Hyprland headers')"
    say "running   : ${run:-not inside Hyprland}"
    if is_loaded; then say "loaded    : yes"; else say "loaded    : no"; fi
}

remove() {
    if is_loaded; then
        hyprctl plugin unload "$SO" >/dev/null 2>&1 || true
    fi
    rm -f "$SO" "$STAMP"
    say "removed"
}

mkdir -p "$DIR"
case "${1:-}" in
    build)  build ;;
    load)   load ;;
    status) status ;;
    remove) remove ;;
    ensure)
        # one at a time: a second login session must not compile alongside
        exec 9>"$DIR/.lock"
        flock -n 9 || exit 0
        ensure
        ;;
    *) die "usage: cursor-plugin.sh build | load | ensure | status | remove" ;;
esac
