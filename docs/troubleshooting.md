# Troubleshooting

## Agent not loading

**Symptom**: `@architect` (or another agent) does not respond or is not recognized.

**Check**:
```bash
ls ~/.claude/agents/
bash scripts/setup.sh --verify
```

If `~/.claude/agents/` is missing files, run `bash scripts/setup.sh`.

## Skill not appearing

**Symptom**: `/audit-module` or another skill is not listed when typing `/` in Claude Code.

**From this repository**: Skills should appear. If they don't, check that `.claude/commands/` exists and contains the `.md` files.

**From another project**: `~/.claude/commands/` as a global location has not been confirmed in the official Claude Code 2.1.87 documentation. If the skill does not appear from another project directory, it may only load locally from this repository. There is no workaround until global command loading is confirmed.

## Hook not triggering

**Symptom**: `secret-scan.py` does not warn before `git commit`.

**Check**:
```bash
# Verify hook file is deployed
ls ~/.claude/hooks/

# Verify hook config is in settings.json
python3 -m json.tool ~/.claude/settings.json | grep -A5 '"hooks"'

# Test hook manually
echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' \
    | python3 ~/.claude/hooks/secret-scan.py
```

If the hook file is missing, run `bash scripts/setup.sh`.

If the config is missing from `settings.json`, run `bash scripts/setup.sh` — it will add the hook configuration.

**WSL2 note**: Hook execution in WSL2 (Windows binary + Linux shell) has not been independently verified. The hook exits silently on failure and never blocks.

## settings.json is corrupted

**Symptom**: Claude Code fails to start or reports an invalid settings file.

**Recover**:
```bash
python3 -m json.tool ~/.claude/settings.json   # verify syntax
ls ~/.claude/backups/ces/settings/              # list backups
cp ~/.claude/backups/ces/settings/settings.json.<timestamp> ~/.claude/settings.json
```

## setup.sh reports sha256sum not found

`sha256sum` is a GNU coreutils command available on Linux and WSL2. On macOS, install via Homebrew:

```bash
brew install coreutils
```

## Deployment check shows DIFFERS

**Symptom**: `--verify` shows a file differs from the source.

A `DIFFERS` result means the deployed file and the source file have different content. This can happen if the file was edited manually in `~/.claude/`.

To resync to the source:
```bash
bash scripts/setup.sh
```

The installer backs up the existing deployed file before overwriting it.

## Running setup.sh from any directory

```bash
bash ~/claude-engineering-system/scripts/setup.sh
bash ~/claude-engineering-system/scripts/setup.sh --verify
```

The script locates the repository root from its own path and does not depend on the current working directory.
