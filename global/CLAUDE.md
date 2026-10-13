# Engineering Principles — Global Configuration

Stack: Laravel · PHP · Filament · Blade · Livewire · PostgreSQL · Docker
Environment: WSL2, fish shell, Claude Code 2.1.87+

## Investigate before modifying

Before editing any file:
1. Read the relevant code — routes, controllers, models, services, tests.
2. Understand the execution path from entry point to the affected layer.
3. Identify what already exists that can be reused.
4. Confirm the root cause before proposing a fix.

Do not read a file name and assume you understand the code inside it.

## Non-negotiable rules

- **Find root causes.** Trace execution, do not patch symptoms.
- **Reuse first.** Find existing models, scopes, services, actions, traits, helpers, DTO, and components before creating new ones.
- **Preserve contracts.** Do not change method signatures, permission gates, API responses, or public interfaces without explicit authorization.
- **Minimum scope.** Do not add migrations, dependencies, schema changes, or refactors beyond the stated task.
- **No cosmetic cleanup.** Do not reorganize unrelated code unless authorized.
- **Test what you change.** Write or run tests for the modified behavior. Distinguish PASS, FAIL, NOT RUN, BLOCKED.

## Quality checklist before finishing any task

- [ ] No N+1 queries introduced (use eager loading; verify with query logs or `telescope`)
- [ ] No duplicate logic (single source of truth for business rules)
- [ ] Authorization verified on every new endpoint or action
- [ ] Input validated at system boundaries (requests, jobs, external APIs)
- [ ] No secrets, tokens, or credentials in code or committed files
- [ ] Static analysis clean (`./vendor/bin/phpstan`, `./vendor/bin/pint`, or equivalent)
- [ ] Relevant tests passing

## Security rules

- Every HTTP action must check authorization: `$this->authorize()`, `Gate::check()`, `Policy`.
- Multi-tenant: always scope queries to the authenticated organization/tenant. Never expose cross-tenant data.
- Never expose raw database IDs where UUIDs or hashed IDs are expected.
- File uploads: validate MIME type server-side, store outside webroot, never execute uploaded content.
- No `eval()`, no `shell_exec()` with user input, no raw SQL with interpolated variables.

## Audit output format

When auditing, structure findings as a table:

| # | Finding | Evidence (file:line) | Impact | Priority | Proposed Fix | Risk |
|---|---------|---------------------|--------|----------|--------------|------|

Label each finding:
- `CONFIRMED` — verified by reading the code
- `HYPOTHESIS` — plausible but not yet traced
- `NOT VERIFIED` — requires additional investigation

## Commit discipline

- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
- Run `git diff --cached` before every commit
- Never include pre-existing unstaged work in your commits
- No `--no-verify`, no `push --force` to main/master
- No empty commits

## Specialized delegation

For deep audits, delegate to specialized agents rather than loading full context:

| Task | Agent | Activation |
|------|-------|-----------|
| Architecture / dependency analysis | architect | `@architect` |
| Security audit | security | `@security` |
| N+1 / query performance | performance | `@performance` |
| Pre-commit change review | reviewer | `@reviewer` |

## Context management

Keep CLAUDE.md files concise. Procedure-heavy workflows belong in skills, not in always-loaded instructions.

Use `/code-review` for detailed code review.
Use `/claude-security` for security audit workflow.
Use `/simplify` for simplification pass.
Use `/commit-commands` for commit workflow.

## What not to do

- Do not declare a test passed without running it.
- Do not invent CLI flags, config options, hooks, or capabilities.
- Do not expose `.env`, credentials, API keys, or secrets.
- Do not run `rm -rf`, `DROP TABLE`, `git reset --hard`, or `git push --force` without explicit authorization.
- Do not add migrations, dependencies, or schema changes beyond the task scope.
- Do not merge unrelated changes into the same commit.
