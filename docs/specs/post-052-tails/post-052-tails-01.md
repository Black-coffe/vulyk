---
story: post-052-tails-01
spec: post-052-tails
status: todo
returned:
tier: 2
worker: worker-code
wave: 1
blocked_by: []
---

# Ship and status tails after 0.52.0-dev.1

## Goal
`/vulyk-ship`'s description no longer says it never tags. The impossible-day hold test uses a day that is not yet
past, so it fails when the real-day rule is removed. `/vulyk-status` prints the lagging-hives line in the VULYK source
with a registry. Step 2a re-checks every live hold on each ship. CHANGELOG `[Unreleased]` names the four changes.

## Requirements
> в описании /vulyk-ship осталось «never tags», хотя локальный тег теперь ставится;
> тест на «несуществующий день» берёт уже прошедшую дату, поэтому проходит и без самого правила;
> строка про ульи с отставанием в /vulyk-status вынесена за рамки задачи;
> до 19.11 пересмотреть паузы 10 ульев.

## Files
- .claude/commands/vulyk-ship.md
- .claude/commands/vulyk-status.md
- tests/maintenance.test.sh
- CHANGELOG.md

## Non-goals
- No change to `scripts/hives-behind.sh`: the status line and the hold re-check use it as it is.
- No SessionStart line for lagging hives (the owner chose the status line only).
- Do not reword the rest of step 2a or step 3 (publish order).
- Do not run the hold re-check now: it runs at this spec's ship.

## Map slice
`memory/map/agents-and-commands.md` (`/vulyk-ship` step 2a, `/vulyk-status`); `memory/map/scripts.md` (`hives-behind.sh`)

## Acceptance criteria
- [ ] `vulyk-ship.md` description says the only tag is the local dev build's, never pushed; "never tags" is gone; a maintenance check pins it.
- [ ] The impossible-day check uses `hold 2026-11-31` with `VULYK_TODAY=2026-11-28` and expects exit 1 and `is not a real day`; with the real-day `return 1` in `day_number` removed by hand, the check goes red (done once while building, noted below, then restored).
- [ ] `vulyk-status.md` has a step that runs `bash scripts/hives-behind.sh` only where `install.sh` and `VERSION` are at the root and the registry exists, printing its summary and `RED` lines; elsewhere nothing. A maintenance check pins `hives-behind.sh` in the command.
- [ ] Step 2a says every ship re-checks each live hold: clean tree on its ship branch -> hold removed, hive upgraded; otherwise a fresh hold with the reason seen now, date <= 7 days; a dirty tree is never touched. A maintenance check pins the rule.
- [ ] CHANGELOG `## [Unreleased]` carries the four changes.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
