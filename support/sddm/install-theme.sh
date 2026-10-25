#!/usr/bin/env bash
# install-theme.sh [dest] [--fingerprint | --no-fingerprint] [--current] —
# installs Lucid's sddm theme. needs root: install.sh runs it through sudo, and
# running it by hand updates the theme alone. --fingerprint lets the login
# screen take a fingerprint (two lines in /etc/pam.d/sddm), --no-fingerprint
# takes them out; without either, pam is left as it is. --current also makes it
# the theme sddm shows; without it, which theme is shown stays as it was.
#
# root owns the theme. the one writable part is users/, sticky and
# world-writable like /tmp, where each account's sync-sddm.sh keeps its own
# wallpaper and palette, so the greeter can wear whoever is picked.

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST=/usr/share/sddm/themes/lucid
FINGER=""
CURRENT=0
for arg in "$@"; do
    case $arg in
        --fingerprint) FINGER=on ;;
        --no-fingerprint) FINGER=off ;;
        --current) CURRENT=1 ;;
        *) DEST=$arg ;;
    esac
done
# overridable so the pam and theme edits can be tried on a copy
PAM_SDDM="${LUCID_PAM_SDDM:-/etc/pam.d/sddm}"
SDDM_CONF="${LUCID_SDDM_CONF:-/etc/sddm.conf}"

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

# the login screen plays a live wallpaper as a small video. left to itself,
# Qt's ffmpeg backend opens every hardware decoder and encoder first, CUDA and
# VDPAU included: ~3 s before the video starts, and a hybrid laptop's dGPU
# woken at the login screen. a 1080p copy decodes fine in software. the glance
# chips read battery, network and bluetooth off sysfs, which qml may only do
# with QML_XHR_ALLOW_FILE_READ. a GreeterEnvironment set anywhere else is left
# alone, since this would replace it
GREETER_CONF=/etc/sddm.conf.d/lucid-greeter.conf
if ! grep -qs '^[[:space:]]*GreeterEnvironment=.' /etc/sddm.conf $(ls /etc/sddm.conf.d/*.conf 2>/dev/null | grep -vx "$GREETER_CONF"); then
    install -d -m755 /etc/sddm.conf.d
    printf '%s\n' \
        "# written by lucid's install-theme.sh: the greeter decodes the live" \
        "# wallpaper in software rather than waking every GPU to look for a decoder," \
        "# and reads the battery, network and bluetooth state for its chips" \
        "[General]" \
        "GreeterEnvironment=QT_FFMPEG_DECODING_HW_DEVICE_TYPES=,QT_FFMPEG_ENCODING_HW_DEVICE_TYPES=,QML_XHR_ALLOW_FILE_READ=1" \
        > "$GREETER_CONF"
    chmod 644 "$GREETER_CONF"
fi

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

# a fingerprint at the login screen. sddm checks one attempt at a time through
# its own pam service: a typed password goes first, an empty one reaches the
# reader and ends at pam_deny so faillock never counts it. marked, so it comes out again
FP_HELPER="$DEST/pam-empty-password"
install -Dm755 "$SRC/support/sddm/pam-empty-password" "$FP_HELPER"
FP_BEGIN="# >>> lucid: fingerprint login"
FP_END="# <<< lucid: fingerprint login"
pam_module() {
    local d
    for d in /usr/lib/security /usr/lib64/security /lib/security /lib/x86_64-linux-gnu/security; do
        [[ -e "$d/$1" ]] && return 0
    done
    return 1
}
if [[ $FINGER == off && -f "$PAM_SDDM" ]]; then
    sed -i "/^$FP_BEGIN/,/^$FP_END/d" "$PAM_SDDM"
elif [[ $FINGER == on && -f "$PAM_SDDM" ]]; then
    if ! pam_module pam_fprintd.so; then
        echo "install-theme.sh: pam_fprintd.so is not installed (fprintd), leaving $PAM_SDDM alone" >&2
    else
        [[ -e "$PAM_SDDM.lucid-backup" ]] || cp -p "$PAM_SDDM" "$PAM_SDDM.lucid-backup"
        sed -i "/^$FP_BEGIN/,/^$FP_END/d" "$PAM_SDDM"
        awk -v begin="$FP_BEGIN" -v end="$FP_END" -v helper="$FP_HELPER" '
            !done && /^[[:space:]]*-?auth[[:space:]]/ {
                print begin " (install-theme.sh --no-fingerprint takes it out)"
                print "auth        [success=3 new_authtok_reqd=3 default=ignore]  pam_unix.so try_first_pass likeauth nullok nodelay"
                print "auth        [success=ignore default=2]  pam_exec.so quiet expose_authtok " helper
                print "auth        sufficient  pam_fprintd.so max-tries=1 timeout=10"
                print "auth        [default=die]  pam_deny.so"
                print end
                done = 1
            }
            { print }
        ' "$PAM_SDDM" > "$PAM_SDDM.lucid-tmp"
        cat "$PAM_SDDM.lucid-tmp" > "$PAM_SDDM"
        rm -f "$PAM_SDDM.lucid-tmp"
    fi
fi

# the greeter offers a fingerprint only where pam takes one, this edit or the
# machine's own
FP_ON=false
if [[ -f "$PAM_SDDM" ]] && grep -qE '^[[:space:]]*-?auth[[:space:]].*pam_fprintd\.so' "$PAM_SDDM"; then
    FP_ON=true
fi
printf '\n# set by install-theme.sh: whether /etc/pam.d/sddm takes a fingerprint\nfingerprintLogin=%s\n' "$FP_ON" >> "$DEST/theme.conf"

# the theme sddm shows. /etc/sddm.conf outranks /etc/sddm.conf.d, so the line
# goes in the file that wins, backed up once before the first change
if [[ $CURRENT -eq 1 ]]; then
    name=$(basename "$DEST")
    if ! sed -n '/^\[Theme\]/,/^\[/p' "$SDDM_CONF" 2>/dev/null | grep -qx "Current=$name"; then
        [[ ! -f "$SDDM_CONF" || -e "$SDDM_CONF.lucid-backup" ]] || cp -p "$SDDM_CONF" "$SDDM_CONF.lucid-backup"
        if ! grep -qs '^\[Theme\]' "$SDDM_CONF"; then
            printf '\n[Theme]\nCurrent=%s\n' "$name" >> "$SDDM_CONF"
        elif sed -n '/^\[Theme\]/,/^\[/p' "$SDDM_CONF" | grep -q '^[[:space:]]*Current='; then
            sed -i "/^\[Theme\]/,/^\[/ s/^[[:space:]]*Current=.*/Current=$name/" "$SDDM_CONF"
        else
            sed -i "/^\[Theme\]/a Current=$name" "$SDDM_CONF"
        fi
    fi
fi
