#!/usr/bin/env bash
# measure-tokens.sh — Report the token cost of every file the system deploys.
#
# Usage:
#   bash scripts/measure-tokens.sh           # table output
#   bash scripts/measure-tokens.sh --json    # JSON output for scripting
#
# Uses tiktoken (cl100k_base) when available; falls back to a bytes/3.5 estimate.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JSON=false
[[ "${1-}" == "--json" ]] && JSON=true

python3 - "$REPO_DIR" "$JSON" <<'PY'
import json
import os
import sys

repo = sys.argv[1]
as_json = sys.argv[2] == "True"

try:
    import tiktoken
    enc = tiktoken.get_encoding("cl100k_base")
    def tokens(text): return len(enc.encode(text))
    method = "tiktoken(cl100k_base)"
except ImportError:
    def tokens(text): return max(1, int(len(text) / 3.5))
    method = "estimate (bytes / 3.5)"

def measure(path, category):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    return {
        "path": os.path.relpath(path, repo),
        "category": category,
        "lines": text.count("\n") + 1,
        "bytes": len(text.encode("utf-8")),
        "tokens": tokens(text),
    }

items = []
items.append(measure(os.path.join(repo, "global/CLAUDE.md"), "permanent"))

for name in sorted(os.listdir(os.path.join(repo, "agents"))):
    if name.endswith(".md"):
        items.append(measure(os.path.join(repo, "agents", name), "agent"))

for name in sorted(os.listdir(os.path.join(repo, ".claude/commands"))):
    if name.endswith(".md"):
        items.append(measure(os.path.join(repo, ".claude/commands", name), "skill"))

permanent = sum(i["tokens"] for i in items if i["category"] == "permanent")
agents = [i for i in items if i["category"] == "agent"]
skills = [i for i in items if i["category"] == "skill"]

summary = {
    "method": method,
    "permanent_per_turn_tokens": permanent,
    "agent_count": len(agents),
    "agent_mean_tokens": round(sum(a["tokens"] for a in agents) / max(1, len(agents))),
    "agent_largest": max(agents, key=lambda a: a["tokens"]) if agents else None,
    "skill_count": len(skills),
    "skill_mean_tokens": round(sum(s["tokens"] for s in skills) / max(1, len(skills))),
    "skill_largest": max(skills, key=lambda s: s["tokens"]) if skills else None,
    "files": items,
}

if as_json:
    print(json.dumps(summary, indent=2))
else:
    print(f"[measure] tokenization method: {method}")
    print()
    print(f"{'category':<10} {'tokens':>7}  {'lines':>5}  {'bytes':>6}  path")
    print("-" * 72)
    for i in items:
        print(f"{i['category']:<10} {i['tokens']:>7}  {i['lines']:>5}  {i['bytes']:>6}  {i['path']}")
    print()
    print(f"Permanent per-turn cost (CLAUDE.md):  {permanent} tokens")
    print(f"Agents: {len(agents)}, mean {summary['agent_mean_tokens']} tokens")
    if summary["agent_largest"]:
        a = summary["agent_largest"]
        print(f"  largest: {a['path']}  ({a['tokens']} tokens)")
    print(f"Skills: {len(skills)}, mean {summary['skill_mean_tokens']} tokens")
    if summary["skill_largest"]:
        s = summary["skill_largest"]
        print(f"  largest: {s['path']}  ({s['tokens']} tokens)")
    print()
    print("For exact Claude tokenization, run:")
    print("  anthropic api count_tokens --model claude-opus-4-7 < global/CLAUDE.md")
PY
