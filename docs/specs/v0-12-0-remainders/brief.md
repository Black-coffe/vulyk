# Brief: v0-12-0-remainders

**Date:** 2026-09-13 · **Owner:** Andrei · **Tier:** 4 (the cycle state contract, both drivers, the installer, six command files, the ADR record and the docs that describe them)
**Escaped from:** autonomous-cycle
**Carried forward from:** [docs/specs/autonomous-cycle/plan.md](../autonomous-cycle/plan.md) `## Next circle` (39 items, council rounds 1-2) + council round 3 `review.md` (7 majors, 14 minors) + three installer defects found after the merge.

## Request (verbatim)

> Следующий круг (новая сессия, по твоему решению): /vulyk-plan «остатки v0.12.0» — гриль сам соберёт пункты из plan.md ## Next circle, найденных инсталлерных хвостов (ADR-утечка, неудаление устаревших файлов, конституция при апгрейде) и мажоров раунда 3. И первый настоящий тест Haiku-места — прогнать одну живую задачу в хайве с заполненным Client path.

## Inventory the request points at (counted 2026-09-13, before the grill)

| Source | Items | Where |
|---|---|---|
| `## Next circle`, council round 1 | 14 (13 + M-7, decided in delta 6 as ADR-004) | `docs/specs/autonomous-cycle/plan.md:151-167` |
| `## Next circle`, council round 2 | 25 | `docs/specs/autonomous-cycle/plan.md:169-192` |
| Council round 3 majors | 7 (lead-review 1-3, second reviewer X-M1..X-M4) | `docs/specs/autonomous-cycle/council/round-3/review.md` |
| Council round 3 minors | 14 (lead-review 1-9, X-m1..X-m5) | same |
| Installer tails | 3 | `install.sh` - see below |
| Live Haiku-seat test | 1 | no hive yet qualifies - see below |

### The three installer tails, reproduced 2026-09-13 (not recalled)

Run: `bash install.sh /e/Projects/VPN --upgrade --check` from this repo at `3e200bb`.

1. **ADR leak.** `install.sh:347` copies `docs/adr` into the hive and `shippable()` (`:49-65`)
   refuses `docs/specs/*` but names no `docs/adr/*` case. The dry run prints
   `would copy docs/adr/001-cycle-state-contract.md` … `004-driver-mutual-exclusion.md` -
   VULYK's own architecture record landing in a client hive. `install.sh:10` says the installer
   "never touches … docs/specs|adr" and `:452` closes with "your … ADRs … were not touched":
   both sentences are false for a hive that has not got these four files yet.
2. **Nothing is ever deleted.** `copy_tree` only adds or replaces; the word `remove` appears
   nowhere as an action on a target file. A framework file retired in a release (the 0.12.0
   example: `.claude/agents/drone-acceptance.md`, deleted in `7d243a9`) stays in every upgraded
   hive forever, and the dry run has no `would remove` line to show it.
3. **The constitution is never carried forward.** `install.sh:362-380` leaves `CLAUDE.md` alone
   by design and prints a `diff` hint instead. Measured across the 11 hives on this machine, all
   stamped `.claude/vulyk-version = 0.12.0`: **9 of 11 have no `## Profile` section at all**
   (`AI` and `VPN` are the two that do). The Profile is where C5's `Client path` and the
   `## Commands` rows live - the inputs `council-haiku` and `council-sonnet` are contractually
   given. So on nine hives the v0.12.0 council cannot be run as specified, and the installer
   reports success.

### The live Haiku-seat test has no venue yet

Surveyed 2026-09-13: of the 11 installed hives, `AI` and `VPN` carry the `Client path` row and
**both still hold the placeholder** (`<fill in - how a person reaches the running thing …>`);
the other nine have no row to fill. The request's "хайв с заполненным Client path" therefore does
not exist yet - filling one is part of this circle, not a precondition of it.

## Pre-grill decisions (2026-09-13, recorded before `templates/grill.md` ran)

Two questions were put to the owner in the intake session, recommended option first; the chosen
label and description are verbatim. The full grill has **not** run - fold these into `## Answers`
when it does, do not treat them as the grill's output.

**PG1. Проектные агенты хайва в этой сессии недоступны. Как продолжаем круг?**
> Перезапустить в репо (Рекомендую) — Ты закрываешь эту сессию и запускаешь Claude Code из
> E:\Projects\vulyk — тогда подтянутся .claude/agents (drone-scout, queen-planner, lead-architect,
> council-haiku/sonnet/opus, worker-code, cycle-clerk) и команды /vulyk-*.

