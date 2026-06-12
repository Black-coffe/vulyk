#!/usr/bin/env bash
# PreCompact hook: snapshot memory index + active spec statuses before compaction.
set -uo pipefail
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
