# Development

## Running tests

```bash
bash scripts/test.sh
```

Tests cover:
- JSON validity of all JSON files
- Frontmatter requirements for agents and commands
- No hardcoded credentials in tracked files
- Hook script behavior (silent on non-matching input, graceful on bad input)
- Deployment verification (deployed files match source)

## Adding an agent

1. Create `agents/<name>.md` with the required frontmatter:

```markdown
---
name: <name>
description: One-line description (shown in agent selection)
---

# Instructions

...
```

2. Run `bash scripts/setup.sh` to deploy to `~/.claude/agents/`.

Agents are read-only by convention. Do not write agents that modify files, make commits, or execute destructive commands.

## Adding a skill

1. Create `.claude/commands/<name>.md` with the required frontmatter:

```markdown
---
description: One-line description
---

# Skill name

...
```

2. Run `bash scripts/setup.sh` to deploy to `~/.claude/commands/`.

## Adding a hook

1. Create `hooks/<name>.py` (Python) or `hooks/<name>.sh` (shell).

   Hook scripts receive tool invocation data as JSON on stdin and must:
   - Exit 0 silently when there is nothing to report
   - Print a JSON object `{"systemMessage": "..."}` when reporting a warning
   - Never block — always exit 0 after reporting

2. Update `global/settings.json` to register the hook under the appropriate event (`PreToolUse`, `PostToolUse`).

3. Run `bash scripts/setup.sh` to deploy the script to `~/.claude/hooks/` and merge the configuration into `~/.claude/settings.json`.

Hook input format (JSON on stdin):
```json
{
  "tool_name": "Bash",
  "tool_input": {
    "command": "git commit -m 'feat: example'"
  }
}
```

## Adding permissions

Add the pattern to `global/settings.json` under `permissions.allow`, then run `bash scripts/setup.sh`. The merge is additive — existing permissions are never removed.

## Conventions

- **Commit messages**: conventional commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)
- **Agents**: read-only; every finding cites `file:line` and is labeled `CONFIRMED` or `HYPOTHESIS`
- **Skills**: structured output, defined steps — not open-ended instructions
- **Hooks**: always non-blocking (exit 0, warning only); graceful failure on any exception
- **Settings reference**: `global/settings.json` contains only what this system manages — no personal preferences
- **No false claims**: do not document a feature as available if it has not been confirmed

## Verified vs. unverified features

The comments in `scripts/setup.sh` section 3 document that `~/.claude/commands/` global loading has not been confirmed. When a feature's behavior is unconfirmed, document it as such rather than asserting it works. Confirmation requires a manual test from outside this repository.

## Repository structure

```
global/             source for ~/.claude/ root files
agents/             source for ~/.claude/agents/
hooks/              source for ~/.claude/hooks/
templates/          project CLAUDE.md template
.claude/commands/   source for ~/.claude/commands/ (and local skills)
.claude/settings.json  project-level permissions for this repo
scripts/
  setup.sh          idempotent installer
  test.sh           regression tests
docs/               user-facing documentation
CHANGELOG.md        version history
```