**PG2. Скоуп «остатков v0.12.0» — 46+ пунктов, потолок CLAUDE.md 16 историй на спеку. Как резать?**
> Сначала рантайм-дефекты (Рекомендую) — Один спек ≤16 историй: 7 мажоров раунда 3 + те пункты
> Next circle, что ломают поведение (row_exists/escalate_row_exists матчат номер раунда префиксом,
> wave_stories дают заблокированную историю, close-story ставит done до коммита, **Council:**
> пишется в EOF, ok:false без error, коммит редукции суда с || true) + три инсталлерных хвоста.
> Доки, ADR-текст и CHANGELOG уезжают во второй спек.

## Where the intake stopped

`/vulyk-plan` steps 1 and 2 are done (tier called, brief written). Step 3 (recon) has **not** run:
`memory/memory.md` `## Unmapped territory` names exactly the ground this spec needs and the map
does not cover - `install.sh`, `scripts/vulyk-update.sh` upgrade mechanics, `.claude/hooks/`, and
the `docs/` narrative pages. That is two to three `drone-scout` dispatches, and they are why the
circle waits for a session launched inside this repository.

## Answers

One grill round per `templates/grill.md`, 2026-09-13, five questions; the two pre-grill decisions above fold in first. Each entry is the label the owner saw and the description they chose, verbatim.

**PG1. Проектные агенты хайва в этой сессии недоступны. Как продолжаем круг?**
> Перезапустить в репо: Ты закрываешь эту сессию и запускаешь Claude Code из E:\Projects\vulyk — тогда подтянутся .claude/agents (drone-scout, queen-planner, lead-architect, council-haiku/sonnet/opus, worker-code, cycle-clerk) и команды /vulyk-*.

**PG2. Скоуп «остатков v0.12.0» — 46+ пунктов, потолок CLAUDE.md 16 историй на спеку. Как резать?**
> Сначала рантайм-дефекты: Один спек ≤16 историй: 7 мажоров раунда 3 + те пункты Next circle, что ломают поведение (row_exists/escalate_row_exists матчат номер раунда префиксом, wave_stories дают заблокированную историю, close-story ставит done до коммита, **Council:** пишется в EOF, ok:false без error, коммит редукции суда с || true) + три инсталлерных хвоста. Доки, ADR-текст и CHANGELOG уезжают во второй спек.

**Конституция. Как переносить конституцию при апгрейде?**
> Вставлять недостающие блоки: При --upgrade, если CLAUDE.md уже конституция VULYK, но в нём нет блока VULYK:PROFILE (или VULYK:COMMANDS), инсталлер вставляет плейсхолдер этого блока на то же место, где он стоит в исходнике, и печатает, какие строки ещё держат <fill in>. Заполненные блоки не трогаются. Почему: в install.sh уже есть reset_marked_block и обе семьи маркеров, а CI-джоб install-smoke уже проверяет, что апгрейд не трогает заполненный Profile — добавляется одна ветка и один ассерт, без смены модели владения файлом.

**Удаление. Как убирать из хайва файлы, снятые в новом релизе?**
> Манифест рядом со штампом: install.sh пишет .claude/vulyk-manifest — список путей, которые он отгрузил. При --upgrade файлы из старого манифеста, которых новый релиз не отгружает, удаляются (в --check печатается would remove). Хайв без манифеста (все одиннадцать сегодня) при первом апгрейде получает манифест и отчёт о файлах в фреймворковых деревьях (OWNED), которых нет в релизе — без удаления. Почему: скаут назвал соседство штампа (install.sh:418-425) естественным местом, а список OWNED уже определяет, что фреймворк вправе трогать; свои агенты владельца в .claude/agents не страдают, потому что их нет в манифесте.

**Проверка драйвера. Чем заменить node --check?**
> Свой тест драйвера + CI-джоб: Новый tests/driver.test.sh: срезает export, компилирует тело как асинхронную функцию (так делает сам рантайм), переносит сюда харнес foldReviews и гоняет драйвер с подменёнными agent/parallel/clerk по сценариям мажоров (два красных промаха, нет second_model на Tier 4, нет args, пробельный отчёт). Без node локально тест честно печатает skipped; в CI появляется джоб с setup-node. Почему: суиты tests/ уже имеют одинаковую форму (expect, fail-аккумулятор), а три из семи мажоров раунда 3 сидят в коде, который ни разу не выполнялся.

**Живой тест. Как встроить тест Haiku-места в круг?**
> После шипа, как открытие следующего круга: Этот спек чинит инсталлер так, чтобы апгрейд приносил строку Client path в любой хайв. Сразу после шипа ты апгрейдишь один хайв (VPN — на нём уже воспроизведены все три хвоста), заполняешь Client path руками и прогоняешь там одну задачу Tier 3; результат кладётся в ## Next circle этого плана как первый пункт. Почему: верификация истории обязана быть ячейкой таблицы Commands этого репо, а прогон в другом репо ею быть не может.

