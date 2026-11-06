---
description: Toggle the CES statusline banner on or off. Usage: /banner — flips the current state and reports it.
---

# Banner Toggle

Toggles the pixel-art skull banner that appears above the CES statusline. The banner renders a
horned variant when a heavy model is in use (`CES_HEAVY_MODELS`, default `opus`); this command
toggles the whole banner, not the variant.

## Behavior

Check whether `~/.ces-no-banner` exists:

- **If it exists** (banner is hidden): delete it with `rm ~/.ces-no-banner`, then confirm: "Banner shown — the skull will appear on the next Claude response."
- **If it does not exist** (banner is visible): create it with `touch ~/.ces-no-banner`, then confirm: "Banner hidden — the skull is suppressed until you run /banner again."

Do not ask for confirmation. Run the shell command directly, report the new state in one sentence.

## Note

This writes a flag file (`~/.ces-no-banner`) that the statusline script reads on every update. The change takes effect on the next response — no restart needed.

The `CES_BANNER_HIDDEN` environment variable is a session-only alternative; `/banner` uses the persistent file flag instead so the state survives new terminals.
