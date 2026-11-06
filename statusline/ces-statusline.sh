#!/usr/bin/env bash
# ces-statusline.sh — status line for claude-engineering-system.
#
# Design constraint: spawn nothing. No jq, no python, no git, no sed, no date.
# Every value comes from the stdin JSON or from bash builtins, so a run costs
# one process instead of five or six.
#
# Claude Code runs this on session start and on each new assistant message,
# debounced at 300ms, cancelling an in-flight run if a new trigger arrives.
# That is roughly once per turn. `refreshInterval` is deliberately NOT set in
# the deployed config: it would add a timed run every N seconds for data that
# does not change between turns.
#
# Contract: all stdout is rendered; exit status must be 0 or the line blanks.
# Every segment degrades independently — a field that is missing or unparseable
# drops its segment rather than failing the line.
#
# Test:
#   echo '{"model":{"display_name":"Opus 5"},"workspace":{"current_dir":"/tmp"},
#          "context_window":{"used_percentage":34},"session_id":"x"}' \
#     | bash statusline/ces-statusline.sh

# No `set -e`: a non-zero exit blanks the status line. Failures degrade instead.

# The theme list lives here and nowhere else. setup.sh reads it from this flag
# rather than keeping a copy that would drift out of sync.
CES_THEME_NAMES="ghost ember matrix ice mono default"

# Which models wear the horns. Space-separated substrings, matched
# case-insensitively against the model's display name. These are family names,
# not exact ids, so "opus" keeps matching across "Opus 4.1", "Opus 5" and
# whatever follows without an edit here. Anything that matches nothing — an
# unfamiliar model, a retired one, or no model field at all — renders the plain
# skull, so a rename or a discontinuation degrades quietly instead of breaking
# the line. Override without touching this file:
#   export CES_HEAVY_MODELS="opus fable"
CES_HEAVY_MODELS="${CES_HEAVY_MODELS:-opus}"

if [[ "${1:-}" == "--theme-names" ]]; then
    printf '%s\n' $CES_THEME_NAMES
    exit 0
fi

# `--themes` renders every theme at three pressure levels so a choice can be
# made by looking rather than by reading colour codes. It re-execs this script
# once per sample; that spawning only happens here, never on the status path.
if [[ "${1:-}" == "--themes" ]]; then
    _self="${BASH_SOURCE[0]}"
    for _t in $CES_THEME_NAMES; do
        printf '\n  %s\n' "$_t"
        for _p in 30 70 92; do
            printf '    '
            printf '%s' "{\"model\":{\"display_name\":\"Opus 5\"},\"workspace\":{\"current_dir\":\"$PWD\"},\"context_window\":{\"used_percentage\":$_p}}" \
                | CES_THEME="$_t" bash "$_self"
        done
    done
    printf '\n  Set one with CES_THEME, or edit THEME in %s\n\n' "$_self"
    exit 0
fi