**Требования. Подтверди список или правь его.**
> Подтверждаю все семь: Список становится ## Asks, интейк закрывается сразу и сборка стартует без отдельного утверждения плана. Почему: все семь пунктов уже записаны советом с номерами строк и условиями, планировщику нечего домысливать.

The seven lines shown in that question and confirmed, verbatim:
> Семь мажоров совета раунда 3 закрыты: настоящая проверка драйвера (M1), стоп после двух промахов несёт настоящую ошибку (M2/X-M1), история с ответом NEEDS_CONTEXT/WALL не закрывается (M3), запись R14 в истории 22 и абзац D2 в ADR-001 описывают драйвер как есть (X-M2/X-M3), Tier 4 без second_model отказывает на старте (X-M4).
> Рантайм-дефекты cycle.sh из ## Next circle закрыты: attempts считает попытки (LR19); номер раунда матчится точно (LR21, r2m1); **Council:** ложится по C7, не в EOF (LR25); wave_stories не отдаёт заблокированную (LR31); close-story не оставляет done при падении коммита (r2m2); no-op ветка open-round коммитит незакоммиченный ROUND (r2m3); каждый ok:false несёт error, exit 6 значит одно и то же везде (r2m4/N-m1); блок потолка несёт RED-строки и имеет тест (r2m5, r2m6); коммит редукции суда без || true, с --no-verify и без подписи (r2m7/N-m2); ячейка Commands с && матчится целиком (r2m9); оба драйвера одинаково отвечают на next:briefed (r2m15); open-round отказывает blocked-истории (r2m16); record-seat exit 3 — терминал paused (r2m17); каталог раунда без ROUND не читается как открытый (N-m3); note проходит redact (N-m7); оверрайд в ту же секунду побеждает (m-4); запись в леджер атомарна (m-10); живые скрипты больше не шлют к drone-acceptance (LR26).
> Второй драйвер на том же спеке получает отказ — семафор DRIVER через cycle.sh claim/release (M-7, решено в дельте 6).
> Сессионный бриф не запускает CLI ради гейта, который не может определить (m-11).
> Инсталлер не отгружает docs/adr и docs/wiki, и его фразы «not touched» становятся правдой.
> Инсталлер ведёт манифест .claude/vulyk-manifest и при апгрейде удаляет снятые файлы; --check печатает would remove.
> При апгрейде конституция получает недостающие блоки Profile/Commands, заполненные не трогаются.

## Asks

Confirmed by the owner on 2026-09-13 ("Подтверждаю все семь"). The council judges these lines and nothing else; everything else in this brief is context.

1. Семь мажоров совета раунда 3 закрыты: настоящая проверка драйвера (M1), стоп после двух промахов несёт настоящую ошибку (M2/X-M1), история с ответом NEEDS_CONTEXT/WALL не закрывается (M3), запись R14 в истории 22 и абзац D2 в ADR-001 описывают драйвер как есть (X-M2/X-M3), Tier 4 без second_model отказывает на старте (X-M4).
2. Рантайм-дефекты cycle.sh из ## Next circle закрыты: attempts считает попытки (LR19); номер раунда матчится точно (LR21, r2m1); **Council:** ложится по C7, не в EOF (LR25); wave_stories не отдаёт заблокированную (LR31); close-story не оставляет done при падении коммита (r2m2); no-op ветка open-round коммитит незакоммиченный ROUND (r2m3); каждый ok:false несёт error, exit 6 значит одно и то же везде (r2m4/N-m1); блок потолка несёт RED-строки и имеет тест (r2m5, r2m6); коммит редукции суда без || true, с --no-verify и без подписи (r2m7/N-m2); ячейка Commands с && матчится целиком (r2m9); оба драйвера одинаково отвечают на next:briefed (r2m15); open-round отказывает blocked-истории (r2m16); record-seat exit 3 — терминал paused (r2m17); каталог раунда без ROUND не читается как открытый (N-m3); note проходит redact (N-m7); оверрайд в ту же секунду побеждает (m-4); запись в леджер атомарна (m-10); живые скрипты больше не шлют к drone-acceptance (LR26).
3. Второй драйвер на том же спеке получает отказ — семафор DRIVER через cycle.sh claim/release (M-7, решено в дельте 6).
4. Сессионный бриф не запускает CLI ради гейта, который не может определить (m-11).
5. Инсталлер не отгружает docs/adr и docs/wiki, и его фразы «not touched» становятся правдой.
6. Инсталлер ведёт манифест .claude/vulyk-manifest и при апгрейде удаляет снятые файлы; --check печатает would remove.
7. При апгрейде конституция получает недостающие блоки Profile/Commands, заполненные не трогаются.
