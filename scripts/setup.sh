#!/usr/bin/env bash
# setup.sh — Deploy claude-engineering-system to ~/.claude/
#
# Usage:
#   bash scripts/setup.sh          # deploy all components
#   bash scripts/setup.sh --verify # verify deployment without changes
#   bash scripts/setup.sh --help   # show usage
#
# Idempotent: skips files that have not changed (checksum comparison).
# Backups: stored in ~/.claude/backups/ces/ with timestamps.
# Manifest: ~/.claude/backups/ces/manifest.json tracks managed files.
# Preserves: theme, model, and any settings keys not managed by this system.

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
BACKUP_DIR="${CLAUDE_DIR}/backups/ces"
MANIFEST="${BACKUP_DIR}/manifest.json"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
VERIFY_ONLY=false
CHANGED=0
SKIPPED=0
BACKED_UP=0

# ── Helpers ───────────────────────────────────────────────────────────────────

log()  { echo "[setup] $*"; }
warn() { echo "[setup] WARN: $*" >&2; }
err()  { echo "[setup] ERROR: $*" >&2; exit 1; }

checksum() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

backup_file() {
    local src="$1"
    local category="$2"    # agents / root / commands / settings
    [[ -f "$src" ]] || return 0

    local filename
    filename="$(basename "$src")"
    local dest="${BACKUP_DIR}/${category}/${filename}.${TIMESTAMP}"
    mkdir -p "${BACKUP_DIR}/${category}"
    cp "$src" "$dest"
    BACKED_UP=$((BACKED_UP + 1))
    log "  backed up → backups/ces/${category}/${filename}.${TIMESTAMP}"
}

# Deploy a single file: skip if identical, backup and replace if different.
deploy_file() {
    local src="$1"
    local dst="$2"
    local category="$3"

    [[ -f "$src" ]] || { warn "Source not found: $src"; return 1; }

    if [[ "$VERIFY_ONLY" == "true" ]]; then
        if [[ ! -f "$dst" ]]; then
            log "  MISSING: $dst"
        elif [[ "$(checksum "$src")" != "$(checksum "$dst")" ]]; then
            log "  DIFFERS: $dst"
        else
            log "  OK:      $dst"
        fi
        return 0
    fi

    mkdir -p "$(dirname "$dst")"

    if [[ -f "$dst" ]] && [[ "$(checksum "$src")" == "$(checksum "$dst")" ]]; then
        log "  unchanged: $(basename "$dst")"
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    backup_file "$dst" "$category"
    cp "$src" "$dst"
    log "  deployed: $(basename "$dst")"
    CHANGED=$((CHANGED + 1))

    # Record in manifest
    record_manifest "$dst"
}

record_manifest() {
    local path="$1"
    [[ -f "$MANIFEST" ]] || echo '{"managed":[]}' > "$MANIFEST"
    python3 - "$MANIFEST" "$path" <<'PY' 2>/dev/null || true
import json, sys
m_path, file_path = sys.argv[1], sys.argv[2]
with open(m_path) as f:
    m = json.load(f)
if file_path not in m.get("managed", []):
    m.setdefault("managed", []).append(file_path)
with open(m_path, "w") as f:
    json.dump(m, f, indent=2)
PY
}

# ── Argument parsing ──────────────────────────────────────────────────────────

for arg in "$@"; do
    case "$arg" in
        --verify) VERIFY_ONLY=true ;;
        --help)
            echo "Usage: bash scripts/setup.sh [--verify] [--help]"
            echo "  --verify   check deployment status without making changes"
            echo "  --help     show this help"
            exit 0 ;;
        *) warn "Unknown argument: $arg" ;;
    esac
done

# ── Preflight ─────────────────────────────────────────────────────────────────

[[ -f "${REPO_DIR}/global/CLAUDE.md" ]] || err "Not a claude-engineering-system repo: ${REPO_DIR}"
[[ -d "${CLAUDE_DIR}" ]] || err "~/.claude/ not found. Is Claude Code installed?"
command -v python3 &>/dev/null || err "python3 is required for settings merge"

