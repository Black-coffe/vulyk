#!/usr/bin/env bash
# PostToolUse(Skill) hook: increment per-skill invocation counters for skill-gardener.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATS="$ROOT/memory/stats/skills.json"
[ -f "$STATS" ] || exit 0

payload=$(cat 2>/dev/null || true)
[ -n "$payload" ] || exit 0
skill=$(printf '%s' "$payload" | jq -r '.tool_input.skill_name // .tool_input.skill // .tool_input.name // empty' 2>/dev/null)
[ -n "$skill" ] || exit 0

tmp=$(mktemp)
jq --arg s "$skill" --arg d "$(date +%Y-%m-%d)" \
   '.[$s] = ((.[$s] // {count:0}) | .count += 1 | .last_used = $d)' \
   "$STATS" > "$tmp" 2>/dev/null && mv "$tmp" "$STATS" || rm -f "$tmp"
exit 0
