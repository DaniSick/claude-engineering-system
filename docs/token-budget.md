# Token Budget

This document records what the system costs in input tokens per session, and how to measure it yourself. The "token saver" claim in the README is only credible if it can be reproduced.

## What counts as the system's token cost

Every Claude Code session loads global configuration into the system prompt. For this repository, the loaded surface is:

| Component | File | When it is loaded |
|-----------|------|-------------------|
| Global principles | `~/.claude/CLAUDE.md` | Every session, every turn |
| Agent definition | `~/.claude/agents/<name>.md` | Only when the agent is invoked (`@name` or `subagent_type: name`) |
| Skill body | `~/.claude/commands/<name>.md` | Only when the skill is invoked (`/name`) |
| Hook script | `~/.claude/hooks/secret-scan.py` | Not loaded into context; executed by the harness |
| Permissions | `~/.claude/settings.json` | Permission names are not part of the LLM prompt |

The permanent cost per turn is `CLAUDE.md`. Agents and skills are on-demand — their size matters when they fire, not between.

## Current measurements

Run `bash scripts/measure-tokens.sh` for an up-to-date count. The reference figures below were produced by that script using a bytes/3.5 heuristic; install `tiktoken` to get a tokenizer-based count (`pip install tiktoken`).

| Surface | Lines | Bytes | Approx tokens |
|---------|------:|------:|--------------:|
| `global/CLAUDE.md` | 219 | 14.8 KB | ~4,231 |
| Mean `agents/*.md` | 100 | 5.5 KB | ~1,575 |
| Largest agent (`security-web.md`) | 145 | 8.0 KB | ~2,276 |
| Mean `.claude/commands/*.md` | 75 | 3.4 KB | ~969 |
| Largest skill (`ui-review.md`) | 124 | 6.4 KB | ~1,818 |

Permanent per-turn cost: **~4,231 tokens** from the global principles file.

_Last measured: 2026-11-05 with `scripts/measure-tokens.sh` (bytes/3.5 heuristic). Re-run after any edit to `global/CLAUDE.md` — this table goes stale silently._

The jump from ~3,786 to ~4,231 (+445) paid for the **Mode precedence** rule, which resolves six
documented contradictions between the response modes and the safety triggers. Contradictory
instructions are a known degradation mode — the model resolves them arbitrarily — so the trade
is judged worthwhile. Like everything else in this document's benefit column, that judgment is
reasoned, not measured.

A session that invokes two agents and one skill once each loads an additional ~4,000 tokens, but only on the turns where they fire.

The permanent cost went up (+880 tokens vs. 0.2.0) because `global/CLAUDE.md` now carries the six response modes (`ninja`, `ferb`, `surgical`, `blueprint`, `explained`, `auto`) with the strategic rules that make the saver modes actually cheap. The expectation is that these rules save more tokens per task than they add per turn — see "How savings happen" below.

## How savings happen

The system does not reduce input tokens compared to a blank Claude Code session — in fact, it adds ~1,300 permanent tokens. The savings are indirect:

1. **Fewer wasted turns.** The global principles file tells the model to detect the stack, trace root causes, and reuse existing code before writing new code. This is intended to cut the common failure mode where the model asks obvious questions, scaffolds code that already exists, or edits the wrong file. A wasted turn in a mid-sized repo typically costs several thousand input tokens — enough that preventing one pays for the fixed ~4,231. **This break-even has not been measured on this system; it is the design rationale, not a result.** See "Validation status" below.
2. **Narrow agents instead of a wide context.** The specialized security and performance agents run with their own small prompt and read only the files relevant to one dimension. The alternative — asking the main session to do a security audit — pulls much more code into the main context and keeps it there for the rest of the conversation.
3. **Saver response modes with strategic rules, not just terse text.** The modes `ninja`, `ferb`, `surgical`, and `blueprint` each add concrete rules: no re-reading files in context, `grep`/`find` to locate before opening, no decision surveys, no agents for light or normal tasks, one update per task instead of per step, no filler words. Those rules cut both input and output tokens on every turn. `blueprint` additionally caps the cost of multi-file tasks by forcing a 3-5 bullet plan before any edit, which prevents the expensive case of discovering mid-execution that you were heading the wrong way.
4. **Read-only agents.** `architect`, `performance`, `reviewer`, and the `security-*` family cannot write files. The harness can and does short-circuit them when their analysis is enough, instead of letting a long edit cycle run.

None of this is magic. If the user asks a one-line question, this system costs more tokens than not having it. The gain shows up on tasks that would otherwise take several wrong turns.

## Measuring on your own repository

```bash
bash scripts/measure-tokens.sh
```

This prints a table with the token count of every file the system deploys, plus a per-turn and per-invocation summary.

The script uses `tiktoken` when available and falls back to a bytes-based heuristic (chars / 3.5) when it is not. The heuristic is within ~15% of a true tokenizer for English and code.

If you want exact Claude tokenization, run the Anthropic `count_tokens` API on each file; the script prints the exact `anthropic` command to use.

## When this system is a net cost

- One-off questions ("what does `uniq -c` do?"). The 4,231 tokens are wasted.
- Projects with a very small CLAUDE.md already present. The global file duplicates intent.
- Sessions that never invoke an agent or skill.

To run a session without the global principles file, use `claude --bare`, which skips `CLAUDE.md`
auto-discovery (among other startup work). Verify the flag's behavior on your version with
`claude --help`.

## Validation status

**No claim in this document has been empirically validated.** The token counts are measured;
the ROI argument is not. Specifically unverified:

- That the principles file prevents wasted turns at any particular rate.
- That saver modes reduce total session cost rather than shifting it.
- The per-wasted-turn cost figure used in the break-even reasoning.

`docs/eval-scenarios.md` specifies 22 scenarios but records zero runs. `docs/sec-fixture.py`
contains four planted vulnerabilities and has never been scored. Closing this gap is tracked
as the project's main open item — see the repository README.

## Notes

- `tiktoken` is a proxy for Anthropic's tokenizer; the bytes/3.5 fallback is rougher still.
  Treat every figure here as an estimate with unquantified error, not a precise count.
- These numbers describe the *input* prompt. Output tokens are a function of the task and are not controlled by this system.
