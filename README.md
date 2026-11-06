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
bash scripts/setup.sh --init                    # interactive: stacks + theme
bash scripts/setup.sh --profile node,python     # or name them directly
bash scripts/setup.sh --theme matrix            # set the status line theme
bash scripts/setup.sh --help                    # list profiles and themes
```

`--init` is the one command that does everything: it asks which stacks you work in, renders
every status line theme at three pressure levels so you can pick by looking, and deploys.

Later updates are just `bash scripts/setup.sh` — your theme, your profiles and your personal
additions all survive. Nothing you chose is reset by an update.

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

## Status line

A compact status line showing that the system is active, plus the model, git branch, and
context-window pressure:

```
◆ ces · Opus 5 · main · ▅▅▅░░ 45%
```

The bar shifts colour as context fills, so pressure is visible before a compaction surprises you.

**Cost**: ~3.8ms per run, and it runs roughly once per turn. Claude Code triggers the status
line on session start and on each new assistant message, debounced at 300ms, cancelling an
in-flight run if a new trigger arrives — it is event-driven, not a render loop.

Two deliberate choices keep it cheap:

- **No `refreshInterval`.** Setting it would add a timed run every N seconds for data that only
  changes between turns.
- **No subprocesses.** The branch is read from `.git/HEAD` directly rather than by running
  `git`, and the JSON is parsed with bash parameter expansion rather than `jq` or `python`.
  One process per run instead of five or six.

Every segment degrades independently: a missing field drops its segment rather than blanking
the line, and the script exits 0 on any input, including malformed JSON. `NO_COLOR` is honoured.

If you already have a `statusLine` configured, `setup.sh` leaves it alone and tells you how to
switch.

### Themes

```bash
bash ~/.claude/statusline/ces-statusline.sh --themes   # preview them all
```

| Theme | Look |
|-------|------|
| `ghost` | dark violet, escalating to hot magenta under pressure (default) |
| `ember` | warm oranges and browns |
| `matrix` | terminal green, yellow at the top end |
| `ice` | cold blues |
| `mono` | no hue — weight only |
| `default` | the original blue-grey |

Set one with `CES_THEME=matrix` in your shell, or change `THEME` near the top of the script.
An unknown name falls back to `default` rather than breaking the line.

Every theme escalates its bar colour with context pressure, whatever its hue — the signal has
to survive the palette. Dim text stays legible on a dark background, which is why the deepest
end of each ramp is avoided. Swap `GLYPH` for anything your font renders.

### Banner

`CES_BANNER=full` or `CES_BANNER=small` draws pixel art above the info line. The art has three
tiers, and the model running the session picks one:

| Tier | Look | Set by |
|------|------|--------|
| 0 | plain skull | anything unmatched |
| 1 | horns | `CES_HEAVY_MODELS` — default `opus` |
| 2 | horns, palette inverted | `CES_APEX_MODELS` — default `fable` |

```
   ▄▄▄▄▄▄▄▄▄         █▄           ▄█
 █████████████       ▀██▄▄▄▄▄▄▄▄▄██▀
███████████████       █████████████
███████████████      ███████████████
     tier 0              tier 1
```

Tier 2 keeps the horned silhouette and inverts the palette. The three bone tones collapse to
near-black — holding their relative order so dome, mass and horns still separate — and the
sockets, nasal cavity and tooth gaps take the theme's lit tone instead of true black. The skull
stops being a lit object with dark holes and becomes a silhouette with its sockets burning
through; the pupils still flare red during tool use. Only the banner inverts, so the info line
keeps the theme's text colours and stays legible at every tier.

Both lists are **family substrings**, matched case-insensitively against the model's display
name:

```bash
export CES_HEAVY_MODELS="opus"          # the defaults
export CES_APEX_MODELS="fable"

export CES_APEX_MODELS="fable titan"    # add a family: one word
```

Substrings rather than exact model ids is the deliberate part: `opus` keeps matching across
`Opus 4.1`, `Opus 5`, `claude-opus-5` and whatever version comes next, so a release does not
require an edit here. A model matching neither list — one you never listed, one that has been
retired, or a payload with no model field at all — falls to tier 0. The check never fails
closed and never blanks the line. Apex is tested first, so a model in both lists gets the
heavier look.

Only the crown row branches on tier, and the palette is resolved in one place before any escape
code is built, so the skull stays defined once and the horns cannot drift out of alignment with
it. Both sizes hold a fixed grid — 15 columns for `full`, 13 for `small` — which
`ces-statusline.sh --test` enforces on every tier.

Hide the banner with `/banner`, or `touch ~/.ces-no-banner`.

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

### Running an eval

```bash
# A/B the system against a blind fixture
FIXTURE=$PWD/docs/eval/fixture-app bash scripts/eval-security.sh 5

# Add a third condition to test a change before deploying it
FIXTURE=$PWD/docs/eval/fixture-app \
  bash scripts/eval-security.sh 5 --variant global/CLAUDE.md

# Score
bash scripts/score-eval.sh  docs/eval/runs/<timestamp>   # report discipline
bash scripts/score-chain.sh docs/eval/runs/<timestamp>   # compound-chain detection
```

Runs execute concurrently, bounded by `CONCURRENCY` (default 3). Each run is an independent
process with its own HOME and its own private copy of the fixture, so the only shared resource
is the API — which is why the bound exists rather than dispatching everything at once. Set
`CONCURRENCY=1` for serial execution.

Completion lines arrive out of order; the output file names carry the mapping. Recall against
the answer keys is scored by hand, deliberately — judging whether a report names a mechanism or
hand-waves at a category does not automate reliably.

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
