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

# ── Presentation ─────────────────────────────────────────────────────────────
# 256-color only. COLORTERM is frequently unset even where truecolor works, so
# assuming it is not safe; the 256 palette renders correctly far more widely.
if [[ -n "${NO_COLOR:-}" ]]; then
    A="" D="" G="" C="" R=""
else
    A=$'\033[38;5;110m'   # accent — the CES marker
    D=$'\033[38;5;244m'   # dim — separators and secondary text
    G=$'\033[38;5;108m'   # branch
    R=$'\033[0m'
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

    # Bar colour tracks pressure, so the line reads at a glance.
    if [[ -z "${NO_COLOR:-}" ]]; then
        if   (( PCTN >= 80 )); then C=$'\033[38;5;174m'
        elif (( PCTN >= 60 )); then C=$'\033[38;5;179m'
        else                        C=$'\033[38;5;109m'
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

SEP="${D} · ${R}"
OUT="${A}◆ ces${R}"
[[ -n "$MODEL"  ]] && OUT+="${SEP}${D}${MODEL}${R}"
[[ -n "$BRANCH" ]] && OUT+="${SEP}${G}${BRANCH}${R}"
[[ -n "$PCTN"   ]] && OUT+="${SEP}${C}${BAR}${R}${D} ${PCTN}%${R}"
[[ -n "$STYLE" && "$STYLE" != "default" ]] && OUT+="${SEP}${D}${STYLE}${R}"

printf '%s\n' "$OUT"
exit 0
