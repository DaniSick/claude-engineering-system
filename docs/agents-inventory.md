# Agents Inventory

All agents are read-only unless explicitly noted. Deploy with `bash scripts/setup.sh`.

## Custom agents (this system)

### architect
**File**: `agents/architect.md` → `~/.claude/agents/architect.md`
**Activation**: `@architect <question or path>`
**Purpose**: Architecture analysis — module boundaries, execution flow, dependency violations, coupling issues
**Output**: ASCII dependency map + findings table (CONFIRMED / HYPOTHESIS)
**Constraints**: Read-only. Never modifies files. Cites file:line for every claim.
**When to use**:
- "How does the payment module connect to billing?"
- "Is there circular dependency between these services?"
- "What calls this method?"
- Before a major refactor to understand blast radius

### security
**File**: `agents/security.md` → `~/.claude/agents/security.md`
**Activation**: `@security <controller, module, or concern>`
**Purpose**: Security audit — auth, authorization, injection, data exposure, CSRF, XSS, secrets, multi-tenant isolation
**Output**: Findings table with CWE, severity (CRITICAL/HIGH/MEDIUM/LOW)
**Constraints**: Read-only. Does not access `.env` or credentials. Cites file:line.
**When to use**:
- Before merging an auth or permission change
- "Is there IDOR risk in this endpoint?"
- "Does this query scope to the correct tenant?"
- After adding a new file upload feature

### performance
**File**: `agents/performance.md` → `~/.claude/agents/performance.md`
**Activation**: `@performance <file, controller, or module>`
**Purpose**: Performance analysis — N+1, missing indexes, redundant queries, cache misses, unbounded collections
**Output**: Findings table with category and estimated impact
**Constraints**: Read-only. Requires migration files to confirm index presence.
**When to use**:
- "This endpoint is slow, find why"
- After adding a new list/dashboard page
- Before a high-traffic feature goes to production
- "Does this query have N+1?"

### reviewer
**File**: `agents/reviewer.md` → `~/.claude/agents/reviewer.md`
**Activation**: `@reviewer` or `@reviewer check the current diff`
**Purpose**: Pre-commit change review — regressions, broken contracts, scope violations, missing tests, concrete defects
**Output**: Findings table with category and severity (BLOCKER/HIGH/MEDIUM/LOW/NIT)
**Constraints**: Read-only. Reports only evidence-backed findings.
**When to use**:
- Before every PR (especially for complex changes)
- "Is this diff safe to merge?"
- After refactoring shared utilities
- When a change touches multiple layers

## Marketplace agents/skills (pre-installed)

Available via `/skill <name>` — no setup required:

| Skill | Activation | Purpose |
|-------|-----------|---------|
| code-review | `/code-review` | Full code review with findings report |
| claude-security | `/claude-security` | Security audit workflow |
| pr-review-toolkit | `/skill pr-review-toolkit` | PR review with inline GitHub comments |
| code-modernization | `/skill code-modernization` | Modernization audit |
| code-simplifier | `/simplify` | Simplification and cleanup pass |
| feature-dev | `/skill feature-dev` | Feature development workflow |
| commit-commands | `/skill commit-commands` | Structured commit workflow |
| hookify | `/skill hookify` | Hook configuration assistant |
| skill-creator | `/skill skill-creator` | Create new custom skills |

## Agent vs skill: when to use which

Use a **custom agent** (`@architect`, `@security`, etc.) when:
- You want an isolated analysis that doesn't load into the main session context
- The analysis is deep and the agent instructions need to be precise
- You want the result without the agent's reasoning polluting your context

Use a **marketplace skill** (`/code-review`, etc.) when:
- You want a full interactive workflow in the current session
- The skill includes multi-step procedures or structured output
- You want to use a pre-tested workflow without writing agent instructions
