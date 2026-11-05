# Eval results

## Run 20261105_144238

**Setup**: 3 trials per condition, identical prompt, identical fixture.
Baseline ran in a temporary `HOME` containing only a credentials symlink — no global
`CLAUDE.md`, no agents, no skills. System ran in the real `HOME` with this repository
deployed. Claude Code 2.1.87, model as configured by default in each session.

Prompt: `Review account_service.py for security issues. List each issue with its line number.`

### Detection: no measurable difference

| Core finding | base-1 | base-2 | base-3 | sys-1 | sys-2 | sys-3 |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| SQL injection (`find_by_username`) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Hardcoded secret (`SIGNING_KEY`) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Password written to logs | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Missing authorization — write | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Broken object-level auth — read | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Command injection + traversal | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| **Recall (of 6)** | **6** | **6** | **6** | **6** | **6** | **6** |
| Bonus: weak password hashing | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| False positives (of 4 traps) | 0 | 0 | 0 | 0 | 0 | 0 |
| Total findings reported | 13 | 13 | 11 | 12 | 13 | 11 |

**Recall is saturated at 6/6 in both conditions.** The fixture does not discriminate: a current
frontier model finds all six planted vulnerability classes in a single-file target without any
configuration assistance. Neither condition produced a false positive on any of the four traps,
and every run also caught the unscored bonus finding.

**On this evidence, the system produced no improvement in vulnerability detection.**

### Output conformance: consistent difference

The difference that did appear is in report structure, and it was consistent across all three
trials per condition.

| Property | Baseline (3/3) | System (3/3) |
|---|---|---|
| Audit table from `global/CLAUDE.md` | no — prose with severity headings | yes, exact column set |
| `CONFIRMED` / `NOT VERIFIED` status labels | no | yes |
| Explicit "what I checked and found safe" | 1 of 3 (partial) | 3 of 3 |
| Scope caveats (uncheckable callers, unswept refs) | 1 of 3 | 3 of 3 |
| Test-status label (`NOT RUN`) | 0 of 3 | 1 of 3 |
| Fix sequencing / ordering | 0 of 3 | 2 of 3 |

The system condition reproduced the audit format specified in `global/CLAUDE.md` — including the
status vocabulary and the instruction to state what was examined rather than declaring a surface
clean. The baseline wrote good prose reports but did not volunteer negative findings or scope
limits as reliably.

Whether that structure is worth ~4,231 tokens per turn is a judgment call this eval does not
settle. It is a real, reproducible difference; it is not a detection improvement.

### Corrections to the answer key

Two entries in `ANSWER-KEY.md` were wrong when written, and the runs exposed them:

1. **`list_recent_signups` was listed as a safe trap. It is not.** Two baseline runs correctly
   identified that a negative `limit` passes the `if limit > 1000` cap, and SQLite treats a
   negative `LIMIT` as unbounded — the whole table is returned. `days` is also unbounded. This
   is a genuine seventh vulnerability that was planted accidentally.
2. **`deactivate_account` holds an adjacent real issue.** The authorization check itself is
   correct (the trap stands as written), but `find_by_id` does not filter on `active`, so a
   deactivated admin retains the ability to deactivate others. One baseline run found this.

Both are now reflected in the answer key.

## What this run does and does not establish

**Establishes**: the harness works, isolation is sound, and the system reliably changes report
structure. Also that the current fixture is too easy to measure detection ability.

**Does not establish**: that the system improves outcomes on real tasks. The headline claim
remains unvalidated.

## Next fixture, if this is pursued

Discriminating on detection requires a target where a competent single-pass review plausibly
misses something:

- **Multi-file**, so the vulnerability lives in the interaction between files rather than in one
  visible function — e.g. a check in a decorator that a second code path bypasses.
- **A compound chain**: two individually-low findings that combine into a high one. This is what
  `@security-logic` exists for and what a single pass most often misses.
- **Realistic ratio**: a few hundred lines of correct code per planted flaw, instead of a file
  that is roughly half vulnerabilities.
- **Measure turn count and tool calls**, not only recall, once recall stops being saturated.

Until such a fixture exists, the honest position is the one stated in the README: the design is
reasoned, the detection benefit is unmeasured.
