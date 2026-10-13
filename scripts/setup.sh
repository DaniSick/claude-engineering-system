#!/bin/bash
# setup.sh — Deploy claude-engineering-system config to ~/.claude/
# Run from the repository root: bash scripts/setup.sh
# Safe to re-run: creates backups before overwriting.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_SUFFIX=".backup.$(date +%s)"

log() { echo "[setup] $*"; }
warn() { echo "[setup] WARNING: $*" >&2; }
backup_if_exists() {
    local target="$1"
    if [[ -f "$target" ]]; then
        cp "$target" "${target}${BACKUP_SUFFIX}"
        log "Backed up: ${target} → ${target}${BACKUP_SUFFIX}"
    fi
}

# Verify we're in the right repo
if [[ ! -f "$REPO_DIR/global/CLAUDE.md" ]]; then
    echo "ERROR: Run from claude-engineering-system repo root"
    exit 1
fi

log "Repository: $REPO_DIR"
log "Target: $CLAUDE_DIR"
echo

# 1. Deploy global CLAUDE.md
log "Deploying global CLAUDE.md..."
backup_if_exists "$CLAUDE_DIR/CLAUDE.md"
cp "$REPO_DIR/global/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
log "OK: $CLAUDE_DIR/CLAUDE.md"

# 2. Deploy agents
log "Deploying agents..."
mkdir -p "$CLAUDE_DIR/agents"
for agent_file in "$REPO_DIR/agents/"*.md; do
    [[ -f "$agent_file" ]] || continue
    filename="$(basename "$agent_file")"
    target="$CLAUDE_DIR/agents/$filename"
    backup_if_exists "$target"
    cp "$agent_file" "$target"
    log "OK: $target"
done

# 3. Deploy hooks (if any)
if [[ -d "$REPO_DIR/hooks" ]]; then
    log "Deploying hooks..."
    mkdir -p "$CLAUDE_DIR/hooks"
    for hook_file in "$REPO_DIR/hooks/"*.sh; do
        [[ -f "$hook_file" ]] || continue
        filename="$(basename "$hook_file")"
        target="$CLAUDE_DIR/hooks/$filename"
        backup_if_exists "$target"
        cp "$hook_file" "$target"
        chmod +x "$target"
        log "OK: $target (executable)"
    done
fi

# 4. Update settings.json — replace permissions.allow with reference list
# User preferences (theme, model, etc.) are preserved.
# permissions.allow is replaced entirely so removed entries are also removed.
SETTINGS="$CLAUDE_DIR/settings.json"
REF_SETTINGS="$REPO_DIR/global/settings.json"

if command -v python3 &>/dev/null; then
    log "Updating permissions allowlist in $SETTINGS..."
    python3 - "$SETTINGS" "$REF_SETTINGS" <<'PYEOF'
import json, sys

settings_path = sys.argv[1]
ref_path = sys.argv[2]

# Read current settings (or empty object)
try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

# Read reference settings
with open(ref_path) as f:
    ref = json.load(f)

# Replace permissions.allow with the reference list (authoritative)
# Tech-specific permissions belong in project-level .claude/settings.json
ref_allow = sorted(ref.get("permissions", {}).get("allow", []))

if "permissions" not in settings:
    settings["permissions"] = {}
settings["permissions"]["allow"] = ref_allow

# Write back
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print(f"[setup] Set {len(ref_allow)} permissions in settings.json")
PYEOF
else
    warn "python3 not available. Skipping settings.json update. Copy permissions manually from $REF_SETTINGS"
fi

echo
log "Setup complete."
echo
echo "Verify:"
echo "  cat $CLAUDE_DIR/CLAUDE.md | head -5"
echo "  ls $CLAUDE_DIR/agents/"
echo "  cat $CLAUDE_DIR/settings.json | python3 -m json.tool"
