# Claude Engineering System

A personal, reusable engineering system for Claude Code. Version-controlled configuration that loads personal principles in every session, enables specialized agent delegation, and provides structured workflows for common engineering tasks.

## What this is

Not a collection of prompts — a **deployable engineering system** that makes Claude Code:
- Investigate before modifying
- Detect the project's technology before applying rules
- Delegate deep audits to specialized read-only agents
- Follow structured workflows for bugs, refactors, and code review
- Commit less noise and fewer regressions

## Structure

```
.
├── global/                  # Deploys to ~/.claude/ (loaded in every session)
│   ├── CLAUDE.md            # Personal engineering principles
│   └── settings.json        # Permissions reference (read-only global allowlist)
├── agents/                  # Read-only specialized agents → ~/.claude/agents/
│   ├── architect.md         # Architecture and dependency analysis
│   ├── security.md          # Security audit (auth, injection, exposure, secrets)
│   ├── performance.md       # Redundant queries, missing indexes, cache misses
│   └── reviewer.md          # Pre-commit change review
├── templates/
│   └── project-CLAUDE.md   # Generic project context template (copy to project root)
├── hooks/
│   └── README.md            # Hook design and WSL2 notes (not yet deployed)
├── docs/
│   ├── audit-baseline.md    # Initial system state audit
│   ├── architecture.md      # Design rationale
│   └── agents-inventory.md  # Agent usage guide
├── scripts/
│   └── setup.sh             # Deploy global/ and agents/ to ~/.claude/
└── .claude/
    ├── settings.json        # Project-level permissions for this repo
    └── commands/            # Reusable workflow commands for Claude sessions
        ├── audit-module.md
        ├── investigate-bug.md
        ├── safe-refactor.md
        └── pre-commit-review.md
```

## Setup

```bash
# Clone and deploy global config to ~/.claude/
git clone https://github.com/DaniSick/claude-engineering-system.git ~/claude-engineering-system
cd ~/claude-engineering-system
bash scripts/setup.sh

# Verify
ls ~/.claude/CLAUDE.md ~/.claude/agents/
```

## Update after changes

```bash
bash scripts/setup.sh   # re-deploys CLAUDE.md, agents, permissions
```

## Requirements

- Claude Code >= 2.1.87
- Linux / macOS / WSL2
- `bash`, `git`, `python3`

## Using agents

In any Claude Code session:

```
@architect analyze the module structure in [path]
@security review [auth or sensitive directory]
@performance find redundant queries in [data access layer]
@reviewer check the current diff
```

## Using workflow commands

This repo's `.claude/commands/` directory provides structured workflows. In sessions started from this directory, use:

```
/audit-module       — structured multi-agent module audit
/investigate-bug    — root cause analysis workflow
/safe-refactor      — behavior-preserving refactor checklist
/pre-commit-review  — staged diff review before committing
```

## Setting up a project

Copy `templates/project-CLAUDE.md` to your project root as `CLAUDE.md` and fill in the sections. This gives Claude Code project-specific context (stack, architecture, constraints) without duplicating global principles.

```bash
cp ~/claude-engineering-system/templates/project-CLAUDE.md ~/your-project/CLAUDE.md
```

## Maintenance

| Task | Action |
|------|--------|
| Update global principles | Edit `global/CLAUDE.md`, run `bash scripts/setup.sh` |
| Add/update agent | Edit `agents/<name>.md`, run `bash scripts/setup.sh` |
| Add workflow command | Add `.claude/commands/<name>.md` (no deploy needed) |
| Add project-level permissions | Edit `<project>/.claude/settings.json` |
| Restore previous global config | `cp ~/.claude/CLAUDE.md.backup.<timestamp> ~/.claude/CLAUDE.md` |

## Design

See `docs/architecture.md` for layer design and decision rationale.
See `docs/agents-inventory.md` for agent usage guide.
See `hooks/README.md` for hook design (pending WSL2 validation).
