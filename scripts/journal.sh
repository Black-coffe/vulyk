#!/usr/bin/env bash
# VULYK journal - one line per state change, on disk, mirrored to the terminal.
#
#   Usage: scripts/journal.sh <spec-dir> <stage> "<what happened>" "<what next>"
#          scripts/journal.sh docs/specs/oauth 04-council:GREEN "round 1 verdict GREEN" green
#
# Called from cycle.sh, /vulyk-plan, /vulyk-ship and hooks alike (ADR-001 D1) so the same
# line lands in <spec-dir>/journal.md whichever caller wrote it. It also prints the line to
# stdout - the Queen (or a driver) echoes stdout rather than re-deriving the text, so the
# terminal and the file never differ.
#
# <stage> is one of state.sh's stages (01-spec … 06-shipped, 04-council:<verdict>) or
# `paused`; this script does not validate it - the stage vocabulary is the caller's contract.
#
# Exit status is always 0: appending a record is not a gate.
set -u

SPEC="${1:-}"; STAGE="${2:-}"; WHAT="${3:-}"; NEXT="${4:-}"
if [ -z "$SPEC" ] || [ -z "$STAGE" ]; then
  echo "journal: usage: $0 <spec-dir> <stage> \"<what happened>\" \"<what next>\"" >&2
  exit 0
fi

JOURNAL="$SPEC/journal.md"
if [ ! -f "$JOURNAL" ]; then
  mkdir -p "$SPEC"
  printf '# Journal: %s\n\n' "$(basename "$SPEC")" > "$JOURNAL"
fi

LINE="- $(date -u +%Y-%m-%dT%H:%M:%SZ) · $STAGE · $WHAT · next: $NEXT"
printf '%s\n' "$LINE" >> "$JOURNAL"
printf '%s\n' "$LINE"
exit 0
