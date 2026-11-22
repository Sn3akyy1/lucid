#!/usr/bin/env bash
# sync-sddm.sh [--check] [--missing] [palette.json]
# sync-sddm.sh --lock <layout.json> [weather.json]
#
# paints the active SDDM theme from the palette Lucid last applied. sddm runs
# before anyone logs in, so it cannot read a per-user palette - the colours
# have to live in the theme itself.
#
# two modes:
#
#   lucid   the active theme is Lucid's own. every token is read off the
#           RUNNING shell (theme-dump.qml), because Theme.qml derives its
#           colours in L* tone space and that is not reproducible from the
#           palette file alone. the wallpaper is copied in and pre-blurred.
#           each account paints only its own users/<name>/, and the greeter
#           wears whichever account is picked. a theme installed before
#           users/ existed has one shared copy, painted by whoever owns it.
#
#   generic any other theme. rewrites any key whose value is ALREADY a hex
#           colour and whose name reads as an accent, a background or a
#           foreground. the hex check is the safety net: a wallpaper path, a
#           font name or a number is never touched.
#
# --missing paints only an account the greeter has nothing for yet. the shell
# runs it at login, so an account shows up as itself without waiting for its
# next wallpaper change.
#
# --lock sends the lock screen's layout (and, if given, the last weather
# reading) to this account's users/<name>/lock.conf, and nothing else: no qs,
# no wallpaper. the shell runs it a moment after every edit. it prints one of
#   lock ok | lock old (the installed theme predates layouts) | lock readonly |
#   lock notheme | lock notlucid | lock bad (the json would not parse)
#
# --check reports what would happen and writes nothing. it prints one of:
#   ok lucid <theme>  the Lucid theme is installed and writable
#   ok <theme>        another theme, writable, will follow the palette
#   readonly <path>   the theme exists but is not writable by this user
#   notheme           sddm is not configured, or its theme has no theme.conf
#   nopalette         Lucid has not written a palette yet

set -euo pipefail

CHECK=0
MISSING=0
LOCK=0
while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --check) CHECK=1 ;;
        --missing) MISSING=1 ;;
        --lock) LOCK=1 ;;
        *) break ;;
    esac
    shift
done
if [[ $LOCK -eq 1 ]]; then
    LOCK_LAYOUT="${1:-}"
    LOCK_WEATHER="${2:-}"
    set --
fi
# --lock speaks its own words, whether or not anything could be done
lockreport() { echo "lock $1"; exit 0; }

PALETTE="${1:-$HOME/.cache/quickshell/matugen.json}"
CONFIG_DIR="${LUCID_CONFIG_DIR:-$HOME/.config/quickshell}"
# a terminal condition: nothing can be painted. always exits, and only says
# why under --check. note this is NOT for the "ok" lines - those mean the
# opposite, that the work should now happen, so they exit under --check only
report() { [[ $CHECK -eq 1 ]] && echo "$1"; exit 0; }
ok() { [[ $CHECK -eq 1 ]] && { echo "$1"; exit 0; }; return 0; }

