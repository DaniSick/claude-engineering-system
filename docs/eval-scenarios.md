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
