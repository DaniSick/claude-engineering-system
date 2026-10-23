#!/usr/bin/env bash
# doctor.sh — Diagnose the local environment and the state of the deployment.
#
# Usage:
#   bash scripts/doctor.sh          # print report
#   bash scripts/doctor.sh --json   # machine-readable output
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more hard failures (required tool missing, repo not valid)
#   2 — soft issues only (deployment drifted, non-critical warning)

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
MANIFEST="${CLAUDE_DIR}/backups/ces/manifest.json"
SETTINGS="${CLAUDE_DIR}/settings.json"
REF_SETTINGS="${REPO_DIR}/global/settings.json"

JSON=false
[[ "${1-}" == "--json" ]] && JSON=true

HARD_FAILS=0
SOFT_FAILS=0
declare -a CHECKS

add_check() {
    local status="$1" name="$2" detail="$3"
    CHECKS+=("${status}|${name}|${detail}")
    case "$status" in
        FAIL) HARD_FAILS=$((HARD_FAILS + 1)) ;;
        WARN) SOFT_FAILS=$((SOFT_FAILS + 1)) ;;
    esac
}

# ── 1. Required tools ────────────────────────────────────────────────────────
for tool in bash git python3 sha256sum; do
    if command -v "$tool" &>/dev/null; then
        add_check "OK" "tool:${tool}" "$(command -v "$tool")"
    else
        add_check "FAIL" "tool:${tool}" "not found in PATH"
    fi
done

if command -v jq &>/dev/null; then
    add_check "OK" "tool:jq" "$(command -v jq) (optional, used by CI tests)"
else
    add_check "WARN" "tool:jq" "not found (optional)"
fi

# ── 2. Repository shape ──────────────────────────────────────────────────────
for p in global/CLAUDE.md global/settings.json scripts/setup.sh hooks/secret-scan.py; do
    if [[ -f "${REPO_DIR}/${p}" ]]; then
        add_check "OK" "repo:${p}" "present"
    else
        add_check "FAIL" "repo:${p}" "missing — not a valid repository checkout"
    fi
done

