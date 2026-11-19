# A repair re-checks what it repaired, not the whole spec (brief) - stage 1 of 0.54.0

**Date:** 2026-11-15 · **Owner:** Andrei · **Tier:** 3 · **Release:** 0.54.0, built and judged by a full council
BEFORE `guards-1115`, `tails-1115` and `docs-1115`, whose repairs then run on it.
**Evidence:** crossgrill verdict `.crossgrill/2026-11-14-vulyk-slow-cycle/verdict.md` (git-ignored, local): 66% of the
audit-fixes-1113 wall time went before round 1; a full round after a narrow repair cost ~110 min.

## Request (verbatim)

2026-11-14, the owner, on the audit-fixes-1113 repair:

> Ты можешь мне объяснить, что мы ремонтируем два часа? Почему два часа? Куда уходит это время — два часа? Смотри, вот моя логика, и ты скажи, в чём она неправа. Например, мы шо-то сделали, проводим тесты, проводим проверки, получаем грин по 95% проекта. В 5% мы видим какую-то проблему. Мы эту проблему устраняем и, как идиоты, начинаем снова весь проект, все 100%, прогонять часовыми проверками, грилями, тестами. Зачем? Мы ремонтировали маленький кусочек и проверяем. Глобально тесты мы гоняем только, например, раз в месяц или когда явно какие-то баги начинают вылазить, или фидбэк какой-то идёт. И глобально тесты мы гоняем, когда мажорная версия подымается, например, 0.5, 0.6 — это считаем мажор, 0.7 — мажор. А когда 0.51 было, стало 0.52 — это минорные версии. То есть мы тратим впустую тысячи, миллионы, десятки миллионов токенов , чтобы просто по кругу гонять одно и то же. Я, честно, логику не понимаю. Мне кажется, нужно запускать совет моделей — Fable, Opus, Sonnet — и разбираться, почему у нас такая дичь происходит в этом проекте. Почему у нас добавление простого правила в улик или простой логики, потом мы два дня не можем выкатить этот улик. Это вообще мне в голове не помещается.

2026-11-15:

> бери все известные косяки и недочеты и устраняй и выкати минорную версию после фикса

## Answers (owner, picked options verbatim)
- 2026-11-14, local merge gate: «Полные тесты без агентов (Рекомендую)» - the full suite runs once before a local merge,
  with no council seats.
- 2026-11-14, the policy as a spec: «Да, следующей задачей (Рекомендую)».
- 2026-11-15: «Взять первым этапом (Рекомендую)» - this spec goes first in 0.54.0, judged once by a full council.
- 2026-11-15, at plan approval (added 2026-11-16, after the ship: it was written into story 02 only, so the blind
  seat judged ask 5 by "mention"): «Утверждаю все три, тесты exact (Рекомендую)» - pick tests by direct calls
  only, not by any mention.
- 2026-11-16, after round 2 escalated: «Принять, доделать в tails (Рекомендую)» - the two remaining gaps go to
  tails-1115 asks 11 and 12.

## Asks
1. A repair after a round where the other asks were green re-checks only what it repaired: the findings' own tests,
   the suite parts covering the files it touched, a review of its diff, and the owner's acceptance. No new full round,
   whatever the number of files, unless an ask was red for a design fault.
2. A repair story carries only its findings' verification rows, never the union of every earlier story's rows.
3. A council seat re-runs only for a red ask or an ask whose files the repair touched; a seat with nothing to judge is
   not dispatched (no empty reports).
4. The full suite, without agents, runs once before a local merge. A full check of the whole project runs, in the
   owner's words, when the major version goes up (0.5 -> 0.6 -> 0.7; 0.51 -> 0.52 is minor), about once a month, or
   when bugs or feedback come in - not on every repair and not on every minor public release. (This spec itself gets
   one full council round because the owner chose so for it on 2026-11-15, not as a rule.)
5. At plan time the tests that mention a story's files are added to its lists automatically, so a story's own rows
   cover its files.
6. Card `full-round-for-a-narrow-fix` gets the owner's 2026-11-14 words and its "full round when an ask was red" line
   is rewritten to this policy; the constitution, cycle docs and `/vulyk-build` say the same thing.
7. Every rule above has a failing test with the original case (the audit-fixes-1113 repair) and a neighbour form.
8. A story's sections (`## Files`, `## Verification` and the rest) are read outside fenced code blocks only, so a red receipt's captured test output can never add a line to them (framework defect met mid-build on 2026-11-15: story 01's receipt held a fixture's `## Verification` and `advance` refused the wave).
9. The defect gate of close-story never runs a card's check on the library's own fixtures and terms files (`docs/defects/**/*.fixture`, `*.terms`, `fixtures/`), which are red by design, so a story whose `## Files` holds `docs/defects/*` can close (framework defect met mid-build on 2026-11-16: repair story 06 refused on `host-internals-in-public-repo.terms`).
