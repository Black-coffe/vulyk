# Brief: gate-split

**Date:** 2026-11-02
**Tier:** 3 (cross-cutting: the suite runner, every long test file, cycle.sh round and close-story verification, the reviewer agent and the driver)

## Request (verbatim)

> 2026-11-02, spec `weekly-budget` round 2 ESCALATE (suite 904 s of 905 s): «Давай запомни, построй запрет, разрешение, правила раз и навсегда. Любые тесты, которые имеют лимиты и могут теоретически впереться в эти лимиты, переоткрываем с супердробными частями. Лучше разбить на 10 шагов гейтов дробными лимитами по 300, по 100, по 200 секунд, нежели гонять по 20-30 мин. и постоянно упираться в лимиты. Ты уже достал это дерьмо делать. Давай наводи порядок в своей технической части, экспертности, запускай тройное кросс-валидирование агентами и сделайте раз и навсегда нормальные тесты без вот этих лимитов.»

> 2026-11-02, same session: «да, сначала тесты, потом weekly-budget или паралельно едалй»

> 2026-11-02, this session: «Новая сессия поднимет 20261102-194530-gate-split.md и продолжит с пункта 1»

## Context

- Defect card `docs/defects/test-gate-one-long-limit.md` (2b52d67) holds the owner's rule (Never / Allowed / How-to); its `check:` is empty = Law 6 debt this spec pays.
- Triple cross-validation (crossgrill, fable/opus/sonnet, R1+R2), verdict in `.crossgrill/2026-11-02-gate-split/verdict.md` (git-ignored; summary here):
  1. Cap per part (hard 300 s) and per step (one Bash call, < 600 s). 3/3.
  2. The suite runs ONCE per round before seats are dispatched, in steps; reviewers read the SHA-bound log and may rerun single parts. 3/3.
  3. A part at its cap is a FAIL of that part ("cut part X"), never a `suite-timeout` escalation. 3/3.
  4. Growth check is red, not a warning (Law 6): a part over 70% of its cap (210 s at 300) on contended time fails the gate. 3/3 red; threshold 2/3 (one seat: red at alone > 150 s).
  5. Runtime cap acts on contended time at the real `--jobs`; the cutting target is ~100 s alone. 3/3.
  6. close-story: per-line cap; a repair story keeps only lines covering its Files; lines deduplicated; when the next line would not fit a call, stop with a resume mark and continue in the next call. 3/3.
- Measurements 2026-11-02 (this box, 12 jobs): 51 jobs, wall 698 s, sum 7042 s. Alone vs contended: solo 192/377, e2e 145/303, telemetry constitution 195/282, install 162/280, ysk 158/202, model-profile 151/262, council replays 135/271, council walks/seats/roster/ceilings 102-117/205-225; every part under 200 s alone; contention 1.3-2.1x.
- `tests/driver.test.sh` exits 0 "skipped: node not found" on a box without node: a vacuous pass.
- Speed (side-agent note relayed in the 2026-11-02 session, not an owner quote): splitting removes timeouts, not work; one run per round instead of three concurrent is the speed lever; parts in a step run in parallel, steps in sequence.

## Horizon

Skipped: not new ground (the runner, parts and round gate exist: `tests/full-suite.sh`, `--list-parts`, `cycle.sh` SUITE readers).

## Answers

1. Лимиты в CI — Те же 300 с (Рекомендую). Правило одно для всех машин, как в карточке: «раз и навсегда». Если часть на macOS упрётся в 300 с, это красный сигнал «разрежь её», а не повод поднять лимит. Риск: первый прогон в CI может покраснеть, тогда режем ещё мельче.
2. Пропуски — Показывать как SKIP (Рекомендую). Прогон отдельно выводит строку SKIP с причиной, итог считает пропуски отдельно от ok, и проверяющий видит, что именно не проверено. В CI, где node есть, SKIP превращается в ошибку. Правка небольшая: в двух тестах и в программе, которая запускает тесты.
3. Требования — Да, план на утверждение (Рекомендую). Работа затрагивает механику раунда, драйвер и все проекты на VULYK. Сначала вы видите план по историям, и только потом тратятся исполнители и суд.
4. Windows — По локальному логу (Рекомендую). Эта машина на Windows, каждый раунд пишет время каждой части в лог: время на Windows видно уже сейчас. В GitHub на Windows тесты ни разу не запускались, их сначала пришлось бы там чинить; это отдельная работа, позже отдельным планом. (2026-11-02, gate-split plan approval)


**After escalation (round 2, 2026-11-02).**
> Owner 2026-11-03: reopen. (1) install.sh --upgrade tells every hive, including one that already has a Full suite (round-only) row, that the row may be split into several part rows of 300 s each and that every verification line now has a 300 s cap; fix install.sh:268 (the reviewer no longer runs the suite: the round gate does, before the seats). (2) A Full suite (round-only) row with an empty or missing command cell is a red step (refused, named in the log), never a silent drop and never SUITE: none. (3) Reviewer minors: a step number beyond the row count fails the step; two rows with the same Purpose get distinct part names.
## Asks

1. У каждой части тестов свой лимит не больше 300 с, шаг прогона влезает в один вызов, одного общего лимита больше нет.
2. Тесты идут один раз за раунд, по шагам, до запуска проверяющих; проверяющие читают лог и могут перезапустить часть.
3. Часть, дошедшая до лимита, считается ошибкой этой части, владельца не зовут.
4. Часть дольше 210 с даёт красную проверку заранее, и карточка получает настоящую проверку.
5. solo, e2e, model-profile и длинные части telemetry и council разрезаны до ~100 с.
6. Проверка перед закрытием истории: лимит на строку, исправление берёт только проверки своих файлов, продолжение с отметки.
7. CI с теми же 300 с на часть, время частей видно на Linux, macOS и Windows.
8. Тест без нужного инструмента показывается как SKIP, а в CI SKIP считается ошибкой.
9. В проектах на VULYK свой «полный прогон» можно разбить на несколько строк-частей с лимитом 300 с на каждую, и при обновлении об этом сказано.
