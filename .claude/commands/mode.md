---
description: Set the response mode for this session. Usage: /mode ninja | ferb | surgical | blueprint | explained | auto. Without argument shows a selection prompt.
---

# Response Mode

Switches how verbose Claude is AND, for the saver modes, how aggressively it cuts tool and agent cost.

## Usage

```
/mode ninja      — maximum compression: diff + one-line outcome, zero prose
/mode ferb       — strategic saver: result first, ≤3-line explanation, no re-reads
/mode surgical   — minimum reads: one file, one zone, no agents, no exploration
/mode blueprint  — plan first (3-5 bullets) → wait OK → execute in ferb
/mode explained  — causes, alternatives, risks, reproducible steps
/mode auto       — adapt per task
/mode            — show a selection prompt
```

## Behavior

**With an argument**: acknowledge the new mode in one sentence, apply it immediately to all subsequent responses.

**Without an argument**: use `AskUserQuestion` to present the six options and wait for the selection before responding to anything else.

## Picking the right mode

| Situation | Mode |
|-----------|------|
| Typo, label, one-line fix in a known file | `surgical` |
| Normal task, you know the shape | `ferb` |
| You read diffs directly, want pure signal | `ninja` |
| Multi-file, unclear, risky, or hard to reverse | `blueprint` |
| Learning, design decisions, want context | `explained` |
| Mixed session, don't want to pick each time | `auto` |

## What the saver modes actually do

They are not just "shorter text". The rules in `global/CLAUDE.md` require:

- No announcing before tool calls.
- No re-reading files already in context.
- `grep` / `find` to locate before opening a file end-to-end.
- One progress update per task, not per step.
- No decision surveys — pick and go.
- Batch all pending questions into a single `AskUserQuestion` block.
- No agents for `light` or `normal` tasks.
- No restating the user's prompt or the tool's output.
- No filler words.

`ninja` goes further: zero prose during work, final response is diff + one line.
`surgical` goes further on reads: one file, one zone, no exploration.
`blueprint` goes further on direction: plan phase before any edit, to avoid rework.

## What the mode never changes

Engineering effort — investigation scope, validations, tests, security checks — always matches the task's actual risk and complexity, regardless of mode.

- In `ninja` or `ferb`: a trivial fix gets a one-line answer. A security vulnerability still gets the full trace and validation, with a terse final report.
- In `explained`: a simple question gets a clear explanation. It does not trigger a full architecture audit.

## Scope

Current conversation only. The selection is not saved between sessions. To set a persistent default, add `Response mode: ferb` (or your preference) to the project's `CLAUDE.md`.
