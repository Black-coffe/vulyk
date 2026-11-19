#!/usr/bin/env bash
# PostToolUse(Skill) and UserPromptExpansion hook: increment per-skill invocation counters for skill-gardener.
# Counts only VULYK's own: a skill whose folder is under the project's .claude/skills/ and a vulyk-* command
# (.claude/commands/vulyk-*.md). Any other name is not written, and a key already in the file that fails the
# rule is dropped on the next write. memory/stats/skills.json is local and gitignored (audit-fixes-1113, ask 2).
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
STATS="$ROOT/memory/stats/skills.json"
[ -d "$ROOT/memory/stats" ] || exit 0

payload=$(cat 2>/dev/null || true)
[ -n "$payload" ] || exit 0
# UserPromptExpansion (tails-1115, T72; cc-facts F9): a typed command never runs the Skill tool; its command_name is
# counted only for a vulyk-* command.
skill=$(printf '%s' "$payload" | jq -r 'if .hook_event_name == "UserPromptExpansion"
  then (.command_name // "" | if startswith("vulyk-") then . else "" end)
  else (.tool_input.skill_name // .tool_input.skill // .tool_input.name // empty) end' 2>/dev/null | tr -d '\r')
ours() { # ours <name> - 0 for a project skill folder or a vulyk-* command file; no path characters either way
  case "$1" in ''|*[!A-Za-z0-9._-]*|.*) return 1 ;; esac
  [ -d "$ROOT/.claude/skills/$1" ] && return 0
  case "$1" in vulyk-*) [ -f "$ROOT/.claude/commands/$1.md" ] ;; *) return 1 ;; esac
}
ours "$skill" || exit 0
[ -f "$STATS" ] || printf '{}\n' > "$STATS" 2>/dev/null || exit 0

# The keys that pass the rule now: the file is rewritten with these alone.
keep=""
for k in $(jq -r 'keys[]' "$STATS" 2>/dev/null | tr -d '\r'); do ours "$k" && keep="$keep$k"$'\n'; done
keep_json=$(printf '%s' "$keep" | jq -R . | jq -s . | tr -d '\r')

tmp=$(mktemp)
# Windows jq prints CRLF: strip the \r so skills.json stays LF. pipefail (above) keeps a failed jq from moving.
jq --arg s "$skill" --arg d "$(date +%Y-%m-%d)" --argjson keep "$keep_json" \
   'with_entries(select(.key as $k | any($keep[]; . == $k))) | .[$s] = ((.[$s] // {count:0}) | .count += 1 | .last_used = $d)' \
   "$STATS" 2>/dev/null | tr -d '\r' > "$tmp" && mv "$tmp" "$STATS" || rm -f "$tmp"
exit 0
