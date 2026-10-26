# Brief: fast-verification

**Date:** 2026-10-25
**Tier:** 3 (tests, close-story and the council round, lead-review, story template, the ## Commands table)

## Request (verbatim)

> Дальше разделение тестов на быстрые и полные, ты его одобрил. Причина, на которую оно отвечает: telemetry.test.sh идёт 18 минут, а close-story даёт проверке истории максимум 9.

## Context

- Owner chose this on 2026-10-25 with «Жавай» on option 1 of three. The option text is the Queen's, not an owner quote: "История проверяется быстрым набором за минуту-две, полный идёт один раз на раунде совета. Это чинит причину, а не одну машину." Rejected then: a `--quick` patch for telemetry.test.sh alone; doing nothing.
- First ordered 2026-09-23 («Запиши в следующую спеку как часть будущего хендофф»), draft in docs/specs/convergent-judge/next-circle.md.

## Recon facts (measured 2026-10-25, this box, 28 cores, Git Bash)

- Sequential, each suite alone: telemetry 1030 s, council 671 s, council --quick 249 s, cycle 114 s, intake 48 s, solo 43 s, defects 41 s, e2e 34 s, maintenance 32 s, model-profile 29 s, inject 18 s, mods 3 s, token-report 3 s, driver ~1 s. Total 2315 s (38.6 min).
- All 13 suites started at once: wall 1070 s, equal to telemetry alone (council 689 s, cycle 121 s, the rest <= 62 s). Contention is small: the wall is the slowest suite.
- `maintenance.test.sh` is red on main: `agent + command descriptions 5308 B > 4983 B` (0.35.0 added drone-horizon). CI on main failed for both 0.35.0 pushes (runs 40199426394, 40199505228). horizon-intake's stories verified with solo/telemetry only, and the round ran no full suite: VULYK's `Full suite / build` row is `none`.
- Today: close-story caps the whole ## Verification at 540 s (`scripts/cycle.sh:1999`); lead-review runs the constitution's full suite "once, prefixed with timeout 540 ... A suite that times out is a minor, never a BLOCK" (`.claude/agents/lead-review.md:49-51`).

## Answers

1. Полный набор - «Ускорить (Рекомендую)»: Один скрипт запускает все наборы разом. Телеметрию и council делим на 2–3 части. Замер: параллельно всё идёт ровно столько, сколько самый медленный набор (1070 с), так что с делением выйдет около 6–7 минут. Ревьюер запускает это как сейчас, новой механики нет.
2. Провал - «Падение блок, таймаут к тебе (Рекомендую)»: Упавший тест блокирует раунд и идёт в починку, как любая регрессия. Таймаут не чинится починкой кода истории, поэтому раунд останавливается и спрашивает тебя с цифрой времени. Зелёным не считается ни то, ни другое.
3. Метка - «Метка в таблице команд (Рекомендую)»: Строки медленных наборов в таблице команд помечаются как «только для раунда». План, назвавший такую строку, ловится ещё до сборки: ту же таблицу уже проверяет wave-check, правило встаёт рядом. close-story такую строку тоже откажется запускать. Медленный набор получает быстрые части по темам (например `--part install`), и история берёт часть под свои файлы.
4. Требования - «Подтверждаю (Рекомендую)»: plan stops for approval.


**After escalation (round 1, 2026-10-26).**
> Owner 2026-10-26: fix the root, not the budget. (1) Shared test setup is built once and reused by every part, so a part costs its own tests, not the suite's fixture again - targets ask 1 (a part in one to two minutes) and ask 2 together. (2) full-suite.sh runs whole suites (not every part) at a bounded --jobs, and the wall-clock latency suites (inject, intake) run after the rest, outside the contended window. (3) CLAUDE.md back under the model-profile.test.sh size cap. (4) judge treats SUITE: FAIL like SUITE: TIMEOUT - never green regardless of VERDICT. Then measure the full suite under round conditions (another seat running) and record it; VULYK_SUITE_TIMEOUT stays 540.

**After escalation (round 2, 2026-10-26).**
> Owner 2026-10-26, round 2: one more repair, budget stays 540 s. Fix the four bugs (record-seat SUITE: none in a hive whose round-only full-suite row has no runnable command; SUITE line forms enforced at record-seat - a missing line or TIMEOUT without seconds is never green; maintenance.test.sh slug rule vs memory-triage.sh on a checkout path with a dot; a stale install_cache lock). Mark the Council, quick row round-only. Split tests/cycle.test.sh, the longest job (293 s under round load), into --part topics so the runner fits 540 s with the latency tail under round conditions.
## Asks

1. Каждая строка проверки истории укладывается в минуту-две; telemetry и council получают быстрые части по темам, история берёт часть под свои файлы.
2. Полный набор запускается одним скриптом, все наборы разом, и проходит целиком внутри 9 минут; ревьюер запускает его один раз на раунд.
3. Упавший тест полного набора блокирует раунд; неуложившийся набор останавливает раунд и спрашивает тебя с цифрой времени; зелёным ни то, ни другое не считается.
4. Медленные строки таблицы команд помечены «только для раунда»; историю, назвавшую такую строку, ловит проверка плана до сборки, а close-story отказывается её запускать.
5. Первичная настройка (bootstrap) и шаблоны учат ульи так же делить свои команды на быстрые и полные.
