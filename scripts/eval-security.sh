#!/usr/bin/env bash
# eval-security.sh — A/B the system against a blind security fixture.
#
# Usage:
#   bash scripts/eval-security.sh [TRIALS]              # 2 conditions
#   bash scripts/eval-security.sh [TRIALS] --variant F  # adds a third
#
# Conditions
#   baseline  — an isolated HOME containing only a symlink to the existing
#               credentials. No global CLAUDE.md, no agents, no skills.
#   system    — the real HOME, with this system deployed.
#   variant   — an isolated HOME holding credentials plus the CLAUDE.md given
#               by --variant. Used for ablations: which sections are actually
#               load-bearing. Agents and skills are absent, matching baseline,
#               so the only difference from baseline is the file under test.
#
# Both conditions get the identical prompt and the identical fixture, so the
# only variable is whether ~/.claude/ configuration is present.
#
# Outputs land in docs/eval/runs/<timestamp>/ for scoring against ANSWER-KEY.md.
# Scoring is manual and deliberately so: judging whether a report names a
# mechanism or hand-waves at a category is not reliably automatable.
#
# Note: --bare would be the natural isolation flag, but it accepts only
# ANTHROPIC_API_KEY and refuses OAuth, so it is unusable on an OAuth login.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRIALS=3
VARIANT=""

args=("$@")
for i in "${!args[@]}"; do
    case "${args[$i]}" in
        --variant) VARIANT="${args[$((i+1))]:-}" ;;
        [0-9]*)    TRIALS="${args[$i]}" ;;
    esac
done
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${REPO_DIR}/docs/eval/runs/${TIMESTAMP}"
# FIXTURE may be a single file or a directory. A directory is copied whole, so
# multi-file fixtures — where a flaw only appears by connecting two files — work
# the same way as the original single-file one.
FIXTURE="${FIXTURE:-${REPO_DIR}/docs/eval/fixture-blind.py}"
PROMPT="${PROMPT:-Review this codebase for security issues. List each issue with the file and line number.}"

log() { echo "[eval] $*"; }
err() { echo "[eval] ERROR: $*" >&2; exit 1; }

[[ -e "$FIXTURE" ]] || err "fixture not found: $FIXTURE"
command -v claude &>/dev/null || err "claude CLI not found on PATH"
[[ -f "${HOME}/.claude/.credentials.json" ]] \
    || err "no credentials at ~/.claude/.credentials.json — baseline cannot authenticate"

WORK="$(mktemp -d)"
trap '[[ -n "${WORK:-}" ]] && rm -rf "$WORK"' EXIT

# Isolated home: credentials only, by symlink. The secret is never copied.
ISO_HOME="${WORK}/iso-home"
mkdir -p "${ISO_HOME}/.claude"
ln -sf "${HOME}/.claude/.credentials.json" "${ISO_HOME}/.claude/.credentials.json"
[[ -f "${ISO_HOME}/.claude/CLAUDE.md" ]] && err "isolation broken: CLAUDE.md leaked into baseline home"

# Target directory. A single-file fixture is renamed to look like ordinary
# application code; a directory fixture is copied with its structure intact.
TARGET="${WORK}/target"
mkdir -p "$TARGET"
if [[ -d "$FIXTURE" ]]; then
    cp -R "${FIXTURE}/." "$TARGET/"
    log "fixture: $(basename "$FIXTURE")/ ($(find "$TARGET" -name '*.py' | wc -l) python files)"
else
    cp "$FIXTURE" "${TARGET}/account_service.py"
    log "fixture: $(basename "$FIXTURE") (single file)"
fi

mkdir -p "$RUN_DIR"

log "trials per condition: ${TRIALS}"
log "output: ${RUN_DIR}"
log "prompt: ${PROMPT}"
echo

run_one() {
    local condition="$1" trial="$2" home_dir="$3"
    local out="${RUN_DIR}/${condition}-${trial}.txt"
    local started elapsed
    started=$(date +%s)

    if ( cd "$TARGET" && HOME="$home_dir" timeout 300 claude -p "$PROMPT" ) \
        > "$out" 2> "${RUN_DIR}/${condition}-${trial}.err"; then
        elapsed=$(( $(date +%s) - started ))
        log "  ${condition} trial ${trial}: ok (${elapsed}s, $(wc -l < "$out") lines)"
    else
        elapsed=$(( $(date +%s) - started ))
        log "  ${condition} trial ${trial}: FAILED after ${elapsed}s — see ${condition}-${trial}.err"
    fi
}

log "Condition: baseline (no system configuration)"
for i in $(seq 1 "$TRIALS"); do
    run_one baseline "$i" "$ISO_HOME"
done
echo

log "Condition: system (configuration deployed)"
for i in $(seq 1 "$TRIALS"); do
    run_one system "$i" "$HOME"
done
echo

if [[ -n "$VARIANT" ]]; then
    [[ -f "$VARIANT" ]] || err "variant file not found: $VARIANT"
    VAR_HOME="${WORK}/var-home"
    mkdir -p "${VAR_HOME}/.claude"
    ln -sf "${HOME}/.claude/.credentials.json" "${VAR_HOME}/.claude/.credentials.json"
    cp "$VARIANT" "${VAR_HOME}/.claude/CLAUDE.md"
    cp "$VARIANT" "${RUN_DIR}/variant-source.md"

    log "Condition: variant ($(basename "$VARIANT"))"
    for i in $(seq 1 "$TRIALS"); do
        run_one variant "$i" "$VAR_HOME"
    done
    echo
fi

cat > "${RUN_DIR}/META.md" <<EOF
# Run ${TIMESTAMP}

- Claude Code: $(claude --version 2>/dev/null | head -1)
- Trials per condition: ${TRIALS}
- Prompt: \`${PROMPT}\`
- Fixture: \`${FIXTURE#${REPO_DIR}/}\`
- Baseline isolation: temporary HOME with only a credentials symlink

Score each output against \`docs/eval/ANSWER-KEY.md\` and record recall (of 6),
false positives (of 4 traps), and whether findings cite line numbers.
EOF

log "Done. Score the outputs against docs/eval/ANSWER-KEY.md"
