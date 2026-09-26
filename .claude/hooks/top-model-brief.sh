#!/usr/bin/env bash
# SessionStart hook: say which model holds the gate on this account (ADR-012, narrowed to
# Tier 4 and retries by ADR-013 D3), so the Queen dispatches it without anyone remembering
# the plan terms.
#
# One `[VULYK]` line into context. The resolution itself lives in scripts/top-model.sh -
# this hook only reads it out and adds the one thing the resolver cannot know: whether the
# Queen's own session is pinned to hers (always opus). It never writes anything. Pinning is a
# decision (`scripts/top-model.sh --apply`), and a hook that edits settings behind your back
# is the failure mode this framework spends its update check preventing.
#
# Fails open: no resolver, no bash, an odd profile - silence, exit 0.
#
#   VULYK_TOP_MODEL_BRIEF=0   disable the line
set -uo pipefail

[ "${VULYK_TOP_MODEL_BRIEF:-1}" = "0" ] && exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RESOLVER="$ROOT/scripts/top-model.sh"
[ -f "$RESOLVER" ] || exit 0

MODEL="$(bash "$RESOLVER" 2>/dev/null | tr -d '[:space:]')"
[ -n "$MODEL" ] || exit 0

EXPLAIN="$(bash "$RESOLVER" --explain 2>/dev/null)"
PLAN="$(printf '%s\n' "$EXPLAIN" | sed -n 's/^plan      : //p' | head -1)"
SECOND="$(printf '%s\n' "$EXPLAIN" | sed -n 's/^second reviewer (Tier 4): //p' | head -1)"
BY="$(printf '%s\n' "$EXPLAIN" | sed -n 's/^decided by: \([a-z]*\) - .*/\1/p' | head -1)"

case "$MODEL" in
  fable) NAME="Fable 5.1" ;;
  opus)  NAME="Opus 5.5" ;;
  *)     NAME="$MODEL" ;;
esac

if bash "$RESOLVER" --check 2>/dev/null; then
  SESSION="Queen session pinned to opus."
else
  SESSION="Queen session NOT pinned to opus - tell the owner: \`/model opus\` now (cache is cold, the switch is free) and \`bash scripts/top-model.sh --apply\` so the next launch starts there."
fi

# Workflow driver gate: a hook cannot see which tools the session was launched with, so it
# makes no claim about the CLI version (a version floor is not the same as the tool being
# enabled). /vulyk-build's own step 1 decides this in-session from the tool list.
WORKFLOW="Workflow driver: decided in-session (Tier 3-4: Workflow tool present -> vulyk-cycle.js, else the same advance loop run by the Queen; Tier 1-2 build solo)."

echo "[VULYK] gate model: $MODEL ($NAME) - by ${BY:-plan}, plan ${PLAN:-unknown}. Dispatch model: $MODEL for the Tier 4 lead-review (second reviewer: ${SECOND:-opus}), lead-architect, a Tier 4 queen-planner and a missed story's retry; lead-review at Tier 1-3 and everything else run on their frontmatter (opus, Opus 5.5). $SESSION $WORKFLOW Details: bash scripts/top-model.sh --explain"
exit 0