agents_count=$(ls "${REPO_DIR}/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
if [[ "$agents_count" -gt 0 ]]; then
    add_check "OK" "repo:agents" "${agents_count} agent file(s)"
else
    add_check "FAIL" "repo:agents" "no agent files found"
fi

commands_count=$(ls "${REPO_DIR}/.claude/commands/"*.md 2>/dev/null | wc -l | tr -d ' ')
if [[ "$commands_count" -gt 0 ]]; then
    add_check "OK" "repo:commands" "${commands_count} skill file(s)"
else
    add_check "WARN" "repo:commands" "no skill files found"
fi

# ── 3. Claude Code environment ───────────────────────────────────────────────
if [[ -d "${CLAUDE_DIR}" ]]; then
    add_check "OK" "env:~/.claude" "exists"
else
    add_check "FAIL" "env:~/.claude" "not found — install Claude Code first"
fi

if command -v claude &>/dev/null; then
    version=$(claude --version 2>/dev/null | head -n1 || echo "unknown")
    add_check "OK" "env:claude" "${version}"
else
    add_check "WARN" "env:claude" "'claude' CLI not in PATH"
fi

# ── 4. Deployment state ──────────────────────────────────────────────────────
if [[ -f "${MANIFEST}" ]]; then
    managed_count=$(python3 -c 'import json; print(len(json.load(open("'"${MANIFEST}"'")).get("managed", [])))' 2>/dev/null || echo 0)
    add_check "OK" "deploy:manifest" "${managed_count} managed file(s)"

    # Drift check: every managed file should match its source checksum
    drifted=0
    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        [[ -f "$f" ]] || { drifted=$((drifted + 1)); continue; }
        case "$f" in
            "${CLAUDE_DIR}/CLAUDE.md")
                src="${REPO_DIR}/global/CLAUDE.md" ;;
            "${CLAUDE_DIR}/agents/"*)
                src="${REPO_DIR}/agents/$(basename "$f")" ;;
            "${CLAUDE_DIR}/commands/"*)
                src="${REPO_DIR}/.claude/commands/$(basename "$f")" ;;
            "${CLAUDE_DIR}/hooks/"*)
                src="${REPO_DIR}/hooks/$(basename "$f")" ;;
            *) continue ;;
        esac
        [[ -f "$src" ]] || continue
        if [[ "$(sha256sum "$src" | cut -d' ' -f1)" != "$(sha256sum "$f" | cut -d' ' -f1)" ]]; then
            drifted=$((drifted + 1))
        fi
    done < <(python3 -c '
import json
for p in json.load(open("'"${MANIFEST}"'")).get("managed", []): print(p)
' 2>/dev/null)
    if [[ "$drifted" -eq 0 ]]; then
        add_check "OK" "deploy:drift" "deployment matches sources"
    else
        add_check "WARN" "deploy:drift" "${drifted} file(s) drifted — run setup.sh"
    fi
else
    add_check "WARN" "deploy:manifest" "no manifest — run scripts/setup.sh"
fi

# ── 5. settings.json integrity ───────────────────────────────────────────────
if [[ -f "${SETTINGS}" ]]; then
    if python3 -c 'import json; json.load(open("'"${SETTINGS}"'"))' 2>/dev/null; then
        add_check "OK" "settings:json" "parses"
    else
        add_check "FAIL" "settings:json" "invalid JSON"
    fi
    if [[ -f "${REF_SETTINGS}" ]]; then
        missing=$(python3 - "${SETTINGS}" "${REF_SETTINGS}" <<'PY' 2>/dev/null
import json, sys
try: cur = json.load(open(sys.argv[1]))
except: cur = {}
ref = json.load(open(sys.argv[2]))
ca = set(cur.get("permissions", {}).get("allow", []))
ra = set(ref.get("permissions", {}).get("allow", []))
print(len(ra - ca))
PY
)
        if [[ "${missing:-0}" -eq 0 ]]; then
            add_check "OK" "settings:perms" "all reference permissions present"
        else
            add_check "WARN" "settings:perms" "${missing} reference permission(s) missing"
        fi
    fi
else
    add_check "WARN" "settings:json" "no settings.json — run setup.sh"
fi

# ── 6. Hook executability ────────────────────────────────────────────────────
if [[ -f "${CLAUDE_DIR}/hooks/secret-scan.py" ]]; then
    if python3 -c 'compile(open("'"${CLAUDE_DIR}"'/hooks/secret-scan.py").read(), "secret-scan.py", "exec")' 2>/dev/null; then
        add_check "OK" "hook:secret-scan" "compiles"
    else
        add_check "FAIL" "hook:secret-scan" "syntax error"
    fi
else
    add_check "WARN" "hook:secret-scan" "not deployed"
fi

# ── Report ───────────────────────────────────────────────────────────────────
if [[ "$JSON" == "true" ]]; then
    python3 - <<PY
import json
checks = []
for line in """${CHECKS[@]+${CHECKS[@]}}""".split("\n"):
    if not line.strip(): continue
    s, n, d = line.split("|", 2)
    checks.append({"status": s, "name": n, "detail": d})
print(json.dumps({"hard_failures": ${HARD_FAILS}, "soft_failures": ${SOFT_FAILS}, "checks": checks}, indent=2))
PY
else
    echo "[doctor] Claude Engineering System health check"
    echo "[doctor] repo: ${REPO_DIR}"
    echo "[doctor] target: ${CLAUDE_DIR}"
    echo
    for row in "${CHECKS[@]}"; do
        status="${row%%|*}"
        rest="${row#*|}"
        name="${rest%%|*}"
        detail="${rest#*|}"
        printf "  [%-4s] %-24s %s\n" "$status" "$name" "$detail"
    done
    echo
    if [[ "$HARD_FAILS" -eq 0 && "$SOFT_FAILS" -eq 0 ]]; then
        echo "[doctor] All checks passed."
    elif [[ "$HARD_FAILS" -eq 0 ]]; then
        echo "[doctor] ${SOFT_FAILS} soft issue(s). System is usable; consider addressing warnings."
    else
        echo "[doctor] ${HARD_FAILS} hard failure(s), ${SOFT_FAILS} warning(s). Fix hard failures before using the system."
    fi
fi

if [[ "$HARD_FAILS" -gt 0 ]]; then
    exit 1
elif [[ "$SOFT_FAILS" -gt 0 ]]; then
    exit 2
fi
exit 0
