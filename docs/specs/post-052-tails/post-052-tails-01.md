---
story: post-052-tails-01
spec: post-052-tails
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required           # --busy adds branches (DRIVER, transcript age, unknown roots) that guard a write into hives
red_reason: hives-behind --slug: drive, colon and underscore become dashes
red_verified_at: 2026-11-12T19:26:08Z 108d465a499f560bd71ae0badade9568f0ff6c1350efa09bd67125d4cb111a46
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
- `scripts/hives-behind.sh`: new `--busy <hive>` and `--slug <path>` forms, ahead of the registry read. Slug = every non-alphanumeric character turned into `-`, checked against real `~/.claude/projects` folders (`.claude` -> `-claude`, `_` -> `-`). Git Bash `/e/x` is read as `E:/x`. Roots without an array (portability-check).
- Stale `DRIVER` files left by old builds make a hive `busy` (the vulyk source itself has one from weekly-budget): safe direction, the hold reason names the file.
- Impossible-day test: with the real-day `[ "$d" -le "$dim" ] || return 1` line replaced by `:`, both checks went red (2 failed), then restored.
- Step 2a canary bullet left as written: a canary that is busy is held, so it is not green and the rollout waits, as for a red canary.

## Findings

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 108d465a499f560bd71ae0badade9568f0ff6c1350efa09bd67125d4cb111a46 (tests/maintenance.test.sh)
- impl: 01a386d039d90d5d62d31c885eaabb6e161b8cf9bf1054569d0680d91624aa53
- stamped: 2026-11-12T19:26:08Z

```
::error::hives-behind --slug: drive, colon and underscore become dashes - expected '<hive slug, masked>' in:
  ok    ship 2a: the local-beta step ends on hives-behind.sh
  ok    ship 2a: the step skips by name without a registry
  ok    ship 2a: the dev build is never pushed
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
maintenance.test.sh: 577 checks, 19 failed
```
