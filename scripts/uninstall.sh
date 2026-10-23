#!/usr/bin/env bash
# uninstall.sh — Reverse what setup.sh deployed to ~/.claude/
#
# Usage:
#   bash scripts/uninstall.sh            # interactive confirmation
#   bash scripts/uninstall.sh --dry-run  # show what would be removed
#   bash scripts/uninstall.sh --yes      # skip confirmation
#   bash scripts/uninstall.sh --restore  # restore the most recent backup for each managed file
#
# Strategy:
#   1. Read ~/.claude/backups/ces/manifest.json (list of managed files).
#   2. For each managed file:
#        - with --restore: copy the most recent backup back in place.
#        - otherwise: delete the file.
#   3. Remove the permissions and hook entries that global/settings.json contributed
#      to ~/.claude/settings.json. Leave user-added entries alone.
#   4. Leave ~/.claude/backups/ces/ in place so the user can always roll back manually.
#
# Does NOT touch:
#   - the user's own theme, model, custom permissions, or custom hooks in settings.json
#   - ~/.claude/backups/
#   - anything outside the manifest

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${HOME}/.claude"
BACKUP_DIR="${CLAUDE_DIR}/backups/ces"
MANIFEST="${BACKUP_DIR}/manifest.json"
SETTINGS="${CLAUDE_DIR}/settings.json"
REF_SETTINGS="${REPO_DIR}/global/settings.json"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

DRY_RUN=false
ASSUME_YES=false
RESTORE=false

log()  { echo "[uninstall] $*"; }
warn() { echo "[uninstall] WARN: $*" >&2; }
err()  { echo "[uninstall] ERROR: $*" >&2; exit 1; }

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --yes|-y)  ASSUME_YES=true ;;
        --restore) RESTORE=true ;;
        --help|-h)
            sed -n '1,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) warn "Unknown argument: $arg" ;;
    esac
done

[[ -d "${CLAUDE_DIR}" ]] || err "~/.claude/ not found — nothing to uninstall."
[[ -f "${MANIFEST}" ]] || err "No manifest at ${MANIFEST}. Run setup.sh first or remove files manually."
command -v python3 &>/dev/null || err "python3 is required."

MANAGED=$(python3 -c '
import json, sys
with open("'"${MANIFEST}"'") as f: m = json.load(f)
for p in m.get("managed", []): print(p)
')

if [[ -z "${MANAGED}" ]]; then
    log "Manifest is empty — nothing to uninstall."
    exit 0
fi

log "Repository:  ${REPO_DIR}"
log "Target:      ${CLAUDE_DIR}"
log "Mode:        $([[ "$DRY_RUN" == "true" ]] && echo dry-run || echo apply)$([[ "$RESTORE" == "true" ]] && echo " (restore)" || echo "")"
echo

log "Managed files:"
while IFS= read -r f; do
    echo "    $f"
done <<< "${MANAGED}"
echo

if [[ "$DRY_RUN" == "false" && "$ASSUME_YES" == "false" ]]; then
    read -r -p "[uninstall] Proceed? [y/N] " answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) log "Aborted."; exit 0 ;;
    esac
fi

# ── Remove or restore managed files ───────────────────────────────────────────
removed=0
restored=0
missing=0

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ "$RESTORE" == "true" ]]; then
        # Find the most recent backup for this file across all category dirs.
        base="$(basename "$file")"
        latest="$(find "${BACKUP_DIR}" -type f -name "${base}.*" 2>/dev/null | sort | tail -n1 || true)"
        if [[ -z "${latest}" ]]; then
            warn "No backup found for ${file}, skipping"
            missing=$((missing + 1))
            continue
        fi
        if [[ "$DRY_RUN" == "true" ]]; then
            log "  would restore: ${file}  ←  $(basename "${latest}")"
        else
            cp "${latest}" "${file}"
            log "  restored: ${file}"
            restored=$((restored + 1))
        fi
    else
        if [[ ! -f "$file" ]]; then
            missing=$((missing + 1))
            continue
        fi
        if [[ "$DRY_RUN" == "true" ]]; then
            log "  would remove: ${file}"
        else
            rm -f "${file}"
            log "  removed:  ${file}"
            removed=$((removed + 1))
        fi
    fi
done <<< "${MANAGED}"
echo

# ── Clean settings.json ───────────────────────────────────────────────────────
if [[ -f "${SETTINGS}" && -f "${REF_SETTINGS}" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        log "would clean permissions and hooks contributed by global/settings.json"
    else
        # Backup before mutating.
        mkdir -p "${BACKUP_DIR}/settings"
        cp "${SETTINGS}" "${BACKUP_DIR}/settings/settings.json.uninstall.${TIMESTAMP}"
        python3 - "${SETTINGS}" "${REF_SETTINGS}" <<'PY'
import json, sys

settings_path, ref_path = sys.argv[1], sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)
with open(ref_path) as f:
    ref = json.load(f)

# Remove permissions.allow entries that the reference contributed.
ref_allow = set(ref.get("permissions", {}).get("allow", []))
cur_allow = settings.get("permissions", {}).get("allow", [])
new_allow = [p for p in cur_allow if p not in ref_allow]
if "permissions" in settings:
    if new_allow:
        settings["permissions"]["allow"] = new_allow
    else:
        settings["permissions"].pop("allow", None)
    if not settings["permissions"]:
        settings.pop("permissions")

# Remove hook entries whose command came from the reference.
ref_cmds = {
    h.get("command", "")
    for groups in ref.get("hooks", {}).values()
    for g in groups
    for h in g.get("hooks", [])
}
cur_hooks = settings.get("hooks", {})
for event, groups in list(cur_hooks.items()):
    new_groups = []
    for g in groups:
        new_h = [h for h in g.get("hooks", []) if h.get("command", "") not in ref_cmds]
        if new_h:
            entry = dict(g)
            entry["hooks"] = new_h
            new_groups.append(entry)
    if new_groups:
        cur_hooks[event] = new_groups
    else:
        cur_hooks.pop(event)
if cur_hooks:
    settings["hooks"] = cur_hooks
else:
    settings.pop("hooks", None)

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print("[uninstall]   cleaned permissions and hook entries from settings.json")
PY
    fi
fi
echo

# ── Clear the manifest ────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "false" ]]; then
    echo '{"managed":[]}' > "${MANIFEST}"
    log "manifest cleared: ${MANIFEST}"
fi
echo

if [[ "$DRY_RUN" == "true" ]]; then
    log "Dry run complete. Re-run without --dry-run to apply."
else
    log "Uninstall complete."
    log "  removed:  ${removed} files"
    log "  restored: ${restored} files"
    log "  missing:  ${missing} files (not present when uninstall ran)"
    log "  backups kept at: ${BACKUP_DIR}/"
fi
