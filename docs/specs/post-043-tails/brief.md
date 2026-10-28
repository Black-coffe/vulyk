# Brief: post-043-tails

**Date:** 2026-10-28 · **Tier:** 2 (small fixes in prompt-check, close-story, trace-autopsy, the handoff hook and one test; paperwork of two old specs; a drone-docs pass at ship)

## Request (verbatim)

> Да, запускай `/vulyk-plan post-043-tails` (Tier 2) с этим составом, а `handoff-ownership` и `constitution-merge` пойдём следом отдельными сборками после сверки их планов с HEAD.
>
> При нарезке плана и историй `post-043-tails` учти три вещи:
> 1. Раздели кодовые правки (`prompt-check.py`, `cycle.sh`, `trace-autopsy.py`, `handoff.sh`, флейки-тест `symbol-map`) и чисто текстовые/бумажные правки (`docs/architecture.md:23`, закрытие `self-learning` и `upgrade-keeps-host-edits`) на отдельные истории, чтобы бумажные правки не требовали `red: required` / `stamp-red`.
> 2. Для `upgrade-keeps-host-edits` проверь по `scripts/state.sh` (и по тому, как в 0.29.0 были сняты `vulyk-watcher` / `you-should-know`), как именно оформить закрытие «заменена 0.29.0», чтобы `state.sh` и `/vulyk-status` больше не считали эту спеку висящей в `todo`.
> 3. В план (на этап `/vulyk-ship`) явно запиши задачу для `drone-docs`: добавить в `memory/memory.md` ADR-022..024, `drone-horizon`, `trace-autopsy`, `prompt-check` (удержав лимит ≤ 60 строк), добавить ADR-024 в срез карты и сжать все три среза `memory/map/*.md` обратно к их целевому бюджету (~80 строк).

## Context: «этот состав» (model text, not an owner quote)

The composition the owner approved is the Queen's recommendation from study `docs/specs/post-043-audit/report.md`
(`## Options`, option 1), quoted here as the Queen wrote it in chat:

```text
post-043-tails (Tier 2): четыре замечания prompt-check, два замечания trace-autopsy, проверка Python в handoff.sh,
закрытие бумаг двух спек и проход drone-docs при выпуске.
```

## Recon facts (the Queen, 2026-10-28; not owner words)

- prompt-check minors (`docs/specs/prompt-check/council/round-1/review.md:11-14`) at HEAD: agent name only as a whole
  span `scripts/prompt-check.py:181`; silent verb skip `:67-68`, `:198`; rc 1 without an `error` line refused with an
  empty reason `scripts/cycle.sh:2347-2351`; «Those four» after five names `docs/architecture.md:21-23`.
- trace-autopsy minors 1 and 4 (`docs/specs/trace-autopsy/council/round-1/review.md`): `frames_of` reverses every
  frame when the brief holds `most recent call last` (`scripts/trace-autopsy.py:61-62`); the `< 1000 ms` check
  (`tests/symbol-map.test.sh:223-241`, GNU `date +%s%N`) depends on host load.
- `.claude/hooks/handoff.sh:9-11` `exec`s the first `python3` `command -v` finds; on Windows that can be the Store
  stub (exit 49) (`docs/specs/upgrade-keeps-host-edits/plan.md:47-49`).
- `scripts/state.sh` counts `todo` from story `status:` lines and derives `stage` from `plan.md` markers; a
  `**Shipped:**` line gives `06-shipped`. No superseded/retired marker exists anywhere in `scripts/`, `docs/cycle.md`
  or `/vulyk-status`. `vulyk-watcher` and `you-should-know` were not closed in 0.29.0: both are `06-shipped` (0.27.0,
  0.25.0) with every story `done`; 0.29.0 retired the mod, not the specs.
- `**Shipped:**` is written by `scripts/ship-check.sh --record <spec-dir> <version> [note]` (`:33-60`): today's date,
  HEAD, the note, and a row in `memory/stats/ship.jsonl`, a ledger only `ship-check.sh` writes and nothing aggregates.
- `upgrade-keeps-host-edits`: `**Approved:**` still the placeholder (`plan.md:57`), story 01 `status: todo`; its asks
  shipped in 0.29.0 by `5239eb0` (`CHANGELOG.md:415-417`). `self-learning`: no story files, shipped in 0.19.0
  (merge `b6d61e9`), no `**Shipped:**` line; `state.sh` does not list it.
- Found on the way: `state.sh` takes any `^story:` line as a story, so `architecture-passport/report.md:474` (a quoted
  story template) shows as one `todo` story of a study spec. Out of the approved composition.

## Answers

1. Закрытие: Штатный --record (Рекомендую) - История получает done с пометкой, а ship-check.sh --record пишет «Shipped: 0.29.0 - superseded: собрано в 5239eb0 вне этой спеки, не одобрялась». state.sh покажет 06-shipped и 0 todo. Нового кода нет, тот же скрипт, что на каждом выпуске.
2. state.sh: Да, в этой сборке (Рекомендую) - Та же цель, что в пункте 2: /vulyk-status не должен показывать висящее. Правка узкая: читать story: и status: только из frontmatter, как 0.40.1 сделал для red:.
3. Сбой линтера: Отказ со своей причиной (Рекомендую) - История не закрывается, в причине пишется «prompt-check упал» и последняя строка трейсбека. Сломанная проверка не должна молча пропускать (карточка safeguard-bypassable-or-late).
4. Требования: Верно, покажи план (Рекомендую) - Шесть пунктов идут в требования как есть. Я пишу план и истории и останавливаюсь на ваше одобрение: это стандартный порядок для правки cycle.sh и хука.

## Asks

1. Три замечания prompt-check в коде: имя агента внутри длинного фрагмента; предупреждение вместо тихого пропуска глаголов; падение линтера в close-story — отказ со своей причиной.
2. handoff.sh проверяет, что Python настоящий, прежде чем запускать.
3. trace-autopsy: порядок фреймов при «most recent call last»; тест скорости не зависит от нагрузки.
4. state.sh читает story/status только из frontmatter.
5. Бумаги отдельной историей без красной квитанции: «Those four» в architecture.md; upgrade-keeps-host-edits закрыта через --record как заменённая 0.29.0; self-learning получает строку 0.19.0.
6. На выпуске drone-docs: memory.md (ADR-022..024, drone-horizon, trace-autopsy, prompt-check, ≤ 60 строк), ADR-024 в срез, три среза к ~80 строкам.
