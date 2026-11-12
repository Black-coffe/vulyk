---
story: post-052-tails-01
spec: post-052-tails
status: todo
returned:
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required           # --busy adds branches (DRIVER, transcript age, unknown roots) that guard a write into hives
red_reason:
---

# Ship and status tails after 0.52.0-dev.1

## Goal
`/vulyk-ship`'s description no longer says it never tags. The impossible-day hold test uses a day that is not yet
past, so it fails when the real-day rule is removed. `/vulyk-status` prints the lagging-hives line in the VULYK source
with a registry. `hives-behind.sh --busy <hive>` tells a hive in use from an idle one (plan.md `## Assumptions`,
hold re-check), and step 2a asks it before every hive upgrade and again before the hive commit, and re-checks every
live hold on each ship. CHANGELOG `[Unreleased]` names the changes.

## Requirements
> в описании /vulyk-ship осталось «never tags», хотя локальный тег теперь ставится;
> тест на «несуществующий день» берёт уже прошедшую дату, поэтому проходит и без самого правила;
> строка про ульи с отставанием в /vulyk-status вынесена за рамки задачи;
> до 19.11 пересмотреть паузы 10 ульев.
> 7. Шаг 2a /vulyk-ship на каждом выпуске перепроверяет все паузы и перед обновлением любого улья проверяет, не занят ли он: обновляется только улей с чистым деревом на своей ветке, без файла сборки DRIVER и без записи в журнал сессии за последние 60 минут; если журналы улья не найдены - он считается занятым; занятый улей получает паузу с причиной. Перед коммитом в улье проверка повторяется: появились чужие файлы - стоп и сообщение владельцу. Первая такая проверка проходит при выпуске этой правки, до 19.11.

## Files
- scripts/hives-behind.sh
- .claude/commands/vulyk-ship.md
- .claude/commands/vulyk-status.md
- tests/maintenance.test.sh
- CHANGELOG.md

## Non-goals
- `hives-behind.sh` gains only `--busy`; its judge, registry and `--check` forms stay as they are.
- No detection of an open but silent session (process lists, ListAgents): the owner accepted that gap.
- No SessionStart line for lagging hives (the owner chose the status line only).
- Do not reword the rest of step 2a or step 3 (publish order).
- Do not run the hold re-check now: it runs at this spec's ship.

## Map slice
`memory/map/agents-and-commands.md` (`/vulyk-ship` step 2a, `/vulyk-status`); `memory/map/scripts.md` (`hives-behind.sh`)

## Acceptance criteria
- [ ] `vulyk-ship.md` description says the only tag is the local dev build's, never pushed; "never tags" is gone; a maintenance check pins it.
- [ ] The impossible-day check uses `hold 2026-11-31` with `VULYK_TODAY=2026-11-28` and expects exit 1 and `is not a real day`; with the real-day `return 1` in `day_number` removed by hand, the check goes red (done once while building, noted below, then restored).
- [ ] `vulyk-status.md` has a step that runs `bash scripts/hives-behind.sh` only where `install.sh` and `VERSION` are at the root and the registry exists, printing its summary and `RED` lines; elsewhere nothing. A maintenance check pins `hives-behind.sh` in the command.
- [ ] `hives-behind.sh --busy <hive>` prints `idle` (exit 0), `busy <reason>` (exit 1) on a `docs/specs/*/DRIVER` file or a transcript written in the last 60 minutes under any root, and `unknown <reason>` (exit 1) when no root has the hive's transcript dir; roots from `VULYK_SESSION_ROOTS` when set, else `${CLAUDE_CONFIG_DIR:-~/.claude}` plus every `~/.claude*`. Maintenance checks cover idle, DRIVER, fresh transcript, stale (over 60 min) transcript = idle, a second root, no dir = unknown, and the slug of a path with `_` and `:`.
- [ ] Step 2a says every ship re-checks each live hold and asks `--busy` before every hive upgrade: idle + clean tree + ship branch -> hold removed, hive upgraded; busy or unknown -> a hold with that reason, date <= 7 days; a dirty tree is never touched; right before the hive commit `--busy` and `git status --porcelain` run again, and a path the upgrade did not write or a busy verdict stops that hive with no commit and a line to the owner. Maintenance checks pin these lines.
- [ ] CHANGELOG `## [Unreleased]` carries the changes.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
