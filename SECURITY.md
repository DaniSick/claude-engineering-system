# Security policy

## Supported versions

Only the `main` branch and the most recent tagged release receive security fixes.

## Reporting a vulnerability

If you believe you have found a security issue in this repository — in a hook, in a script that is executed during `setup.sh`, in an agent prompt that could be abused, or in configuration that would reduce the user's isolation — please do not open a public issue.

Report it privately through GitHub's **"Report a vulnerability"** button on the Security tab of the repository, or send an email to the maintainer listed in the repository metadata.

Please include:

- A description of the issue and its potential impact.
- Steps to reproduce or a proof of concept.
- The commit hash or release tag you tested against.
- Your environment (OS, Claude Code version).

You will receive an acknowledgement within 7 days. A fix or mitigation plan will be shared within 30 days for confirmed issues.

## Scope

In scope:

- `scripts/setup.sh`, `scripts/uninstall.sh`, `scripts/doctor.sh`, `scripts/test.sh`.
- `hooks/secret-scan.py` and any other hook under `hooks/`.
- Permissions declared in `global/settings.json`.
- Agent and skill prompts that could be exploited to execute unsafe actions.

Out of scope:

- Vulnerabilities in Claude Code itself (report to Anthropic).
- Issues that require the attacker to already have write access to `~/.claude/` or the repository.
- Social engineering of the user by a malicious prompt pasted into their session.