if [[ "${1:-}" == "--test" ]]; then
    _self="${BASH_SOURCE[0]}"
    PASS=0 FAIL=0
    _ok()   { printf 'PASS  %s\n' "$1"; PASS=$(( PASS + 1 )); }
    _fail() { printf 'FAIL  %s\n' "$1"; FAIL=$(( FAIL + 1 )); }

    # Inline copies of the parsers — originals are defined later in the script.
    _jget() {
        local s="$1" k="$2" v
        REPLY=""
        [[ "$s" == *"\"$k\":"* ]] || return 1
        v="${s#*\"$k\":}"; v="${v# }"
        if [[ "$v" == '"'* ]]; then v="${v:1}"; v="${v%%\"*}"
        else v="${v%%,*}"; v="${v%%\}*}"; v="${v%% *}"; fi
        [[ -n "$v" ]] || return 1; REPLY="$v"
    }
    _jobj() {
        local s="$1" k="$2"
        REPLY=""
        [[ "$s" == *"\"$k\":{"* ]] || return 1
        REPLY="${s#*\"$k\":\{}"
    }

    _jget '{"display_name":"Opus 5"}' display_name \
        && [[ "$REPLY" == "Opus 5" ]]  && _ok "_jget:string"  || _fail "_jget:string"
    _jget '{"used_percentage":42}' used_percentage \
        && [[ "$REPLY" == "42" ]]       && _ok "_jget:number"  || _fail "_jget:number"
    _jget '{"a":"b"}' missing 2>/dev/null \
        && _fail "_jget:missing (should fail)" || _ok "_jget:missing"
    _jobj '{"model":{"display_name":"X"}}' model \
        && [[ "$REPLY" == *'"display_name"'* ]] && _ok "_jobj:nested" || _fail "_jobj:nested"
    _jobj '{"a":{"b":"c"}}' missing 2>/dev/null \
        && _fail "_jobj:missing (should fail)"  || _ok "_jobj:missing"

    # Banner widths: strip ANSI escape codes, count chars per row, check the max.
    # Requires a UTF-8 locale so bash's ${#s} counts chars, not bytes.
    _vislen() {
        local s="$1" i c esc=0 n=0
        for (( i=0; i<${#s}; i++ )); do
            c="${s:$i:1}"
            if (( esc )); then [[ "$c" == "m" ]] && esc=0; continue; fi
            [[ "$c" == $'\033' ]] && { esc=1; continue; }
            (( n++ ))
        done
        printf '%d' "$n"
    }
    # One render, two measurements: REPLY is the widest visible row (the grid
    # invariant) and ROWS is the line count including the info line (which
    # variant was selected). `< <(...)` keeps the loop in this shell so ROWS
    # survives it.
    _render() {
        local mode="$1" json="$2" row
        ROWS=0; W=()
        while IFS= read -r row; do
            W[ROWS]="$(_vislen "$row")"
            (( ROWS++ ))
        done < <(printf '%s' "$json" | NO_COLOR=1 CES_BANNER="$mode" bash "$_self")
    }
    # Widest banner row only. The last line is the info line, whose width
    # tracks the model name and directory; it is not part of the art grid and
    # measuring it against the grid is what made this check pass only for
    # payloads with no model field.
    _banner_width() {
        local i max=0
        for (( i=0; i<ROWS-1; i++ )); do (( W[i] > max )) && max=${W[i]}; done
        REPLY="$max"
    }
    _check_banner() {
        local label="$1" mode="$2" exp="$3" json="$4"
        [[ -n "$json" ]] || json='{}'
        _render "$mode" "$json"
        _banner_width
        (( REPLY == exp )) && _ok "banner:${label} max-width=${exp}" \
                          || _fail "banner:${label} expected max-width=${exp} got=${REPLY}"
    }
    _check_rows() {
        local label="$1" mode="$2" exp="$3" json="$4"
        _render "$mode" "$json"
        (( ROWS == exp )) && _ok "variant:${label} rows=${exp}" \
                         || _fail "variant:${label} expected rows=${exp} got=${ROWS}"
    }

    _OPUS='{"model":{"display_name":"Opus 5"}}'
    _LOWER='{"model":{"display_name":"claude-opus-5"}}'
    _SONNET='{"model":{"display_name":"Sonnet 4.6"}}'
    _RETIRED='{"model":{"display_name":"Nimbus 9"}}'
    _NOMODEL='{"workspace":{"current_dir":"/tmp"}}'

    # The horned variant has to hold the same grid as the plain one.
    _check_banner full        full  15
    _check_banner small       small 13
    _check_banner demon-full  full  15 "$_OPUS"
    _check_banner demon-small small 13 "$_OPUS"

    # Variant selection. The horned crown is two rows where the plain one is
    # one, so a full banner goes 10->11 rows; +1 for the info line either way.
    _check_rows skull-full   full 11 '{}'
    _check_rows demon-full   full 12 "$_OPUS"
    _check_rows demon-lower  full 12 "$_LOWER"
    # A model outside the list, one that no longer exists, and a payload with
    # no model field at all must all fall back to the skull rather than fail.
    _check_rows sonnet-full  full 11 "$_SONNET"
    _check_rows retired-full full 11 "$_RETIRED"
    _check_rows nomodel-full full 11 "$_NOMODEL"

    printf '\n%d passed  %d failed\n' "$PASS" "$FAIL"
    (( FAIL == 0 )); exit $?
fi

read -r -d '' INPUT   # unterminated read returns non-zero; the data is in INPUT
: "${INPUT:=}"

# ── JSON field extraction (sets REPLY; no subshell, no fork) ─────────────────
# Handles the flat scalar case only, which is all this script needs. Callers
# narrow to the parent object first so key names cannot collide across objects.
_jget() {
    local s="$1" k="$2" v
    REPLY=""
    [[ "$s" == *"\"$k\":"* ]] || return 1
    v="${s#*\"$k\":}"
    v="${v# }"
    if [[ "$v" == '"'* ]]; then
        v="${v:1}"
        v="${v%%\"*}"
    else
        v="${v%%,*}"
        v="${v%%\}*}"
        v="${v%% *}"
    fi
    [[ -n "$v" ]] || return 1
    REPLY="$v"
}

# Narrow to a nested object before reading a key from it. `used_percentage`
# exists under both context_window and rate_limits, so anchoring on the
# object's opening brace is what keeps them apart.
_jobj() {
    local s="$1" k="$2"
    REPLY=""
    [[ "$s" == *"\"$k\":{"* ]] || return 1
    REPLY="${s#*\"$k\":\{}"
}

MODEL="" DIR="" PCT="" BRANCH="" STYLE=""

_jobj "$INPUT" model      && { _jget "$REPLY" display_name    && MODEL="$REPLY"; }
_jobj "$INPUT" workspace  && { _jget "$REPLY" current_dir     && DIR="$REPLY"; }
_jobj "$INPUT" context_window && { _jget "$REPLY" used_percentage && PCT="$REPLY"; }
_jobj "$INPUT" output_style   && { _jget "$REPLY" name        && STYLE="$REPLY"; }
[[ -z "$DIR" ]] && { _jget "$INPUT" cwd && DIR="$REPLY"; }

# ── Model weight ─────────────────────────────────────────────────────────────
# HEAVY=1 swaps the banner's smooth crown for horns. Matching is substring and
# case-insensitive, against the display name only: it is the field the status
# JSON is documented to carry, and a family substring survives the version
# bumps and id reshuffles that an exact match would not. The pattern list is
# CES_HEAVY_MODELS at the top of this file — adding a family is one word there,
# and no other part of the script needs to know about it.
HEAVY=0
if [[ -n "$MODEL" ]]; then
    shopt -s nocasematch
    for _pat in $CES_HEAVY_MODELS; do
        [[ "$MODEL" == *"$_pat"* ]] && { HEAVY=1; break; }
    done
    shopt -u nocasematch
fi

# ── Git branch, read from the filesystem rather than by running git ──────────
# Walks up looking for .git. A directory holds HEAD directly; a worktree or
# submodule leaves a `gitdir:` pointer file instead.
_branch() {
    local d="$1" head gitdir line i=0
    REPLY=""
    while [[ -n "$d" && "$d" != "/" && $i -lt 24 ]]; do
        if [[ -d "$d/.git" ]]; then
            head="$d/.git/HEAD"
        elif [[ -f "$d/.git" ]]; then
            read -r line < "$d/.git" 2>/dev/null || return 1
            gitdir="${line#gitdir: }"
            [[ "$gitdir" == /* ]] || gitdir="$d/$gitdir"
            head="$gitdir/HEAD"
        else
            d="${d%/*}"; i=$((i + 1)); continue
        fi
        [[ -r "$head" ]] || return 1
        read -r line < "$head" 2>/dev/null || return 1
        if [[ "$line" == ref:* ]]; then
            REPLY="${line##*/}"
        else
            REPLY="${line:0:7}"   # detached HEAD: short sha
        fi
        return 0
    done
    return 1
}
[[ -n "$DIR" ]] && _branch "$DIR"
BRANCH="$REPLY"

# ── Theme ────────────────────────────────────────────────────────────────────
# Change THEME below, or set CES_THEME in your environment to override it.
# Adding one means adding a case branch: set the glyph, three text colours, and
# three pressure colours. Nothing else in the script needs to know about it.
#
# 256-colour codes only. COLORTERM is frequently unset even where truecolor
# works, so assuming truecolor is not safe; the 256 palette renders far wider.

THEME="${CES_THEME:-ghost}"

# Dim carries the model name, so it has to stay legible on a dark background —
# the deep end of each hue ramp (22, 24, 94) is too dark to read and is avoided.
# Swap GLYPH for anything your font renders: ᗝ ◆ ▲ ▮ ❄ ✦ ◈ ☾ ❉ ⬢ ·

# Three banner tones, not five. A five-step ramp spread over ten rows reads as
# a muddy gradient; three let the skull break into zones a viewer can actually
# parse — lit dome, bone, shadowed jaw — which is what gives it structure.
# BD dark, BM mid, BL light. Separate from the text colours, which have to stay
# legible as text while these only have to read as one surface.

case "$THEME" in
    ghost)    # dark violet, faintly haunted
        GLYPH="ᗝ"; CA=141; CD=103; CG=177; P1=97;  P2=141; P3=205
        # BD stays deep violet (54) so the lower skull and jaw read as a dark
        # hood/collar accent, preserving the Claude purple aesthetic. BM and BL
        # switch to warm bone tones so the cranium reads as skull, not ghost.
        BD=54;  BM=230; BL=255 ;;
    ember)    # warm, embers banking down
        GLYPH="▲"; CA=208; CD=137; CG=180; P1=130; P2=179; P3=203
        BD=94;  BM=208; BL=223 ;;
    matrix)   # terminal green
        GLYPH="▮"; CA=46;  CD=71;  CG=84;  P1=65;  P2=112; P3=226
        BD=28;  BM=46;  BL=120 ;;
    ice)      # cold blues
        GLYPH="❄"; CA=81;  CD=109; CG=117; P1=66;  P2=74;  P3=147
        BD=24;  BM=81;  BL=159 ;;
    mono)     # no hue at all, only weight
        GLYPH="·"; CA=252; CD=243; CG=248; P1=243; P2=248; P3=255
        BD=239; BM=248; BL=255 ;;
    *)        # the original
        GLYPH="◆"; CA=110; CD=244; CG=108; P1=109; P2=179; P3=174
        BD=24;  BM=110; BL=153 ;;
