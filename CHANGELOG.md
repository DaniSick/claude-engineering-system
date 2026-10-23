# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/).

## [0.2.0] — 2026-10-23

### Added
- `LICENSE` (MIT) as a real file, matching the README claim.
- `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`.
- `.github/ISSUE_TEMPLATE/` with bug and feature forms.
- `.github/PULL_REQUEST_TEMPLATE.md` with per-component checklist.
- `.github/FUNDING.yml`.
- `scripts/uninstall.sh`: reads the manifest at `~/.claude/backups/ces/manifest.json` and either removes or restores (`--restore`) every managed file. Also strips the permissions and hook entries that `global/settings.json` contributed, leaving user keys intact. Supports `--dry-run` and `--yes`.
- `scripts/doctor.sh`: health check for required tools, repository shape, Claude Code environment, deployment drift, `settings.json` validity, and hook executability. Exits `0`/`1`/`2`; supports `--json`.
- `scripts/measure-tokens.sh`: reports the token cost of every file the system deploys. Uses `tiktoken` when installed, falls back to a bytes/3.5 heuristic. Supports `--json`.
- `.github/workflows/ci.yml`: GitHub Actions pipeline on Ubuntu and macOS — shellcheck, setup, verify, frontmatter check, hook tests, full suite, doctor, uninstall dry-run and apply, markdown lint.
- `.markdownlint.json` with pragmatic defaults.
- `tests/hook-fixtures/`: 3 positive (password, AWS, Bearer) and 2 negative (doc text, env var) diffs.
- `tests/test-hook.sh`: exercises `secret-scan.py` against the fixtures with a mocked `git` on `PATH`.
- `tests/test-frontmatter.sh`: validates YAML frontmatter in every agent and skill (`name:` matches filename, `description:` present and under 500 characters).
- `docs/token-budget.md`: explains the real per-turn token cost and when the system is a net save vs. a net cost.

### Fixed
- `hooks/secret-scan.py`: credential patterns are now anchored to `^\+.*?` instead of `^\+.{0,10}`, so AWS access keys and Bearer tokens are detected regardless of their position in the added line. Adds GitHub PAT prefix detection (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`).

## [0.1.1] — 2026-10-13
- **Advanced security engineering system** — orchestrator + 6 domain specialists + `/sec-audit` skill:
  - `agents/security.md` (rewritten as orchestrator): scope assessment, specialist selection table, direct analysis for narrow scope, coverage matrix format
  - `agents/security-auth.md`: authentication flows, session management, JWT/OAuth, IDOR/BOLA, mass assignment, multi-tenancy
  - `agents/security-injection.md`: SQL/NoSQL/command injection, XSS (all contexts), SSRF, path traversal, deserialization, dynamic eval
  - `agents/security-web.md`: CSRF, CORS, CSP, security headers, rate limiting, API exposure, GraphQL, WebSocket, caching
  - `agents/security-data.md`: file upload/download, hardcoded secrets, crypto configuration, TLS, sensitive data in logs/exports
  - `agents/security-logic.md`: business logic flaws, state machine violations, race conditions/TOCTOU, resource exhaustion, compound chains
  - `agents/security-deps.md`: package CVEs (with explicit training-cutoff limitation), abandoned packages, lockfile integrity, supply chain
  - `.claude/commands/sec-audit.md`: full audit orchestration — assess → select specialists → parallel execution → compound analysis → report with coverage matrix
  - `docs/sec-fixture.py`: synthetic vulnerable Python file (SQLi, hardcoded secret, missing auth/IDOR, command injection) for verifying analysis quality
- **UI/UX engineering capability**:
  - `.claude/commands/ui-review.md`: structured audit skill (inspect visual system → identify with evidence → implement → validate)
  - `global/CLAUDE.md`: compact UI/UX section (~8 lines) with visual system principles
- **Adaptive effort policy**: three levels (light/normal/deep) in `global/CLAUDE.md`
- **Response modes** (ferb/explained/auto): in `global/CLAUDE.md`; `/mode` skill to switch within session
- `hooks/secret-scan.py`: PreToolUse hook that warns before `git commit` if the staged diff contains credential-like patterns. Non-blocking.
- `global/settings.json`: hooks configuration for `secret-scan.py`.
- `scripts/setup.sh`: hook deployment for `.py` and `.sh` files; additive merge of `hooks` section in `settings.json`.
- `scripts/test.sh`: automated regression tests covering JSON validity, frontmatter, no-secrets scan, hook behavior, and deployment verification.
- `docs/installation.md`: install, update, uninstall, WSL2 notes.
- `docs/usage.md`: agents, skills, hook, project setup.
- `docs/configuration.md`: settings merge strategy, permissions reference, hooks configuration.
- `docs/troubleshooting.md`: common errors and recovery steps.
- `docs/development.md`: contributing, conventions, hook and agent authoring guide.

### Changed
- `global/settings.json`: removed personal preferences (`theme`, `model`, `includeCoAuthoredBy`). The reference file now contains only what this system manages.
- `templates/project-CLAUDE.md`: replaced framework-specific entry point examples with generic equivalents.
- `docs/architecture.md`: updated to reflect hooks deployment, settings management, and installer design.
- `README.md`: rewritten as a concise open-source project README.

### Removed
- `docs/audit-baseline.md`: internal historical document, no user value.
- `docs/agents-inventory.md`: content merged into `docs/usage.md`.
- `hooks/README.md`: design content moved to `docs/development.md`.

---

## [0.1.0] — 2026-10-13

### Added
- `global/CLAUDE.md`: universal engineering principles (detect stack, investigate before modifying, non-negotiable rules, quality checklist, security rules, audit output format, commit discipline).
- `agents/architect.md`, `agents/security.md`, `agents/performance.md`, `agents/reviewer.md`: four read-only specialized agents.
- `global/settings.json`: 16 read-only permissions for safe inspection commands.
- `.claude/commands/audit-module.md`, `investigate-bug.md`, `safe-refactor.md`, `pre-commit-review.md`: four workflow skills.
- `templates/project-CLAUDE.md`: generic project CLAUDE.md template.
- `scripts/setup.sh`: idempotent installer with sha256 checksums, backups, verify mode, and additive settings merge.
