# Contributing

Thanks for considering a contribution to `claude-engineering-system`. This document explains how to propose changes safely.

## Ground rules

- This repo deploys files to `~/.claude/`. Any change must preserve the user's own settings (`theme`, `model`, custom permissions, custom hooks).
- Agents and skills are read-only by design. Do not add tools that modify files to the `security-*`, `architect`, `performance`, or `reviewer` agents.
- No secrets, tokens, or credentials in any committed file.
- English for code, agent prompts, and skill definitions. Spanish is accepted in issues and PR discussion.

## Development loop

```bash
git clone git@github.com:DaniSick/claude-engineering-system.git
cd claude-engineering-system
bash scripts/doctor.sh          # verify the environment
bash scripts/setup.sh --verify  # dry-run deployment check
bash scripts/test.sh            # run the local test suite
```

Make your changes in `global/`, `agents/`, `.claude/commands/`, or `hooks/`, then:

```bash
bash scripts/setup.sh           # deploy to ~/.claude/
bash scripts/setup.sh --verify  # confirm the deployment matches sources
```

## Commit style

Conventional commits:

- `feat:` new agent, skill, hook, or user-visible capability
- `fix:` bug fix
- `docs:` documentation only
- `refactor:` internal change with no behavior difference
- `test:` test-only change
- `chore:` tooling, CI, release plumbing

One logical change per commit. Keep subject under 72 characters.

## Pull requests

1. Open an issue first for anything bigger than a typo or doc fix.
2. Describe the problem, the proposed change, and how you tested it.
3. CI must be green before review.
4. If the change touches an agent prompt, include a sample invocation in the PR description so reviewers can judge the output shape.

## Testing changes to agents or skills

Agents and skills ship as Markdown with YAML frontmatter. The CI validates:

- Frontmatter parses as YAML.
- `name:` matches the filename (without extension).
- `description:` is present and under 500 characters.
- The body has no shell commands that would be auto-executed by Claude Code.

Run locally:

```bash
bash scripts/test.sh
```

## Reporting security issues

Do not open a public issue. See [`SECURITY.md`](SECURITY.md).
