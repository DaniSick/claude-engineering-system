# [Project Name] — Claude Context

<!-- Copy this file to your project root as CLAUDE.md and fill in each section.
     Keep it concise: this file is loaded on every session. Move procedural details to
     .claude/commands/ or skills. Delete sections that don't apply. -->

## Stack

<!-- What technology actually runs in this project. Be specific enough to be useful. -->

- Language: <!-- e.g. TypeScript 5.x, PHP 8.3, Python 3.12 -->
- Runtime / Framework: <!-- e.g. Node 20 + Express, Laravel 11, Django 5 -->
- Database: <!-- e.g. PostgreSQL 16, MySQL 8, SQLite -->
- Build / Package: <!-- e.g. pnpm, Composer, Poetry -->
- Test tooling: <!-- e.g. PHPUnit, Vitest, pytest -->
- Static analysis: <!-- e.g. phpstan --level max, ESLint, mypy -->
- Containerization: <!-- e.g. Docker Compose, none -->

## Architecture

<!-- How the codebase is organized. Name the actual directories and layers. -->

Entry points:
- <!-- e.g. HTTP: routes/, controllers/, handlers/ -->
- <!-- e.g. CLI: commands/, bin/, cli/ -->
- <!-- e.g. Background: jobs/, workers/, queues/ -->

Layer structure:
- <!-- e.g. controllers/ → services/ → models/ -->
- <!-- e.g. handlers/ → domain/ → persistence/ -->

Key conventions:
- <!-- e.g. Business logic goes in services/, never in controllers or models -->
- <!-- e.g. All database access through a repository layer -->
- <!-- e.g. No direct framework calls below the application layer -->

## How to run things

```bash
# Start development server
# e.g. pnpm dev
# e.g. docker compose up && go run ./cmd/server
TODO

# Run tests
# e.g. pnpm test
# e.g. pytest -x
TODO

# Static analysis / lint
# e.g. pnpm lint
# e.g. mypy src/
TODO

# Format / fix
TODO
```

## Constraints

<!-- Things Claude must not do without explicit approval. -->

- Do not modify migrations without approval
- Do not add external packages without approval
- Do not change public API response structure without approval
- <!-- Add project-specific constraints here -->

## Known complexity

<!-- Warn Claude about non-obvious things it might get wrong. -->

- <!-- e.g. Payment processing is in app/Services/Stripe/ — never bypass it for direct API calls -->
- <!-- e.g. Multi-tenant scoping must use the TenantScope global scope — check it's applied -->
- <!-- e.g. The event system is custom, not the framework's built-in events -->

## Relevant agents for this project

<!-- Which global agents are most useful here. Adapt activation examples to this project. -->

- `@architect` — analyze module structure in [your main module dir]
- `@security` — review [auth-related directory]
- `@performance` — find redundant queries in [data access layer]
- `@reviewer` — check the current diff before committing
