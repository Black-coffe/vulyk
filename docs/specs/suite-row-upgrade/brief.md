# Brief: suite-row-upgrade

Date: 2026-10-28 · Deliverable: code (`/vulyk-plan`, Tier 1) · Source: the owner's `/vulyk-plan` argument

## Request (verbatim)

> Двухуровневая верификация: Fast Smoke на истории vs Full Suite перед Советом
> Как сейчас в «Вулике»: В close-story гоняется полная проверка истории. В отчёте (report.md, п. 7.3) прямо отмечено узкое место: долгие тесты (вроде council.test.sh) оплачиваются временем на закрытии каждой истории, а не один раз перед раундом Совета.
> 
> Что делают в Anthropic: Строго разделяют Tight Loop (таргетированный тест конкретной функции/модуля за 1–3 секунды после правки) и Pre-Review Gate (прогон всего тяжелого сьюта один раз перед ревью).
> 
> Как внедрить в «Вулик»:
> 
> В шаблоне истории (templates/story.md) и таблице ## Commands разделить проверку на ## Verification (fast) (крутится внутри close-story --commit за секунды) и ## Verification (wave/round) (крутится один раз внутри cycle.sh open-round перед созывом Совета).
> 
> Профит: Сборка волн на Tier 2–4 ускорится в разы без потери надёжности ворот. интегрировать в наш вулик и сделать совместимол, верно, консистетно и едиино с текущим фреймворком вулика

## Recon (Queen, 2026-10-28; model text, not owner quotes)

- The split already shipped in 0.36.0 (spec `fast-verification`): slow `## Commands` rows carry `round-only`,
  `wave-check` reports a story naming one (`scripts/wave-check.sh:227`), `close-story` refuses it
  (`scripts/cycle.sh:2058-2077`), `lead-review` runs the full suite once per round (`.claude/agents/lead-review.md:51-56`),
  and record-seat demands a `SUITE:` line when a round-only full-suite row exists (`scripts/cycle.sh:1607-1661`).
  Report 7.3 (`docs/specs/architecture-passport/report.md:800`) was written 2026-10-25 from the 0.34.0 map, before it.
- The gap: the framework finds the full-suite row by its Purpose text `full suite` + `round-only`. Only a fresh install
  writes `Full suite / build (round-only)` (`install.sh:255`); `--upgrade` never touches a filled Commands block, so
  hives keep `Full test suite`, `Повний набір тестів`, `Полный прогон (аналог suite)`. There close-story accepts the
  full suite on every story (recent stories naming it: one hive 15/46, another 18/55, a third 4/26) and the round's
  SUITE gate is silently off.

## Answers

1. Направление - «Закрыть хвосты (Рекомендую)»: Второй механизм не строим. Помечаю медленные строки (round-only) в живых ульях: это обещали при одобрении 0.36.0, и именно там сейчас close-story гоняет медленные наборы. Ещё исправлю устаревший п. 7.3 в architecture-passport и предложу тебе принять ADR-023. Выигрыш, ради которого ты это предлагаешь, появится в ульях. Дубля правил не будет.
2. План - «Одобряю (Рекомендую)»: (1) VULYK, Tier 1: в /vulyk-update добавить шаг — апгрейд сам приводит строку полного набора хозяина к канону `Full suite / build (round-only)`, команда остаётся его. Тестом зафиксировать пример с `Full test suite`. Поправить устаревший п. 7.3. (2) Шесть ульев на 0.38: замерить их полный набор, переименовать строку и закоммитить; в четырёх с remote ещё и запушить. Ульи на старых версиях получат это на своём апгрейде через шаг (1).
3. ADR-023 - «Принять (Рекомендую)».

## Asks

1. Апгрейд улья сообщает, когда в его таблице команд нет строки `Full suite / build (round-only)`, и /vulyk-update приводит строку полного набора хозяина к этому канону, команда остаётся его; тест фиксирует пример с `Full test suite`.
2. Устаревший п. 7.3 в architecture-passport поправлен: разделение уже выпущено в 0.36.0.
3. ADR-023 принят.
4. Шесть ульев на 0.38: строка полного набора переименована в канон и закоммичена; четыре с remote запушены.
