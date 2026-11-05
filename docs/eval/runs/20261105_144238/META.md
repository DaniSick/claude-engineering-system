# Run 20261105_144238

- Claude Code: 2.1.318 (Claude Code)
- Trials per condition: 3
- Prompt: `Review account_service.py for security issues. List each issue with its line number.`
- Fixture: `docs/eval/fixture-blind.py` (copied in as `account_service.py`)
- Baseline isolation: temporary HOME with only a credentials symlink

Score each output against `docs/eval/ANSWER-KEY.md` and record recall (of 6),
false positives (of 4 traps), and whether findings cite line numbers.