log "Repository:  ${REPO_DIR}"
log "Target:      ${CLAUDE_DIR}"
log "Mode:        $([[ "$VERIFY_ONLY" == "true" ]] && echo verify || echo deploy)"
echo

mkdir -p "${BACKUP_DIR}"

# ── 1. Global CLAUDE.md ───────────────────────────────────────────────────────

log "1. Global CLAUDE.md"
deploy_file \
    "${REPO_DIR}/global/CLAUDE.md" \
    "${CLAUDE_DIR}/CLAUDE.md" \
    "root"
echo

# ── 2. Agents ────────────────────────────────────────────────────────────────

log "2. Agents  (${CLAUDE_DIR}/agents/)"
[[ "$VERIFY_ONLY" == "false" ]] && mkdir -p "${CLAUDE_DIR}/agents"
for src in "${REPO_DIR}/agents/"*.md; do
    [[ -f "$src" ]] || continue
    filename="$(basename "$src")"
    deploy_file "$src" "${CLAUDE_DIR}/agents/${filename}" "agents"
done
echo

# ── 3. Commands (global) ─────────────────────────────────────────────────────
# ~/.claude/commands/ is the global equivalent of .claude/commands/ in a project.
# STATUS: Not yet confirmed in official docs for 2.1.87.
# The files are deployed here; verify by checking if they appear as skills
# in a session started outside this repository.

log "3. Commands  (${CLAUDE_DIR}/commands/)  [global — see verification note]"
[[ "$VERIFY_ONLY" == "false" ]] && mkdir -p "${CLAUDE_DIR}/commands"
for src in "${REPO_DIR}/.claude/commands/"*.md; do
    [[ -f "$src" ]] || continue
    filename="$(basename "$src")"
    deploy_file "$src" "${CLAUDE_DIR}/commands/${filename}" "commands"
done
echo

# ── 4. Hook scripts ──────────────────────────────────────────────────────────

log "4. Hooks  (${CLAUDE_DIR}/hooks/)"
hook_count=0
[[ "$VERIFY_ONLY" == "false" ]] && mkdir -p "${CLAUDE_DIR}/hooks"
for src in "${REPO_DIR}/hooks/"*.sh "${REPO_DIR}/hooks/"*.py; do
    [[ -f "$src" ]] || continue
    hook_count=$((hook_count + 1))
    filename="$(basename "$src")"
    deploy_file "$src" "${CLAUDE_DIR}/hooks/${filename}" "hooks"
    if [[ "$VERIFY_ONLY" == "false" && "$src" == *.sh ]]; then
        chmod +x "${CLAUDE_DIR}/hooks/${filename}"
    fi
done
[[ $hook_count -eq 0 ]] && log "  (no hook scripts found in hooks/)"
echo

# ── 5. settings.json — safe merge ────────────────────────────────────────────
# Merges ONLY the permissions.allow list from global/settings.json.
# All other settings keys (theme, model, hooks, MCP, etc.) are left untouched.
# Adds entries present in the reference; removes entries present in the reference
# that were previously managed (tracked in manifest). Does NOT remove manual entries.

log "5. settings.json  (permissions + hooks merge)"

SETTINGS="${CLAUDE_DIR}/settings.json"
REF_SETTINGS="${REPO_DIR}/global/settings.json"

if [[ "$VERIFY_ONLY" == "true" ]]; then
    python3 - "$SETTINGS" "$REF_SETTINGS" <<'PY'
import json, sys
try:
    with open(sys.argv[1]) as f: current = json.load(f)
except: current = {}
with open(sys.argv[2]) as f: ref = json.load(f)

# Check permissions
cur_allow = set(current.get("permissions", {}).get("allow", []))
ref_allow = set(ref.get("permissions", {}).get("allow", []))
missing = ref_allow - cur_allow
if not missing:
    print("[setup]   OK: permissions.allow matches reference")
