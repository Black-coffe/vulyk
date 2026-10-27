# Brief: fable-fallback

Date: 2026-10-27 · Deliverable: code (`/vulyk-plan`, Tier 3) · Source: the owner's `/vulyk-plan` argument, after the
study `docs/specs/fable-budget/report.md` (commit be030a1)

## Request (verbatim)

> делай вариант A из fable-budget, судья при отказе — Opus

"Вариант A" is option A of `docs/specs/fable-budget/report.md`: (1) a hive's own judge scripts take the judge family
from `model-profile.sh --role seat`, pass `--effort high`, drop a hard-coded `"fable"`, and rerun once on the fallback
family on the Fable-limit refusal; (2) `lead-review` stops letting the prompt cache expire while the test suite runs;
(3) a Fable-limit fallback in VULYK: a refused role is redispatched once on the fallback family, with a journal line,
a telemetry code and a one-line notice; (4) `modelSettings.claude-fable-5-1.effortLevel` from `xhigh` to `high` on both
accounts. The report text is model-written, not an owner quote.

## Answers

1. Кэш 1 час: Только ревьюеру, и замерить (Рекомендую) - 1 час ставится только в карточке lead-review (`experimental.cacheTtl`), плюс тесты в фоне. Через неделю сравниваю расход и решаем, распространять ли на всех. Почему: ждёт тестов именно ревьюер, у него перезаписей 31% — ближе всех к порогу 37,5%; как подписка считает часовой кэш, не опубликовано, так что честнее измерить на одной роли.
2. Скрипты улья: После его сборки, сам (Рекомендую) - Когда сборка ролика 8 закончится, я делаю в YouTube_AI отдельную маленькую задачу по его же правилам. До тех пор скрипты запускаются с `--model opus`. Почему: в 26.10 уже был случай, когда параллельная сессия в том же каталоге сломала сборку улья; правка скриптов под живыми воркерами повторит его.
3. Выпуск: 0.39.0 + обновить ульи (Рекомендую) - Выпускаю 0.39.0 вместе с horizon-audit, затем обновляю шесть ульев на 0.38.0 с аудитом их правок (YouTube_AI — после его сборки). Почему: твоё правило «правка должна дойти до живых ульев», а дефект сработал сегодня и повторится на следующей неделе.
4. Требования: Верно, покажи план (Рекомендую) - Список принят как есть. Планировщик пишет план и истории, я показываю и жду одного слова. Почему: задеты сборка и совет — лучше увидеть волны до запуска.

## Asks

1. Когда у судьи, планировщика или архитектора кончается Fable, роль один раз перезапускается на Opus: строка в журнал, код телеметрии, одна строка мне; сборка не встаёт.
2. Ревьюер запускает тесты в фоне и смотрит дифф, пока они идут; если проба покажет, что фон в субагенте не работает, — скажу и предложу другое.
3. Кэш на 1 час только у ревьюера; через неделю замер расхода и решение, распространять ли.
4. Модель ворот — только для Tier 4 и повтора истории; свой судья улья берёт семью судьи из профиля и явно задаёт усилие; это написано в документации и в подсказке top-model.sh.
5. В настройках обоих аккаунтов усилие Fable 5.1 с xhigh на high.
6. Скрипты-судьи YouTube_AI правлю сам после его сборки ролика 8; до тех пор они запускаются с --model opus.
7. Выпуск 0.39.0 и обновление ульев на 0.38.0 с аудитом их правок; YouTube_AI — после его сборки.

## Recon (Queen, 2026-10-27; model text, not owner quotes)

- The refusal a parent sees when a subagent's Fable runs out (a real 2026-10-27 task-notification): `Agent terminated
  early due to an API error: You've reached your Fable limit. Run /usage-credits to continue or switch models with
  /model. (error type rate_limit, HTTP 429, request id …, model sent to the API: claude-fable-5-1)`. In a transcript
  record: `apiError: "model_requires_usage_credits"`. Claude Code's own fallback chain does not fire on it
  (code.claude.com/docs/en/model-config, «Fallback model chains»: billing and rate-limit errors never switch).
- Cache TTL (code.claude.com/docs/en/prompt-caching, «Cache lifetime», read 2026-10-27): subagents and workflow agents
  get 5 minutes even on a subscription; a subagent's `experimental` frontmatter field takes `cacheTtl` (`5m` | `1h`,
  Claude Code >= 2.1.248; installed 2.1.311); `1h` is ignored while the subscription uses usage credits. API price of a
  1-hour cache write is 2x base input against 1.25x for 5 minutes (platform.claude.com prompt-caching pricing note).
- Measured rewrite share of cache writes (7 days, all models): lead-review 31%, worker-code 21%, queen-planner 19%,
  council-opus 12%; break-even for 1h is 37.5%.
- Driver: `.claude/workflows/vulyk-cycle.js` dispatches with `agent(prompt, {agentType, model})` wrapped in `caught()`;
  seats are re-dispatched once on a rejected report. Solo: `.claude/commands/vulyk-build.md` step 3.
- Background Bash in a subagent (code.claude.com/docs/en/sub-agents, read 2026-10-27): «A background subagent can leave a
  background Bash or PowerShell command running past the end of its turn. When that command ends, Claude Code sends
  the subagent a notification.» Unverified here: whether the parent (Agent tool or Workflow `agent()`) receives the
  subagent's return at the end of its first turn, before the suite result. A probe decides ask 2.
- `experimental` frontmatter syntax: `experimental:` then `  cacheTtl: 1h` (only in subagent files).
