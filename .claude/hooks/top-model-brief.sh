#!/usr/bin/env bash
# SessionStart hook: say which model is the king of planning on this account, so the Queen
# dispatches the top castes to it without anyone remembering the plan terms.
#
# One `[VULYK]` line into context. The resolution itself lives in scripts/top-model.sh -
# this hook only reads it out and adds the one thing the resolver cannot know: whether the
# Queen's own session is pinned to the same model. It never writes anything. Pinning is a
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
  opus)  NAME="Opus 5" ;;
  *)     NAME="$MODEL" ;;
esac

if bash "$RESOLVER" --check 2>/dev/null; then
  SESSION="Queen session pinned to $MODEL."
else
  SESSION="Queen session NOT pinned to $MODEL - tell the owner: \`/model $MODEL\` now (cache is cold, the switch is free) and \`bash scripts/top-model.sh --apply\` so the next launch starts there."
fi

echo "[VULYK] top model: $MODEL ($NAME) - by ${BY:-plan}, plan ${PLAN:-unknown}. Dispatch queen-planner, lead-architect and lead-review with model: $MODEL; Tier 4 second reviewer: ${SECOND:-opus}. $SESSION Details: bash scripts/top-model.sh --explain"
exit 0
