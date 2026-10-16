#!/usr/bin/env bash
# SessionStart hook: offer Claude Code's built-in "You should know" mod, never switch it on.
#
# The mod (Claude Code 2.1.287+, cc-plugin-you-should-know@builtin) is a side agent that flags above
# the prompt what the user or Claude might miss. Whether to run it is the user's call: this hook shows
# the offer at most three times per machine, at most once a day, as a message to the user (not to the
# model), and goes quiet for good once any settings file names the key - true (turned on) or false
# (declined with /plugin disable).
#
# Fails open, always: no home, an unwritable counter, a missing settings file - exit 0 in silence.
#
#   VULYK_YSK_OFFER=0        never show the offer
#   CLAUDE_CONFIG_DIR        where the user's settings and the counter live (default ~/.claude)
set -uo pipefail

[ "${VULYK_YSK_OFFER:-1}" = "0" ] && exit 0

ID="cc-plugin-you-should-know@builtin"
MAX=3
GAP=$((20 * 3600))   # a day, give or take the hour the owner opens the first session

# The mod runs only in first-party sessions with telemetry on: offering it anywhere else is noise.
[ -n "${DISABLE_TELEMETRY:-}${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-}${CLAUDE_CODE_USE_BEDROCK:-}${CLAUDE_CODE_USE_VERTEX:-}${CLAUDE_CODE_USE_FOUNDRY:-}" ] && exit 0

HOMEDIR="${HOME:-${USERPROFILE:-}}"
CFG="${CLAUDE_CONFIG_DIR:-${HOMEDIR:+$HOMEDIR/.claude}}"
[ -n "$CFG" ] || exit 0
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# A key in any settings file is a decision already made.
for f in "$CFG/settings.json" "$ROOT/.claude/settings.json" "$ROOT/.claude/settings.local.json"; do
  grep -qF "\"$ID\"" "$f" 2>/dev/null && exit 0
done

STATE="$CFG/vulyk-ysk-offer"
SHOWN=0; LAST=0
[ -f "$STATE" ] && read -r SHOWN LAST < "$STATE" 2>/dev/null
case "${SHOWN:-}" in ''|*[!0-9]*) SHOWN=0 ;; esac
case "${LAST:-}" in ''|*[!0-9]*) LAST=0 ;; esac
[ "$SHOWN" -lt "$MAX" ] || exit 0
NOW="$(date +%s 2>/dev/null || echo 0)"
[ "$NOW" -gt 0 ] || exit 0
[ $((NOW - LAST)) -ge "$GAP" ] || exit 0
N=$((SHOWN + 1))
# Count it before showing it: a counter that cannot be written would show the offer every session.
printf '%s %s\n' "$N" "$NOW" > "$STATE" 2>/dev/null || exit 0

LANG_ROW="$(grep -h -m1 '^| Owner language |' "$ROOT/CLAUDE.vulyk.md" "$ROOT/CLAUDE.md" 2>/dev/null | head -n 1)"
case "$LANG_ROW" in
  *'| ru'*|*'| `ru'*) L=ru ;;
  *'| uk'*|*'| `uk'*) L=uk ;;
  *) L=en ;;
esac

case "$L" in
  ru)
    L1="💡 [VULYK] Совет $N из $MAX: включите официальный плагин Anthropic «You should know»."
    L2="Это боковой агент: пока Claude работает, он следит за сессией и подсказывает над полем ввода (✦ Heads up), что вы или Claude могли упустить: решение, которое модель приняла молча, результат с возможной ошибкой. На длинных задачах очень помогает."
    L3="Включить:    /plugin enable $ID"
    L4="Отказаться:  /plugin disable $ID  (совет больше не появится)"
    L5="Нужны Claude Code 2.1.287+ и включённая телеметрия; агент делает свои запросы к модели. Решать вам: без ответа совет вернётся завтра, всего не больше $MAX раз."
    LAST_LINE="Это последний раз: дальше совет не появится." ;;
  uk)
    L1="💡 [VULYK] Порада $N з $MAX: увімкніть вбудований плагін Anthropic «You should know»."
    L2="Це боковий агент: поки Claude працює, він стежить за сесією і підказує над полем вводу (✦ Heads up), що ви чи Claude могли пропустити: рішення, яке модель ухвалила мовчки, результат із можливою помилкою. На довгих задачах дуже допомагає."
    L3="Увімкнути:    /plugin enable $ID"
    L4="Відмовитися:  /plugin disable $ID  (порада більше не з'явиться)"
    L5="Потрібні Claude Code 2.1.287+ і ввімкнена телеметрія; агент робить власні запити до моделі. Вирішувати вам: без відповіді порада повернеться завтра, загалом не більше $MAX разів."
    LAST_LINE="Це останній раз: далі порада не з'явиться." ;;
  *)
    L1="💡 [VULYK] Tip $N of $MAX: turn on Anthropic's official You should know plugin."
    L2="A side agent watches the session while Claude works and flags above the prompt (✦ Heads up) what you or Claude might miss: a decision the model made silently, a result that may be wrong. Very useful on long tasks."
    L3="Turn on:  /plugin enable $ID"
    L4="Decline:  /plugin disable $ID  (the tip stops)"
    L5="Needs Claude Code 2.1.287+ with telemetry on; the agent makes its own model calls. Your call: without an answer the tip returns tomorrow, $MAX times at most."
    LAST_LINE="This is the last time: the tip will not come back." ;;
esac
[ "$N" -lt "$MAX" ] || L5="$L5 $LAST_LINE"

# systemMessage goes to the user, not into the model's context. The lines hold no quote or backslash.
printf '{"systemMessage": "%s\\n%s\\n%s\\n%s\\n%s"}\n' "$L1" "$L2" "$L3" "$L4" "$L5"
exit 0
