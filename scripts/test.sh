#!/usr/bin/env bash
# scripts/test.sh — Regression tests for claude-engineering-system
#
# Usage: bash scripts/test.sh
#
# Exit 0 if all tests pass, 1 if any fail.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
ERRORS=()

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1: $2"; FAIL=$((FAIL + 1)); ERRORS+=("$1: $2"); }

echo "=== Claude Engineering System — Tests ==="
echo

# ── 1. JSON validity ──────────────────────────────────────────────────────────

echo "1. JSON validity"
for f in \
    "${REPO_DIR}/global/settings.json" \
    "${REPO_DIR}/.claude/settings.json"; do
    if python3 -m json.tool "$f" >/dev/null 2>&1; then
        pass "$(basename "$f")"
    else
        fail "$(basename "$f")" "invalid JSON"
    fi
done
echo

# ── 2. Agent frontmatter ──────────────────────────────────────────────────────

echo "2. Agent frontmatter (name + description required)"
for f in "${REPO_DIR}/agents/"*.md; do
    [[ -f "$f" ]] || continue
    has_name=$(grep -c '^name:' "$f" 2>/dev/null || true)
    has_desc=$(grep -c '^description:' "$f" 2>/dev/null || true)
    if [[ "$has_name" -ge 1 && "$has_desc" -ge 1 ]]; then
        pass "$(basename "$f")"
    else
        fail "$(basename "$f")" "missing name: or description: in frontmatter"
    fi
done
echo

# ── 3. Command frontmatter ────────────────────────────────────────────────────

echo "3. Command frontmatter (description required)"
for f in "${REPO_DIR}/.claude/commands/"*.md; do
    [[ -f "$f" ]] || continue
    has_desc=$(grep -c '^description:' "$f" 2>/dev/null || true)
    if [[ "$has_desc" -ge 1 ]]; then
        pass "$(basename "$f")"
    else
        fail "$(basename "$f")" "missing description: in frontmatter"
    fi
done
echo

# ── 4. No hardcoded secrets ───────────────────────────────────────────────────

echo "4. No hardcoded secrets in tracked files"
secret_found=0
declare -A patterns
patterns=(
    ["password literal"]='password\s*=\s*["\x27][^\s"'\'']{6,}'
    ["api_key literal"]='api[_-]?key\s*=\s*["\x27][^\s"'\'']{6,}'
    ["AWS key prefix"]='AKIA[A-Z0-9]{16}'
)
for label in "${!patterns[@]}"; do
    pattern="${patterns[$label]}"
    if git -C "$REPO_DIR" grep --quiet -rn -iE "$pattern" -- \
        '*.md' '*.json' '*.sh' '*.py' 2>/dev/null; then
        fail "secret-scan" "pattern matched: $label"
        secret_found=1
    fi
done
[[ $secret_found -eq 0 ]] && pass "no credential patterns in tracked files"
echo

# ── 5. Hook script functional ─────────────────────────────────────────────────

echo "5. secret-scan.py hook"
HOOK="${REPO_DIR}/hooks/secret-scan.py"
if [[ ! -f "$HOOK" ]]; then
    fail "secret-scan.py" "file not found"
else
    # Non-Bash tool: silent exit 0
    output=$(echo '{"tool_name":"Read","tool_input":{"path":"x"}}' \
        | python3 "$HOOK" 2>&1 || true)
    if [[ -z "$output" ]]; then
        pass "non-Bash input → silent"
    else
        fail "non-Bash input" "expected no output, got: ${output:0:80}"
    fi

    # Bash non-commit: silent exit 0
    output=$(echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' \
        | python3 "$HOOK" 2>&1 || true)
    if [[ -z "$output" ]]; then
        pass "Bash non-commit → silent"
    else
        fail "Bash non-commit" "expected no output, got: ${output:0:80}"
    fi

    # Malformed JSON: silent exit 0 (graceful failure)
    output=$(echo 'not-json' | python3 "$HOOK" 2>&1 || true)
    if [[ -z "$output" ]]; then
        pass "malformed JSON → silent"
    else
        fail "malformed JSON" "expected no output, got: ${output:0:80}"
    fi

    # Empty input: silent exit 0
    output=$(echo '' | python3 "$HOOK" 2>&1 || true)
    if [[ -z "$output" ]]; then
        pass "empty input → silent"
    else
        fail "empty input" "expected no output, got: ${output:0:80}"
    fi
fi
echo

# ── 6. Deployment verification ────────────────────────────────────────────────

echo "6. Deployment verification (setup.sh --verify)"
CLAUDE_DIR="${HOME}/.claude"
if [[ ! -d "$CLAUDE_DIR" ]]; then
    fail "deployment" "~/.claude/ not found — is Claude Code installed?"
else
    verify_out=$(bash "${REPO_DIR}/scripts/setup.sh" --verify 2>&1)
    if echo "$verify_out" | grep -q 'MISSING\|DIFFERS'; then
        fail "deployment" "files out of sync — run: bash scripts/setup.sh"
        echo "$verify_out" | grep 'MISSING\|DIFFERS' | sed 's/^/    /'
    else
        pass "all deployed files match source"
    fi
fi
echo

# ── Summary ───────────────────────────────────────────────────────────────────

echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
if [[ ${FAIL} -gt 0 ]]; then
    echo
    echo "Failures:"
    for err in "${ERRORS[@]}"; do
        echo "  - $err"
    done
    exit 1
fi
