---
description: Behavior-preserving refactor checklist. Baseline tests, incremental steps, contract verification, reviewer pass.
---

# Safe Refactor

Structured workflow for refactoring code without breaking behavior.

## When to use

When a module needs structural improvement — not a bug fix, not a new feature — and behavior must be preserved exactly.

## Preconditions (verify before starting)

- [ ] The current behavior is tested. If not, write characterization tests first.
- [ ] The public interface (function signatures, return types, API responses, events) is documented or understood.
- [ ] The scope of the refactor is agreed: which files, which responsibilities.

## Steps

1. **Understand before changing**:
   - Read the module completely
   - List all callers of the components being refactored
   - Identify all tests that cover the refactored behavior
   - Run those tests: confirm they pass before you change anything

2. **Define the target structure**:
   - Describe what the code will look like after the refactor
   - Confirm the description preserves all existing contracts
   - Do not expand scope without authorization

3. **Refactor incrementally**:
   - Make one structural change at a time (move, rename, extract, inline)
   - Run the relevant tests after each change
   - Do not mix refactoring with behavior changes in the same step

4. **Verify contracts are preserved**:
   - Every public method that existed before still exists (or is replaced with a documented migration path)
   - Every API response, event, job payload, or CLI output that callers depend on is unchanged
   - Every permission or authorization check is still in place

5. **Verify with @reviewer**:
   - After completing the refactor, ask @reviewer to check the diff
   - Address any BLOCKER or HIGH findings before proceeding

## Output format

After completing each step, report:

| Step | Status | Notes |
|------|--------|-------|
| Tests baseline | PASS / FAIL / NOT RUN | [count passing] |
| Target structure defined | YES / NO | [brief description] |
| Refactoring complete | YES / PARTIAL | [what changed] |
| Tests after refactor | PASS / FAIL | [count passing] |
| Reviewer pass | CLEAR / FINDINGS | [findings if any] |

## What not to do

- Do not rename public interfaces without updating all callers
- Do not move authorization checks to a different point in the flow without re-verifying they still run before the action executes
- Do not add new behavior during a refactor
- Do not remove tests because they test implementation details — refactor the tests too
- Do not declare the refactor complete if any test that was passing before is now failing
