#!/usr/bin/env bash
# wallpaper-thumbs.sh <folder>
#
# lists the folder's pictures for the wallpaper strip, sorted, one
# "<path><TAB><thumbnail>" a line. the thumbnail is a small copy in
# ~/.cache/lucid/wallpaper-thumbs, or empty while there is none yet: those are
# made in the background, niced and one at a time, so the next listing has them.
# the strip used to decode every original, up to 8k, each time it opened

set -uo pipefail

DIR="${1:-}"
# twice the strip's hero card, covered rather than fitted
SIZE=680x422
THUMBS="$HOME/.cache/lucid/wallpaper-thumbs/$SIZE"

[[ -d "$DIR" ]] || exit 0

# inode, size and mtime name the copy, so a picture replaced in place gets a new one
MISSING=()
while IFS=$'\t' read -r path key; do
    [[ -n "$path" ]] || continue
    thumb="$THUMBS/$key.jpg"
    if [[ -f "$thumb" ]]; then
        printf '%s\t%s\n' "$path" "$thumb"
    else
        printf '%s\t\n' "$path"
        MISSING+=("$path" "$thumb")
    fi
done < <(find "$DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
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
