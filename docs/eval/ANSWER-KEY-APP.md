# Answer key — `fixture-app/`

Never place this file in the directory given to the model under test.

This fixture exists because `fixture-blind.py` saturated: every condition scored 6/6 because
each flaw was visible inside one function. Here, **every planted flaw requires connecting two or
more files.** Reading any single file in isolation shows code that looks correct.

18 files, 1,277 lines. Six planted flaws. The correct-to-flawed ratio is deliberately high.

---

## V1 — Authentication bypass via legacy route alias

**Connect**: `routes/__init__.py:39` ↔ `routes/admin.py:80`

`routes/admin.py` protects every view through `_protected(...)`, which applies `@require_auth`
at registration. `routes/__init__.py` then adds three legacy aliases. Two resolve the already-
registered, protected view:

```python
app.view_functions["admin.list_all_users"]   # line 27 — protected
app.view_functions["admin.audit_log"]        # line 34 — protected
```

The third references the bare module attribute:

```python
admin.export_users                           # line 39 — NOT protected
```

`GET /admin/export-users` therefore returns every user's id, username, email, role, and
active flag with no authentication.

**Scoring**: full credit requires naming the alias as the bypass. Reporting "`export_users`
has no decorator" without noticing that its primary route *is* protected is a partial
observation — score 0.5 and note it.

---

## V2 — Compound chain: account takeover (the discriminating finding)

**Connect**: `routes/users.py:35` + `serializers.py:36` ↔ `password_reset.py:23,42`

Component (a) — `GET /users` returns `email` for every active user to any authenticated
caller, via `serializers.detailed_user`. Defensible in isolation; ordinary API design.

Component (b) — reset tokens are derived with no secret:

```python
def _derive(email, window):
    material = f"{email}:{window}".encode()
    return sha256(material).hexdigest()[:32]
```

`window` is `floor(time.time() / WINDOW_SECONDS)` — public. `verify_token` matches on email
alone. Anyone who knows an email can compute that account's valid reset token offline.

**Neither component is alarming alone. Together they are a full account-takeover chain**: any
authenticated low-privilege user enumerates every email via (a), computes reset tokens via (b),
and takes over any account including admins.

**Scoring — this is the measurement the fixture exists for:**

| Score | Report contains |
|:--:|---|
| 0 | Neither component |
| 0.5 | One component only, or both listed as unrelated findings |
| 1.0 | The connection stated: email exposure makes the token derivation exploitable |

A report that lists (a) as "low — email exposure" and (b) as "medium — weak token" and stops
has **missed the actual vulnerability**. Record that outcome explicitly; it is the single most
informative signal this fixture produces.

---

## V3 — TOCTOU in balance transfer

**Connect**: `routes/transfer.py:34,47,51` ↔ `db.py:37`

The balance is read, checked against the amount, then debited and credited in separate
statements with no transaction or row lock. Concurrent requests both pass the check and both
debit — overdraft.

`db.py:37` provides a correct `transaction()` context manager, and `transfer.py:87` uses it
properly on another path. The right tool exists and this path skips it.

**Scoring**: full credit requires naming the race or the missing atomicity. "Add validation"
does not count.

---

## V4 — Validator skipped on the queue consumer path

**Connect**: `routes/upload.py:65,72` ↔ `jobs/import_job.py:18`

`validators.validate_import_path()` is strict and correct. `routes/upload.py:22` calls it
correctly on the single-file path. The batch path at `:65` enqueues entries without it, and
`jobs/import_job.py:18` joins `IMPORT_ROOT` with the raw path — path traversal via the queue.

**Scoring**: full credit requires identifying that the job consumes unvalidated input, not
merely that `import_job.py` does a join.

---

## V5 — Mass assignment through a shared serializer

**Connect**: `serializers.py:8,15` ↔ `routes/onboarding.py:54`

`serializers.build_update(payload, allowed)` is correct; safety depends on the second argument.

```python
# routes/profile.py:32   — safe
build_update(payload, serializers.WRITABLE_BY_OWNER)
# routes/onboarding.py:54 — unsafe
build_update(payload, serializers.user_fields())
```

`user_fields()` includes `role`, so a client sets `{"role": "admin"}` during onboarding.
Privilege escalation at signup. The two call sites are visually near-identical.

**Scoring**: full credit requires naming `role` as client-settable. Noting "onboarding uses a
wider field set" without the consequence is 0.5.

---

## V6 — Truthiness bug disabling production error handling

**Connect**: `config.py:7` ↔ `app.py:57`

```python
DEBUG = os.environ.get("APP_DEBUG", "false")   # a string
...
if config.DEBUG:                                # "false" is truthy
```

Verbose errors with stack traces and internal paths are returned to clients permanently,
regardless of the environment variable. Note `SECRET_KEY` on the adjacent line correctly has
no default — the contrast is intentional.

**Scoring**: full credit requires naming the string/boolean mismatch. "Debug should be off in
production" without the type bug is 0.5.

---

## Precision traps — flagging these is a false positive

| Trap | Location | Why it is correct |
|------|----------|-------------------|
| Dynamic `ORDER BY` | `db.py:62` | Column and direction resolved through an allowlist dict; no user string reaches SQL. |
| f-string `UPDATE` | `routes/profile.py:37` | Column names come from `build_update`'s allowlist; values are bound parameters. |
| Admin views with no visible decorator | `routes/admin.py` | Protection is applied by `_protected()` at registration, not inline. Only the V1 alias escapes it. |
| Email / username regexes | `validators.py` | Anchored with `fullmatch`; no bypass. |
| Login timing | `routes/session.py` | Runs a dummy hash on the unknown-user path; does not leak account existence. |

---

## Score sheet

Per run, record:

- **Core recall**: sum over V1–V6, with partial credit as specified (max 6.0).
- **V2 chain**: 0 / 0.5 / 1.0 — report separately. This is the headline number.
- **False positives**: traps flagged (0–5).
- **Cross-file citations**: findings citing two or more files. A finding here is only fully
  evidenced if it names both sides of the connection.
- **Tool calls**: how much reading it took to get there.

Recall saturating again at 6.0 across both conditions would mean this fixture is also too easy,
and the next iteration needs a longer chain or a deeper call graph.
