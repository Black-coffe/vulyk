#!/usr/bin/env bash
# SessionEnd hook: capture a learnings stub. With VULYK_AUTOLEARN=1, distill the
# transcript via a one-shot headless Haiku call (cheap, opt-in - it spends tokens).
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
OUT_DIR="$ROOT/memory/learnings"
[ -d "$OUT_DIR" ] || exit 0

# memory/learnings/ is committed to git - transcript-derived text passes through the
# secret filter first. redact.sh degrades to cat on its own, but guard its absence too.
redact() {
  if [ -f "$ROOT/scripts/redact.sh" ]; then bash "$ROOT/scripts/redact.sh"; else cat; fi
}
TS=$(date +%Y-%m-%d_%H%M%S)
OUT="$OUT_DIR/$TS.md"

payload=$(cat 2>/dev/null || true)
transcript=""
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  transcript=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)
fi

if [ "${VULYK_AUTOLEARN:-0}" = "1" ] && [ -n "$transcript" ] && [ -f "$transcript" ] && command -v claude >/dev/null 2>&1; then
  tail -c 200000 "$transcript" | claude -p --model haiku \
    "From this Claude Code session transcript, extract ONLY project-specific learnings worth remembering: gotchas hit, expensive dead ends, conventions discovered, decisions made. Output 1-6 terse markdown bullets, or exactly NOTHING_NOTEWORTHY if the session was routine." \
    > "$OUT.tmp" 2>/dev/null
  if [ -s "$OUT.tmp" ] && ! grep -q "NOTHING_NOTEWORTHY" "$OUT.tmp"; then
    { echo "# Session $TS (auto-distilled)"; cat "$OUT.tmp"; } | redact > "$OUT"
  fi
  rm -f "$OUT.tmp"
else
  cat > "$OUT" << STUB
# Session $TS
<!-- Stub captured by VULYK. Replace with 1-6 bullets of project-specific learnings,
     or delete this file if the session was routine. Tip: set VULYK_AUTOLEARN=1 for
     automatic Haiku distillation. Consolidation: /vulyk-gc -->
STUB
fi
exit 0
