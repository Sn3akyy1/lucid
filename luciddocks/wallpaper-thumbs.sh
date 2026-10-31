#!/usr/bin/env bash
# wallpaper-thumbs.sh <folder> [live] [--also <file>]
#
# lists the folder's pictures for the wallpaper strip, sorted, one
# "<path><TAB><thumbnail>" a line. with "live" the videos come too, their lines
# ending in "<TAB>video", their thumbnail cut from the first frame by ffmpeg. the thumbnail is a small copy in
# ~/.cache/lucid/wallpaper-thumbs, or empty while there is none yet: those are
# made in the background, niced and one at a time, so the next listing has them.
# the strip used to decode every original, up to 8k, each time it opened.
# --also is the wallpaper in use when it lives outside the folder (set from
# lumen, say): it comes first, its line ending in "<TAB>temp", for as long as
# it is the one in use

set -uo pipefail

DIR="${1:-}"
shift || true
LIVE=""
if [[ "${1:-}" == live ]]; then
    LIVE=live
    shift
fi
ALSO=""
if [[ "${1:-}" == --also ]]; then
    ALSO="${2:-}"
fi
# twice the strip's hero card, covered rather than fitted
SIZE=680x422
THUMBS="$HOME/.cache/lucid/wallpaper-thumbs/$SIZE"

[[ -d "$DIR" ]] || exit 0

# inode, size and mtime name the copy, so a picture replaced in place gets a new one
NAMES=(-iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp')
[[ "$LIVE" == live ]] && NAMES+=(-o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.m4v')

is_video() {
    [[ "${1,,}" =~ \.(mp4|webm|mkv|mov|m4v)$ ]]
}

MISSING=()
# the outside one: a picture, or a video, whatever the live switch says, since
# it is on the desktop already
if [[ -n "$ALSO" && -f "$ALSO" && "$(dirname -- "$ALSO")" != "${DIR%/}" && "${ALSO,,}" =~ \.(jpe?g|png|webp|mp4|webm|mkv|mov|m4v)$ ]]; then
    IFS=$'\t' read -r path key < <(find "$ALSO" -maxdepth 0 -printf '%p\t%i-%s-%T@\n')
    thumb="$THUMBS/$key.jpg"
    kind=""
    is_video "$path" && kind="video"
    if [[ -f "$thumb" ]]; then
        printf '%s\t%s\t%s\ttemp\n' "$path" "$thumb" "$kind"
    else
        printf '%s\t\t%s\ttemp\n' "$path" "$kind"
        MISSING+=("$path" "$thumb")
    fi
fi
while IFS=$'\t' read -r path key; do
    [[ -n "$path" ]] || continue
    thumb="$THUMBS/$key.jpg"
    kind=""
    is_video "$path" && kind=$'\tvideo'
    if [[ -f "$thumb" ]]; then
        printf '%s\t%s%s\n' "$path" "$thumb" "$kind"
    else
        printf '%s\t%s\n' "$path" "$kind"
        MISSING+=("$path" "$thumb")
    fi
done < <(find "$DIR" -maxdepth 1 -type f \( "${NAMES[@]}" \) \
    -printf '%p\t%i-%s-%T@\n' | sort -t $'\t' -k1,1)

(( ${#MISSING[@]} )) && command -v magick &>/dev/null || exit 0

mkdir -p "$THUMBS"
LOW=(nice -n 19)
command -v ionice &>/dev/null && LOW+=(ionice -c 3)
# detached from the listing's stdout, or the strip would wait for every copy
(
    exec 9>"$THUMBS/.lock"
    # a run already making copies; whatever it misses, the next listing hands on
    flock -n 9 || exit 0
    set -- "${MISSING[@]}"
    while (( $# >= 2 )); do
        src="$1" thumb="$2"
        shift 2
        [[ -f "$thumb" ]] && continue
        tmp="$thumb.$$.tmp.jpg"
        if is_video "$src"; then
            if command -v ffmpeg &>/dev/null && "${LOW[@]}" ffmpeg -v error -y -threads 1 -i "$src" -frames:v 1 \
                    -vf "scale=${SIZE%x*}:${SIZE#*x}:force_original_aspect_ratio=increase,crop=${SIZE%x*}:${SIZE#*x}" \
                    -q:v 3 "$tmp" </dev/null; then
                mv -f "$tmp" "$thumb"
            else
                rm -f "$tmp"
            fi
            continue
        fi
        # jpeg:size lets libjpeg decode a 4k or 8k original at a fraction of its size
        if "${LOW[@]}" env MAGICK_THREAD_LIMIT=1 \
                magick -define jpeg:size=1360x844 "$src[0]" -auto-orient -thumbnail "$SIZE^" \
                -strip -quality 90 "$tmp" 2>/dev/null; then
            mv -f "$tmp" "$thumb"
        else
            rm -f "$tmp"
        fi
    done
    find "$THUMBS" -type f -name '*.jpg' -mtime +120 -delete 2>/dev/null
) </dev/null &>/dev/null &
exit 0
