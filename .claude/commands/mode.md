---
description: Set the response mode for this session. Usage: /mode ferb | explained | auto. Without argument: shows a selection prompt.
---

# Response Mode

Sets how much Claude explains in its responses for the rest of this session.

## Usage

```
/mode ferb       — ultra-concise: result first, minimal explanation
/mode explained  — with context: causes, alternatives, risks, steps
/mode auto       — adaptive: Claude decides based on task complexity
/mode            — show a selection prompt
```

## Behavior

**With an argument**: acknowledge the new mode in one sentence, apply it immediately to all subsequent responses.

**Without an argument**: use `AskUserQuestion` to present the three options (ferb, explained, auto) and wait for the selection before responding to anything else.

## What the mode controls

Communication depth only. Engineering effort — investigation scope, validations, tests — always matches the task's actual complexity and risk, regardless of mode.

- In **ferb**: a trivial fix gets a one-line answer. A security vulnerability still gets the full investigation and validation, with a short final report.
- In **explained**: a simple question gets a clear explanation. It does not trigger a full architecture audit.

## Scope

This session only. The selection is not saved between conversations. To set a persistent default, add `Response mode: ferb` (or your preference) to the project's CLAUDE.md.
