#!/usr/bin/env bash
# SessionEnd hook: run the anomaly-telemetry detectors (scripts/telemetry.sh scan) once per
# session (ADR-013 D7 dropped the per-turn Stop wiring). Fail-open, silent: a missing
# prerequisite is exit 0 with nothing printed, never a block (docs/token-economy.md).
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
command -v jq >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1 || command -v py >/dev/null 2>&1 || exit 0
SCRIPT="$ROOT/scripts/telemetry.sh"
[ -f "$SCRIPT" ] || exit 0

payload=$(cat 2>/dev/null || true)
transcript=""
event=""
if [ -n "$payload" ]; then
  transcript=$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)
  event=$(printf '%s' "$payload" | jq -r '.hook_event_name // empty' 2>/dev/null)
fi

# `agent_empty` is a permanent row, so it is only judged when the session is over: at `Stop`
# a subagent mid-turn looks exactly like one that returned nothing (plan A17, review Major 6).
# The check stays for a hive whose settings.json still wires this hook on Stop.
final=""
[ "$event" = "SessionEnd" ] && final="--final"

# `sessionend_llm`: a SessionEnd hook gets at most 60 s (code.claude.com/docs/en/hooks), so a
# headless model call wired there - in the settings.json command itself or in the script that
# command runs - is killed before it answers (the old VULYK_AUTOLEARN distillation). One row per
# such hook, its script's name in the ref. Comment lines of a script do not count.
LLM_RE='(^|[^A-Za-z0-9_./-])claude[[:space:]]+([^|;&]*[[:space:]])?(-p|--print)([[:space:]"]|$)'
detect_sessionend_llm() {
  local settings="$ROOT/.claude/settings.json" cmd tok path name hit
  local -a toks
  [ -f "$settings" ] || return 0
  jq -r '.hooks.SessionEnd[]?.hooks[]?.command? // empty' "$settings" 2>/dev/null | tr -d '\r' |
  while IFS= read -r cmd; do
    [ -n "$cmd" ] || continue
    hit=""; name=""
    printf '%s\n' "$cmd" | grep -Eq "$LLM_RE" && hit=1
    read -ra toks <<< "$cmd"
    for tok in "${toks[@]}"; do
      tok="${tok//\"/}"; tok="${tok//\'/}"
      tok="${tok//\$\{CLAUDE_PROJECT_DIR\}/$ROOT}"; tok="${tok//\$CLAUDE_PROJECT_DIR/$ROOT}"
      case "$tok" in /*|[A-Za-z]:*) path="$tok" ;; *) path="$ROOT/$tok" ;; esac
      case "$tok" in *.sh|*.bash|*.py|*.js|*.mjs|*.ts) ;; *) continue ;; esac
      [ -f "$path" ] || continue
      [ -n "$name" ] || name="$(basename "$path")"
      if [ -z "$hit" ] && grep -Iv '^[[:space:]]*#' "$path" 2>/dev/null | grep -Eq "$LLM_RE"; then
        hit=1; name="$(basename "$path")"
      fi
    done
    [ -n "$hit" ] || continue
    bash "$SCRIPT" record sessionend_llm 1 0 --ref "sessionend:${name:-inline}" >/dev/null 2>&1 < /dev/null
  done
  return 0
}
[ "${VULYK_TELEMETRY_SCAN:-1}" = "0" ] || detect_sessionend_llm

if [ -n "$transcript" ]; then
  bash "$SCRIPT" scan --transcript "$transcript" $final >/dev/null 2>&1 < /dev/null
else
  bash "$SCRIPT" scan $final >/dev/null 2>&1 < /dev/null
fi
exit 0
