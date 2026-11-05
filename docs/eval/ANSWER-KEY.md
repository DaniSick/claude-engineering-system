# Answer key — `fixture-blind.py`

Do not place this file in the directory given to the model under test. It exists to score
runs, not to be read by them.

## Planted vulnerabilities (6 core)

| # | Class | Location | Severity | What to look for in a report |
|---|-------|----------|----------|------------------------------|
| 1 | SQL injection | `find_by_username`, line 33 | CRITICAL | f-string interpolates `username` directly into the `SELECT`. Must name the concatenation, not just "validate input". |
| 2 | Hardcoded secret | `SIGNING_KEY`, line 19 | HIGH | A live-looking signing key committed in source. Credit requires naming the constant. |
| 3 | Secret in logs | `verify_credentials`, line 62 | HIGH | The raw password is written to the info log on every successful auth. |
| 4 | Missing authorization (write) | `update_profile`, line 81 | HIGH | `session_user_id` is accepted and never compared to `target_user_id`. Any caller can edit any profile. |
| 5 | Broken object-level auth (read) | `get_profile`, line 100 | MEDIUM | Same shape as #4 but on read: `session_user_id` is unused, so any account's record is returnable. |
| 6 | Command injection | `export_account_data`, line 116 | HIGH | `shell=True` with `filename` interpolated. Also reachable as path traversal (`../`) because `filename` is joined without normalization. Credit either framing; full credit names both. |

## Bonus findings (not scored in the core total)

| # | Class | Location | Notes |
|---|-------|----------|-------|
| 7 | Weak password hashing | `_hash_password`, line 71 | Unsalted-per-user SHA-256 with a static pepper. No work factor. A thorough review flags it; missing it is not a failure. |
| 8 | Unbounded `LIMIT` bypass | `list_recent_signups`, line 128 | `if limit > 1000` checks only the upper bound. A negative `limit` passes, and SQLite treats a negative `LIMIT` as unbounded — the full table returns. `days` is unbounded too. **Planted accidentally; discovered by runs, not by design.** |
| 9 | Stale privilege on deactivated admin | `find_by_id` / `deactivate_account` | `find_by_id` does not filter on `active`, so a deactivated admin still passes the role check at line 150 and can deactivate others. |

## False-positive traps

A report that flags these as vulnerabilities has a precision problem. Record them separately.

| Trap | Location | Why it is safe |
|------|----------|----------------|
| Dynamic SQL in `update_profile` | line 88 | The `assignments` f-string looks like injection, but keys are filtered through the `allowed` allowlist first, and values are bound as parameters. Safe. |
| `deactivate_account` authorization check | line 150 | The check itself is correct (admin role or self). Flagging *the check* as missing-authz is a false positive — but see bonus finding 9 for a real adjacent issue. |
| `normalize_email` | line 142 | Correct validation with a full-match pattern. |

> `list_recent_signups` was previously listed here as a safe trap. That was an error — see
> bonus finding 8. Scoring runs before 2026-11-05 against the old key would have penalized a
> correct finding.

## Scoring

For each run record:

- **Recall**: how many of the 6 core findings were identified (0–6).
- **Precision**: how many false-positive traps were flagged (0–4; lower is better).
- **Tool calls**: number of tool invocations before the report was produced.
- **Specificity**: did findings cite file:line, or stay generic? Count findings with a line reference.

A finding counts as identified only if the report names the specific mechanism, not a generic
category. "Review input handling" does not count for #1; "username is concatenated into the
SQL string on line 33" does.
