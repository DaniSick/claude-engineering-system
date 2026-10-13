---
description: Review the staged diff before committing. Runs quick checks and delegates to @reviewer.
---

# Pre-Commit Review

Review the current staged diff before committing. Delegates to @reviewer for a systematic check.

## When to use

Before every non-trivial commit, especially:
- Changes that touch multiple layers
- Changes to shared utilities or public interfaces
- Changes that add or modify authorization logic
- After a refactor

## Steps

1. Run `git diff --cached` to see the staged diff
2. Run `git status` to confirm only intended files are staged
3. Delegate to @reviewer: "check the current staged diff for blockers and regressions"
4. For each BLOCKER or HIGH finding: fix before committing
5. For MEDIUM and NIT findings: document or address in a follow-up
6. Confirm no secrets, credentials, or private config in the staged content
7. Commit with a conventional commit message

## Quick checks (run before @reviewer)

```bash
git diff --cached
git diff --check        # trailing whitespace
git status              # confirm only intended files are staged
```

## Commit message format

```
<type>(<scope>): <short description>

[optional body explaining why, not what]
```

Types: `feat` `fix` `refactor` `test` `docs` `chore` `perf` `ci`

## What not to do

- Do not commit with `--no-verify` to bypass hooks
- Do not stage unrelated files to make the diff "cleaner"
- Do not ignore BLOCKER findings
- Do not commit if `git diff --check` reports whitespace errors
