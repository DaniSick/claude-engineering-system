#!/usr/bin/env bash
# tests/test-frontmatter.sh — Validate YAML frontmatter of agents and skills.
#
# Rules:
#   - Every agents/*.md must have `name:` matching the filename and a `description:`
#     under 500 characters.
#   - Every .claude/commands/*.md must have a `description:` under 500 characters.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1: $2"; FAIL=$((FAIL + 1)); }

echo "=== Frontmatter validation ==="
echo

python3 - "$REPO_DIR" <<'PY' || exit 1
import os, re, sys

repo = sys.argv[1]
errors = []
passed = 0

def frontmatter(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        return None
    return m.group(1)

# Agents
for name in sorted(os.listdir(os.path.join(repo, "agents"))):
    if not name.endswith(".md"):
        continue
    path = os.path.join(repo, "agents", name)
    fm = frontmatter(path)
    expected = name[:-3]
    if fm is None:
        errors.append(f"{path}: no YAML frontmatter block")
        continue
    name_m = re.search(r"^name:\s*(\S+)", fm, re.M)
    desc_m = re.search(r"^description:\s*(.+)$", fm, re.M)
    if not name_m:
        errors.append(f"{path}: missing name:")
        continue
    if name_m.group(1) != expected:
        errors.append(f"{path}: name '{name_m.group(1)}' does not match filename '{expected}'")
        continue
    if not desc_m:
        errors.append(f"{path}: missing description:")
        continue
    if len(desc_m.group(1)) > 500:
        errors.append(f"{path}: description over 500 characters ({len(desc_m.group(1))})")
        continue
    print(f"  PASS  agents/{name}")
    passed += 1

# Commands
for name in sorted(os.listdir(os.path.join(repo, ".claude/commands"))):
    if not name.endswith(".md"):
        continue
    path = os.path.join(repo, ".claude/commands", name)
    fm = frontmatter(path)
    if fm is None:
        errors.append(f"{path}: no YAML frontmatter block")
        continue
    desc_m = re.search(r"^description:\s*(.+)$", fm, re.M)
    if not desc_m:
        errors.append(f"{path}: missing description:")
        continue
    if len(desc_m.group(1)) > 500:
        errors.append(f"{path}: description over 500 characters ({len(desc_m.group(1))})")
        continue
    print(f"  PASS  .claude/commands/{name}")
    passed += 1

print()
print(f"=== Frontmatter: {passed} passed, {len(errors)} failed ===")
for e in errors:
    print(f"  FAIL  {e}")
sys.exit(1 if errors else 0)
PY
