#!/usr/bin/env bash
# VULYK acceptance drift log - fourth deterministic record, beside scope/wave/trace.
#
#   Usage: scripts/acceptance-log.sh <spec-dir> <ACCEPTED|REJECTED|CANNOT_RUN> [note]
#          scripts/acceptance-log.sh docs/specs/oauth REJECTED "logout ask never wired up"
#
# `drone-acceptance` judges the built software against brief.md alone - it never sees the
# stories, so it does not know what the hive believes it finished. This script writes down
# both accounts side by side and computes the only number worth keeping:
#
#   drift = the stories all say `done` and the blind gate did NOT accept.
#
# That is the framework contradicting its own story about itself, and it is the one series
# no other gate in VULYK can produce. `false` here is evidence; a long run of `false` is
# the closest thing to proof that the pipeline delivers what was asked.
#
# Story statuses come from the spec dir (frontmatter `status:`), the verdict from the
# caller - the Queen, right after reading the drone's report. Deterministic, no model.
# Exit status is always 0: this records, it does not block.

set -u

SPEC="${1:-}"
VERDICT="${2:-}"
NOTE="${3:-}"

if [ -z "$SPEC" ] || [ ! -d "$SPEC" ] || [ -z "$VERDICT" ]; then
  echo "acceptance-log: usage: $0 <spec-dir> <ACCEPTED|REJECTED|CANNOT_RUN> [note]" >&2
  exit 0
fi

case "$VERDICT" in
  ACCEPTED|REJECTED|CANNOT_RUN) ;;
  *) echo "acceptance-log: verdict must be ACCEPTED, REJECTED or CANNOT_RUN (got '$VERDICT')" >&2; exit 0 ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "acceptance-log: CANNOT RUN - not a git repo, so there is no memory/stats to append to." >&2
  exit 0
}

TOTAL=0; DONE=0; BLOCKED=0
for f in "$SPEC"/*.md; do
  [ -f "$f" ] || continue
  grep -q '^story:' "$f" 2>/dev/null || continue
  TOTAL=$((TOTAL+1))
  st="$(awk -F': *' '$1 == "status" { sub(/[[:space:]]*#.*$/, "", $2); gsub(/[[:space:]]/, "", $2); print $2; exit }' "$f")"
  case "$st" in
    done)    DONE=$((DONE+1)) ;;
    blocked) BLOCKED=$((BLOCKED+1)) ;;
  esac
done

DRIFT=false
if [ "$TOTAL" -gt 0 ] && [ "$DONE" -eq "$TOTAL" ] && [ "$VERDICT" != "ACCEPTED" ]; then
  DRIFT=true
fi

# Keep the free-text note JSON-safe the blunt way: double quotes become apostrophes,
# backslashes and newlines are dropped. The note is a human hint sitting next to the
# numbers, not data anything parses - losing a character beats emitting a broken line.
ESCAPED="$(printf '%s' "$NOTE" | tr -d '\n' | tr -d '\\' | tr '"' "'")"

mkdir -p "$ROOT/memory/stats"
STATS="$ROOT/memory/stats/acceptance.jsonl"
printf '{"ts":"%s","spec":"%s","verdict":"%s","stories":%s,"done":%s,"blocked":%s,"drift":%s,"note":"%s"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(basename "$SPEC")" "$VERDICT" \
  "$TOTAL" "$DONE" "$BLOCKED" "$DRIFT" "$ESCAPED" >> "$STATS"

echo "acceptance-log: $(basename "$SPEC") - verdict $VERDICT, stories $DONE/$TOTAL done, $BLOCKED blocked, drift $DRIFT"
if [ "$DRIFT" = true ]; then
  echo "  ! Every story reports done and the blind gate did not accept. One of the two accounts"
  echo "    is wrong, and the story statuses are the one written by the party with an interest."
fi
exit 0
