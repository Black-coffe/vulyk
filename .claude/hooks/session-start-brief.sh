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
exit 0
