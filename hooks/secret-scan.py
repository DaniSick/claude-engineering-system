#!/usr/bin/env python3
"""PreToolUse hook: warn when a git commit may stage credential-like content.

Input:  JSON from stdin (Claude Code hook protocol)
Output: JSON systemMessage warning if credentials detected, or silent exit 0
Effect: Non-blocking — never prevents the commit, only warns.
"""
import json
import re
import subprocess
import sys


CREDENTIAL_PATTERNS = [
    # key = value with a non-trivial value
    r'^\+.{0,40}(?:password|passwd|secret|api[_-]?key|private[_-]?key|access[_-]?token|auth[_-]?token)\s*[=:]\s*["\']?[^\s"\']{8,}',
    # Bearer tokens
    r'^\+.{0,10}Bearer\s+[A-Za-z0-9+/=_\-]{20,}',
    # AWS-style keys
    r'^\+.{0,10}(?:AKIA|ASIA)[A-Z0-9]{16}',
]


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, EOFError):
        sys.exit(0)

    if data.get("tool_name") != "Bash":
        sys.exit(0)

    command = data.get("tool_input", {}).get("command", "")
    if "git commit" not in command:
        sys.exit(0)

    try:
        result = subprocess.run(
            ["git", "diff", "--cached"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        diff = result.stdout
    except Exception:
        sys.exit(0)

    if not diff:
        sys.exit(0)

    hits = []
    for line in diff.splitlines():
        for pattern in CREDENTIAL_PATTERNS:
            if re.search(pattern, line, re.IGNORECASE):
                hits.append(line[:100])
                break
        if len(hits) >= 3:
            break

    if hits:
        preview = "\n".join(f"  {h}" for h in hits)
        msg = (
            "WARNING: staged diff may contain credentials.\n"
            f"{preview}\n\n"
            "Review with:  git diff --cached\n"
            "To proceed anyway, this warning is non-blocking."
        )
        print(json.dumps({"systemMessage": msg}))
    else:
        sys.exit(0)


main()
