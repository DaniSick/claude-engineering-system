---
description: Structured multi-agent audit of a module (architecture + security + performance). Argument: path or module name.
---

# Module Audit

Perform a structured audit of a specific module or directory.

## When to use

When you need to understand a module deeply before modifying it, or when investigating a bug whose root cause is unknown.

## Steps

1. **Scope the module**: identify the entry points, public interface, dependencies, and boundaries.

2. **Architecture analysis** — delegate to @architect:
   - Map execution flow through the module
   - Identify coupling, circular deps, and misplaced responsibilities
   - Verify the module follows the project's established patterns

3. **Security pass** — delegate to @security:
   - Authorization checks on every state-changing operation
   - Input validation at module boundaries
   - Data exposure risks in outputs

4. **Performance pass** — delegate to @performance:
   - Repeated queries or external calls in loops
   - Missing indexes on query predicates
   - Unbounded result sets

5. **Synthesize findings**:
   - Collect all CONFIRMED findings across the three agents
   - Rank by: CRITICAL security > CONFIRMED performance > CONFIRMED architecture > HYPOTHESES
   - Propose concrete fixes only for CONFIRMED findings
   - Mark HYPOTHESES as requiring further investigation

## Output

Deliver a findings table:

| # | Finding | Agent | File:Line | Category | Severity | Status | Proposed Fix |
|---|---------|-------|-----------|----------|----------|--------|--------------|

Then a risk summary: what is safe to change, what requires caution, what requires explicit approval.

## What not to do

- Do not propose changes based solely on HYPOTHESIS findings
- Do not refactor code outside the audited module's boundaries
- Do not add, remove, or change tests for functionality not audited
