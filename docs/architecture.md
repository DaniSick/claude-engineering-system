# System Architecture

## Design principles

**Two-layer model**:
1. **Global layer** (`~/.claude/`) — personal engineering conventions, agents, and settings that apply to every Claude Code session regardless of project.
2. **Project layer** (`.claude/` in each project) — project-specific context, tech stack, commands, and local settings.

This repo manages the global layer only. Each project manages its own project layer.

## Directory mapping

| Repo path | Deployed to | Purpose |
|-----------|------------|---------|
| `global/CLAUDE.md` | `~/.claude/CLAUDE.md` | Personal engineering principles loaded in every session |
| `agents/*.md` | `~/.claude/agents/*.md` | Specialized read-only agents for delegation |
| `hooks/*.sh` | `~/.claude/hooks/*.sh` | Pre/post tool validation scripts |
| `global/settings.json` | merged into `~/.claude/settings.json` | Reference for permissions and hook config |

## Agent design

Agents are isolated sub-sessions with constrained instructions. Key decisions:

**Read-only constraint**: All four agents (architect, security, performance, reviewer) are read-only. They can read files and run safe commands (git log, grep, ls) but must not write, edit, or execute mutations. This prevents analysis agents from accidentally modifying code.

**Single responsibility**: Each agent covers one audit dimension. This keeps instructions concise and prevents context dilution from loading all analysis patterns simultaneously.

**Evidence requirement**: Every agent is required to cite file:line for every finding. Findings without evidence are not findings.

**Labeled certainty**: Agents must label each finding as `CONFIRMED` (traced the code path) or `HYPOTHESIS` (inferred from pattern). This prevents false certainty from being reported as fact.

## Agent selection guide

| Situation | Agent |
|-----------|-------|
| "How does module X interact with Y?" | architect |
| "Is there an authorization check missing here?" | security |
| "Why is this endpoint slow?" | performance |
| "Is this diff safe to merge?" | reviewer |

## Skill vs agent

**Agents** (`.md` files in `agents/`) are sub-sessions with their own persistent instructions. Best for deep, isolated analysis that shouldn't contaminate the main session context.

**Skills** (marketplace plugins or `.claude/skills/`) are reusable workflows loaded into the current session. Best for multi-step procedures with structured output.

For this system: agents for analysis, skills for workflow execution.

## Settings merge strategy

`setup.sh` does NOT replace `~/.claude/settings.json` entirely. It merges only the `permissions.allow` list. Reason: `settings.json` contains user preferences (theme, model) that should not be overwritten by a deployment script.

If hook configuration is needed, it must be added manually or via a specific merge target — not by overwriting the file.

## What this system does NOT manage

- **Project CLAUDE.md files**: Each project should define its own. Templates may be provided later.
- **MCP server configuration**: Connection credentials are environment-specific; not tracked here.
- **Credentials or secrets**: Never tracked in this repo.
- **CI/CD pipeline**: Out of scope for a personal configuration system.

## Evolution path

Current: Global config + agents
Next: Project CLAUDE.md templates for Laravel/Filament, Node/Expo projects
Later: Hooks when format is validated on WSL2
Later: Workflow commands in `.claude/commands/` for this repo
