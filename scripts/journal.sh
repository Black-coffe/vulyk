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
# Exit status is 0: appending a record is not a gate. The one exception is a line that cannot
# be masked (no redact.sh, or it fails): exit 1 and nothing is written.
set -u

SPEC="${1:-}"; STAGE="${2:-}"; WHAT="${3:-}"; NEXT="${4:-}"
if [ -z "$SPEC" ] || [ -z "$STAGE" ]; then
  echo "journal: usage: $0 <spec-dir> <stage> \"<what happened>\" \"<what next>\"" >&2
  exit 0
fi

LINE="- $(date -u +%Y-%m-%dT%H:%M:%SZ) · $STAGE · $WHAT · next: $NEXT"
# P9-07: journal.md is committed and <what happened> is often free text (a pause reason, a
# fallback note) - mask credential shapes with the redact.sh beside this script. When masking
# cannot run (no redact.sh, a failure, nothing back) the line is refused: exit 1, nothing written.
REDACT="$(dirname "$0")/redact.sh"
refuse() { echo "journal: refused - $1; nothing written to $SPEC/journal.md" >&2; exit 1; }
[ -f "$REDACT" ] || refuse "no redact.sh beside journal.sh, so the line cannot be masked"
MASKED="$(printf '%s' "$LINE" | bash "$REDACT" 2>/dev/null)" || refuse "redact.sh failed to mask the line"
[ -n "$MASKED" ] || refuse "redact.sh returned nothing"
LINE="$MASKED"

JOURNAL="$SPEC/journal.md"
if [ ! -f "$JOURNAL" ]; then
  mkdir -p "$SPEC"
  printf '# Journal: %s\n\n' "$(basename "$SPEC")" > "$JOURNAL"
fi
printf '%s\n' "$LINE" >> "$JOURNAL"
printf '%s\n' "$LINE"
exit 0
