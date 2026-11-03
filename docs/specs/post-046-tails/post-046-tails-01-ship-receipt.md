---
story: post-046-tails-01
spec: post-046-tails
status: todo
returned:
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a red run re-dispatched green on the same commit -> ci ok
---

# ci judges the newest run per workflow; the red receipt shows its failing line

## Goal
`ship-check.sh`'s `ci_check` asks `gh run list --commit <sha>` also for `createdAt` and keeps only the newest
run of each `workflowName` (sort on the ISO time, then `awk '!seen[$3]++'`) before judging. An old failed or
cancelled run that a newer run of the same workflow on that commit replaced no longer holds the ship; a newest
run that is red or unfinished still does. `/vulyk-ship` step 1 gains one line for `ci: <workflow> failure on
<sha>`: read the log (`gh run view <id> --log-failed`); a flake or load is cleared by `gh run rerun <id>` or a
fresh `gh workflow run` on the branch, and ship-check reads the newest run. `vulyk-build.md` `## Terminal`
`green` drops «ship prints them and never runs them» and says what ship does now: pushes the spec branch for
its CI run, prints tag and publish. `stamp-red` builds its receipt tail from the lines of the hit output that
carry `red_reason` (at most 3, `grep -F`) followed by the last 10 lines, so the receipt shows the failing check.

## Requirements
> - Ревьюер, scripts/ship-check.sh:213: строка ci хочет, чтобы каждый прогон на коммите был success. Если упавший или отменённый прогон потом повторили и он стал зелёным на том же sha, ship-check остаётся NOT READY, пока кто-то не запустит gh run rerun на старом прогоне. Инструкций на этот случай в /vulyk-ship нет.
> В .claude/commands/vulyk-build.md:126-127 осталось «Push and publish stay the owner's: ship prints them and never runs them», а vulyk-ship.md теперь пушит ветку.
> - Ревьюер: в red receipt историй 02 и 03 хвосты показывают только проходящие строки ok, без падающей проверки из red_reason. Доказательство слабое, но это не подстроенная поломка.
> 1. ci в ship-check: зелёный повтор на том же коммите снимает красный прогон, в /vulyk-ship есть инструкция.
> 2. vulyk-build.md больше не говорит, что ship ничего не пушит.
> 3. red receipt показывает падающую строку из red_reason.

## Files
- scripts/ship-check.sh
- .claude/commands/vulyk-ship.md
- .claude/commands/vulyk-build.md
- scripts/cycle.sh
- tests/cycle.test.sh

## Non-goals
- Do not change which commit ci reads (HEAD or the newest with only paperwork after it) or the gh-missing refusal.
- Do not key runs by event: a `workflow_dispatch` re-run must clear a red `push` run.
- Do not reformat the rest of `## Red receipt` or the receipt hash.

## Map slice
memory/map/cycle.md: `ship-check.sh` ci line, `stamp-red`

## Acceptance criteria
- [ ] Fake gh rows `completed failure CI <t1>` and `completed success CI <t2>`, t2 newer: `ci   ok       ci: green on <sha7> (CI)`; with t1 newer: `ci: CI failure on <sha7>`.
- [ ] Two workflows, one newest red: still OPEN naming that one.
- [ ] Existing ci cases in `--part ship` pass with a fourth column added to their fixture rows.
- [ ] A stamp whose failing output has the `red_reason` line before 10+ passing `ok` lines: `## Red receipt` contains that line.
- [ ] vulyk-ship.md has the rerun line; vulyk-build.md no longer says ship never runs push.

## Verification
`bash tests/cycle.test.sh --part ship`
`bash tests/cycle.test.sh --part red`

## Implementation notes

## Findings
