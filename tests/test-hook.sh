#!/usr/bin/env bash
# tests/test-hook.sh — Positive and negative detection tests for secret-scan.py
#
# Runs the hook with a mocked `git diff --cached` output and checks that the
# positive fixtures produce a warning while negative ones stay silent.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${REPO_DIR}/hooks/secret-scan.py"
FIXTURES="${REPO_DIR}/tests/hook-fixtures"
PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1: $2"; FAIL=$((FAIL + 1)); }

[[ -f "$HOOK" ]] || { echo "hook not found: $HOOK"; exit 1; }
[[ -d "$FIXTURES" ]] || { echo "fixtures dir not found: $FIXTURES"; exit 1; }

echo "=== Hook detection tests ==="
echo

# Build a temporary git repo so `git diff --cached` can be mocked by placing
# a fake `git` on PATH that cats the fixture file.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

make_fake_git() {
    local diff_file="$1"
    cat > "${TMP}/git" <<EOF
#!/usr/bin/env bash
# Fake git for the hook test. Only answers 'diff --cached'.
if [[ "\$1" == "diff" && "\$2" == "--cached" ]]; then
    cat "${diff_file}"
    exit 0
fi
exec /usr/bin/env -i /usr/bin/git "\$@" 2>/dev/null || true
EOF
    chmod +x "${TMP}/git"
}

run_hook() {
    PATH="${TMP}:${PATH}" python3 "${HOOK}" <<< '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' 2>&1
}

# ── Positive fixtures: must produce warning output ───────────────────────────
for fixture in "${FIXTURES}"/positive-*.diff; do
    [[ -f "$fixture" ]] || continue
    name="$(basename "$fixture")"
    make_fake_git "$fixture"
    out="$(run_hook)"
    if [[ -n "$out" ]]; then
        pass "${name} → warning produced"
    else
        fail "${name}" "expected warning, got empty output"
    fi
done

# ── Negative fixtures: must stay silent ──────────────────────────────────────
for fixture in "${FIXTURES}"/negative-*.diff; do
    [[ -f "$fixture" ]] || continue
    name="$(basename "$fixture")"
    make_fake_git "$fixture"
    out="$(run_hook)"
    if [[ -z "$out" ]]; then
        pass "${name} → silent"
    else
        fail "${name}" "expected silent, got: ${out:0:80}"
    fi
done

echo
echo "=== Hook results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -gt 0 ]] && exit 1
exit 0