else:
    print(f"[setup]   MISSING from allow: {sorted(missing)}")

# Check hooks
ref_hooks = ref.get("hooks", {})
if ref_hooks:
    existing_cmds = set()
    for groups in current.get("hooks", {}).values():
        for g in groups:
            for h in g.get("hooks", []):
                existing_cmds.add(h.get("command", ""))
    missing_hooks = [
        h.get("command", "")
        for groups in ref_hooks.values()
        for g in groups
        for h in g.get("hooks", [])
        if h.get("command", "") not in existing_cmds
    ]
    if not missing_hooks:
        print("[setup]   OK: hooks config present")
    else:
        for cmd in missing_hooks:
            print(f"[setup]   MISSING hook: {cmd}")
PY
else
    python3 - "$SETTINGS" "$REF_SETTINGS" "$BACKUP_DIR" "$TIMESTAMP" <<'PY'
import json, sys, os, shutil

settings_path, ref_path, backup_dir, ts = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

with open(ref_path) as f:
    ref = json.load(f)

changed = False

# ── Merge permissions.allow (additive) ───────────────────────────────────────
ref_allow = set(ref.get("permissions", {}).get("allow", []))
cur_allow = set(settings.get("permissions", {}).get("allow", []))
merged = sorted(cur_allow | ref_allow)
added_perms = ref_allow - cur_allow
if added_perms:
    if "permissions" not in settings:
        settings["permissions"] = {}
    settings["permissions"]["allow"] = merged
    changed = True

# ── Merge hooks (additive: add missing hooks, never remove) ──────────────────
ref_hooks = ref.get("hooks", {})
added_hooks = []
if ref_hooks:
    existing_cmds = set()
    cur_hooks = settings.get("hooks", {})
    for groups in cur_hooks.values():
        for g in groups:
            for h in g.get("hooks", []):
                existing_cmds.add(h.get("command", ""))

    for event, ref_groups in ref_hooks.items():
        if event not in cur_hooks:
            cur_hooks[event] = []
        for ref_group in ref_groups:
            new_hooks = [
                h for h in ref_group.get("hooks", [])
                if h.get("command", "") not in existing_cmds
            ]
            if new_hooks:
                entry = dict(ref_group)
                entry["hooks"] = new_hooks
                cur_hooks[event].append(entry)
                for h in new_hooks:
                    added_hooks.append(h.get("command", ""))
                    existing_cmds.add(h.get("command", ""))
    if added_hooks:
        settings["hooks"] = cur_hooks
        changed = True

if not changed:
    print("[setup]   unchanged: settings.json")
    sys.exit(0)

# Backup before writing
bk_dir = os.path.join(backup_dir, "settings")
os.makedirs(bk_dir, exist_ok=True)
shutil.copy2(settings_path, os.path.join(bk_dir, f"settings.json.{ts}"))
print(f"[setup]   backed up → backups/ces/settings/settings.json.{ts}")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

if added_perms:
    print(f"[setup]   added {len(added_perms)} permission(s), total {len(merged)}")
    for p in sorted(added_perms):
        print(f"[setup]     + {p}")
if added_hooks:
    print(f"[setup]   added {len(added_hooks)} hook(s)")
    for h in added_hooks:
        print(f"[setup]     + {h}")
PY
fi
echo

# ── Summary ───────────────────────────────────────────────────────────────────

if [[ "$VERIFY_ONLY" == "true" ]]; then
    log "Verification complete."
else
    log "Deployment complete."
    log "  deployed: ${CHANGED} files"
    log "  skipped:  ${SKIPPED} files (unchanged)"
    log "  backups:  ${BACKED_UP} files → ${BACKUP_DIR}/"
    echo
    log "Verify the deployment:"
    echo "  bash scripts/setup.sh --verify"
    echo "  head -3 ${CLAUDE_DIR}/CLAUDE.md"
    echo "  ls ${CLAUDE_DIR}/agents/"
    echo "  ls ${CLAUDE_DIR}/commands/"
fi
