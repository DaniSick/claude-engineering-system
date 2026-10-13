# Claude Engineering System

A reusable, version-controlled configuration system that maximizes Claude Code's capabilities across all projects.

## What this is

Not a collection of prompts — a **deployable engineering system** that makes Claude Code investigate deeper, audit more rigorously, delegate work correctly, and commit fewer errors across every session and project.

## Structure

```
.
├── global/           # Source of truth for ~/.claude/ user-level config
│   ├── CLAUDE.md     # Personal engineering principles (deployed globally)
│   └── settings.json # Settings reference (hooks, permissions, model)
├── agents/           # Specialized read-only agent definitions
│   ├── architect.md  # Architecture and dependency analysis
│   ├── security.md   # Security audit (OWASP, auth, injection, secrets)
│   ├── performance.md # N+1, cache, query optimization
│   └── reviewer.md   # Pre-commit change review
├── hooks/            # Hook scripts and documentation
│   └── README.md
├── docs/
│   ├── audit-baseline.md      # Initial system audit findings
│   ├── architecture.md        # System design decisions
│   └── agents-inventory.md   # Agent capabilities and usage guide
├── scripts/
│   └── setup.sh      # Deploy config files to ~/.claude/
└── .claude/
    └── settings.json # Project-level settings for this repo
```

## Quick setup

```bash
# Deploy global config to ~/.claude/
bash scripts/setup.sh

# Verify
ls ~/.claude/CLAUDE.md ~/.claude/agents/
```

## Requirements

- Claude Code >= 2.1.87
- Linux / macOS / WSL2
- `bash`, `git`, `python3` (for setup.sh settings merge)

## Using agents

In any Claude Code session:

```
# Delegate architecture analysis (path depends on the project)
@architect analyze the module structure in src/services/

# Request security audit
@security review src/auth/

# Performance investigation
@performance find redundant queries in the data access layer

# Pre-commit review
@reviewer check the current diff
```

## Installed marketplace plugins

The following plugins are already installed and available via `/skill`:
- `/code-review` — comprehensive code review
- `/claude-security` — security audit workflow
- `/pr-review-toolkit` — PR review with inline comments
- `/feature-dev` — feature development workflow
- `/code-modernization` — modernization audit
- `/code-simplifier` — simplification pass
- `/commit-commands` — commit message workflow
- `/hookify` — hook configuration helper
- `/skill-creator` — create new skills

## Maintenance

| Task | Command |
|------|---------|
| Re-deploy global config | `bash scripts/setup.sh` |
| Add new agent | Edit `agents/<name>.md`, re-run setup |
| Update global principles | Edit `global/CLAUDE.md`, re-run setup |
| Add hook | Edit `hooks/`, update `global/settings.json`, re-run setup |

## Design decisions

See `docs/architecture.md` for rationale behind structural choices.
See `docs/audit-baseline.md` for the initial state audit that informed this design.
