#!/usr/bin/env bash
# sync-sddm.sh [--check] [palette.json]
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
#
#   generic any other theme. rewrites any key whose value is ALREADY a hex
#           colour and whose name reads as an accent, a background or a
#           foreground. the hex check is the safety net: a wallpaper path, a
#           font name or a number is never touched.
#
# --check reports what would happen and writes nothing. it prints one of:
#   ok lucid <theme>  the Lucid theme is installed and writable
#   ok <theme>        another theme, writable, will follow the palette
#   readonly <path>   the theme exists but is not writable by this user
#   notheme           sddm is not configured, or its theme has no theme.conf
#   nopalette         Lucid has not written a palette yet

set -euo pipefail

CHECK=0
[[ "${1:-}" == "--check" ]] && { CHECK=1; shift; }

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
[[ -n "$THEME" ]] || report notheme

DIR="/usr/share/sddm/themes/$THEME"
CONF="$DIR/theme.conf"
[[ -f "$CONF" ]] || report notheme
[[ -w "$CONF" ]] || report "readonly $CONF"

# ── lucid's own theme ────────────────────────────────────────────────────────
# identified by its marker, not its directory name, so a renamed copy still works
if grep -q '^Theme-Id=lucid$' "$DIR/metadata.desktop" 2>/dev/null; then
    [[ -w "$DIR" ]] || report "readonly $DIR"
    ok "ok lucid $THEME"

    # the running shell is the only place the resolved tokens exist
    TOKENS=$(timeout 30 qs -p "$CONFIG_DIR/theme-dump.qml" 2>&1 \
             | grep -oE 'LUCIDTOKENS .*' | head -1 | cut -d' ' -f2- || true)
    if [[ -z "$TOKENS" ]]; then
        echo "sync-sddm: could not read the shell's theme; leaving $THEME alone" >&2
        exit 1
    fi

    TMP=$(mktemp)
    {
        echo "[General]"
        echo "# written by sync-sddm.sh from the running shell. edits are overwritten."
        echo "background=background.jpg"
        echo
        python3 - "$TOKENS" <<'PY'
import json, sys
t = json.loads(sys.argv[1])
for k, v in t.items():
    print("%s=%s" % (k, str(v).lower() if isinstance(v, bool) else v))
PY
    } > "$TMP"
    cp "$TMP" "$CONF"
    rm -f "$TMP"

    # the greeter must not run a 64px blur over 1080p on a cold gpu at boot,
    # so the resting blur is baked in here. downscale/upscale rather than a
    # straight -blur: same look, a fraction of the work
    WALL=$(cat "$HOME/.cache/current_wallpaper" 2>/dev/null || true)
    if [[ -n "$WALL" && -f "$WALL" ]]; then
        IM=$(command -v magick || command -v convert || true)
        if [[ -n "$IM" ]]; then
            "$IM" "$WALL" -strip -resize 25% -blur 0x8 -resize 400% \
                  -quality 88 "$DIR/background.jpg"
        else
            cp "$WALL" "$DIR/background.jpg"
        fi
    fi
    exit 0
fi

# ── any other theme ──────────────────────────────────────────────────────────
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
