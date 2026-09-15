#!/usr/bin/env bash
# Stop + SessionEnd hook: run the anomaly-telemetry detectors (scripts/telemetry.sh scan)
# after every turn and every session. Fail-open, silent: a missing prerequisite is exit 0
# with nothing printed, never a block (docs/token-economy.md).
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1 || command -v py >/dev/null 2>&1 || exit 0
SCRIPT="$ROOT/scripts/telemetry.sh"
[ -f "$SCRIPT" ] || exit 0

payload=$(cat 2>/dev/null || true)
transcript=""
[ -n "$payload" ] && transcript=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)

if [ -n "$transcript" ]; then
  bash "$SCRIPT" scan --transcript "$transcript" >/dev/null 2>&1 < /dev/null
else
  bash "$SCRIPT" scan >/dev/null 2>&1 < /dev/null
fi
exit 0
