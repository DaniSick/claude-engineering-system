# Claude Engineering System

A version-controlled personal configuration for [Claude Code](https://claude.ai/code) that deploys global agents, skills, and settings to `~/.claude/` — available across every project.

## What it installs

| Component | Deploys to | Purpose |
|-----------|-----------|---------|
| `global/CLAUDE.md` | `~/.claude/CLAUDE.md` | Engineering principles loaded in every session |
| `agents/*.md` | `~/.claude/agents/` | Specialized read-only analysis agents |
| `.claude/commands/*.md` | `~/.claude/commands/` | Workflow skills |
| `hooks/secret-scan.py` | `~/.claude/hooks/` | Pre-commit credential warning |
| `global/settings.json` | merged into `~/.claude/settings.json` | Read-only permissions and hook config |

## Requirements

- Claude Code ≥ 2.1.87
- Linux, macOS, or WSL2
- `bash`, `git`, `python3`, `sha256sum`

## Install

```bash
git clone git@github.com:DaniSick/claude-engineering-system.git ~/claude-engineering-system
cd ~/claude-engineering-system
bash scripts/setup.sh
```

## Verify

```bash
bash scripts/setup.sh --verify
```

## Update

```bash
cd ~/claude-engineering-system
git pull
bash scripts/setup.sh
```

## Agents

Available in every Claude Code session:

```
@architect   — module structure, dependency boundaries, coupling
@security    — authorization, input validation, injection risks
@performance — N+1 queries, redundant operations, cache misses
@reviewer    — pre-commit change review
```

## Skills

```
/audit-module        — audit a module for correctness, security, and coupling
/investigate-bug     — structured root-cause investigation
/safe-refactor       — refactor with behavioral preservation checklist
/pre-commit-review   — staged diff review before committing
```

> **Note**: `~/.claude/commands/` as a global location has not been confirmed in the official Claude Code 2.1.87 documentation. Skills are confirmed to work from within this repository; global availability requires manual verification (see [docs/usage.md](docs/usage.md#verifying-global-skills)).

## Hook

`secret-scan.py` activates before `git commit` and warns if the staged diff contains credential-like patterns (passwords, API keys, AWS key prefixes). The warning is non-blocking — it shows a message but does not prevent the commit.

The hook requires the hook configuration to be present in `~/.claude/settings.json`. `setup.sh` adds it automatically.

## Project template

```bash
cp ~/claude-engineering-system/templates/project-CLAUDE.md ~/your-project/CLAUDE.md
```

Fill in the stack, architecture, and constraints for your project. The global `~/.claude/CLAUDE.md` loads automatically; the project file adds local context.

## Docs

- [docs/installation.md](docs/installation.md) — install, update, uninstall, WSL2 notes
- [docs/usage.md](docs/usage.md) — agents, skills, project setup
- [docs/architecture.md](docs/architecture.md) — design decisions and component model
- [docs/configuration.md](docs/configuration.md) — settings merge strategy and permissions
- [docs/troubleshooting.md](docs/troubleshooting.md) — common errors and recovery
- [docs/development.md](docs/development.md) — contributing, testing, conventions

## License

MIT
