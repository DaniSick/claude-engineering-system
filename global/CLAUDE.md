# Engineering Principles — Personal Configuration

## Detect before assuming

Read the project's technology before applying any rule. Identify the language, framework, build system, database, and test tooling from the actual files. Do not assume a stack.

## Effort proportional to problem

Before acting, assess: what does the user need, what's the minimum sufficient scope, what can go wrong?

- **Light** — typo, label, explanation, isolated one-file fix: read only what's needed, make the change, verify. Skip planning and agents.
- **Normal** — feature addition, multi-file bug, test changes: inspect the affected flow and its direct dependencies, run the relevant tests, review the diff.
- **Deep** — architecture changes, security issues, auth/authorization, data migrations, cross-cutting refactors: trace root causes, map affected boundaries, use agents when they bring a distinct perspective unavailable in the main session.

Start at the lowest level that's reliable. Escalate when unknown dependencies surface, effects cross boundaries, or evidence contradicts the initial read. Don't escalate just because multiple files are involved.

## Investigate before modifying

For trivial changes (typo, label, isolated single-line fix): confirm the location, make the change, verify. Skip the steps below that don't apply.

For everything else, before editing any file:
1. Read the relevant code — entry points, modules, interfaces, data models, and tests.
2. Trace the execution path from the trigger to the affected component.
3. Identify what already exists that can be reused.
4. Confirm the root cause before proposing a fix.

Do not read a file name and assume you understand the code inside it.

## Non-negotiable rules

- **Find root causes.** Trace execution; do not patch symptoms.
- **Reuse first.** Find existing components, abstractions, utilities, and patterns before adding new ones.
- **Preserve contracts.** Do not change public interfaces, API responses, permissions, or observable behavior without explicit authorization.
- **Minimum scope.** Do not add dependencies, schema changes, or refactors beyond the stated task.
- **No cosmetic cleanup.** Do not reorganize unrelated code unless authorized.
- **Test what you change.** Run or write tests for modified behavior. Label results as PASS, FAIL, NOT RUN, or BLOCKED.

## Quality checklist (apply items relevant to the change scope)

- [ ] No unnecessary repeated calls to external systems (N+1, redundant requests, duplicate queries)
- [ ] No duplicate logic — single source of truth for business rules
- [ ] Authorization verified on every new action that modifies state or reads sensitive data
- [ ] Input validated at system boundaries (HTTP, jobs, external APIs, CLI arguments)
- [ ] No secrets, tokens, or credentials in code or committed files
- [ ] Static analysis and linting clean (use the appropriate tool for the project's language)
- [ ] Relevant tests passing

## Security rules

- Every action that modifies state or reads sensitive data must verify authorization before executing.
- When the system is multi-tenant, always scope data access to the authenticated context. Never expose cross-tenant data.
- Validate and sanitize all user-controlled input before using it in queries, commands, file paths, or output.
- Never execute user-supplied content, deserialize untrusted data without schema validation, or pass user input to system calls.
- File uploads: validate type server-side, store outside the public root, never execute uploaded content.
- No secrets, API keys, passwords, or tokens hardcoded in source or config files that are committed.

## Audit output format

Structure findings as a table:

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

Delegate to specialized agents when the task requires distinct expertise on an independent dimension and the benefit justifies the coordination cost. For localized or simple work, inspect directly.

| Task | Agent |
|------|-------|
| Architecture and dependency analysis | `@architect` |
| Security audit | `@security` |
| Performance and query analysis | `@performance` |
| Pre-commit change review | `@reviewer` |

## What not to do

- Do not declare a test passed without running it.
- Do not invent CLI flags, config options, hooks, or API capabilities.
- Do not expose `.env`, credentials, API keys, or secrets.
- Do not run destructive commands (delete, drop, reset, force-push) without explicit authorization.
- Do not add schema migrations, external dependencies, or configuration changes beyond the task scope.
- Do not merge unrelated changes into the same commit.
