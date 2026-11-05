#!/usr/bin/env bash
# score-eval.sh — Score eval outputs for format-discipline markers.
#
# Usage: bash scripts/score-eval.sh docs/eval/runs/<timestamp>
#
# Scores only what is mechanically checkable: whether a report carries the
# reporting conventions specified in global/CLAUDE.md. Vulnerability recall
# still needs a human read against docs/eval/ANSWER-KEY.md — judging whether a
# report names a mechanism or hand-waves a category is not greppable.
#
# Markers, one point each:
#   table     — a findings table with Evidence and Impact columns
#   status    — CONFIRMED / HYPOTHESIS / NOT VERIFIED labels
#   negative  — states what was checked and found safe
#   scope     — flags what could not be verified from the available context
#   lineref   — findings cite file:line or "line N"

set -euo pipefail

RUN_DIR="${1:-}"
[[ -n "$RUN_DIR" && -d "$RUN_DIR" ]] || { echo "usage: $0 <run-dir>" >&2; exit 1; }

has() { grep -qiE "$2" "$1" 2>/dev/null; }

printf '%-12s %6s %6s %8s %6s %7s %6s\n' CONDITION TABLE STATUS NEGATIVE SCOPE LINEREF TOTAL
printf '%s\n' "------------------------------------------------------------------"

declare -A COND_SUM COND_N

for f in "$RUN_DIR"/*.txt; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .txt)"
    cond="${name%-*}"
    score=0

    has "$f" '^\|.*(evidence|file:line).*\|' && t=1 || t=0
    has "$f" '\b(CONFIRMED|HYPOTHESIS|NOT VERIFIED|NOT REPRODUCED)\b' && s=1 || s=0
    has "$f" '(not a finding|not flagged|not broken|checked and found (sound|safe)|correctly (parameterized|check|allowlists|uses)|is the one function|found no bypass|is solid|does the (ownership|authorization) check correctly)' && n=1 || n=0
    has "$f" '(NOT VERIFIED|did not sweep|check (the )?callers|can.?t verify|cannot verify|no callers|depends on (how|what) the|I can.?t verify|NOT RUN)' && c=1 || c=0
    has "$f" '([a-z_]+\.py:[0-9]+|line[s]? [0-9]+)' && l=1 || l=0

    score=$((t + s + n + c + l))
    printf '%-12s %6d %6d %8d %6d %7d %6d\n' "$name" "$t" "$s" "$n" "$c" "$l" "$score"

    COND_SUM[$cond]=$(( ${COND_SUM[$cond]:-0} + score ))
    COND_N[$cond]=$(( ${COND_N[$cond]:-0} + 1 ))
done

printf '%s\n' "------------------------------------------------------------------"
for cond in "${!COND_SUM[@]}"; do
    n=${COND_N[$cond]}
    sum=${COND_SUM[$cond]}
    printf '%-12s mean %.1f / 5  (%d trials)\n' "$cond" "$(echo "scale=2; $sum/$n" | bc)" "$n"
done
