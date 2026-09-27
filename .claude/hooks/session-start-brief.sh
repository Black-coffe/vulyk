#!/usr/bin/env bash
# SessionStart hook: inject a one-line hive brief into context (stdout becomes context).
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MEM="$ROOT/memory"
[ -d "$MEM" ] || exit 0

pending=$(find "$MEM/learnings" -maxdepth 1 -name '*.md' ! -name 'CONSOLIDATED.md' 2>/dev/null | wc -l | tr -d ' ')
stale=""
[ -f "$MEM/map/.stale" ] && stale=" | map flagged STALE (post-merge) - consider /vulyk-map"
newest_map=$(ls -t "$MEM/map"/*.md 2>/dev/null | head -1)
map_age="no map yet - run /vulyk-bootstrap or /vulyk-map"
if [ -n "${newest_map:-}" ]; then
  map_age="newest map slice: $(basename "$newest_map"), modified $(date -r "$newest_map" +%Y-%m-%d 2>/dev/null || stat -c %y "$newest_map" 2>/dev/null | cut -d' ' -f1)"
fi
echo "[VULYK] $map_age | learnings awaiting GC: $pending$stale | start at memory/memory.md"

# litopys, the session chronicle plugin (0.19, plan 1.7): offered once. Installed = an
# `enabledPlugins` key starting `litopys@` in either settings file; declined = a Profile row
# `| Chronicle | none ... |` in the constitution. Either one silences the line for good.
if ! grep -qsE '"litopys@[^"]*"[[:space:]]*:' "$ROOT/.claude/settings.json" "$ROOT/.claude/settings.local.json" &&
   ! grep -qsE '^\|[[:space:]]*Chronicle[[:space:]]*\|[[:space:]]*`?none' "$ROOT/CLAUDE.md"; then
  echo "[VULYK] litopys (session chronicle plugin) is not installed here. Ask the owner once: install (\`claude plugin marketplace add Black-coffe/litopys --scope project\` then \`claude plugin install litopys@litopys --scope project\`) or decline (then add Profile row \`| Chronicle | none (declined <date>) |\`)."
fi
exit 0
