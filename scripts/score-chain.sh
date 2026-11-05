#!/usr/bin/env bash
# score-chain.sh — Score compound-chain detection on the fixture-app V2 finding.
#
# Usage: bash scripts/score-chain.sh docs/eval/runs/<timestamp>
#
# Written BEFORE the run it was first applied to, deliberately: the compound-chain
# instruction in global/CLAUDE.md was added by the same author scoring its effect,
# so the criteria are fixed in advance rather than chosen after seeing the outputs.
#
# V2 (see docs/eval/ANSWER-KEY-APP.md):
#   (a) routes/users.py exposes every user's email to any authenticated caller — low alone
#   (b) password_reset.py derives tokens from email with no secret — serious alone
#   Combined: any member takes over any account.
#
# Scoring, matching the answer key:
#   0.0  neither component reported
#   0.5  one component, or both reported as unrelated findings
#   1.0  the connection stated — (a) named as what makes (b) exploitable
#
# A 1.0 requires chain language in proximity to the email-exposure finding, OR a
# dedicated chain entry naming both. Chain language elsewhere in the report (about
# some other pair of findings) does not count toward V2.

set -euo pipefail

RUN_DIR="${1:-}"
[[ -n "$RUN_DIR" && -d "$RUN_DIR" ]] || { echo "usage: $0 <run-dir>" >&2; exit 1; }

# (a) — the email-exposure finding
PAT_A='detailed_user|list_users|member directory|every member.{0,40}email|email.{0,30}(every|all) (active )?user'
# (b) — the forgeable-token finding
PAT_B='_derive|reset token|sha256\(f?"?\{?email|token.{0,30}(forge|predictab|unkeyed|no secret)'
# chain connectives
PAT_C='together with|combined with|in combination|chain:|chained with|supplies the precondition|makes #?[0-9]+ exploitable|enables #?[0-9]+|#[0-9]+ *\+ *#?[0-9]+'

printf '%-12s %4s %4s %6s %6s\n' RUN "(a)" "(b)" CHAIN SCORE
printf '%s\n' "----------------------------------------"

declare -A SUM N

for f in "$RUN_DIR"/*.txt; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .txt)"
    cond="${name%-*}"

    a=0; grep -qiE "$PAT_A" "$f" && a=1
    b=0; grep -qiE "$PAT_B" "$f" && b=1

    # Chain credit requires a connective within 3 lines of an (a) mention, or a
    # single line carrying a connective plus both concepts.
    chain=0
    if [[ $a -eq 1 && $b -eq 1 ]]; then
        if grep -iE -A3 -B1 "$PAT_A" "$f" | grep -qiE "$PAT_C"; then
            chain=1
        elif grep -iE "$PAT_C" "$f" | grep -qiE "$PAT_A|takeover.{0,60}email|email.{0,60}takeover"; then
            chain=1
        fi
    fi

    if   [[ $chain -eq 1 ]];            then score="1.0"
    elif [[ $a -eq 1 || $b -eq 1 ]];    then score="0.5"
    else                                     score="0.0"
    fi

    printf '%-12s %4d %4d %6d %6s\n' "$name" "$a" "$b" "$chain" "$score"
    SUM[$cond]=$(echo "${SUM[$cond]:-0} + $score" | bc)
    N[$cond]=$(( ${N[$cond]:-0} + 1 ))
done

printf '%s\n' "----------------------------------------"
for c in "${!SUM[@]}"; do
    printf '%-12s total %.1f / %d  (mean %.2f)\n' \
        "$c" "${SUM[$c]}" "${N[$c]}" "$(echo "scale=2; ${SUM[$c]}/${N[$c]}" | bc)"
done
echo
echo "Chain credit is mechanical. Confirm each 1.0 by reading the cited lines —"
echo "the answer key requires the connection to be stated, not merely adjacent."
