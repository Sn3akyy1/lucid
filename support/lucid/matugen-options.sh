# matugen-options.sh — sourced by set-wallpaper.sh, apply-colour.sh and
# wallpaper-colours.sh
#
# how Settings -> Theme wants matugen to build a palette. every value comes
# from the environment when the caller sets it (Settings passes a new value
# along, since prefs.json is written a moment after a change), otherwise from
# prefs.json, otherwise matugen's own default. anything that is not a valid
# value falls back the same way, so a hand-edited prefs.json cannot break a
# wallpaper change.

LUCID_PREFS="$HOME/.config/quickshell/lucidprefs/prefs.json"

lucid_pref() {
    jq -r --arg k "$1" '.[$k] // empty | tostring' "$LUCID_PREFS" 2>/dev/null || true
}

MATUGEN_SCHEME="${LUCID_MATUGEN_SCHEME:-$(lucid_pref matugenScheme)}"
case "$MATUGEN_SCHEME" in
scheme-content | scheme-expressive | scheme-fidelity | scheme-fruit-salad | \
    scheme-monochrome | scheme-neutral | scheme-rainbow | scheme-tonal-spot | scheme-vibrant) ;;
*) MATUGEN_SCHEME=scheme-tonal-spot ;;
esac

# -1 is the least contrast, 0 the design as specified, 1 the most
MATUGEN_CONTRAST="${LUCID_MATUGEN_CONTRAST:-$(lucid_pref matugenContrast)}"
if ! [[ "$MATUGEN_CONTRAST" =~ ^-?([0-9]+\.?[0-9]*|\.[0-9]+)$ ]] ||
    awk -v c="$MATUGEN_CONTRAST" 'BEGIN { exit !(c < -1 || c > 1) }'; then
    MATUGEN_CONTRAST=0
fi

# the one colour the "colour" theme is built from
THEME_COLOUR="${LUCID_THEME_COLOUR:-$(lucid_pref themeColour)}"
[[ "$THEME_COLOUR" =~ ^#[0-9a-fA-F]{6}$ ]] || THEME_COLOUR="#6750a4"

# which of an image's dominant colours (0 the most dominant, up to 3) to start
# from: the one Settings picked, for the image it was picked on. any other
# image starts from its most dominant, since the second colour of one picture
# says nothing about another
matugen_source_index() {
    local image="$1" picked index
    picked="${LUCID_MATUGEN_SOURCE_IMAGE:-$(lucid_pref matugenSourceImage)}"
    index="${LUCID_MATUGEN_SOURCE_INDEX:-$(lucid_pref matugenSourceIndex)}"
    # matugen's help says 0-4, but it takes 0 to 3
    if [[ -n "$picked" && "$picked" == "$image" && "$index" =~ ^[0-3]$ ]]; then
        printf '%s' "$index"
    else
        printf 0
    fi
}
