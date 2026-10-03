#!/usr/bin/env bash
# set-wallpaper.sh <path-to-image> [dark|light]
#
# sets the wallpaper, then regenerates colours if the active theme derives
# them from the image. ~/.cache/current_theme decides:
#   matugen  — matugen works out the scheme, render-templates.sh renders every
#              template in its config from it
#   pywal    — wal extracts, gen-pywal-palette.py maps it to material roles
#   anything else — a static theme owns its palette, so colours are left alone
#
# the mode argument is remembered in ~/.cache/current_mode, so a later wallpaper
# change keeps whichever of light/dark the desktop is currently in instead of
# silently dropping back to dark.
#
# the wallpaper is set first because it is the only step you actually see.
# ~/.config/lucid/wallpaper-outputs.conf, if it exists, overrides single outputs.

set -euo pipefail

WALLPAPER="${1:-}"
CACHE_DIR="$HOME/.cache"
CURRENT_WALL_FILE="$CACHE_DIR/current_wallpaper"
CURRENT_THEME_FILE="$CACHE_DIR/current_theme"
CURRENT_MODE_FILE="$CACHE_DIR/current_mode"
LUCID_DIR="$HOME/.config/lucid"
WALL_RULES_FILE="$LUCID_DIR/wallpaper-outputs.conf"

CURRENT_THEME="$(cat "$CURRENT_THEME_FILE" 2>/dev/null || echo matugen)"
MODE="${2:-$(cat "$CURRENT_MODE_FILE" 2>/dev/null || echo dark)}"

usage() {
    echo "usage: $(basename "$0") <path-to-image> [dark|light]"
    exit 1
}

[[ -z "$WALLPAPER" ]] && { echo "error: no wallpaper path given" >&2; usage; }

WALLPAPER="${WALLPAPER/#\~/$HOME}"

[[ -f "$WALLPAPER" ]] || { echo "error: file not found: $WALLPAPER" >&2; exit 1; }

if [[ "$MODE" != "dark" && "$MODE" != "light" ]]; then
    echo "error: mode must be dark or light (got: $MODE)" >&2
    usage
fi

# wallpaper daemon: awww, falling back to swww
if command -v awww &>/dev/null; then
    WP_CLI=awww; WP_DAEMON=awww-daemon
elif command -v swww &>/dev/null; then
    WP_CLI=swww; WP_DAEMON="swww-daemon"
else
    echo "error: neither awww nor swww is installed" >&2
    exit 1
fi

if ! "$WP_CLI" query &>/dev/null; then
    "$WP_DAEMON" &>/dev/null &
    sleep 0.5
fi

FADE=1

