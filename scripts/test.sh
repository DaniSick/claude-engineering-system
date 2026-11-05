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

# ── 7. Cross-reference validation ────────────────────────────────────────────

echo "7. Cross-reference validation"

# 7a — Build known agent name index from agents/*.md frontmatter
agent_names=()
for f in "${REPO_DIR}/agents/"*.md; do
    [[ -f "$f" ]] || continue
    name=$(grep -m1 '^name:' "$f" | sed 's/^name:[[:space:]]*//' | tr -d '\r\n')
    [[ -n "$name" ]] && agent_names+=("$name")
done

if [[ ${#agent_names[@]} -eq 0 ]]; then
    fail "agent-index" "no agent files found in agents/"
else
    pass "agent-index: ${#agent_names[@]} agents indexed"

    # check_refs FILE
    # Prints each @name that has no matching agents/<name>.md. Returns 1 if any.
    check_refs() {
        local file="$1" refs any_bad=0
        refs=$(grep -oE '@[a-z][a-z0-9-]+' "$file" 2>/dev/null \
              | sed 's/^@//' | sort -u || true)
        [[ -z "$refs" ]] && return 0
        while IFS= read -r ref; do
            [[ -z "$ref" ]] && continue
            local found=0
            for known in "${agent_names[@]}"; do
                [[ "$known" == "$ref" ]] && { found=1; break; }
            done
            [[ $found -eq 0 ]] && { printf '%s\n' "$ref"; any_bad=1; }
        done <<< "$refs"
        return $any_bad
    }

    # 7b — Validate @agent references in command files and global CLAUDE.md
    xref_ok=1
    for f in "${REPO_DIR}/.claude/commands/"*.md "${REPO_DIR}/global/CLAUDE.md"; do
        [[ -f "$f" ]] || continue
        bad=$(check_refs "$f") || true
        if [[ -n "$bad" ]]; then
            while IFS= read -r ref; do
                [[ -n "$ref" ]] || continue
                fail "agent-xref" "@${ref} in $(basename "$f") — no matching agents/${ref}.md"
            done <<< "$bad"
            xref_ok=0
        fi
    done
    [[ $xref_ok -eq 1 ]] && pass "agent-xref: all @agent references resolve"

    # 7c — Build command name index from .claude/commands/*.md filenames
    cmd_names=()
    for f in "${REPO_DIR}/.claude/commands/"*.md; do
        [[ -f "$f" ]] || continue
        stem="${f%.md}"; stem="${stem##*/}"
        [[ -n "$stem" ]] && cmd_names+=("$stem")
    done

    if [[ ${#cmd_names[@]} -eq 0 ]]; then
        fail "cmd-index" "no command files found in .claude/commands/"
    else
        pass "cmd-index: ${#cmd_names[@]} commands indexed"

        # check_cmds FILE
        # Scope: backtick-quoted /command only (pattern: ` immediately before /).
        # Unquoted prose /command is not matched — all harness /command refs use backtick format.
        check_cmds() {
            local file="$1" refs any_bad=0
            refs=$(grep -oE '`/[a-z][a-z0-9-]+' "$file" 2>/dev/null \
                  | sed 's|`/||' | sort -u || true)
            [[ -z "$refs" ]] && return 0
            while IFS= read -r ref; do
                [[ -z "$ref" ]] && continue
                local found=0
                for known in "${cmd_names[@]}"; do
                    [[ "$known" == "$ref" ]] && { found=1; break; }
                done
                [[ $found -eq 0 ]] && { printf '%s\n' "$ref"; any_bad=1; }
            done <<< "$refs"
            return $any_bad
        }

        # 7d — Validate /command references in global CLAUDE.md and command files
        cmd_xref_ok=1
        for f in "${REPO_DIR}/global/CLAUDE.md" "${REPO_DIR}/.claude/commands/"*.md; do
            [[ -f "$f" ]] || continue
            bad=$(check_cmds "$f") || true
            if [[ -n "$bad" ]]; then
                while IFS= read -r ref; do
                    [[ -n "$ref" ]] || continue
                    fail "cmd-xref" "/$ref in $(basename "$f") — no .claude/commands/${ref}.md"
                done <<< "$bad"
                cmd_xref_ok=0
            fi
        done
        [[ $cmd_xref_ok -eq 1 ]] && pass "cmd-xref: all /command references resolve"
    fi

    # 7e — Self-tests in $(…) subshell — EXIT trap isolated from outer script
    valid_agent=""
    for known in "${agent_names[@]}"; do
        [[ "$known" == "architect" ]] && { valid_agent="architect"; break; }
    done

    if [[ -z "$valid_agent" ]]; then
        fail "self-test/setup" "@architect not in agent index — cannot run fixture tests"
    else
        _st_exit=0
        _st_output=$(
            # Verify mktemp before installing trap or writing files
            tmpdir=$(mktemp -d) \
                || { echo "FAIL:mktemp:mktemp -d failed"; exit 1; }
            [[ -n "$tmpdir" && -d "$tmpdir" ]] \
                || { echo "FAIL:mktemp:tmpdir invalid: '${tmpdir}'"; exit 1; }
            trap 'rm -rf "$tmpdir"' EXIT

            valid_cmd="${cmd_names[0]:-}"

            # Agent fixtures — each write is explicitly guarded
            cat > "${tmpdir}/a-valid.md" << ENDFIXTURE || { echo "FAIL:fixture-write:a-valid.md"; exit 1; }
Use @${valid_agent} for architecture analysis.
ENDFIXTURE
            cat > "${tmpdir}/a-invalid.md" << 'ENDFIXTURE' || { echo "FAIL:fixture-write:a-invalid.md"; exit 1; }
Use @phantom-agent for analysis.
ENDFIXTURE

            bad=$(check_refs "${tmpdir}/a-valid.md") || true
            [[ -n "$bad" ]] \
                && echo "FAIL:agent-valid:@${valid_agent} was falsely rejected" \
                || echo "PASS:agent-valid"

            bad=$(check_refs "${tmpdir}/a-invalid.md") || true
            [[ "$bad" == "phantom-agent" ]] \
                && echo "PASS:agent-invalid" \
                || echo "FAIL:agent-invalid:@phantom-agent not detected (got: '${bad}')"

            # Command fixtures — 5 cases covering scope boundaries; each write is explicitly guarded
            if [[ -n "$valid_cmd" ]]; then
                # 1. Backtick-quoted valid command — must resolve
                printf '`/%s` for this task.\n' "$valid_cmd" > "${tmpdir}/c-bt-valid.md" \
                    || { echo "FAIL:fixture-write:c-bt-valid.md"; exit 1; }
                # 2. Unquoted valid command — must NOT be extracted (scope: backtick-only)
                printf '/%s in prose\n' "$valid_cmd" > "${tmpdir}/c-nobt.md" \
                    || { echo "FAIL:fixture-write:c-nobt.md"; exit 1; }
                # 3. Backtick-quoted nonexistent command — must be detected
                printf '`/phantom-command` for this task.\n' > "${tmpdir}/c-bt-invalid.md" \
                    || { echo "FAIL:fixture-write:c-bt-invalid.md"; exit 1; }
                # 4. System path — must be ignored (no backtick prefix)
                printf '/bin/bash is the shell\n' > "${tmpdir}/c-syspath.md" \
                    || { echo "FAIL:fixture-write:c-syspath.md"; exit 1; }
                # 5. URL with valid command name in path — must be ignored (backtick not before /)
                printf '`https://example.com/%s` see docs\n' "$valid_cmd" > "${tmpdir}/c-url.md" \
                    || { echo "FAIL:fixture-write:c-url.md"; exit 1; }

                bad=$(check_cmds "${tmpdir}/c-bt-valid.md") || true
                [[ -n "$bad" ]] \
                    && echo "FAIL:cmd-bt-valid:/$valid_cmd in backtick falsely flagged" \
                    || echo "PASS:cmd-bt-valid"

                bad=$(check_cmds "${tmpdir}/c-nobt.md") || true
                [[ -n "$bad" ]] \
                    && echo "FAIL:cmd-nobt-scope:unquoted /$valid_cmd incorrectly matched: '$bad'" \
                    || echo "PASS:cmd-nobt-scope"

                bad=$(check_cmds "${tmpdir}/c-bt-invalid.md") || true
                [[ "$bad" == "phantom-command" ]] \
                    && echo "PASS:cmd-bt-invalid" \
                    || echo "FAIL:cmd-bt-invalid:/phantom-command not detected (got: '${bad}')"

                bad=$(check_cmds "${tmpdir}/c-syspath.md") || true
                [[ -n "$bad" ]] \
                    && echo "FAIL:cmd-syspath:/bin/bash incorrectly matched: '$bad'" \
                    || echo "PASS:cmd-syspath"

                bad=$(check_cmds "${tmpdir}/c-url.md") || true
                [[ -n "$bad" ]] \
                    && echo "FAIL:cmd-url:URL path incorrectly matched: '$bad'" \
                    || echo "PASS:cmd-url"
            else
                echo "FAIL:cmd-setup:no commands indexed — command fixture tests skipped"
            fi

            echo "DONE"
        ) || _st_exit=$?

        selftest_ok=1

        if [[ $_st_exit -ne 0 ]]; then
            fail "self-test/exit" "fixture subshell exited with code ${_st_exit}"
            selftest_ok=0
        fi

        if ! grep -q '^DONE$' <<< "$_st_output"; then
            fail "self-test/crash" "fixture subshell did not complete (no DONE marker)"
            selftest_ok=0
        fi

        while IFS= read -r line; do
            case "$line" in
                FAIL:*)
                    label="${line#FAIL:}"; label="${label%%:*}"
                    msg="${line#FAIL:${label}:}"
                    fail "self-test/${label}" "$msg"
                    selftest_ok=0
                    ;;
            esac
        done <<< "$_st_output"

        [[ $selftest_ok -eq 1 ]] && pass "self-test: all agent and command fixtures pass"
        unset _st_output _st_exit
    fi
fi
echo

# ── 8. Personal additions preservation ───────────────────────────────────────

echo "8. Personal additions preservation (deploy_claude_md logic)"

_pa_dir=$(mktemp -d)
trap '[[ -n "${_pa_dir:-}" ]] && rm -rf "$_pa_dir"' EXIT

# Build a fake deployed CLAUDE.md with real custom content in the personal block
cp "${REPO_DIR}/global/CLAUDE.md" "${_pa_dir}/CLAUDE.md"
python3 - "${_pa_dir}/CLAUDE.md" <<'PY'
import sys, re
path = sys.argv[1]
content = open(path).read()
replacement = (
    "<!-- CES:PERSONAL_START -->\n"
    "## Personal additions\n"
    "Response mode: ninja\n"
    "Custom rule: test fixture — do not remove\n"
    "<!-- CES:PERSONAL_END -->"
)
content = re.sub(r'<!-- CES:PERSONAL_START -->.*?<!-- CES:PERSONAL_END -->', replacement, content, flags=re.DOTALL)
open(path, 'w').write(content)
PY

# Step 1 — extraction: same logic as deploy_claude_md
personal_block=$(python3 - "${_pa_dir}/CLAUDE.md" <<'PY'
import sys, re
content = open(sys.argv[1]).read()
m = re.search(r'<!-- CES:PERSONAL_START -->.*?<!-- CES:PERSONAL_END -->', content, re.DOTALL)
if m:
    block = m.group(0)
    placeholder_lines = {
        '<!-- CES:PERSONAL_START -->', '## Personal additions',
        '_This section is preserved when you run `bash scripts/setup.sh`. Edit it freely — git pull + redeploy will never overwrite it._',
        'Suggested uses:',
        '- Set a default response mode (applies every session): `Response mode: ferb`',
        '- Add stack-specific rules, e.g. "This project uses Livewire; prefer wire:model over Alpine"',
        '- Override any principle above for your workflow',
        '<!-- CES:PERSONAL_END -->'
    }
    actual_lines = [l.strip() for l in block.splitlines() if l.strip() and l.strip() not in placeholder_lines]
    if actual_lines:
        print(block)
PY
)

if [[ "$personal_block" == *"Response mode: ninja"* ]]; then
    pass "personal-extract: custom content detected"
else
    fail "personal-extract" "custom content not found in extracted block"
fi

# Step 2 — injection: deploy a fresh CLAUDE.md, re-inject the block
cp "${REPO_DIR}/global/CLAUDE.md" "${_pa_dir}/fresh.md"
_pa_tmp=$(mktemp)
printf '%s' "$personal_block" > "$_pa_tmp"
python3 - "${_pa_dir}/fresh.md" "$_pa_tmp" <<'PY'
import sys, re
dst, block_path = sys.argv[1], sys.argv[2]
content = open(dst).read()
block = open(block_path).read()
content = re.sub(r'<!-- CES:PERSONAL_START -->.*?<!-- CES:PERSONAL_END -->', block, content, flags=re.DOTALL)
open(dst, 'w').write(content)
PY
rm -f "$_pa_tmp"

if grep -q "Response mode: ninja" "${_pa_dir}/fresh.md"; then
    pass "personal-inject: content survives redeploy"
else
    fail "personal-inject" "content not found after injection into fresh deploy"
fi

# Step 3 — placeholder-only content is NOT preserved (no user additions yet)
cp "${REPO_DIR}/global/CLAUDE.md" "${_pa_dir}/placeholder.md"
placeholder_block=$(python3 - "${_pa_dir}/placeholder.md" <<'PY'
import sys, re
content = open(sys.argv[1]).read()
m = re.search(r'<!-- CES:PERSONAL_START -->.*?<!-- CES:PERSONAL_END -->', content, re.DOTALL)
if m:
    block = m.group(0)
    placeholder_lines = {
        '<!-- CES:PERSONAL_START -->', '## Personal additions',
        '_This section is preserved when you run `bash scripts/setup.sh`. Edit it freely — git pull + redeploy will never overwrite it._',
        'Suggested uses:',
        '- Set a default response mode (applies every session): `Response mode: ferb`',
        '- Add stack-specific rules, e.g. "This project uses Livewire; prefer wire:model over Alpine"',
        '- Override any principle above for your workflow',
        '<!-- CES:PERSONAL_END -->'
    }
    actual_lines = [l.strip() for l in block.splitlines() if l.strip() and l.strip() not in placeholder_lines]
    if actual_lines:
        print(block)
PY
)

if [[ -z "$placeholder_block" ]]; then
    pass "personal-placeholder: unmodified placeholder not extracted"
else
    fail "personal-placeholder" "placeholder-only content incorrectly extracted"
fi

echo

# ── 9. Status line ───────────────────────────────────────────────────────────

echo "9. Status line (ces-statusline.sh)"
SL="${REPO_DIR}/statusline/ces-statusline.sh"

if [[ ! -f "$SL" ]]; then
    fail "statusline" "file not found"
else
    # Exit 0 on every input shape — a non-zero exit blanks the line entirely.
    sl_ok=1
    for inp in '' 'not json' '{}' '{"context_window":{"used_percentage":null}}' \
               '{"context_window":{"used_percentage":"abc"}}'; do
        err=$(printf '%s' "$inp" | bash "$SL" 2>&1 >/dev/null) || true
        code=$(printf '%s' "$inp" | bash "$SL" >/dev/null 2>&1; echo $?)
        if [[ "$code" != "0" ]]; then
            fail "statusline/exit" "non-zero exit (${code}) on input: ${inp:0:30}"
            sl_ok=0
        fi
        if [[ -n "$err" ]]; then
            fail "statusline/stderr" "wrote to stderr on input '${inp:0:30}': ${err:0:60}"
            sl_ok=0
        fi
    done
    [[ $sl_ok -eq 1 ]] && pass "degenerate inputs → exit 0, silent stderr"

    # The context bar must read context_window, not rate_limits — both carry a
    # key named used_percentage.
    out=$(echo '{"context_window":{"used_percentage":34},"rate_limits":{"five_hour":{"used_percentage":91}}}' \
          | NO_COLOR=1 bash "$SL" 2>/dev/null)
    if [[ "$out" == *"34%"* && "$out" != *"91%"* ]]; then
        pass "reads context_window, not rate_limits"
    else
        fail "statusline/collision" "expected 34%, not 91% — got: ${out}"
    fi

    # No subprocess spawning: the cost argument depends on this. `$((` is
    # arithmetic expansion and forks nothing, so only `$(` followed by a
    # non-paren counts. Comments are stripped first — they contain backticks.
    forks=$(sed 's/#.*//' "$SL" | grep -nE '\$\([^(]|`' || true)
    if [[ -n "$forks" ]]; then
        fail "statusline/forks" "command substitution found: ${forks%%$'\n'*}"
    else
        pass "no command substitution (no forks)"
    fi

    # Every named theme must render and exit 0, and an unknown one must fall
    # back rather than producing a broken line or an error.
    theme_ok=1
    for th in ghost ember matrix ice mono default __nonexistent__; do
        t_out=$(echo '{"model":{"display_name":"M"},"context_window":{"used_percentage":50}}' \
                | CES_THEME="$th" bash "$SL" 2>/dev/null) || true
        t_err=$(echo '{"model":{"display_name":"M"},"context_window":{"used_percentage":50}}' \
                | CES_THEME="$th" bash "$SL" 2>&1 >/dev/null) || true
        if [[ -z "$t_out" || "$t_out" != *"ces"* ]]; then
            fail "statusline/theme" "theme '${th}' produced no usable line"
            theme_ok=0
        fi
        if [[ -n "$t_err" ]]; then
            fail "statusline/theme" "theme '${th}' wrote to stderr: ${t_err:0:50}"
            theme_ok=0
        fi
    done
    [[ $theme_ok -eq 1 ]] && pass "all themes render; unknown theme falls back"

    # --themes must not read stdin: it is run interactively with a terminal
    # attached, where a blocking read would hang.
    if timeout 5 bash "$SL" --themes </dev/null >/dev/null 2>&1; then
        pass "--themes exits without blocking on stdin"
    else
        fail "statusline/themes-flag" "--themes hung or exited non-zero"
    fi

    # The deployed config must not carry refreshInterval, which would add timed
    # runs for data that only changes between turns.
    if python3 -c "
import json,sys
sl = json.load(open('${REPO_DIR}/global/settings.json')).get('statusLine', {})
sys.exit(0 if 'refreshInterval' not in sl else 1)
" 2>/dev/null; then
        pass "no refreshInterval (event-driven only)"
    else
        fail "statusline/interval" "refreshInterval set — adds periodic runs"
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
