---
story: post-046-tails-01
spec: post-046-tails
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a red run re-dispatched green on the same commit -> ci ok
red_verified_at: 2026-11-03T17:11:13Z 3d8715bb3e95f4363b7b6db6ac6b499e00df4cdf847ee9a732cb4d398232358a
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
- `ci_check` asks gh for `createdAt` too, then `sort -t<TAB> -k4,4r | awk -F'\t' '!seen[$3]++'` keeps the newest
  run per workflow before the unchanged judging awk. ISO 8601 UTC sorts as text, so no date parsing. The fake gh
  rows in `--part ship` gained the fourth column; new cases write rows oldest first so the order is the script's.
- `stamp-red` tail: `grep -F -- "$REASON" | head -n 3` then `tail -n 10`, one redact pass over both. When the
  reason line is already in the last ten it shows twice; accepted, the receipt format is otherwise unchanged.
- vulyk-ship.md step 1: one sentence for `ci: <workflow> failure on <sha>` (log, rerun or fresh dispatch).
  vulyk-build.md green: ship pushes the spec branch, prints tag and publish. The maintenance green-terminal
  checks still match (the strings they grep are untouched).
- `createdAt` checked live: gh 2.91.0 `gh run list --help` lists it, and the exact `--json/--jq` query on this
  repo printed `completed	success	CI	2026-11-03T15:25:59Z` rows. A `gh run rerun` keeps the run id (and its
  createdAt) and changes its own conclusion, so it never needed the newest-run rule; a fresh dispatch does.

## Findings

## Red receipt
- command: bash tests/cycle.test.sh --part ship
- exit: 1
- tests: 3d8715bb3e95f4363b7b6db6ac6b499e00df4cdf847ee9a732cb4d398232358a (tests/cycle.test.sh)
- impl: fc91ad61a6464397a319dc87497d3742f9dec9d78900da3c7ec1dbfb69a3f1b0
- stamped: 2026-11-03T17:11:13Z

```
  ok    GREEN + newer ACCEPTED at HEAD is READY
  ok    code after ACCEPTED: stage 05 is OPEN
  ok    code after ACCEPTED: 05 names STALE (commit)
  ok    code after ACCEPTED: NOT READY
  ok    VERSION + CHANGELOG.md after ACCEPTED stays READY
  ok    a new story after ACCEPTED: 05 names STALE (pack)
  ok    a new story after ACCEPTED: NOT READY
the paperwork whitelist is anchored to docs/specs/*/ (R23/m-2): a commit under src/council/ or a bare src/journal.md is never paperwork, even though it shares the names
  ok    CURRENT right after the recorded check
  ok    src/council/x and src/journal.md are not paperwork -> STALE
```
