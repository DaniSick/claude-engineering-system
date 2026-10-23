# Claude Engineering System

[![CI](https://github.com/DaniSick/claude-engineering-system/actions/workflows/ci.yml/badge.svg)](https://github.com/DaniSick/claude-engineering-system/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A version-controlled personal configuration for [Claude Code](https://claude.ai/code) that deploys engineering principles, specialized agents, workflow skills, and a pre-commit credential scanner to `~/.claude/`.

Goal: fewer wasted turns on real engineering tasks. See [`docs/token-budget.md`](docs/token-budget.md) for exactly what it costs in input tokens per turn and when it saves vs. when it does not.

## What it installs

| Component | Deploys to | Loaded when |
|-----------|-----------|-------------|
| `global/CLAUDE.md` | `~/.claude/CLAUDE.md` | Every session, every turn |
| `agents/*.md` | `~/.claude/agents/` | Only when an agent is invoked (`@name`) |
| `.claude/commands/*.md` | `~/.claude/commands/` | Only when a skill is invoked (`/name`) |
| `hooks/secret-scan.py` | `~/.claude/hooks/` | Before any `git commit` tool call |
| `global/settings.json` | merged into `~/.claude/settings.json` | At startup — permissions + hook config |

Current token footprint, measured by `scripts/measure-tokens.sh`:

- Permanent per-turn cost (`CLAUDE.md`): **~2,150 tokens**.
- Mean agent (loaded on invocation): ~1,560 tokens.
- Mean skill (loaded on invocation): ~890 tokens.

## Requirements

- Claude Code ≥ 2.1.87
- Linux, macOS, or WSL2 (Windows native is not supported)
- `bash`, `git`, `python3`, `sha256sum`
- Optional: `jq` for CI tests, `tiktoken` for exact token counts

## Install

```bash
git clone git@github.com:DaniSick/claude-engineering-system.git ~/claude-engineering-system
cd ~/claude-engineering-system
bash scripts/doctor.sh       # verify your environment first
bash scripts/setup.sh        # deploy to ~/.claude/
bash scripts/setup.sh --verify
```

## Update

```bash
cd ~/claude-engineering-system
git pull
bash scripts/setup.sh
```

## Uninstall

```bash
bash scripts/uninstall.sh --dry-run    # preview
bash scripts/uninstall.sh              # remove managed files
bash scripts/uninstall.sh --restore    # restore the most recent backup instead
```

Backups at `~/.claude/backups/ces/` are kept so you can always roll back manually.

## Agents

Available in every Claude Code session as read-only specialists. They cannot modify files.

```
@architect           — module structure, dependency boundaries, coupling
@performance         — N+1 queries, redundant work, cache misses
@reviewer            — pre-commit change review
@security            — security audit orchestrator
@security-auth       — authN, authZ, session, multi-tenancy
@security-injection  — SQL/NoSQL/command injection, XSS, SSRF, path traversal
@security-web        — CSRF, CORS, CSP, headers, rate limiting
@security-data       — secrets, crypto, file handling, data exposure
@security-logic      — business logic, race conditions, compound chains
@security-deps       — package CVEs, abandoned deps, lockfile integrity
```

## Skills

```
/audit-module        — audit a module for correctness, security, coupling
/investigate-bug     — structured root-cause investigation
/safe-refactor       — refactor with behavioral preservation checklist
/pre-commit-review   — staged diff review before committing
/sec-audit           — full security audit with specialist orchestration
/ui-review           — structured UI/UX engineering workflow
/mode                — switch response mode (ferb/explained/auto)
```

> **Compatibility note**: `~/.claude/commands/` as a global skill location was not confirmed in the Claude Code 2.1.87 docs when this repository was first published. On recent Claude Code versions the directory is loaded. If skills do not appear in a fresh session, see [`docs/usage.md`](docs/usage.md#verifying-global-skills) for verification steps and fallbacks.

## Hook

`secret-scan.py` runs before `git commit` and warns if the staged diff contains credential-like patterns:

- `password`, `secret`, `api_key`, `access_token`, `auth_token` assignments
- AWS access keys (`AKIA...`, `ASIA...`)
- Bearer tokens
- GitHub personal access token prefixes (`ghp_`, `gho_`, …)

The warning is non-blocking — it does not prevent the commit. Detection is tested against positive and negative fixtures in [`tests/hook-fixtures/`](tests/hook-fixtures/).

## Project template

```bash
cp ~/claude-engineering-system/templates/project-CLAUDE.md ~/your-project/CLAUDE.md
```

Fill in the stack, architecture, and constraints for your project. The global `~/.claude/CLAUDE.md` loads automatically; the project file adds local context.

## Measure, diagnose, test

```bash
bash scripts/doctor.sh           # health check — tools, drift, settings integrity
bash scripts/measure-tokens.sh   # token cost of every file deployed
bash scripts/test.sh             # full regression suite
bash tests/test-hook.sh          # hook detection positives + negatives
bash tests/test-frontmatter.sh   # agent and skill frontmatter validation
```

## Docs

- [`docs/token-budget.md`](docs/token-budget.md) — token cost per turn and net save/cost analysis
- [`docs/installation.md`](docs/installation.md) — install, update, uninstall, WSL2 notes
- [`docs/usage.md`](docs/usage.md) — agents, skills, hook, project setup
- [`docs/architecture.md`](docs/architecture.md) — design decisions and component model
- [`docs/configuration.md`](docs/configuration.md) — settings merge strategy and permissions
- [`docs/troubleshooting.md`](docs/troubleshooting.md) — common errors and recovery
- [`docs/development.md`](docs/development.md) — contributing, testing, conventions
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — how to propose changes
- [`SECURITY.md`](SECURITY.md) — vulnerability reporting
- [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)

## License

[MIT](LICENSE)
