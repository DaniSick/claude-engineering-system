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

---

## Run 20261105_145852 — ablation

**Question**: do the five sections hypothesized redundant with frontier-model defaults carry
any measurable weight? Variant under test: `docs/eval/variants/trimmed.md`, which drops
"Detect before assuming", "UI/UX tasks", "Investigate before modifying" steps 1–4, "Security
rules", and "What not to do" — 729 tokens, 17% of the file. Everything the Mode precedence rule
references is retained.

Three conditions, 3 trials each, scored with `scripts/score-eval.sh`.

| Condition | Format score | Core recall |
|---|---|---|
| baseline (no config) | 1.0 / 5 | 6 / 6 |
| variant (trimmed) | 3.7 / 5 | 6 / 6 |
| system (full) | 4.3 / 5 | 6 / 6 |

### The result is inconclusive, and the reason matters

The same `system` condition scored **5.0** in run 20261105_144238 and **4.3** here. That
run-to-run variance (0.7) is **larger than the measured gap between full and trimmed** (0.6).
At n=3 this experiment cannot separate signal from noise, and no conclusion about the trim
should be drawn from the headline means.

### What the per-marker breakdown does show

| Marker | Specified in `CLAUDE.md`? | Configured conditions, both runs |
|---|---|---|
| Findings table | Yes, explicitly | **9 / 9** |
| `CONFIRMED` / `NOT VERIFIED` labels | Yes, explicitly | **9 / 9** |
| Explicit negative findings | No — emergent | 3/3, then 1/3, then 0/3 |
| Scope caveats | No — emergent | 3/3, 3/3, 2/3 |

**Explicitly instructed output conventions held at 100% in both the full and trimmed files.
Emergent ones were volatile in every condition, including the full one.** The 0.6 gap sits
entirely in markers that no section specifies — including the sections the trim removed.

Note that "state what you examined rather than declaring a surface clean" is specified in
`agents/security.md`, which was never loaded in these runs because no agent was invoked. Its
volatility is therefore expected: nothing in the loaded context asked for it.

### Practical read

The trim did not measurably harm anything the file actually instructs. That is weaker than
"the trim is safe" — n=3 cannot establish that — but it is the honest state of the evidence:

- **Recall**: unaffected (6/6 everywhere, though the fixture is saturated and cannot discriminate).
- **Instructed format conventions**: unaffected (9/9 both conditions).
- **Emergent conventions**: noisy everywhere; the gap is not attributable to the trim.

Resolving this properly needs roughly n=10 per condition — about 30 sessions. Whether that is
worth 729 tokens per turn is a cost judgment, not a technical one.

---

## What these runs do and do not establish

**Establishes**:

- The harness works and the baseline isolation is sound.
- Configured vs. unconfigured is a large, consistent effect on report structure: baseline scored
  1.0 and 1.7 across two runs; every configured condition scored 3.7–5.0. That gap reproduced.
- Output conventions the file states explicitly are followed reliably (9/9); conventions it only
  implies are not (volatile in every condition).
- The current fixture is saturated and cannot measure detection ability.

**Does not establish**:

- That the system improves engineering outcomes on real tasks. The headline claim is still unvalidated.
- That the 17% trim is safe, or that it is harmful. The experiment is underpowered at n=3.

**Methodological lesson for anyone extending this**: measure run-to-run variance of a single
condition before interpreting a between-condition gap. This ablation would have looked like a
clean 0.6-point degradation had the earlier run not happened to provide a variance estimate.

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

---

## Run 20261105_151827 — multi-file fixture

First run against `docs/eval/fixture-app/` (18 files, 1,277 lines), built so that every planted
flaw requires connecting two or more files. Scored against `ANSWER-KEY-APP.md`. 3 trials per
condition.

### Individual flaws: still saturated

V1, V2b, V3, V4, V5 and V6 were found by all six runs. Making flaws cross-file did not make
them hard to find — once a reviewer reads the whole tree, a decorator bypass or a truthiness
bug is still visible. Both conditions also reported many unplanted real defects (replayable
transfer reversal, login-throttle lockout, cleartext reset tokens in the outbox), which means
the generated code contains genuine flaws beyond the six planted ones and the answer key is
incomplete by construction.

### The compound chain: the system did worse than the baseline

V2 was designed as the discriminating finding: `/users` exposes every email (low alone),
`password_reset` derives tokens from email with no secret (serious alone). Together, any member
takes over any account.

| Run | V2a — email exposure | V2b — forgeable token | Chain named | V2 score |
|---|:--:|:--:|:--:|:--:|
| baseline-1 | yes | yes | **yes** | **1.0** |
| baseline-2 | yes | yes | no | 0.5 |
| baseline-3 | yes | yes | no | 0.5 |
| system-1 | no | yes | no | 0.5 |
| system-2 | yes | yes | no | 0.5 |
| system-3 | no | yes | no | 0.5 |

**Baseline found the chain component 3/3; the configured system found it 1/3.** Only
`baseline-1` stated the connection outright: *"Together with issue 1, this hands an attacker
every email address they need for account takeover."* `system-2` found both halves and left
them as unrelated rows at P0 and P2 — the exact 0.5 case the answer key anticipated.

### Why, most likely

Baseline reports ran 56–78 lines; configured reports ran 24–40. The audit table scores 4.7/5 on
report discipline and is genuinely better structured — but **a table is a list of independent
rows and has no slot for "this one combines with that one."** The compression the format rewards
appears to suppress exactly the connective reasoning a compound chain needs, and to push
low-severity findings out of the report entirely — and low-severity findings are the raw material
of chains.

This is a defect in the system, found by measuring it. `global/CLAUDE.md` now requires a
compound-chain pass after the table, with chains reported as their own entries at combined
severity, and an explicit instruction never to drop a finding for looking minor alone.

### Caveats

n=3. The chain result on its own (1/3 vs 0/3) is within noise. The V2a result (3/3 vs 1/3) is
the firmer signal, and it points the same direction. Re-running after the format change is the
obvious next step, and it would be the first eval here to test a fix rather than a hypothesis.

### Scorer correction

`score-eval.sh` under-counted the "explicit negative findings" marker: its pattern missed
"checked and found sound" and "correctly allowlists", so `system-2` and `system-3` were scored 4
when they belonged at 5. Corrected; the table above reflects the fixed scorer. Earlier runs in
this document were scored with the narrower pattern and may be similarly conservative.
