#!/usr/bin/env bash
# sync-sddm.sh [--check] [palette.json]
#
# paints the active SDDM theme from the palette Lucid last applied. sddm runs
# before anyone logs in, so it cannot read a per-user palette - the colours
# have to live in the theme itself.
#
# themes do not agree on key names, so rather than hardcoding one theme's
# schema this rewrites any key whose value is ALREADY a hex colour and whose
# name reads as an accent, a background or a foreground. the hex check is the
# safety net: a wallpaper path, a font name or a number is never touched.
#
# --check reports what would happen and writes nothing. it prints one of:
#   ok <theme>        the theme is writable and will follow the palette
#   readonly <path>   the theme exists but is not writable by this user
#   notheme           sddm is not configured, or its theme has no theme.conf
#   nopalette         Lucid has not written a palette yet

set -euo pipefail

CHECK=0
[[ "${1:-}" == "--check" ]] && { CHECK=1; shift; }

PALETTE="${1:-$HOME/.cache/quickshell/matugen.json}"
report() { [[ $CHECK -eq 1 ]] && echo "$1"; exit 0; }

[[ -f "$PALETTE" ]] || report nopalette
command -v jq &>/dev/null || report nopalette

# whichever theme sddm is actually pointed at
THEME=$(grep -rhE '^[[:space:]]*Current=' /etc/sddm.conf /etc/sddm.conf.d/*.conf 2>/dev/null \
        | tail -1 | cut -d= -f2- | tr -d '[:space:]')
[[ -n "$THEME" ]] || report notheme

CONF="/usr/share/sddm/themes/$THEME/theme.conf"
[[ -f "$CONF" ]] || report notheme
[[ -w "$CONF" ]] || report "readonly $CONF"

c() { jq -r --arg k "$1" '.[$k] // empty' "$PALETTE"; }
ACCENT=$(c primary)
BG=$(c surface)
FG=$(c on_surface)
[[ -n "$ACCENT" && -n "$BG" && -n "$FG" ]] || report nopalette

report "ok $THEME"

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
