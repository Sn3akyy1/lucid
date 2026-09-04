#!/usr/bin/env sh
# resolve-icons.sh <theme> <name>...
#
# prints "<name><TAB><path>" for every name that resolves, nothing for the rest.
# qt reads the icon theme once at process start and never again, so the dock
# cannot ask QIcon for it - this walks the theme directories itself.
#
# one find per theme directory, not per name: the whole batch is matched in awk
# afterwards, so adding names costs nothing.

theme="${1:-hicolor}"
shift

dirs="$HOME/.local/share/icons $HOME/.icons /usr/share/icons /usr/local/share/icons"

# theme inheritance chain, breadth first, each theme visited once.
# hicolor is the spec's mandatory last resort
chain=""
seen=""
queue="$theme hicolor"
while [ -n "$queue" ]; do
    t="${queue%% *}"
    case "$queue" in
    *" "*) queue="${queue#* }" ;;
    *) queue="" ;;
    esac
    [ -n "$t" ] || continue
    case " $seen " in
    *" $t "*) continue ;;
    esac
    seen="$seen $t"
    chain="$chain $t"
    for d in $dirs; do
        [ -f "$d/$t/index.theme" ] || continue
        inh=$(sed -n 's/^Inherits=//p' "$d/$t/index.theme" | head -n1 | tr ',' ' ')
        [ -n "$inh" ] && queue="$queue $inh"
        break
    done
done

want=$(printf '%s|' "$@")

# prefix each file with its position in the chain, so awk can rank matches
i=0
for t in $chain; do
    i=$((i + 1))
    for d in $dirs; do
        [ -d "$d/$t" ] || continue
        find "$d/$t" \( -name '*.svg' -o -name '*.png' \) -printf "$i\t%p\n" 2>/dev/null
    done
done | awk -F'\t' -v want="$want" '
BEGIN {
    n = split(want, a, "|")
    for (k = 1; k <= n; k++)
        if (a[k] != "") W[a[k]] = 1
}
{
    p = $2
    b = p
    sub(/.*\//, "", b)
    sub(/\.(svg|png)$/, "", b)
    if (!(b in W)) next
    # earlier theme wins; full-colour beats symbolic; svg beats png
    s = $1 * 100
    if (p ~ /\/symbolic\//) s += 20
    if (p ~ /\/small\//) s += 10
    if (p ~ /\.png$/) s += 1
    if (!(b in BEST) || s < BEST[b]) { BEST[b] = s; P[b] = p }
}
END {
    for (b in P) printf "%s\t%s\n", b, P[b]
}'
