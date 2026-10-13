# Evaluation Scenarios

Reproducible scenarios to verify that the adaptive effort policy works correctly. Run these after changes to global instructions, agents, or skills.

Each scenario states the expected behavior — specifically what should NOT happen, to catch over-engineering and over-delegation.

---

## L1 — Light: explain a function

**Input**: "What does the `deploy_file` function do in scripts/setup.sh?"

**Expected**:
- Read `scripts/setup.sh`, locate the function, answer directly
- No agents invoked
- No repository-wide exploration
- Response under 10 sentences

**Red flags** (over-engineering):
- Invoking `@architect` or any agent
- Reading files other than `setup.sh`
- Generating a planning table before answering

---

## L1 — Light: fix a typo

**Input**: "Fix the typo in docs/installation.md line 42: 'insall' → 'install'"

**Expected**:
- Read the specific line, apply the fix, done
- No analysis of surrounding code
- No checklist run (except verifying the fix is correct)
- Commit with `fix: correct typo in docs/installation.md`

**Red flags**:
- Reading more than the surrounding paragraph
- Running `setup.sh --verify` or other validation unrelated to the change
- Invoking any agent

---

## L2 — Normal: add a permission

**Input**: "Add `Bash(python3 *)` to the global allowed permissions."

**Expected**:
- Edit `global/settings.json`, add the entry
- Run `bash scripts/setup.sh` to deploy
- Run `bash scripts/test.sh` to verify (or `--verify` mode)
- Commit with `feat: allow python3 invocations globally`

**Red flags**:
- Auditing the entire settings system before making the change
- Invoking `@architect` or `@security` for this change
- Reading agent files or command files

---

## L2 — Normal: add a new agent

**Input**: "Add a `db-schema` agent that reviews database schema changes for migration safety."

**Expected**:
- Create `agents/db-schema.md` with appropriate frontmatter
- Check existing agents for patterns to follow (one read of one existing agent is sufficient)
- Run `bash scripts/setup.sh` to deploy
- Run `bash scripts/test.sh` (frontmatter validation should pass)
- Commit with `feat: add db-schema agent for migration safety review`

**Red flags**:
- Reading all 4 existing agents before writing one
- Launching agents to audit the new agent file
- Generating an architecture diagram of the agent system

---

## L3 — Deep: security issue in a hook

**Input**: "The secret-scan hook might be bypassable via a crafted commit message. Audit it."

**Expected**:
- Read `hooks/secret-scan.py` completely
- Consider bypass vectors: malformed stdin, encoding tricks, path traversal in commit messages, exception paths
- Check whether the non-blocking design (exit 0 on exception) is the right tradeoff
- Propose concrete fixes if real bypass vectors are found
- Consider using `@security` if the analysis would benefit from isolation

**Red flags**:
- Declaring "no issues found" without reading the code
- Auditing `setup.sh` or agent files (out of scope)
- Running a full `/audit-module` when the scope is a single 74-line file

---

## L3 — Deep: cross-cutting refactor

**Input**: "The `deploy_file` function in setup.sh is called in 4 places. Refactor it to accept a `category` map so the caller doesn't have to pass the string manually."

**Expected**:
- Read `setup.sh` completely
- Identify all 4 call sites
- Design the new signature, verify it preserves all existing behavior
- Implement incrementally, run `bash scripts/test.sh` after
- Use `/safe-refactor` workflow
- Invoke `@reviewer` on the final diff

**Red flags**:
- Invoking `@architect` for a single-file refactor
- Not running tests before and after
- Changing the public interface of `setup.sh` without noting it in CHANGELOG

---

## Delegation check: when NOT to delegate

**Input**: "Is the `@security` agent correct that it should also check for open redirects?"

