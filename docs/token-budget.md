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
| `global/CLAUDE.md` | 120 | 7.4 KB | ~2,150 |
| Mean `agents/*.md` | 100 | 5.5 KB | ~1,560 |
| Largest agent (`security-web.md`) | 145 | 7.8 KB | ~2,280 |
| Mean `.claude/commands/*.md` | 70 | 3.1 KB | ~890 |
| Largest skill (`ui-review.md`) | 124 | 6.2 KB | ~1,820 |

Permanent per-turn cost: **~2,150 tokens** from the global principles file.

A session that invokes two agents and one skill once each loads an additional ~4,000 tokens, but only on the turns where they fire.

## How savings happen

The system does not reduce input tokens compared to a blank Claude Code session — in fact, it adds ~1,300 permanent tokens. The savings are indirect:

1. **Fewer wasted turns.** The global principles file tells the model to detect the stack, trace root causes, and reuse existing code before writing new code. This cuts the common failure mode where the model asks obvious questions, scaffolds code that already exists, or edits the wrong file. One extra wasted turn costs 5,000–30,000 input tokens; the fixed ~2,150 pays for itself the first time it prevents one.
2. **Narrow agents instead of a wide context.** The specialized security and performance agents run with their own small prompt and read only the files relevant to one dimension. The alternative — asking the main session to do a security audit — pulls much more code into the main context and keeps it there for the rest of the conversation.
3. **Response modes.** `ferb` suppresses explanation. On a long debugging session this reduces assistant output tokens by roughly half compared to the default verbose style.
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

- One-off questions ("what does `uniq -c` do?"). The 2,150 tokens are wasted.
- Projects with a very small CLAUDE.md already present. The global file duplicates intent.
- Sessions that never invoke an agent or skill.

In those cases, disable the global principles file for the session by renaming `~/.claude/CLAUDE.md` or by using `--no-user-config` if your Claude Code version supports it.

## Notes

- `tiktoken` is a proxy for Anthropic's tokenizer. For Claude 4+ models the real token count is within roughly 5–10% of cl100k_base for English and code.
- These numbers describe the *input* prompt. Output tokens are a function of the task and are not controlled by this system.