# the daemon decodes the whole original on every switch, 0.36 s for an 8k jpeg
# before the fade can even start. a copy scaled to the screen decodes in a
# fraction of that, so each picture gets one, made after its first use
FIT_DIR="$CACHE_DIR/lucid/wallpaper-fit"
FIT_SIZE=""
if command -v magick &>/dev/null && command -v jq &>/dev/null && command -v hyprctl &>/dev/null; then
    FIT_SIZE=$(hyprctl monitors -j 2>/dev/null | jq -r '
        [.[] | if (.transform % 2) == 1 then [.height, .width] else [.width, .height] end]
        | if length == 0 then empty else "\(map(.[0]) | max)x\(map(.[1]) | max)" end' 2>/dev/null || true)
fi
FIT_TODO=()

fit_key() {
    local mtime
    mtime=$(stat -c %Y "$1" 2>/dev/null || echo 0)
    printf '%s|%s|%s' "$1" "$mtime" "$FIT_SIZE" | sha1sum | cut -c1-16
}

fit_copy() {
    # sets FIT_IMG to what the daemon should load: the scaled copy when there is
    # one. not printed, because a $( ) subshell would lose FIT_TODO
    local img="$1" key
    FIT_IMG="$img"
    [[ -n "$FIT_SIZE" && "${img,,}" =~ \.(jpe?g|png|webp)$ ]] || return 0
    key=$(fit_key "$img")
    if [[ -f "$FIT_DIR/$key.jpg" ]]; then
        touch "$FIT_DIR/$key.jpg"
        FIT_IMG="$FIT_DIR/$key.jpg"
    elif [[ ! -f "$FIT_DIR/$key.orig" ]]; then
        FIT_TODO+=("$img")
    fi
}

make_fit_copies() {
    # runs after the fade, niced: scales each new picture to cover the largest
    # screen, or leaves a .orig marker when it is already close to that size
    local img key dims sw sh tw th tmp
    mkdir -p "$FIT_DIR"
    tw=${FIT_SIZE%x*}; th=${FIT_SIZE#*x}
    for img in "$@"; do
        key=$(fit_key "$img")
        dims=$(magick identify -ping -format '%w %h' "$img[0]" 2>/dev/null) || continue
        read -r sw sh <<<"$dims"
        # under a third more pixels than the screen is not worth a second file
        if (( sw * sh * 3 <= tw * th * 4 )); then
            : > "$FIT_DIR/$key.orig"
            continue
        fi
        tmp="$FIT_DIR/.$key.$$.jpg"
        if magick "$img[0]" -auto-orient -resize "${tw}x${th}^" \
                -quality 95 -sampling-factor 4:4:4 "$tmp" 2>/dev/null; then
            mv -f "$tmp" "$FIT_DIR/$key.jpg"
        else
            rm -f "$tmp"
        fi
    done
    find "$FIT_DIR" -type f -mtime +60 -delete 2>/dev/null || true
}

set_output() {
    # $1 image, $2 output ("" for every one), rest passed to the daemon.
    # extra args may be --resize no or fit, which need the original's own size
    local img="$1" out="$2"; shift 2
    if [[ $# -eq 0 ]]; then
        fit_copy "$img"
        img="$FIT_IMG"
    fi
    if [[ -n "$out" ]]; then
        "$WP_CLI" img "$img" -o "$out" \
            --transition-type fade --transition-duration "$FADE" --transition-fps 60 "$@" \
            || echo "warning: could not set the wallpaper on $out" >&2
    else
        "$WP_CLI" img "$img" \
            --transition-type fade --transition-duration "$FADE" --transition-fps 60 "$@"
    fi
}

# per-output overrides, one rule a line:  <output>  <extra args for img>
# any argument that is a file becomes that output's image, the rest are passed
# through, so a portrait screen can letterbox instead of crop, or show its own
# picture. every other output gets $WALLPAPER, in the same pass, so nothing
# fades twice
declare -A WALL_RULES=()
if [[ -f "$WALL_RULES_FILE" ]]; then
    while read -r RULE_OUT RULE_ARGS; do
        [[ -z "${RULE_OUT:-}" || "$RULE_OUT" == \#* ]] && continue
        WALL_RULES["$RULE_OUT"]="$RULE_ARGS"
    done < "$WALL_RULES_FILE"
fi

OUTPUTS=()
if [[ ${#WALL_RULES[@]} -gt 0 ]] && command -v hyprctl &>/dev/null; then
    while read -r NAME; do
        [[ -n "$NAME" ]] && OUTPUTS+=("$NAME")
    done < <(hyprctl monitors | awk '/^Monitor /{print $2}')
fi

if [[ ${#OUTPUTS[@]} -eq 0 ]]; then
    set_output "$WALLPAPER" ""
else
    for OUT in "${OUTPUTS[@]}"; do
        OUT_IMG="$WALLPAPER"
        OUT_ARGS=()
        for ARG in ${WALL_RULES[$OUT]:-}; do
            ARG="${ARG/#\~/$HOME}"
            if [[ -f "$ARG" ]]; then
                OUT_IMG="$ARG"
            else
                OUT_ARGS+=("$ARG")
            fi
        done
        set_output "$OUT_IMG" "$OUT" ${OUT_ARGS[@]+"${OUT_ARGS[@]}"}
    done
fi

mkdir -p "$CACHE_DIR"
printf '%s' "$WALLPAPER" > "$CURRENT_WALL_FILE"
printf '%s' "$MODE" > "$CURRENT_MODE_FILE"

if [[ ${#FIT_TODO[@]} -gt 0 ]]; then
    # once a browse has moved on, and one picture at a time: a burst through the
    # strip used to start a full-size resize for every picture it passed
    mkdir -p "$FIT_DIR"
    ( sleep 3; flock "$FIT_DIR/.lock" nice -n 19 ionice -c 3 env MAGICK_THREAD_LIMIT=2 \
        bash -c "$(declare -f fit_key make_fit_copies); FIT_DIR='$FIT_DIR' FIT_SIZE='$FIT_SIZE' make_fit_copies \"\$@\"" _ "${FIT_TODO[@]}" \
    ) &>/dev/null &
fi

# the picture is up; everything below only re-derives colours, and that is what
# stuttered the whole desktop. browsing the wallpaper strip sets a picture every
# half second or so, so the work is split by who is looking at it:
#
#   colours   the palette the shell reads, worked out once no new picture has
#             been asked for in COLOUR_SETTLE. a picture only passed through
#             never reaches imagemagick
#   apps      everything else: kitty, vscodium, discord, spotify, steam, the gtk
#             theme bounce (which restyles every gtk, firefox and electron
#             window there is) and the login screen. nobody sees those while
#             browsing, so they wait for APPS_SETTLE of quiet and run once
#
# and three guards on both:
#
#   low priority, two threads   imagemagick takes every core by default, and
#                               eight busy cores starve hyprland and the shell
#                               of frames however cheap their own work is
#   one at a time, newest wins  overlapping runs multiplied the work
#   skip when nothing moved     same theme, mode and picture means the colours
#                               on disk are already the right ones
COLOUR_LOCK="$CACHE_DIR/lucid-colours.lock"
COLOUR_WANT="$CACHE_DIR/lucid-colours.want"
COLOUR_DONE="$CACHE_DIR/lucid-colours.done"
APPS_DONE="$CACHE_DIR/lucid-colours.apps"
# matugen's scheme for the picture last derived, which the apps stage renders from
SCHEME="$CACHE_DIR/lucid/wallpaper-scheme.json"
SHELL_PALETTE="$CACHE_DIR/quickshell/matugen.json"
COLOUR_SETTLE=0.9
APPS_SETTLE=3

export MAGICK_THREAD_LIMIT="${MAGICK_THREAD_LIMIT:-2}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-2}"
LOW=(nice -n 19)
command -v ionice &>/dev/null && LOW+=(ionice -c 3)

# the mtime is in there so that overwriting a wallpaper in place still counts
# as a change; nothing else about the request can move the palette. the file's
# own mtime is when the newest request came in, which is what settle waits on
{
    printf '%s\n' "$CURRENT_THEME" "$MODE"
    stat -c %Y "$WALLPAPER" 2>/dev/null || echo 0
    printf '%s\n' "$WALLPAPER"
} > "$COLOUR_WANT"

settle() {
    # returns once nothing new has been asked for in $1 seconds
    local left
    while :; do
        left=$(awk -v now="$EPOCHREALTIME" -v s="$1" \
            -v at="$(stat -c %.3Y "$COLOUR_WANT" 2>/dev/null || echo 0)" \
            'BEGIN { d = at + s - now; printf "%.3f", (d > 0 && d <= s) ? d : 0 }')
        [[ "$left" == "0.000" ]] && return 0
        sleep "$left"
    done
}

same_picture() {
    # the newest request keeps the picture last derived and only moves the theme
    # or the mode: a single click rather than a browse, so it need not wait
    [[ -f "$COLOUR_DONE" && "$(sed -n '3,4p' "$COLOUR_WANT")" == "$(sed -n '3,4p' "$COLOUR_DONE")" ]]
}

superseded() {
    # a newer picture was asked for while this one was being worked out
    ! cmp -s "$COLOUR_WANT" "$SNAP"
}

# derive_colours sets this instead of returning non-zero, which set -e would
# turn into an exit
SKIPPED=0

derive_colours() {
    local theme="$1" mode="$2" wallpaper="$3"
    local wal_args=()
    SKIPPED=0

    case "$theme" in
    matugen)
        if ! command -v matugen &>/dev/null; then
            echo "warning: matugen not installed, colours unchanged" >&2
            return 0
        fi
        superseded && { SKIPPED=1; return 0; }
        # --source-color-index keeps it non-interactive, so it can't hang on a
        # picker prompt it will never receive from a keybind
        if [[ -x "$LUCID_DIR/render-templates.sh" ]]; then
            # the scheme type, contrast and starting colour set in Settings -> Colours
            local MATUGEN_SCHEME=scheme-tonal-spot MATUGEN_CONTRAST=0 SOURCE_INDEX=0
            if [[ -f "$LUCID_DIR/matugen-options.sh" ]]; then
                # shellcheck source=../lucid/matugen-options.sh
                . "$LUCID_DIR/matugen-options.sh"
                SOURCE_INDEX=$(matugen_source_index "$wallpaper")
            fi
            # matugen only works out the scheme. the shell's own template is
            # rendered from it here, every other one in the apps stage
            mkdir -p "$(dirname "$SCHEME")"
            scheme_from() {
                "${LOW[@]}" matugen image "$wallpaper" -m "$mode" -t "$MATUGEN_SCHEME" --contrast "$MATUGEN_CONTRAST" \
                    --source-color-index "$1" --dry-run --json hex --include-image-in-json true -q > "$SCHEME.tmp"
            }
            # an index past the colours this image has falls back to its most
            # dominant, quietly: matugen's complaint about it is expected
            if { [[ "$SOURCE_INDEX" != 0 ]] && scheme_from "$SOURCE_INDEX" 2>/dev/null; } || scheme_from 0; then
                mv -f "$SCHEME.tmp" "$SCHEME"
                superseded && { SKIPPED=1; return 0; }
                "${LOW[@]}" "$LUCID_DIR/render-templates.sh" "$SCHEME" "$mode" matugen \
                    --only-output "$SHELL_PALETTE" || true
            else
                rm -f "$SCHEME.tmp" "$SCHEME"
                echo "warning: matugen could not read $wallpaper, colours unchanged" >&2
            fi
        else
            # no renderer: matugen renders every template in one go, so the
            # apps stage is left only the login screen and the prompt
            "${LOW[@]}" matugen image "$wallpaper" -m "$mode" --source-color-index 0
            hyprctl reload &>/dev/null || true
        fi
        ;;
    pywal)
        if ! command -v wal &>/dev/null; then
            echo "warning: pywal not installed, colours unchanged" >&2
            return 0
        fi
        # -n leaves the wallpaper alone, it is already set above; -l extracts a
        # light terminal palette, which is what the light branch of the generator
        # expects to be handed
        wal_args=(-i "$wallpaper" -n -s -t -e -q)
        [[ "$mode" == "light" ]] && wal_args+=(-l)
        "${LOW[@]}" wal "${wal_args[@]}" || echo "warning: wal failed" >&2
        if "${LOW[@]}" "$LUCID_DIR/gen-pywal-palette.py" "$mode"; then
            superseded && { SKIPPED=1; return 0; }
            "${LOW[@]}" "$LUCID_DIR/apply-theme.sh" --shell-only pywal "$mode" \
                || echo "warning: could not apply the pywal palette" >&2
        else
            echo "warning: pywal palette generation failed" >&2
        fi
        ;;
    *)
        # a static theme owns its palette; only the login screen's copy of the
        # wallpaper moves, and that is the apps stage's
        echo "static theme ($theme) — colours unchanged"
        ;;
    esac
}

apply_apps() {
    local theme="$1" mode="$2"

    case "$theme" in
    matugen)
        if [[ -x "$LUCID_DIR/render-templates.sh" && -s "$SCHEME" ]]; then
            # every template, the shell's again among them: an identical palette
            # costs the shell nothing, and the record Settings shows stays whole.
            # the renderer reloads hyprland if a template wrote its colours
            "${LOW[@]}" "$LUCID_DIR/render-templates.sh" "$SCHEME" "$mode" matugen || true
        fi
        # matugen writes the palette from its own templates and never reaches
        # apply-theme.sh, so this is the only place the login screen can follow it
        "${LOW[@]}" "$LUCID_DIR/sync-sddm.sh" 2>/dev/null || true
        # the prompt too: a template would own the whole file, this only its palette
        "${LOW[@]}" "$LUCID_DIR/sync-starship.sh" 2>/dev/null || true
        ;;
    pywal)
        "${LOW[@]}" "$LUCID_DIR/apply-theme.sh" --apps-only pywal "$mode" \
            || echo "warning: could not mirror the pywal palette" >&2
        hyprctl reload &>/dev/null || true
        ;;
    *)
        # the palette stays put but the login screen still carries the wallpaper
        "${LOW[@]}" "$LUCID_DIR/sync-sddm.sh" 2>/dev/null || true
        ;;
    esac
}

exec 9>"$COLOUR_LOCK"
# waiting is what makes the hand-off race-free: a run that gave up here would
# have to hope the holder reads the request it wrote a moment ago
if ! flock -w 120 9; then
    echo "colours: another run still has the lock, left it the request" >&2
    exit 0
fi

# no palette on disk at all means the record of what was derived is worthless
[[ -f "$SHELL_PALETTE" ]] || rm -f "$COLOUR_DONE" "$APPS_DONE"

# whoever holds the lock works on the newest request, not its own, so a burst
# of previews costs one run of each stage, not one run each
SNAP=""
trap 'rm -f "$SNAP"' EXIT
while :; do
    while ! cmp -s "$COLOUR_WANT" "$COLOUR_DONE"; do
        same_picture || settle "$COLOUR_SETTLE"
        SNAP=$(mktemp "$CACHE_DIR/lucid-colours.XXXXXX")
        cp "$COLOUR_WANT" "$SNAP"
        mapfile -t WANT < "$SNAP"
        derive_colours "${WANT[0]}" "${WANT[1]}" "${WANT[3]}" 9>&-
        if [[ $SKIPPED -eq 1 ]]; then
            # wal already rewrote its cache for the skipped picture, so even a
            # request matching the last applied one has to be derived again
            rm -f "$SNAP" "$COLOUR_DONE"
        else
            mv "$SNAP" "$COLOUR_DONE"
        fi
    done
    cmp -s "$COLOUR_DONE" "$APPS_DONE" && break
    settle "$APPS_SETTLE"
    # a newer picture came in meanwhile, and its colours come first
    cmp -s "$COLOUR_WANT" "$COLOUR_DONE" || continue
    mapfile -t DONE < "$COLOUR_DONE"
    # 9>&- so that whatever apply-theme.sh leaves running in the background
    # (spicetify, matugen for steam) cannot hold the lock open after this exits
    apply_apps "${DONE[0]}" "${DONE[1]}" 9>&-
    cp "$COLOUR_DONE" "$APPS_DONE"
done

echo "done: $WALLPAPER ($MODE, theme: $CURRENT_THEME)"
