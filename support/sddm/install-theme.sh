#!/usr/bin/env bash
# install-theme.sh [dest] — installs Lucid's sddm theme. needs root: install.sh
# runs it through sudo, and running it by hand updates the theme alone.
#
# root owns the theme. the one writable part is users/, sticky and
# world-writable like /tmp, where each account's sync-sddm.sh keeps its own
# wallpaper and palette, so the greeter can wear whoever is picked.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${1:-/usr/share/sddm/themes/lucid}"

if [[ $EUID -ne 0 ]]; then
    echo "install-theme.sh: needs root, run it with sudo" >&2
    exit 1
fi

install -d -m755 "$DEST"
cp -r "$SRC/support/sddm/lucid/." "$DEST/"
# the greeter runs as its own user, so the font it draws in rides along with
# the theme rather than in anyone's home
install -Dm644 "$SRC/assets/fonts/GoogleSansFlex.ttf" "$DEST/fonts/GoogleSansFlex.ttf"
install -Dm644 "$SRC/assets/fonts/OFL-GoogleSansFlex.txt" "$DEST/fonts/OFL-GoogleSansFlex.txt"

# a shared background.jpg predates users/: one account's wallpaper, shown for
# everyone else. an account that has not painted yet gets a flat surface
rm -f "$DEST/background.jpg"

# earlier installs handed the whole theme to whoever ran them, which left every
# other account unable to paint it. -h, so a planted link changes nothing else
find "$DEST" -path "$DEST/users" -prune -o -exec chown -h root:root {} +

if [[ -L "$DEST/users" || ( -e "$DEST/users" && ! -d "$DEST/users" ) ]]; then
    rm -f "$DEST/users"
fi
install -d "$DEST/users"
chown root:root "$DEST/users"
chmod 1777 "$DEST/users"

# every account sddm would list gets its directory now, so no other account
# can take the name first
UID_LO=$(awk '$1 == "UID_MIN" { print $2 }' /etc/login.defs 2>/dev/null || true)
UID_HI=$(awk '$1 == "UID_MAX" { print $2 }' /etc/login.defs 2>/dev/null || true)
UID_LO=${UID_LO:-1000}
UID_HI=${UID_HI:-60000}
getent passwd | while IFS=: read -r name _ uid gid _; do
    (( uid >= UID_LO && uid <= UID_HI )) || continue
    dir="$DEST/users/$name"
    if [[ -L "$dir" || ( -e "$dir" && ! -d "$dir" ) ]]; then
        rm -f "$dir"
    fi
    install -d -m755 "$dir"
    chown -R -h "$uid:$gid" "$dir"
done
