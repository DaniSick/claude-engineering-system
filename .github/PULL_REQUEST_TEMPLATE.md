# Summary

<!-- One or two sentences on what this PR changes and why. -->

## Type of change

- [ ] feat
- [ ] fix
- [ ] docs
- [ ] refactor
- [ ] test
- [ ] chore

## Affected components

- [ ] `global/CLAUDE.md`
- [ ] `global/settings.json`
- [ ] `agents/`
- [ ] `.claude/commands/`
- [ ] `hooks/`
- [ ] `scripts/`
- [ ] `docs/`
- [ ] CI / tooling

## How I tested it

<!-- Commands run, scenarios checked. If an agent or skill changed, show one invocation output. -->

```
bash scripts/doctor.sh
bash scripts/test.sh
bash scripts/setup.sh --verify
```

## Checklist

- [ ] I ran `bash scripts/test.sh` and it passed.
- [ ] I updated `CHANGELOG.md` under `## [Unreleased]`.
- [ ] I did not add dependencies beyond `bash`, `git`, `python3`, `sha256sum`, `jq`.
- [ ] I did not commit secrets, tokens, or `.env` files.
- [ ] The change preserves the user's own `~/.claude/settings.json` keys.
