---
description: Structured audit of a module. Launches specialized agents for the dimensions actually needed. Argument: path or module name.
---

# Module Audit

Structured audit of a specific module or directory before making significant changes.

## When to use

Use this skill when you need a multi-dimensional pre-change audit: a module is unfamiliar, touches security-sensitive operations, or the blast radius of a change is unknown.

- For structure only → `@architect` directly
- For a targeted security question → `@security` directly
- For a targeted performance question → `@performance` directly
- For a quick pre-commit check → `/pre-commit-review`

## Steps

1. **Scope the module**: identify the entry points, public interface, and direct dependencies. Determine which audit dimensions are relevant.

   | Module characteristic | Dimensions needed |
   |----------------------|------------------|
   | Data access, external calls, jobs | performance |
   | Auth, user input, sensitive data | security |
   | Multiple layers, circular deps, coupling | architecture |
   | Pre-change audit of an unfamiliar module | all relevant |

2. **Delegate to the relevant agents** (only those identified in step 1):

   - `@architect` — map execution flow, identify coupling and misplaced responsibilities
   - `@security` — verify authorization on state-changing operations, input validation, data exposure
   - `@performance` — find N+1 patterns, missing indexes, unbounded queries, redundant calls

3. **Synthesize findings**:
   - Collect CONFIRMED findings across the invoked agents
   - Rank by: CRITICAL security > CONFIRMED performance > CONFIRMED architecture > HYPOTHESES
   - Propose fixes only for CONFIRMED findings
   - Mark HYPOTHESES as requiring further investigation before acting

## Output

| # | Finding | Agent | File:Line | Category | Severity | Status | Proposed Fix |
|---|---------|-------|-----------|----------|----------|--------|--------------|

Then a risk summary: what is safe to change, what requires caution, what requires explicit approval.

## What not to do

- Do not invoke all three agents if the question only concerns one dimension
- Do not propose changes based solely on HYPOTHESIS findings
- Do not refactor code outside the audited module's boundaries
