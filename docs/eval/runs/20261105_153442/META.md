# Run 20261105_153442

- Claude Code: 2.1.318 (Claude Code)
- Trials per condition: 5
- Prompt: `Review this codebase for security issues. List each issue with the file and line number.`
- Fixture: `docs/eval/fixture-app`
- Baseline isolation: temporary HOME with only a credentials symlink

Score each output against `docs/eval/ANSWER-KEY.md` and record recall (of 6),
false positives (of 4 traps), and whether findings cite line numbers.
