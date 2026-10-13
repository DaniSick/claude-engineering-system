# Installation

## Requirements

- Claude Code ≥ 2.1.87
- Linux, macOS, or WSL2
- `bash`, `git`, `python3`, `sha256sum`

## First install

```bash
git clone git@github.com:DaniSick/claude-engineering-system.git ~/claude-engineering-system
cd ~/claude-engineering-system
bash scripts/setup.sh
```

The installer deploys files to `~/.claude/` and merges permissions and hook configuration into `~/.claude/settings.json`. It is idempotent: running it again when nothing has changed makes no modifications.

### Verify

```bash
bash scripts/setup.sh --verify
```

Expected output: all lines show `OK`. Lines marked `MISSING` or `DIFFERS` indicate files that need deploying.

### Verify agents work

Open Claude Code in any project directory and reference an agent:

```
@architect analyze this project's module structure
```

If the agent responds, global agent deployment is confirmed.

## Update

After pulling new commits:

```bash
cd ~/claude-engineering-system
git pull
git log --oneline -5        # review what changed
bash scripts/setup.sh
```

The installer does not run `git pull` automatically. Always review changes before deploying.

## Uninstall

The installer does not provide an uninstall command. To remove deployed files manually:

```bash
rm ~/.claude/CLAUDE.md
rm ~/.claude/agents/{architect,security,performance,reviewer}.md
rm ~/.claude/commands/{audit-module,investigate-bug,safe-refactor,pre-commit-review}.md
rm ~/.claude/hooks/secret-scan.py
```

To restore a previous `settings.json` after the hook configuration was added:

```bash
ls ~/.claude/backups/ces/settings/
cp ~/.claude/backups/ces/settings/settings.json.<timestamp> ~/.claude/settings.json
```

The settings merge only adds entries; removing the permissions and hook configuration from `~/.claude/settings.json` requires editing the file manually.

## WSL2 notes

- Claude Code runs as a Windows binary; the shell (bash/fish/zsh) runs in Linux. The hook script path in `settings.json` uses `~/.claude/hooks/secret-scan.py`, where `~` resolves to the Linux home directory.
- Hook execution in WSL2 has **not been independently verified**. The hook is non-blocking: if execution fails, the commit proceeds without interruption.
- `sha256sum` is required by `setup.sh` and is available by default in most Linux distributions. On macOS, `shasum -a 256` is used instead — the installer uses `sha256sum` and will fail on macOS unless `coreutils` is installed via Homebrew.

## Backups

`setup.sh` backs up existing files before overwriting them:

```
~/.claude/backups/ces/
├── root/        # CLAUDE.md backups
├── agents/      # agent file backups
├── commands/    # command file backups
├── hooks/       # hook script backups
└── settings/    # settings.json backups
```

Each backup has a timestamp suffix: `CLAUDE.md.20261013_102327`.