esac

if [[ -n "${NO_COLOR:-}" ]]; then
    A="" D="" G="" C="" R=""
    SD="" SM="" SL="" V=""
else
    A=$'\033[38;5;'"${CA}"'m'   # accent — the marker
    D=$'\033[38;5;'"${CD}"'m'   # dim — separators and secondary text
    G=$'\033[38;5;'"${CG}"'m'   # branch
    R=$'\033[0m'
    SD=$'\033[38;5;'"${BD}"'m'  # shadow
    SM=$'\033[38;5;'"${BM}"'m'  # bone
    SL=$'\033[38;5;'"${BL}"'m'  # lit
    # Sockets and nasal cavity: true black, so they read as holes punched
    # through the bone rather than as dark-coloured fill.
    V=$'\033[38;5;16m'
    # Pupil: glows red (196) while ~/.ces-working exists — the file is set by
    # a PreToolUse hook and cleared by Stop, so it stays lit during tool-use
    # phases and goes dark when Claude finishes.
    if [[ -f "${HOME}/.ces-working" ]]; then
        PU=$'\033[38;5;196m'
    else
        PU="$V"
    fi
fi
# NO_COLOR path: PU stays empty like V, so the row degrades to colourless.
[[ -n "${NO_COLOR:-}" ]] && PU=""