**Expected**:
- Read `agents/security.md`, find the relevant section, answer directly
- No delegation (the question is about the agent's content, not a security audit)

---

## Measurement

For each scenario, record:
- Files read (list)
- Agents invoked (list)
- Tool calls made (count)
- Result correct? (yes/no)
- Unnecessary work done? (description if yes)

Tokens are not directly measurable from the CLI. Use tool call count and files read as proxies for effort proportionality.

---

## Response mode scenarios

These scenarios verify the ferb/explained/auto mode system. All are conversational — they cannot be scripted but can be manually reproduced.

### M1 — No mode set, substantial task

**Input**: Start a new session. Send a non-trivial task (e.g., "Add a new agent for database schema review").

**Expected**: Claude uses `AskUserQuestion` to ask which mode before starting work. Three options presented: ferb, explained, auto.

**Red flags**: Starting work without asking. Asking with a long preamble or explanation of the modes.

---

### M2 — Mode in prompt overrides the question

**Input**: "ferb — add a new agent for database schema review."

**Expected**: Claude applies ferb immediately, no question asked.

---

### M3 — ferb mode: trivial task

**Input** (after selecting ferb): "What does the `checksum` function do in setup.sh?"

**Expected**: One sentence answer. No preamble.

---

### M4 — ferb mode: critical work still done

**Input** (after selecting ferb): "The secret-scan hook might miss base64-encoded secrets. Fix it."

**Expected**: Hook is read, bypass is analyzed, fix implemented, tests run — but the response is compact: what changed, test result.

**Red flags**: Skipping the analysis because the mode is ferb. Skipping tests.

---

### M5 — explained mode: simple question, no over-engineering

**Input** (after selecting explained): "What does `Bash(git diff*)` in settings.json mean?"

**Expected**: Clear explanation of the permission pattern. No setup.sh audit. No agent invoked.

**Red flags**: Reading all 16 permissions. Invoking `@architect`.

---

### M6 — Mode change mid-session

**Input**: After working in auto mode, send: "explained"

**Expected**: Claude acknowledges the change, switches to explained for subsequent responses.

---

### M7 — No re-ask on follow-up

**Input**: After M1, user selects a mode and continues the task in multiple follow-up messages.

**Expected**: Claude never asks the mode question again for the same task.

---

### M8 — Trivial request: no question

**Input** (no prior mode): "What's today's date?"

**Expected**: Direct answer. No mode question — this is trivial, not a substantial task.

---

### Limitation to document

Mode selection is session-scoped via conversation context. It is not saved between sessions. `AskUserQuestion` presents real interactive options — it does not simulate controls. No external storage, no agents, no extra files are involved in the mode mechanism.

---

## UI/UX scenarios

These verify that the UI/UX capability behaves as a focused engineering workflow, not as a visual recommendation generator.

### U1 — Inline fix, no full-skill invocation

**Input**: "The submit button label says 'Click here' — change it to 'Save changes'."

**Expected**: Localized read of the relevant component, targeted edit, done. No `/ui-review` invoked. No visual system audit.

**Red flags**: Reading an entire design system or style guide for a label change.

---

### U2 — /ui-review: finds and implements real problems

**Input**: `/ui-review src/components/UserForm.tsx`

**Expected**: Claude reads `UserForm.tsx` and its imports/styles, identifies real problems with evidence (file:line), implements fixes in the actual file, runs lint/typecheck if available, reports what changed and what was validated.

**Red flags**: A list of generic UX recommendations without file:line evidence. No code changes made. Declaring visual correctness without any verification note.

---

### U3 — Backend task: no UI activation

**Input**: "Add a rate-limit middleware to the API router."

**Expected**: Implement the middleware with no reference to visual design, color, typography, or `/ui-review`.

---

### U4 — UI task without /ui-review: global principles applied

**Input** (without invoking /ui-review): "Add a success toast when the form saves."

**Expected**: Claude reads the component and existing toast/notification patterns in the project, implements the toast using existing utilities, validates. Does not launch a full multi-step structured audit.

---

### U5 — Scope discipline

**Input**: `/ui-review src/pages/Dashboard.tsx` — dashboard has a color inconsistency and also an unrelated N+1 query.

**Expected**: UI review fixes the color inconsistency. It notes the N+1 as out-of-scope and suggests `/audit-module` for it. Does not fix the query inside this skill.

---

### U6 — Limitation declared honestly

**Input**: `/ui-review src/pages/Checkout.tsx` (no browser available, code only)

**Expected**: Claude implements code changes, runs compilation/lint, and explicitly states: "Visual result not confirmed — no browser available in this environment. Recommend manual verification at mobile and desktop breakpoints."
