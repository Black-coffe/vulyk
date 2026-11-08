# Brief: ab-run-fixes

**Date:** 2026-11-08
**Tier:** 3 - cross-cutting: `scripts/cycle.sh`, `scripts/model-profile.sh`, agent frontmatter, the plan/build/bootstrap
commands, `templates/grill.md`, `install.sh`, a hook and `README.md`; no schema or migration
**Source:** the A/B run autopsy written by a host hive's session (its `HANDOFF-for-vulyk.md`, kept in that hive)
§5-6 and `study/01-run-autopsy.md` (read in full this session). The request below was written by that session and pasted
by the owner; it is the owner's instruction, not the owner's own wording.
**Base:** branch `fix/law5-and-red-seal` (3 commits on v0.48.0, 2026-11-07, unreleased).

## Request (verbatim)

> Прочитай целиком [путь в улье]/HANDOFF-for-vulyk.md и рядом study/01-run-autopsy.md.
> Это разбор А/Б-прогона VULYK 0.47.0 против голого Claude Code на одной задаче: качество вровень по чек-листу
> и тестам, токенов 1,8×, остановок 18 против 4, каскад моделей не проверялся (исполнители шли на Opus).
> Решение владельца: «Сначала правки, потом замер».
>
> Задача:
> 1. Сначала git status: в дереве может быть чужая работа (ветка fix/law5-and-red-seal) — не затирай.
> 2. /vulyk-plan по разделам 5 и 6 handoff: все 15 правок и 8 трений из производства. Каждую сверь с кодом
>    текущего VULYK (разбор делался на 0.47.0, часть могла уже поменяться в 0.48) — что уже исправлено, отметь
>    и не делай повторно. Порядок — по цене из таблицы, первой правкой — профиль моделей (sonnet-builds по
>    умолчанию), без неё следующий замер снова сравнит Opus с Opus.
> 3. Отдельной спекой после правок — план замера по разделу 8 (5 задач, скрытые тесты, слепой судья другого
>    производителя, оператор-скрипт, порог решения записан до прогонов). Замер не запускать без «да» владельца:
>    это ~31 млн weighted.
> 4. README поправить честно: результат этого прогона, что каскад не проверялся, тезис про окно 1M не подтверждён.
>
> Логи и клоны в [папка с логами] — только на чтение, это улики ролика. Видео не открывать. Ничего не публиковать,
> не тегать и не пушить без «да» владельца. Пиши владельцу по-русски.

Owner quotes as recorded by the host hive's session (HANDOFF §1, 2026-11-08):

> если вулик реально отстой надо честно сказать и во первых перестать его использовать на проектах, во вторых понять все слабые сторонгы и моменты и попрравить и уброать

> Сначала правки, потом замер (Рекомендую)

(the second one is an option label the owner picked, written by that session.)

## Reconciliation with the code (recon, 2026-11-08, HEAD 75273d2)

Item numbers are HANDOFF §5 (1-15) and §6 (F1-F8). "Open" = the 0.47 behaviour is still there.

