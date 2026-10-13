# Hooks

Claude Code hooks execute shell commands at lifecycle events. This directory documents the hooks design for this system.

## Status

| Hook | Status | Notes |
|------|--------|-------|
| pre-bash.sh | DESIGNED, NOT DEPLOYED | Format validated; not yet added to settings.json |
| Secret scanner | NOT IMPLEMENTED | Requires `gitleaks` or `detect-secrets` |

## Lifecycle events

| Event | When | Use case |
|-------|------|----------|
| `PreToolUse` | Before Claude calls a tool | Validate command safety |
| `PostToolUse` | After Claude calls a tool | Log results, check output |
| `Stop` | When Claude finishes a response | Remind of pending validations |
| `SubagentStop` | When a subagent completes | Aggregate results |

## Settings format

Hooks are configured in `settings.json` (user or project level):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/pre-bash.sh"
          }
        ]
      }
    ]
  }
}
```

## Planned hooks

### pre-bash.sh — Secret leak guard

Intercepts `git commit` commands and scans the staged diff for credential patterns before the commit proceeds.

**Trigger**: `PreToolUse` on `Bash` tool
**Pattern detected**: commands containing `git commit`
**Action**: Run `git diff --cached` and grep for common credential patterns

```bash
#!/bin/bash
# pre-bash.sh — called before every Bash tool execution
# Warns if a git commit command would commit credential-like content

COMMAND="$1"

# Only act on git commit commands
if [[ "$COMMAND" != *"git commit"* ]]; then
    exit 0
fi

# Scan staged diff for credential patterns
STAGED_DIFF=$(git diff --cached 2>/dev/null)
if echo "$STAGED_DIFF" | grep -qiE '(password|secret|token|api_key|private_key)\s*=\s*["\x27][^"\x27]{8,}'; then
    echo "WARNING: Staged diff may contain credentials. Review with: git diff --cached"
    echo "Hook: pre-bash.sh"
fi

exit 0  # Non-blocking: warn only, do not prevent commit
```

**Why non-blocking**: A blocking hook that fires incorrectly will be disabled. Start with warnings; escalate to blocking only after false-positive rate is measured.

## Deployment

Hooks are NOT automatically deployed. To enable:

1. Verify `pre-bash.sh` produces no false positives on a known-safe commit
2. Copy to `~/.claude/hooks/pre-bash.sh`
3. Make executable: `chmod +x ~/.claude/hooks/pre-bash.sh`
4. Add hook config to `~/.claude/settings.json`
5. Test on a real session

## WSL2 considerations

Claude Code on WSL2 runs as a Windows binary (`claude.exe`). Hooks may run in:
- The WSL2 bash/fish shell (if Claude was launched from WSL2 terminal)
- The Windows environment (if launched from Windows)

**NOT VERIFIED**: Which shell context hooks execute in when using the Windows binary alias. Test before deploying.

## Known limitations

- Hook commands receive limited context about the tool call (exact environment variables depend on Claude Code version)
- Slow hooks block Claude Code. Keep hook scripts under 500ms.
- Recursive hooks (a hook that triggers Claude which triggers a hook) are a risk — avoid hooks that execute Claude commands.
