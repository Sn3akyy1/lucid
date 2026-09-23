#!/usr/bin/env bash
# render-templates.sh <colours.json> <dark|light> <source> [--skip <output>]...
# render-templates.sh --again [--only <name>]
#
# renders every template in the matugen config from one set of colours: the
# json matugen dumps for a scheme (matugen ... --dry-run --json hex). the
# wallpaper hands over matugen's own; a fixed theme hands over a scheme with
# its palette laid on top. set-wallpaper.sh and apply-theme.sh both come
# through here, so the two behave the same:
#
#   - each template renders on its own. matugen stops at the first template
#     that fails, in no fixed order, so one broken template would otherwise
#     leave a random share of the rest unrendered
#   - what happened to each one goes to ~/.cache/lucid/templates.json, for
#     Settings to show, and a template that failed says so in a toast
#   - hyprland is reloaded when a template wrote into its config: it only
#     reads its colours on a reload
#   - --skip leaves out the template that writes a given file, for files the
#     caller writes itself
#   - the colours are kept in ~/.cache/lucid/colours.json, so --again renders
#     with the last ones without redoing the scheme: every template, or with
#     --only just one (Settings does that when a template is switched on)
#
# runs are serialised, so after two quick changes of theme or wallpaper the
# older run can never finish last and leave its colours behind.
#
# exits 0 when every template rendered, 2 when some did not, 1 on bad input.

set -uo pipefail

USAGE="usage: render-templates.sh <colours.json> <dark|light> <source> [--skip <output>]...
       render-templates.sh --again [--only <name>]"
AGAIN=0
ONLY=""
SKIP=()
if [[ "${1:-}" == "--again" ]]; then
    AGAIN=1
    shift
else
    COLOURS="${1:?$USAGE}"
    MODE="${2:?$USAGE}"
    SOURCE="${3:?$USAGE}"
    shift 3