| # | Item | State at HEAD | Evidence |
|---|---|---|---|
| 1 | default profile `sonnet-builds`, Opus workers only on the owner's word, profile in the plan header | open: `--recommend` gives `opus-builds` to any premium plan; the quiz puts it first | `scripts/model-profile.sh:131`, `.claude/commands/vulyk-models.md:16` |
| 2 | council: one blind seat, second Tier 4 reviewer only on BLOCK or risk files, `haiku` only on a real Client path | open: Tier 3-4 = `opus review` (+`haiku` when Client path is filled); Tier 4 always two reviewers | `scripts/cycle.sh:381-394`, `.claude/workflows/vulyk-cycle.js:235-238` |
| 3 | `carry_seats` must not carry a seat whose ask the repair touched | open: carries every GREEN/N/A blind seat | `scripts/cycle.sh:2656-2678` |
| 4 | drop `cacheTtl: 1h` | open on all three | `.claude/agents/{lead-review,worker-code,worker-test}.md:9` |
| 5 | narrow repair (one ask, one file) takes the Tier 1 path | open in code; exists only as a text card | `docs/defects/` card `full-round-for-a-narrow-fix` (no `check:`) |
| 6 | bootstrap: no seven-area scout map, interview only on discrepancies, no handoff/clear push | open: step 4 maps every module; `--quick` exists but is opt-in; the 86 % push is `handoff.py` | `.claude/commands/vulyk-bootstrap.md:11,53`, `.claude/hooks/handoff.py:777` |
| 7 | plan recon reads `memory/map` first, scouts only for missing or stale areas | partly there: step 3 already says "map first, scout only for broad or unmapped territory", with no staleness test, so the Queen sent 4 anyway | `.claude/commands/vulyk-plan.md` step 3 |
| 8 | grill in a batch of up to 4; horizon only by `--horizon` in existing code; Confirm merged with approve; approve launches the build | open: "one question per turn, never a bundle"; horizon fires on a grep test (a new capability in an old repo is "new ground"); the fixed last question is the Confirm | `templates/grill.md:20,35-42`, `vulyk-plan.md` step 3a |
| 9 | the Queen does not wait on Workflow past 55 min | open: nothing in the command | `.claude/commands/vulyk-build.md` |
| 10a | `stamp-red` seals only test-shaped files | **done on this branch, unreleased** | `d27a4da`, `ed7e7de` (ADR-025 D2 amended, `tests/cycle.test.sh` part red) |
| 10b | the plan is committed before `claim` | open: step 9 commits only at approval; the run stopped before it and `claim` refused a dirty tree | `vulyk-plan.md` step 9, `scripts/cycle.sh:3343-3349` |
| 11 | one `suite` command for all parts, one clerk per boundary | open; **conflicts with the owner rule "split gates, never raise the limit"** (each part stays under the clerk's Bash timeout). The per-step commit (`suite round N step K/S`) can go without breaking it | `scripts/cycle.sh:3163`, `vulyk-cycle.js:191-212` |
| 12 | docker stacks: Commands rows with `exec -u <user>` | open | `vulyk-bootstrap.md` step 2, Commands |
| 13 | `close-story` refuses a closer that is not the claimer | **done on this branch for the Queen (Law 5), unreleased** | `75273d2` |
| 14 | `install.sh` without the telemetry question | partly there: `--telemetry on/off` and no-TTY skip the question; the bare interactive install still asks | `install.sh:628-638` |
| 15 | README: this run's result, the cascade not measured, the 1M claim unconfirmed | open | `README.md:40`, `:63` |
| F1 | `verify_run` eats stdin | open: no `< /dev/null` | `scripts/cycle.sh:2011,2018` |
| F2 | `status: open` silently skipped | open: counted as todo, never listed in a wave | `scripts/cycle.sh:591-596, 606` |
| F3 | a manual step holds the whole wave | **not reproduced by reading**: ready stories of the wave are built before the manual stop | `scripts/cycle.sh:629-640`; repro needed |
| F4 | Verification not a Commands cell: no hint | partly there: `wave-check` warns at plan time; `close-story`'s refusal names the segment but not the fix | `scripts/cycle.sh:1950-1953`, `scripts/wave-check.sh:238` |
| F5 | a worker returns without committing, the next `claim`/`open-round` stops | open | `scripts/cycle.sh:2836, 3347` |
| F6 | `story-split-check` | **not VULYK**: the host hive's own `scripts/story-split-check.sh`, `.claude/hooks/story-split-gate.sh` | out of scope here |
| F7 | blind-verdict hook blocks Bash | **not VULYK**: the host hive's own `.claude/hooks/blind-verdict-guard.sh` | out of scope here |
| F8 | judge on the gate model hits the Fable limit | partly there: the driver falls back to Opus after a refusal (0.39); the expensive failures were the host hive's own judge batches | `vulyk-cycle.js:46,66,125-142` |
| F9 (found this session) | the litopys offer fires although litopys is installed at user scope | open: the hook reads only the project settings files | `.claude/hooks/session-start-brief.sh:126` |

## Conflict with pending work

The 2026-11-08 mass audit (47 findings, private report) and a second hive owner's bundle (33 defects, not yet on disk) touch the
same files: `cycle.sh` (close-story, the dirty-tree predicate), `install.sh`, the hooks. The handoff of 2026-11-08 22:11
records the decision not to fix those before reconciling with the bundle.

Owner's decision on it, verbatim, 2026-11-08 (mid-planning, this session):

> Предлагаю все поправить, и то что мы готовили и то что прислали с проекта ютюба, этов се правим сейчас, а вот когда от АВлексея получсим данные просто сверим что с того всего мы не сделали еще и дозакроем

So both are fixed now: this spec carries the A/B-run items; the 47 audit findings get their own spec,
`mass-audit-fixes`, built after this one (same files, so sequential, not parallel). When the bundle arrives, it is
reconciled against what both specs closed and only the remainder is fixed.

Horizon step skipped: the request is inside existing code (every item names a VULYK file).

## Answers

1. Один судья (Рекомендую): Одно слепое место: «чёрный ящик», если у проекта есть Client path, иначе судья замысла. Второй ревьюер на Tier 4 только при BLOCK первого или если дифф задел файлы безопасности или данных. Почему: в прогоне места дублировали друг друга, экономия ≈0,55 млн.
2. Исполнитель + ревью (Рекомендую): Одна история исполнителю, проверка только тестами этого файла, один ревьюер по диффу без слепых судей и полного прогона, карточка дефекта тем же коммитом. Закон 5 цел, а самая дорогая часть (совет и 7 частей прогона) уходит. Это и есть ваше правило «узкая правка без полного раунда» от 16.10, только в коде.
3. Верно, план покажи (Рекомендую): 22 строки становятся требованиями, план ждёт вашего утверждения. Почему: следом идёт ещё спека на 47 находок аудита по тем же файлам, и сессия уже длинная, так что порядок волн стоит увидеть до сборки.

## Asks

1. Профиль моделей: `--recommend` всегда даёт `sonnet-builds`, `opus-builds` включается только явным выбором владельца, профиль печатается в шапке плана.
2. Совет Tier 3–4: одно слепое место (если у проекта есть Client path, это «чёрный ящик», иначе судья замысла); второй ревьюер Tier 4 — только при BLOCK первого или если дифф задел файлы безопасности и данных.
3. Раунд 2 и дальше не переносит место, чей пункт задела ремонтная история.
4. Убрать `cacheTtl: 1h` у `lead-review`, `worker-code` и `worker-test`.
5. Узкая правка (один пункт, один файл): одна история исполнителю, проверка тестами этого файла, один ревьюер по диффу. Без слепых мест и полного прогона, карточка дефекта тем же коммитом.
6. Bootstrap: факты берутся из репо, вопросы — только при расхождении. На старте не строит карту всех областей и не толкает к handoff/clear.
7. Разведка плана: если у области есть свежая карта, разведчика туда не шлём.
8. Грилевка пачкой до 4 вопросов. Горизонт в существующем репо — только по `--horizon`. Подтверждение требований совмещено с утверждением плана, а утверждение Tier 3–4 сразу запускает сборку.
9. Главная сессия не простаивает дольше часа во время сборки, чтобы кэш не умирал.
10. План коммитится раньше, чем `claim` начнёт отказывать из-за грязного дерева.
11. Прогон частей без отдельного коммита на каждую часть. Сами части остаются, по правилу «гейты дробить».
12. В docker-стеке bootstrap пишет строки Commands с `exec -u <user>`.
13. Печать `stamp-red` и запрет Queen закрывать историю уже лежат на ветке: принять, не переделывать.
14. `install.sh` по умолчанию не спрашивает про телеметрию (выключена), спрашивает только при `--telemetry ask`.
15. README: результат прогона, каскад моделей не проверялся, тезис про окно 1M не подтверждён.
16. Строка проверки в `verify_run` не съедает ввод следующей строки.
17. Неизвестный статус истории (`open`) — ошибка в `status`, а не молчаливый пропуск.
18. Ручной шаг в волне: сначала repro. Если готовые истории правда ждут — чиним, если нет — закрываем как не баг.
19. Отказ `close-story` из-за строки проверки вне Commands подсказывает готовую строку.
20. Исполнитель вернулся без коммита: драйвер возвращает историю ему же, а не останавливает сборку.
21. Предложение поставить litopys не всплывает, если плагин включён на уровне пользователя.
22. Отдельная спека-исследование: план замера по разделу 8 handoff. Запуск только после «да» владельца.
