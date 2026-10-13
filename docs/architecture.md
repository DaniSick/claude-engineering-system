# Architecture

## Two-layer model

1. **Global layer** (`~/.claude/`) — personal engineering conventions, agents, skills, hooks, and settings that apply to every Claude Code session regardless of project. This repository manages the global layer.

2. **Project layer** (`.claude/` in each project) — project-specific context, tech stack, commands, and local settings. Each project manages its own project layer.

## Directory mapping

| Repo path | Deployed to | Managed by |
|-----------|------------|------------|
| `global/CLAUDE.md` | `~/.claude/CLAUDE.md` | `setup.sh` direct copy |
| `agents/*.md` | `~/.claude/agents/*.md` | `setup.sh` direct copy |
| `.claude/commands/*.md` | `~/.claude/commands/*.md` | `setup.sh` direct copy |
| `hooks/*.py`, `hooks/*.sh` | `~/.claude/hooks/` | `setup.sh` direct copy |
| `global/settings.json` | merged into `~/.claude/settings.json` | `setup.sh` additive merge |

## Installer design

`scripts/setup.sh` is idempotent: it compares sha256 checksums and skips files that haven't changed. When a file does change, it backs up the existing deployed version before overwriting.

For `settings.json`, a direct copy would overwrite personal preferences. Instead, the installer does an additive merge of the two sections it manages (`permissions.allow` and `hooks`), leaving all other keys untouched.

## Agent design

**Read-only**: All four agents are read-only. They can read files and run safe inspection commands but must not write, edit, or execute mutations. This prevents analysis agents from accidentally modifying code.

**Single responsibility**: Each agent covers one audit dimension. This keeps instructions concise and prevents context dilution.

**Evidence requirement**: Every agent is required to cite `file:line` for every finding. Findings without evidence are not findings.

**Labeled certainty**: Agents must label each finding as `CONFIRMED` (traced the code path) or `HYPOTHESIS` (inferred from pattern).

## Agent selection guide

| Situation | Agent |
|-----------|-------|
| "How does module X interact with Y?" | `@architect` |
| "Is there an authorization check missing?" | `@security` |
| "Why is this endpoint slow?" | `@performance` |
| "Is this diff safe to merge?" | `@reviewer` |

## Skill design

Skills (`.claude/commands/*.md`) are multi-step workflows with structured output. They are loaded into the current session rather than running as isolated sub-sessions.

Use agents for deep, isolated analysis. Use skills for procedural workflows with defined steps and output format.

## Hook design

Hooks are Python scripts that run before or after tool invocations. The protocol:
- Claude Code invokes the script with tool data as JSON on stdin
- The script exits 0 silently when there is nothing to report
- The script prints `{"systemMessage": "..."}` to stdout when reporting
- Hooks must never block — exit 0 regardless of outcome

The current hook (`secret-scan.py`) is a `PreToolUse` hook on `Bash` that warns before `git commit` if the staged diff contains credential-like patterns.

## Settings management

`global/settings.json` contains only what this system manages:
- `permissions.allow`: a list of auto-approved command patterns
- `hooks`: hook event configuration referencing `~/.claude/hooks/`

Personal preferences (`theme`, `model`, `includeCoAuthoredBy`) belong in `~/.claude/settings.json` only and are not tracked in this repository.

## What this system does not manage

- **Project CLAUDE.md files**: each project defines its own using the provided template
- **MCP server configuration**: connection credentials are environment-specific
- **Credentials or secrets**: never tracked in this repository
- **Claude Code marketplace skills** (`~/.claude/skills/synced/`): synchronized by Claude Code itself
