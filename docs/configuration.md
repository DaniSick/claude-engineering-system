# Configuration

## settings.json merge strategy

`setup.sh` merges two sections from `global/settings.json` into `~/.claude/settings.json`:

1. **`permissions.allow`** — additive merge: adds any entries from the reference that are not already present. Never removes entries that already exist, including manual additions.

2. **`hooks`** — additive merge: adds hook entries from the reference that are not already present (identified by the command string). Never removes existing hooks.

All other keys in `~/.claude/settings.json` — `theme`, `model`, `mcpServers`, or any other personal preferences — are preserved without modification.

### Reference file

`global/settings.json` is the source of truth for what this system manages. It contains only the two sections it manages:

```json
{
  "permissions": {
    "allow": [...]
  },
  "hooks": {
    "PreToolUse": [...]
  }
}
```

Personal preferences (`theme`, `model`, etc.) belong only in `~/.claude/settings.json` and are not tracked in this repository.

## Permissions

The 16 default read-only permissions allow safe inspection commands without requiring approval:

| Pattern | Permits |
|---------|---------|
| `Bash(git status)` | git status |
| `Bash(git diff*)` | git diff with any arguments |
| `Bash(git log*)` | git log with any arguments |
| `Bash(git branch*)` | git branch listing |
| `Bash(git remote*)` | git remote info |
| `Bash(git show*)` | git show with any arguments |
| `Bash(ls*)` | directory listings |
| `Bash(find . *)` | find starting from current directory |
| `Bash(grep *)` | grep searches |
| `Bash(cat *)` | file content |
| `Bash(head *)` | file head |
| `Bash(tail *)` | file tail |
| `Bash(wc *)` | word/line count |
| `Bash(pwd)` | print working directory |
| `Bash(echo *)` | echo |
| `Bash(which *)` | binary lookup |

These patterns follow the Claude Code permission syntax: `Bash(command pattern)` where `*` is a wildcard.

## Hook configuration

The hook configuration added to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "python3 ~/.claude/hooks/secret-scan.py",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

The hook runs for every `Bash` tool invocation. The Python script exits silently (exit 0, no output) unless the command is `git commit` and the staged diff matches a credential pattern.

## Settings precedence

Claude Code merges settings from multiple locations. From lowest to highest priority:

1. `~/.claude/settings.json` (global — managed here)
2. `.claude/settings.json` in the project directory (project-level)
3. `.claude/settings.local.json` (local overrides, not committed)

Permissions in project settings add to, not replace, global permissions.

## Adding permissions

To add a new global permission:

1. Add the pattern to `global/settings.json` under `permissions.allow`
2. Run `bash scripts/setup.sh`

The new permission is added to `~/.claude/settings.json` without removing existing entries.

To add a permission only for a specific project, add it to that project's `.claude/settings.json` instead.