# Only treat PCT as a number if it actually is one. An absent or malformed
# field must not reach the arithmetic: a syntax error there writes to stderr on
# every run, which `claude --debug` would log even though the line still renders.
BAR=""
PCTN=""
if [[ "$PCT" =~ ^[0-9]+ ]]; then
    PCTN="${PCT%%.*}"
fi

# A case ladder rather than arithmetic plus substring slicing, because slicing
# multibyte block characters depends on the locale being UTF-8.
if [[ -n "$PCTN" ]]; then
    case $(( PCTN / 20 )) in
        0) BAR="▁░░░░" ;;
        1) BAR="▃▃░░░" ;;
        2) BAR="▅▅▅░░" ;;
        3) BAR="▆▆▆▆░" ;;
        *) BAR="███▇▇" ;;
    esac

    # Bar colour tracks pressure, so the line reads at a glance. Every theme
    # escalates, whatever its hue — the signal must survive the palette.
    if [[ -z "${NO_COLOR:-}" ]]; then
        if   (( PCTN >= 80 )); then C=$'\033[38;5;'"${P3}"'m'
        elif (( PCTN >= 60 )); then C=$'\033[38;5;'"${P2}"'m'
        else                        C=$'\033[38;5;'"${P1}"'m'
        fi
    fi
fi

