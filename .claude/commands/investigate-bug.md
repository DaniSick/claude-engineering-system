---
description: Root cause analysis workflow. Argument: bug description or reproduction steps.
---

# Investigate Bug

Structured root cause analysis for a reported bug or unexpected behavior.

## When to use

When a bug is reported and the cause is not immediately obvious, or when a fix was attempted and the bug recurred.

## Steps

1. **Reproduce the behavior**: identify the exact input, conditions, and observed output that demonstrate the bug. If the reproduction steps are not provided, ask for them before proceeding.

2. **Trace the execution path**:
   - Start from the entry point (HTTP request, CLI command, job trigger, event)
   - Follow the code path step by step to where the behavior diverges from expected
   - Note every branch, conditional, or early return that could alter the path

3. **Identify the failure point**:
   - Find the exact line where incorrect data is produced, wrong decision is made, or exception originates
   - Distinguish between the origin (root cause) and the symptom (where the error surfaces)

4. **Check for related issues**:
   - Is the same logic duplicated elsewhere? Is the bug there too?
   - Are there other callers of the failing component that might exhibit the same issue?
   - Does a test cover this path? If so, why did it not catch this?

5. **Propose a minimal fix**:
   - Target the root cause, not the symptom
   - State what the fix changes and why it resolves the root cause
   - State what it does NOT change (preserved behavior, preserved contracts)
   - Describe the test that would confirm the fix and prevent regression

## Output format

**Reproduction**: [exact steps or conditions]

**Execution trace**: [file:line → file:line → ... → failure point:line]

**Root cause**: [one-sentence statement of what is wrong and where]

**Symptom vs cause**: [how they differ if they differ]

**Proposed fix**: [file:line — what changes and why]

**Test**: [what to verify — new test or modified existing test]

**Risk**: [what else could be affected by this fix]

## What not to do

- Do not propose a workaround that bypasses the root cause
- Do not propose multiple alternative fixes — pick the best one and justify it
- Do not modify code outside the minimal blast radius of the fix without authorization
- Do not declare the bug fixed without describing a reproducible verification
