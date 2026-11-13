#!/usr/bin/env bash
# PreCompact hook: snapshot memory index + active spec statuses before compaction.
set -uo pipefail
# H1 (audit-fixes-1113): a subagent's input carries a non-empty agent_id, and its PreCompact is not the
# session's: exit 0, print nothing, write nothing. A shell call has no input to give: no wait on a terminal, 1 s on a pipe.
IN=""; [ -t 0 ] || IFS= read -r -d '' -t 1 IN || true
re_agent='"agent_id"[[:space:]]*:[[:space:]]*"[^"]'
[[ $IN =~ $re_agent ]] && exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
[ -d "$ROOT/memory" ] || exit 0
SNAP="$ROOT/memory/snapshots/$(date +%Y-%m-%d_%H%M%S)"
mkdir -p "$SNAP"
cp "$ROOT/memory/memory.md" "$SNAP/" 2>/dev/null || true
if [ -d "$ROOT/docs/specs" ]; then
  grep -rn --include='*.md' -i '^status:' "$ROOT/docs/specs" > "$SNAP/spec-statuses.txt" 2>/dev/null || true
fi
echo "[VULYK] context-guard: snapshot saved to ${SNAP#$ROOT/} before compaction"
exit 0
