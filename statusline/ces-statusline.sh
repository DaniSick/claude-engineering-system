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

# B1..B5 are the banner's shading ramp, darkest to brightest, lit from above.
# They are separate from the text colours because art needs more steps than a
# status line does: CA/CD/CG must stay legible as text, while B1..B5 only have
# to read as one surface curving away from the light.

case "$THEME" in
    ghost)    # dark violet, faintly haunted
        GLYPH="ᗝ"; CA=141; CD=103; CG=177; P1=97;  P2=141; P3=205
        B1=54;  B2=61;  B3=97;  B4=141; B5=183 ;;
    ember)    # warm, embers banking down
        GLYPH="▲"; CA=208; CD=137; CG=180; P1=130; P2=179; P3=203
        B1=52;  B2=94;  B3=130; B4=208; B5=223 ;;
    matrix)   # terminal green
        GLYPH="▮"; CA=46;  CD=71;  CG=84;  P1=65;  P2=112; P3=226
        B1=22;  B2=28;  B3=34;  B4=46;  B5=120 ;;
    ice)      # cold blues
        GLYPH="❄"; CA=81;  CD=109; CG=117; P1=66;  P2=74;  P3=147
        B1=17;  B2=24;  B3=31;  B4=81;  B5=159 ;;
    mono)     # no hue at all, only weight
        GLYPH="·"; CA=252; CD=243; CG=248; P1=243; P2=248; P3=255
        B1=236; B2=240; B3=244; B4=250; B5=255 ;;
    *)        # the original
        GLYPH="◆"; CA=110; CD=244; CG=108; P1=109; P2=179; P3=174
        B1=17;  B2=24;  B3=67;  B4=110; B5=153 ;;
esac

if [[ -n "${NO_COLOR:-}" ]]; then
    A="" D="" G="" C="" R=""
    S1="" S2="" S3="" S4="" S5="" V=""
else
    A=$'\033[38;5;'"${CA}"'m'   # accent — the marker
    D=$'\033[38;5;'"${CD}"'m'   # dim — separators and secondary text
    G=$'\033[38;5;'"${CG}"'m'   # branch
    R=$'\033[0m'
    # Banner shading, darkest to brightest.
    S1=$'\033[38;5;'"${B1}"'m'
    S2=$'\033[38;5;'"${B2}"'m'
    S3=$'\033[38;5;'"${B3}"'m'
    S4=$'\033[38;5;'"${B4}"'m'
    S5=$'\033[38;5;'"${B5}"'m'
    # Sockets and nasal cavity: true black, so they read as holes punched
    # through the bone rather than as dark-coloured fill.
    V=$'\033[38;5;16m'
fi

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

# Both variants are laid out on a fixed grid — 19 columns for full, 13 for
# small — so the skull stays symmetric. Colour spans are inserted inside the
# row without changing its visible width; miscounting one row is what makes
# this kind of art look crooked.

# Laid out on a fixed grid — 21 columns for full, 15 for small — with an odd
# width so there is a true centre column. Four tones give the skull volume
# without adding any theme configuration: G is rim light along the cranium,
# A is bone, D is the socket void, E is the pupil burning inside it. Colour
# spans never change a row's visible width, which is what makes hand-counted
# art come out crooked.

case "${CES_BANNER:-off}" in
    full)
        printf '%s\n' "${S5}    ▄▄█████████▄▄${R}"
        printf '%s\n' "${S5}  ▄█${S4}█████████████${S5}█▄${R}"
        printf '%s\n' "${S5} ▄█${S4}███████████████${S5}█▄${R}"
        printf '%s\n' "${S4}██${S3}█████████████████${S4}██${R}"
        printf '%s\n' "${S3}██${S2}▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀${S3}██${R}"
        printf '%s\n' "${S3}██${S2} ▐${V}███${S2}▌     ▐${V}███${S2}▌ ${S3}██${R}"
        printf '%s\n' "${S3}██${S2} ▐${V}███${S2}▌     ▐${V}███${S2}▌ ${S3}██${R}"
        printf '%s\n' "${S2} ███▄▄   ${V}▄▀▄${S2}   ▄▄███${R}"
        printf '%s\n' "${S2}  ████${S1}▄▄▄▄▄▄▄▄▄${S2}████${R}"
        printf '%s\n' "${S3}   ██▌${S1}▐${S3}█▌${S1}▐${S3}█▌${S1}▐${S3}█▌${S1}▐${S3}██${R}"
        ;;
    small)
        printf '%s\n' "${S5} ▄█${S4}█████████${S5}█▄${R}"
        printf '%s\n' "${S3}█${S2} ▐${V}███${S2}▌ ▐${V}███${S2}▌ ${S3}█${R}"
        printf '%s\n' "${S3} █▌${S1}▐${S3}█▌${S1}▐${S3}█▌${S1}▐${S3}█▌${S1}▐${S3}█${R}"
        ;;
esac

SEP="${D} · ${R}"
OUT="${A}${GLYPH} ces${R}"
[[ -n "$MODEL"  ]] && OUT+="${SEP}${D}${MODEL}${R}"
[[ -n "$BRANCH" ]] && OUT+="${SEP}${G}${BRANCH}${R}"
[[ -n "$PCTN"   ]] && OUT+="${SEP}${C}${BAR}${R}${D} ${PCTN}%${R}"
[[ -n "$STYLE" && "$STYLE" != "default" ]] && OUT+="${SEP}${D}${STYLE}${R}"

printf '%s\n' "$OUT"
exit 0