# Shorten the directory to its last two components, with ~ for $HOME.
SHORT="$DIR"
[[ -n "$HOME" && "$SHORT" == "$HOME"* ]] && SHORT="~${SHORT#"$HOME"}"
if [[ "$SHORT" == */*/* ]]; then
    _tail="${SHORT##*/}"; _rest="${SHORT%/*}"
    SHORT="${_rest##*/}/${_tail}"
fi

# ── Optional banner ──────────────────────────────────────────────────────────
# CES_BANNER=small|full prints art above the info line. The status line is the
# only confirmed way to show art: SessionStart hook stdout goes to the model's
# context rather than the screen, and `systemMessage` did not render in print
# mode (interactive mode untested). Colour works here, which it does not in
# hook output.
#
# This is a persistent bar, not a one-time splash — it redraws every update and
# holds its rows permanently. That is the trade for having it render at all.
#
# ── Manual hide ──────────────────────────────────────────────────────────────
# Two ways to suppress the banner without touching settings.json:
#
#   Persistent (survives new terminals):
#     touch ~/.ces-no-banner        # hide
#     rm    ~/.ces-no-banner        # show again
#
#   Session-only (current terminal only):
#     export CES_BANNER_HIDDEN=1    # hide for this session
#     unset  CES_BANNER_HIDDEN      # show again
#
# Either check skips the printf block entirely; the info line still renders.

# Both variants are laid out on a fixed grid — 15 columns for full, 13 for
# small — so the skull stays symmetric. Colour spans are inserted inside the
# row without changing its visible width; miscounting one row is what makes
# this kind of art look crooked.

if [[ -z "${CES_BANNER_HIDDEN:-}" && ! -f "${HOME}/.ces-no-banner" ]]; then
case "${CES_BANNER:-off}" in
    full)
        # Every cell inside the silhouette is a full block. Shape is carried
        # by colour changes between filled cells, never by gaps. Sockets and
        # nasal cavity are true black (V). The cranium uses SL (lit) fading
        # through SM (bone ivory) with SD (purple) as the brow shadow band.
        # Half blocks appear only on the outer edge where the terminal
        # background showing through forms the silhouette.
        #
        # Eye sockets: 3px wide × 2 tall; bridge widened to 5px so they read
        # as clearly separated (SM:2+V:3+SM:5+V:3+SM:2=15).
        # Nose: inverted heart — two 1px nostril dots (row 7) converge into
        # a 3px merged opening (row 8).
        # No purple rows; tooth gaps use true black (V) for clean definition.
        # The crown is the only row that differs between variants — everything
        # below it is shared, so the skull stays defined in exactly one place
        # and the horns cannot drift out of alignment with it. Horns are drawn
        # in SD (the theme's shadow tone) so they read as a different material
        # than the cranium without adding a colour to the palette.
        # Horn rows hold the 15-column grid: 1+1+11+1+1 and 1+2+9+2+1. The
        # 9-cell dome top is the plain crown unchanged, so the horns are added
        # beside the skull rather than by reshaping it — the two variants share
        # the same silhouette from the brow down.
        if (( HEAVY )); then
            printf '%s\n' "${SD}█▄           ▄█${R}"
            printf '%s\n' "${SD}▀██${SL}▄▄▄▄▄▄▄▄▄${SD}██▀${R}"
        else
            printf '%s\n' "${SL}   ▄▄▄▄▄▄▄▄▄${R}"
        fi
        printf '%s\n' "${SL} █████████████${R}"
        printf '%s\n' "${SM}███████████████${R}"
        printf '%s\n' "${SM}███████████████${R}"
        printf '%s\n' "${SM}██${V}███${SM}█████${V}███${SM}██${R}"
        printf '%s\n' "${SM}██${V}█${PU}█${V}█${SM}█████${V}█${PU}█${V}█${SM}██${R}"
        printf '%s\n' "${SM}█████${V}█${SM}███${V}█${SM}█████${R}"
        printf '%s\n' "${SM}██████${V}███${SM}██████${R}"
        printf '%s\n' "${SM} █████████████${R}"
        printf '%s\n' "${SM}  ██${V}█${SM}██${V}█${SM}██${V}█${SM}██${R}"
        ;;
    small)
        # 13px wide. Eyes: SM:2+V:3+SM:3+V:3+SM:2=13.
        # Nose: two 1px dots (SM:4+V:1+SM:3+V:1+SM:4=13).
        # Tooth gaps use V (black), no purple.
        # Same split as full: crown swaps, body is shared. 1+1+9+1+1 and 1+11+1.
        if (( HEAVY )); then
            printf '%s\n' "${SD}█▄         ▄█${R}"
            printf '%s\n' "${SD}▀${SL}███████████${SD}▀${R}"
        else
            printf '%s\n' "${SL} ███████████${R}"
        fi
        printf '%s\n' "${SM}██${V}█${PU}█${V}█${SM}███${V}█${PU}█${V}█${SM}██${R}"
        printf '%s\n' "${SM}████${V}█${SM}███${V}█${SM}████${R}"
        printf '%s\n' "${SM}█${V}█${SM}██${V}█${SM}███${V}█${SM}██${V}█${SM}█${R}"
        ;;
esac
fi  # CES_BANNER_HIDDEN / ~/.ces-no-banner

SEP="${D} · ${R}"
OUT="${A}${GLYPH} ces${R}"
[[ -n "$MODEL"  ]] && OUT+="${SEP}${D}${MODEL}${R}"
[[ -n "$BRANCH" ]] && OUT+="${SEP}${G}${BRANCH}${R}"
[[ -n "$PCTN"   ]] && OUT+="${SEP}${C}${BAR}${R}${D} ${PCTN}%${R}"
[[ -n "$STYLE" && "$STYLE" != "default" ]] && OUT+="${SEP}${D}${STYLE}${R}"

printf '%s\n' "$OUT"
exit 0
