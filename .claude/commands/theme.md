---
description: Preview or switch the CES statusline colour theme. Usage: /theme [name] — shows all themes if no argument, or sets the named one.
---

# Theme

Manage the CES statusline colour theme.

## Behavior

**With no argument:**
Run `bash ~/.claude/statusline/ces-statusline.sh --themes` and print the output verbatim — it shows every theme at three context-window pressures so the user can compare colours. Do not interpret or reformat it.

**With an argument (a theme name):**
1. Valid names: `ghost`, `ember`, `matrix`, `ice`, `mono`, `default`
2. If the name is not in that list: print the valid names and stop.
3. Edit `~/.claude/settings.json` using Python to update the `statusLine.command` value:
   - If `CES_THEME=<anything>` already appears in the command: replace it with `CES_THEME=<newname>`.
   - If `CES_THEME=` does not appear: prepend `CES_THEME=<newname> ` before the `bash` part of the command.
   Use `python3` to read, mutate, and write the JSON — do not use sed on JSON.
4. Confirm in one line: "Theme set to <name> — takes effect on the next response."

Do not restart Claude Code. Do not ask for confirmation.
