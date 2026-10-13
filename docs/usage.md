# Usage

## Agents

Four read-only agents deploy to `~/.claude/agents/` and are available in every Claude Code session.

| Agent | Invocation | Purpose |
|-------|-----------|---------|
| `architect` | `@architect` | Module structure, dependency boundaries, coupling |
| `security` | `@security` | Authorization, input validation, injection risks, secrets |
| `performance` | `@performance` | N+1 queries, redundant operations, cache misses |
| `reviewer` | `@reviewer` | Pre-commit change review |

Agents are read-only — they analyze and report but do not write or modify files. Every finding cites a `file:line` and is labeled `CONFIRMED` or `HYPOTHESIS`.

### Example invocations

```
@architect analyze module structure in src/
@security review the authentication directory
@performance find redundant queries in the data access layer
@reviewer check the current staged diff before committing
```

### When to use agents vs. the main session

Use an agent for deep, isolated analysis that shouldn't contaminate the main session context. The main session is better for tasks that require writing files.

## Skills

Four workflow skills deploy to `~/.claude/commands/`.

| Skill | Invocation | Purpose |
|-------|-----------|---------|
| `audit-module` | `/audit-module` | Audit a module for correctness, security, and coupling |
| `investigate-bug` | `/investigate-bug` | Structured root-cause investigation |
| `safe-refactor` | `/safe-refactor` | Refactor with behavioral preservation checklist |
| `pre-commit-review` | `/pre-commit-review` | Staged diff review before committing |

### Verifying global skills

Skills in `~/.claude/commands/` are confirmed to load from within this repository. Whether they load globally from other project directories depends on Claude Code's configuration, which has not been confirmed in the official 2.1.87 documentation.

To verify:
1. Open Claude Code from a directory that is **not** this repository.
2. Type `/audit-module`. If it appears as an available skill, global loading is confirmed.
3. If it does not appear, skills are only available from within this repository's directory.

## Hook

`secret-scan.py` runs as a `PreToolUse` hook before `git commit` executes. It scans the staged diff for credential-like patterns:

- `password`, `passwd`, `secret`, `api_key`, `access_token` assigned to a non-trivial value
- Bearer tokens
- AWS key prefixes (`AKIA`, `ASIA`)

If a pattern matches, Claude Code displays a warning message. The hook is non-blocking — the commit proceeds regardless.

The hook must be deployed (`bash scripts/setup.sh`) and the hook configuration must be present in `~/.claude/settings.json` (added automatically by the installer).

## Project setup

Copy the template to a project and fill in the details:

```bash
cp ~/claude-engineering-system/templates/project-CLAUDE.md ~/your-project/CLAUDE.md
```

The template has five sections:
- **Stack** — language, framework, database, build tools, test tooling
- **Architecture** — entry points, layer structure, key conventions
- **How to run things** — dev server, tests, lint, format commands
- **Constraints** — what Claude must not do without explicit approval
- **Known complexity** — non-obvious behavior Claude might get wrong

The global `~/.claude/CLAUDE.md` loads in every session and applies universal engineering principles. The project `CLAUDE.md` adds project-specific context on top.

Keep the project `CLAUDE.md` concise. It loads on every session. Move procedural details to `.claude/commands/` (project skills) rather than putting them in `CLAUDE.md`.
