# Claude Engineering System

[![CI](https://github.com/DaniSick/claude-engineering-system/actions/workflows/ci.yml/badge.svg)](https://github.com/DaniSick/claude-engineering-system/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A version-controlled personal configuration for [Claude Code](https://claude.ai/code) that deploys engineering principles, specialized agents, workflow skills, and a pre-commit credential scanner to `~/.claude/`.

Goal: fewer wasted turns on real engineering tasks. See [`docs/token-budget.md`](docs/token-budget.md) for exactly what it costs in input tokens per turn and when it saves vs. when it does not.

## What it changes

These describe what the configuration **instructs** Claude to do. They are design intent,
not measured outcomes — see [Validation status](#validation-status).

**Security review** — `/sec-audit` dispatches `@security-auth`, `@security-injection`, and
`@security-web` against the target, then reports a table with `CONFIRMED` / `HYPOTHESIS`
labels, file:line evidence, and a compound-chain pass that looks for vulnerabilities created
by the interaction of individually-minor findings.

**Bug investigation** — `/investigate-bug` requires tracing to a root cause before any edit,
and escalates to a fresh investigation after two consecutive failed fixes on the same problem.

**Response verbosity** — `/mode ninja` reduces output to diff plus one line. `/mode ferb`
(the default) puts the result first with a ≤3-line explanation and forbids re-reading files
already in context.

## Validation status

One A/B eval has been run. **It found no detection improvement.**

`bash scripts/eval-security.sh` scores the system against a blind security fixture, with the
baseline running in an isolated `HOME` that has no configuration deployed. In the first run
(3 trials per condition), both conditions found **6 of 6** planted vulnerabilities with **zero**
false positives. Recall was saturated: a current model finds these without help, so the fixture
cannot discriminate.

What did differ, consistently across all trials: the configured condition reproduced the audit
table, `CONFIRMED` / `NOT VERIFIED` status labels, explicit negative findings, and scope caveats
specified in `global/CLAUDE.md`. The baseline wrote good prose but volunteered those less
reliably. That is a reproducible difference in report discipline — not evidence of better
detection.

Full data and the honest read: [`docs/eval/RESULTS.md`](docs/eval/RESULTS.md).

So: token costs are measured. Report structure is measured. **Whether the system improves
engineering outcomes remains unproven** — a harder fixture (multi-file, compound chains,
realistic signal-to-noise) is the next step. Treat the design as reasoned, not proven.

## What it installs

| Component | Deploys to | Loaded when |
|-----------|-----------|-------------|
| `global/CLAUDE.md` | `~/.claude/CLAUDE.md` | Every session, every turn |
| `agents/*.md` | `~/.claude/agents/` | Only when an agent is invoked (`@name`) |
| `.claude/commands/*.md` | `~/.claude/commands/` | Only when a skill is invoked (`/name`) |
| `hooks/secret-scan.py` | `~/.claude/hooks/` | Before any `git commit` tool call |
| `global/settings.json` | merged into `~/.claude/settings.json` | At startup — permissions + hook config |

Current token footprint, measured by `scripts/measure-tokens.sh`:

- Permanent per-turn cost (`CLAUDE.md`): **~4,231 tokens** (includes the six response modes and their strategic token-saving rules).
- Mean agent (loaded on invocation): ~1,560 tokens.
- Mean skill (loaded on invocation): ~910 tokens.

Response modes (`/mode <name>`): `ninja` (max compression), `ferb` (strategic saver, default), `surgical` (minimum reads), `blueprint` (plan first), `explained`, `auto`. See [`docs/token-budget.md`](docs/token-budget.md) and `/mode` for details.

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
bash scripts/setup.sh --init # pick your stacks, then deploy
bash scripts/setup.sh --verify
```

### Stack profiles

Base permissions are stack-neutral — `git`, `ls`, `grep`, `find`, `cat` and similar
inspection commands that are safe in any project. Anything language-specific is opt-in,
so a Go developer does not inherit a PHP allowlist.

```bash
bash scripts/setup.sh --init                    # interactive picker
bash scripts/setup.sh --profile node,python     # or name them directly
bash scripts/setup.sh --help                    # list available profiles
```

Available: `php-laravel`, `node`, `python`, `go`, `rust`. Profiles are additive and
re-runnable — add another stack later without losing the first. To add your own, drop a
JSON file with a `permissions.allow` array into `global/profiles/`.

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
@test-quality        — tests that pass without verifying behavior
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

Skills deploy to `~/.claude/commands/` and are available in every session, confirmed in Claude Code 2.1.87+.

## MCP servers

This repository does not bundle MCP servers, but the following are commonly useful alongside it:

| Server | Use case |
|--------|----------|
| [Filesystem](https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem) | Read/write files outside the working directory |
| [GitHub](https://github.com/modelcontextprotocol/servers/tree/main/src/github) | PR review, issues, CI status |
| [Fetch](https://github.com/modelcontextprotocol/servers/tree/main/src/fetch) | Retrieve docs, specs, or changelogs from URLs |
| [SQLite](https://github.com/modelcontextprotocol/servers/tree/main/src/sqlite) | Inspect local databases during debugging |

Install any server with `claude mcp add` and it becomes available in every session. See [`docs/usage.md`](docs/usage.md) for integration notes.

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