fi
while (( $# )); do
    case "$1" in
    --skip)
        [[ $# -ge 2 && $AGAIN == 0 ]] || { echo "$USAGE" >&2; exit 1; }
        SKIP+=("${2/#\~/$HOME}")
        shift 2
        ;;
    --only)
        [[ $# -ge 2 && $AGAIN == 1 ]] || { echo "$USAGE" >&2; exit 1; }
        ONLY="$2"
        shift 2
        ;;
    *)
        echo "$USAGE" >&2
        exit 1
        ;;
    esac
done

for tool in matugen jq; do
    command -v "$tool" &>/dev/null || { echo "error: $tool is required" >&2; exit 1; }
done

CFG="$HOME/.config/matugen/config.toml"
CFG_DIR="$(dirname "$CFG")"
STATE_DIR="$HOME/.cache/lucid"
STATE="$STATE_DIR/templates.json"
KEPT="$STATE_DIR/colours.json"
mkdir -p "$STATE_DIR"

exec 9> "$STATE_DIR/templates.lock"
flock 9

if (( AGAIN )); then
    # the colours, mode, source and skips of the last change
    if [[ ! -f "$KEPT" || ! -f "$STATE" ]]; then
        echo "error: nothing rendered yet to render again" >&2
        exit 1
    fi
    COLOURS="$KEPT"
    MODE=$(jq -r '.mode // "dark"' "$STATE")
    SOURCE=$(jq -r '.source // ""' "$STATE")
    mapfile -t SKIP < <(jq -r '.skip // [] | .[]' "$STATE")
fi

if [[ "$MODE" != "dark" && "$MODE" != "light" ]]; then
    echo "error: mode must be dark or light (got: $MODE)" >&2
    exit 1
fi
if [[ ! -f "$COLOURS" ]]; then
    echo "error: no colours at $COLOURS" >&2
    exit 1
fi
if (( ! AGAIN )); then
    cp "$COLOURS" "$KEPT.tmp" && mv "$KEPT.tmp" "$KEPT"
    COLOURS="$KEPT"
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
: > "$WORK/common"
: > "$WORK/list"
: > "$WORK/results"

# split the config into what every template shares and one file per template;
# [templates.x.y] belongs to x. the list gets index, name, input and output,
# split by \037: a tab is whitespace to read, so an empty field would vanish
if [[ -f "$CFG" ]]; then
    awk -v dir="$WORK" '
        function value(line,    v, q) {
            v = line
            sub(/^[^=]*=[ \t]*/, "", v)
            q = substr(v, 1, 1)
            v = substr(v, 2)
            sub(q ".*$", "", v)
            return v
        }
        /^[ \t]*\[/ {
            h = $0
            sub(/^[ \t]*\[+[ \t]*/, "", h); sub(/[ \t]*\].*$/, "", h)
            if (h ~ /^templates[ \t]*\./) {
                name = h
                sub(/^templates[ \t]*\.[ \t]*/, "", name)
                if (name ~ /^["\047]/) {
                    q = substr(name, 1, 1)
                    name = substr(name, 2)
                    sub(q ".*$", "", name)
                } else {
                    sub(/[ \t]*\..*$/, "", name)
                }
                if (!(name in idx)) { idx[name] = ++n; names[n] = name }
                cur = idx[name]
            } else {
                cur = 0
            }
        }
        { print > (dir "/" (cur ? "t" cur : "common")) }
        cur && /^[ \t]*input_path[ \t]*=/ { input[cur] = value($0) }
        cur && /^[ \t]*output_path[ \t]*=/ { output[cur] = value($0) }
        END {
            for (i = 1; i <= n; i++)
                printf "%d\037%s\037%s\037%s\n", i, names[i], input[i], output[i] > (dir "/list")
        }
    ' "$CFG"
fi
if ! grep -q '^[[:space:]]*\[config\]' "$WORK/common"; then
    { printf '[config]\n'; cat "$WORK/common"; } > "$WORK/common.new"
    mv "$WORK/common.new" "$WORK/common"
fi

# a path as matugen reads it: ~ is home, anything relative hangs off the config
resolve() {
    local p="${1/#\~/$HOME}"
    [[ "$p" == /* ]] || p="$CFG_DIR/$p"
    printf '%s' "$p"
}

# matugen's report, boxes and colours and all, down to one line
explain() {
    local text msg line
    text=$(sed 's/\x1b\[[0-9;]*m//g')
    msg=$(sed -n 's/.*╰.*─ //p' <<< "$text" | tail -1)
    [[ -n "$msg" ]] || msg=$(sed -n 's/^Error: *\(..*\)$/\1/p' <<< "$text" | head -1)
    [[ -n "$msg" ]] || msg=$(sed -n 's/^ *[0-9][0-9]*: //p' <<< "$text" | paste -sd '|' | sed 's/|/ · /g')
    line=$(sed -n 's/.*╭─\[ .*:\([0-9][0-9]*\):[0-9][0-9]* \].*/\1/p' <<< "$text" | head -1)
    [[ -n "$line" ]] && msg="line $line: $msg"
    printf '%s' "${msg:-matugen failed}" | tr '\t\n' '  '
}

FAILED=()
HYPR=0
while IFS=$'\037' read -r i name input output; do
    [[ -n "$ONLY" && "$name" != "$ONLY" ]] && continue
    out=$(resolve "$output")
    in=$(resolve "$input")
    state=ok
    error=""
    skipped=0
    for s in "${SKIP[@]}"; do
        [[ "$out" == "$s" ]] && skipped=1
    done
    if (( skipped )); then
        state=skipped
    elif [[ ! -f "$in" ]]; then
        state=failed
        error="no template at $in"
    else
        # beside the real config, so relative paths in it resolve the same
        one=$(mktemp "$CFG_DIR/.lucid-template-XXXXXX.toml")
        cat "$WORK/common" "$WORK/t$i" > "$one"
        if report=$(matugen -c "$one" json "$COLOURS" -m "$MODE" 2>&1); then
            [[ "$out" == "$HOME/.config/hypr/"* ]] && HYPR=1
        else
            state=failed
            error=$(explain <<< "$report")
        fi
        rm -f "$one"
    fi
    [[ "$state" == failed ]] && FAILED+=("$name")
    printf '%s\t%s\t%s\t%s\n' "$name" "$out" "$state" "$error" >> "$WORK/results"
done < "$WORK/list"

if [[ -n "$ONLY" && ! -s "$WORK/results" ]]; then
    echo "error: no template named $ONLY" >&2
    exit 1
fi

jq -R -s '[split("\n")[] | select(length > 0) | split("\t")
           | {name: .[0], output: .[1], state: .[2], error: (.[3] // "")}]' \
    "$WORK/results" > "$WORK/results.json"
if [[ -n "$ONLY" ]]; then
    # one template again: its entry changes, the rest of the record stays
    jq --slurpfile new "$WORK/results.json" '
        $new[0][0] as $e
        | .templates = (if any(.templates[]; .name == $e.name)
                        then [.templates[] | if .name == $e.name then $e else . end]
                        else .templates + [$e] end)' \
        "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
else
    jq -n --slurpfile t "$WORK/results.json" --arg source "$SOURCE" --arg mode "$MODE" \
        --argjson time "$(date +%s)" \
        --argjson skip "$(printf '%s\n' "${SKIP[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')" '
        {time: $time, source: $source, mode: $mode, skip: $skip, templates: $t[0]}' \
        > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
fi

(( HYPR )) && { hyprctl reload &>/dev/null || true; }

if (( ${#FAILED[@]} )); then
    echo "warning: matugen templates that did not render: ${FAILED[*]} (see $STATE)" >&2
    if (( ${#FAILED[@]} == 1 )); then
        label="The ${FAILED[0]} template didn't render"
    else
        label="${#FAILED[@]} templates didn't render"
    fi
    qs ipc call -- toast warn alert "$label" &>/dev/null || true
    exit 2
fi
exit 0
