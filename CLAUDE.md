# Claude Engineering System — Repository Instructions

This repository IS the engineering system for Claude Code. It tracks configuration, agents, skills, hooks, and documentation.

## What this repo contains

- `global/` — source of truth for `~/.claude/` user-level configuration
- `agents/` — specialized agent definitions (deploy to `~/.claude/agents/`)
- `hooks/` — hook scripts (deploy via `scripts/setup.sh`)
- `docs/` — architecture decisions, usage guides, evaluation scenarios
- `scripts/setup.sh` — deploy all config to `~/.claude/`

## Working in this repo

When modifying this system:

1. Edit source files in `global/`, `agents/`, or `hooks/`.
2. Run `bash scripts/setup.sh` to deploy changes to `~/.claude/`.
3. Verify the deployed file matches the source.
4. Commit both the source change and document the verification result.

## Commit conventions

- `feat: add <agent/skill/hook> for <purpose>`
- `fix: correct <what> in <file>`
- `docs: update <document> with <content>`
- `chore: deploy config to user directory`

Never commit secrets, `.env` files, credential JSON, or tokens.
Never commit files from `~/.claude/` that contain credential data (`.credentials.json`, `daemon.*`).

## Deploying to a new machine

```bash
git clone <repo-url> ~/claude-engineering-system
cd ~/claude-engineering-system
bash scripts/setup.sh
```

## Relationship to project CLAUDE.md files

This repo provides the **global** layer only. Individual projects should have their own `CLAUDE.md` with project-specific context. Global principles defined in `global/CLAUDE.md` apply everywhere; project CLAUDE.md files extend them locally.

## Current system status

See `docs/architecture.md` for design decisions.
See `docs/eval-scenarios.md` for reproducible evaluation scenarios.