# whichever theme sddm is actually pointed at
# grep exits non-zero for both "no match" and "no such file" (sddm.conf.d does
# not exist on every install), and under set -e + pipefail either one killed the
# script before it could report notheme
# sddm.conf(5): lowest to highest precedence is the system conf.d, then the
# local conf.d, then sddm.conf itself. listing them in that order and taking
# the last match is what makes tail -1 the winning value rather than the losing
# one - the old order had sddm.conf first, so a drop-in silently beat it here
# while sddm itself did the opposite
THEME=$({ grep -rhE '^[[:space:]]*Current=' \
            /usr/lib/sddm/sddm.conf.d/*.conf \
            /etc/sddm.conf.d/*.conf \
            /etc/sddm.conf 2>/dev/null || true; } \
        | tail -1 | cut -d= -f2- | tr -d '[:space:]')
[[ -n "$THEME" ]] || { [[ $LOCK -eq 1 ]] && lockreport notheme; report notheme; }

# overridable so the per-account paths can be exercised off a real install
DIR="${LUCID_SDDM_THEMES:-/usr/share/sddm/themes}/$THEME"
CONF="$DIR/theme.conf"
[[ -f "$CONF" ]] || { [[ $LOCK -eq 1 ]] && lockreport notheme; report notheme; }
[[ $LOCK -eq 1 ]] && ! grep -q '^Theme-Id=lucid$' "$DIR/metadata.desktop" 2>/dev/null && lockreport notlucid

# ── lucid's own theme ────────────────────────────────────────────────────────
# identified by its marker, not its directory name, so a renamed copy still works
if grep -q '^Theme-Id=lucid$' "$DIR/metadata.desktop" 2>/dev/null; then
    # install.sh makes users/ sticky and world-writable, like /tmp: any account
    # can start its own directory there, and none can touch another's
    ME=$(id -un)
    SHARED=0
    if [[ -d "$DIR/users" && ! -L "$DIR/users" ]]; then
        OUT="$DIR/users/$ME"
        if [[ -e "$OUT" || -L "$OUT" ]]; then
            # only ever write into a directory this account owns outright
            [[ -d "$OUT" && ! -L "$OUT" && -O "$OUT" && -w "$OUT" ]] || { [[ $LOCK -eq 1 ]] && lockreport readonly; report "readonly $OUT"; }
        else
            [[ -w "$DIR/users" ]] || { [[ $LOCK -eq 1 ]] && lockreport readonly; report "readonly $DIR/users"; }
        fi
    else
        SHARED=1
        OUT="$DIR"
        [[ -w "$CONF" && -w "$DIR" ]] || { [[ $LOCK -eq 1 ]] && lockreport readonly; report "readonly $DIR"; }
    fi

    # ── the lock layout, on its own and quick ───────────────────────────────
    # plain data the greeter checks against its own catalogue; base64 so a
    # comma in it can never turn a QSettings value into a list
    if [[ $LOCK -eq 1 ]]; then
        (( ${#LOCK_LAYOUT} > 0 && ${#LOCK_LAYOUT} <= 65536 && ${#LOCK_WEATHER} <= 4096 )) || lockreport bad
        python3 -c 'import json, sys
for a in sys.argv[1:]:
    if a and not isinstance(json.loads(a), dict):
        raise SystemExit(1)' "$LOCK_LAYOUT" "$LOCK_WEATHER" 2>/dev/null || lockreport bad
        if [[ $SHARED -eq 0 ]]; then
            mkdir "$OUT" 2>/dev/null || true
            [[ -d "$OUT" && ! -L "$OUT" && -O "$OUT" ]] || lockreport readonly
            chmod 755 "$OUT"
        fi
        TMPL=$(mktemp "$OUT/.lock.conf.XXXXXX") || lockreport readonly
        {
            echo "[General]"
            echo "# written by sync-sddm.sh --lock from $ME's shell. edits are overwritten."
            echo "layout=$(printf '%s' "$LOCK_LAYOUT" | base64 -w0)"
            [[ -n "$LOCK_WEATHER" ]] && echo "weather=$(printf '%s' "$LOCK_WEATHER" | base64 -w0)"
            echo "stamp=$(date +%s)"
        } > "$TMPL"
        chmod 644 "$TMPL"
        mv -f "$TMPL" "$OUT/lock.conf"
        # a theme from before layouts has no parts/ to draw this with yet
        [[ -f "$DIR/parts/Stage.qml" ]] || lockreport old
        lockreport ok
    fi
    ok "ok lucid $THEME"
    [[ $MISSING -eq 1 && -s "$OUT/theme.conf" ]] && exit 0

    # one at a time: a live wallpaper's copy finishes in the background and
    # runs this again, maybe while a wallpaper change is painting
    mkdir -p "$HOME/.cache/lucid"
    exec 7>"$HOME/.cache/lucid/sddm-sync.lock"
    flock -w 60 7 || true

    if [[ $SHARED -eq 0 ]]; then
        mkdir "$OUT" 2>/dev/null || true
        # checked again: another account could have taken the name in between
        [[ -d "$OUT" && ! -L "$OUT" && -O "$OUT" ]] || report "readonly $OUT"
        # the greeter runs as sddm, whatever this account's umask says
        chmod 755 "$OUT"
    fi

    # the running shell is the only place the resolved tokens exist
    TOKENS=$(timeout 30 qs -p "$CONFIG_DIR/theme-dump.qml" 2>&1 \
             | grep -oE 'LUCIDTOKENS .*' | head -1 | cut -d' ' -f2- || true)
    if [[ -z "$TOKENS" ]]; then
        echo "sync-sddm: could not read the shell's theme; leaving $THEME alone" >&2
        exit 1
    fi

    # written beside the target and moved over it, so a greeter up on another
    # vt never reads half a file
    TMPC=""
    TMPJ=""
    TMPV=""
    cleanup() {
        local f
        for f in "$TMPC" "$TMPJ" "$TMPV"; do
            [[ -n "$f" ]] && rm -f -- "$f"
        done
        return 0
    }
    trap cleanup EXIT
    # the greeter offers a fingerprint only to an account with one enrolled.
    # fprintd-list lists them as " - #0: right-index-finger"
    FINGER=false
    if command -v fprintd-list &>/dev/null; then
        ENROLLED=$(timeout 5 fprintd-list "$ME" 2>/dev/null || true)
        FINGER_RE='#[0-9]+:'
        [[ $ENROLLED =~ $FINGER_RE ]] && FINGER=true
    fi

    # both copies are sharp and cover the largest screen, as the desktop's own
    # does; the greeter blurs them live, the way the lock does. a blur baked into
    # a smaller copy was the old way, and its stretch showed the encoder's blocks
    SCREEN=1920x1080
    if command -v hyprctl &>/dev/null && command -v jq &>/dev/null; then
        SCREEN_SEEN=$(hyprctl monitors -j 2>/dev/null | jq -r '
            [.[] | if (.transform % 2) == 1 then [.height, .width] else [.width, .height] end]
            | if length == 0 then empty else "\(map(.[0]) | max)x\(map(.[1]) | max)" end' 2>/dev/null || true)
        [[ "$SCREEN_SEEN" =~ ^[0-9]+x[0-9]+$ ]] && SCREEN=$SCREEN_SEEN
    fi

    # a live wallpaper moves on the login screen too: a silent copy, no wider
    # than 1920, which the greeter decodes in software. each video's copy is kept
    # in VID_DIR, and a missing one is made in the background: a 4k clip is ~35 s
    # of cpu, and this runs inside set-wallpaper.sh's colour lock, so the next
    # wallpaper's colours waited on it
    VIDEO=""
    VID_DIR="$HOME/.cache/lucid/sddm-video"
    VW=${SCREEN%x*}
    (( VW > 1920 )) && VW=1920
    # part of the key, so a change remakes the copies
    VF="scale='min($VW,iw)':-2"
    VCRF=20

    # one at a time, at the lowest priority, and only while the video is still
    # the wallpaper, so a browse past several clips makes the last one's copy.
    # runs this script again once it is ready, to put it up
    make_video() {
        local live="$1" key="$2" tmp low=(nice -n 19)
        command -v ionice &>/dev/null && low+=(ionice -c 3)
        exec 6>"$VID_DIR/.lock"
        flock 6
        [[ "$(head -n1 "$HOME/.cache/current_live_wallpaper" 2>/dev/null || true)" == "$live" ]] || return 0
        if [[ ! -s "$VID_DIR/$key.mp4" ]]; then
            tmp="$VID_DIR/.$key.$BASHPID.mp4"
            # -threads ahead of -i caps the decoder too, which otherwise takes every core
            if "${low[@]}" ffmpeg -v error -y -threads 2 -i "$live" -an -sn -dn \
                   -filter_threads 1 -vf "$VF" \
                   -c:v libx264 -preset veryfast -crf "$VCRF" -pix_fmt yuv420p \
                   -movflags +faststart -threads 2 "$tmp"; then
                mv -f "$tmp" "$VID_DIR/$key.mp4"
            else
                rm -f "$tmp"
                : > "$VID_DIR/$key.fail"
                return 0
            fi
            find "$VID_DIR" -type f ! -name .lock -mtime +60 -delete 2>/dev/null || true
        fi
        exec 6>&-
        [[ "$(head -n1 "$HOME/.cache/current_live_wallpaper" 2>/dev/null || true)" == "$live" ]] \
            && "${BASH_SOURCE[0]}"
        return 0
    }

    LIVE=$(head -n1 "$HOME/.cache/current_live_wallpaper" 2>/dev/null || true)
    if [[ -n "$LIVE" && -f "$LIVE" ]] && command -v ffmpeg &>/dev/null; then
        KEY=$(printf '%s|%s|%s|%s' "$LIVE" "$(stat -c %Y "$LIVE" 2>/dev/null || echo 0)" "$VF" "$VCRF" | sha1sum | cut -c1-16)
        mkdir -p "$VID_DIR"
        if [[ -s "$OUT/background.mp4" && "$(cat "$OUT/background.key" 2>/dev/null)" == "$KEY" ]]; then
            VIDEO=background.mp4
            # a copy made before VID_DIR existed counts too
            if [[ ! -s "$VID_DIR/$KEY.mp4" ]] && cp "$OUT/background.mp4" "$VID_DIR/.$KEY.$$.mp4" 2>/dev/null; then
                mv -f "$VID_DIR/.$KEY.$$.mp4" "$VID_DIR/$KEY.mp4"
            fi
        elif [[ -s "$VID_DIR/$KEY.mp4" ]]; then
            TMPV=$(mktemp --suffix=.mp4 "$OUT/.background.XXXXXX")
            cp "$VID_DIR/$KEY.mp4" "$TMPV"
            chmod 644 "$TMPV"
            mv -f "$TMPV" "$OUT/background.mp4"
            echo "$KEY" > "$OUT/background.key"
            chmod 644 "$OUT/background.key"
            touch "$VID_DIR/$KEY.mp4"
            VIDEO=background.mp4
        elif [[ ! -e "$VID_DIR/$KEY.fail" ]]; then
            # closes both locks, this script's and set-wallpaper.sh's colour lock
            make_video "$LIVE" "$KEY" </dev/null &>/dev/null 7>&- 9>&- &
        fi
    fi

    TMPC=$(mktemp "$OUT/.theme.conf.XXXXXX")
    {
        echo "[General]"
        echo "# written by sync-sddm.sh from $ME's running shell. edits are overwritten."
        echo "background=background.jpg"
        echo "backgroundVideo=$VIDEO"
        # tells the greeter to blur them itself; a copy without it has its blur baked in
        echo "backgroundSharp=true"
        echo "fingerprint=$FINGER"
        echo
        python3 - "$TOKENS" <<'PY'
import json, sys
t = json.loads(sys.argv[1])
for k, v in t.items():
    print("%s=%s" % (k, str(v).lower() if isinstance(v, bool) else v))
PY
    } > "$TMPC"
    chmod 644 "$TMPC"
    mv -f "$TMPC" "$OUT/theme.conf"
    # gone only once theme.conf has stopped naming it
    if [[ -z "$VIDEO" ]]; then
        rm -f "$OUT/background.mp4" "$OUT/background.key"
    fi

    # the still, made the way set-wallpaper.sh makes the desktop's: scaled to
    # cover the largest screen (never up), quality 95 with full-size colour.
    # no jpeg:size hint: libjpeg then scales while decoding, up as well as
    # down, and too far for a picture wider than the screen
    WALL=$(cat "$HOME/.cache/current_wallpaper" 2>/dev/null || true)
    if [[ -n "$WALL" && -f "$WALL" ]]; then
        TMPJ=$(mktemp --suffix=.jpg "$OUT/.background.XXXXXX")
        IM=$(command -v magick || command -v convert || true)
        if [[ -n "$IM" ]]; then
            MAGICK_THREAD_LIMIT="${MAGICK_THREAD_LIMIT:-2}" \
                "$IM" "$WALL[0]" -auto-orient -strip \
                  -resize "${SCREEN}^>" \
                  -quality 95 -sampling-factor 4:4:4 "$TMPJ"
        else
            cp "$WALL" "$TMPJ"
        fi
        chmod 644 "$TMPJ"
        mv -f "$TMPJ" "$OUT/background.jpg"
    fi
    exit 0
fi

# ── any other theme ──────────────────────────────────────────────────────────
[[ -w "$CONF" ]] || report "readonly $CONF"
[[ -f "$PALETTE" ]] || report nopalette
command -v jq &>/dev/null || report nopalette

c() { jq -r --arg k "$1" '.[$k] // empty' "$PALETTE"; }
ACCENT=$(c primary)
BG=$(c surface)
FG=$(c on_surface)
[[ -n "$ACCENT" && -n "$BG" && -n "$FG" ]] || report nopalette

ok "ok $THEME"

TMP=$(mktemp)
awk -v accent="$ACCENT" -v bg="$BG" -v fg="$FG" '
{
    line = $0
    if (match(line, /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*/)) {
        key = line
        sub(/[[:space:]]*=.*$/, "", key)
        gsub(/[[:space:]]/, "", key)
        val = substr(line, RLENGTH + 1)
        gsub(/[[:space:]]/, "", val)
        # only ever replace something that is already a hex colour
        if (val ~ /^#[0-9a-fA-F]{3,8}$/) {
            k = tolower(key)
            repl = ""
            if (k ~ /accent|highlight/)               repl = accent
            else if (k ~ /background|^bg/)            repl = bg
            else if (k ~ /text|foreground|^fg/)       repl = fg
            if (repl != "") {
                # keep the original spacing up to and including the "="
                print substr(line, 1, RLENGTH) repl
                next
            }
        }
    }
    print line
}' "$CONF" > "$TMP"

# cp rather than mv, so the file keeps its own owner and mode
cp "$TMP" "$CONF"
rm -f "$TMP"
