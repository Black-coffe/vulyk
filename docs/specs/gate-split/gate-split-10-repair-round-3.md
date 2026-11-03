---
story: gate-split-10
status: done
returned: DONE
worker: worker-code
model: opus
wave: 6
blocked_by: []
red: required
red_reason: ::error::suite row parser: an empty command cell must be a row with no command
red_verified_at: 2026-11-03T00:48:57Z 21977ed578ff85375c87cf2d30475f3b16e76b2e2668b5d89b61e86c143be460
---

# Repair round 3

## Goal
Make the asks and findings council round 3 left RED pass, and change nothing else.

## Requirements
> 9. В проектах на VULYK свой «полный прогон» можно разбить на несколько строк-частей с лимитом 300 с на каждую, и при обновлении об этом сказано.

## Findings
ASK 9: RED - hive full run splittable into 300 s part rows, upgrade says so - run: install.sh --upgrade on a hive with a filled row; cycle.sh suite on fixture hives (probes A-D) saw: upgrade note printed for a hive that already has the row (owner reopen item 1 holds). But reopen item 2 fails: one row `| Full suite (round-only) |  |` -> suite.log "head=... steps=0 / SUITE: none", suite "none"; a missing cell `| Full suite (round-only) |` -> SUITE: none; rows unit=`true` + e2e=empty -> "steps=1", only "PART full-suite-unit-round-only- ok", "SUITE: ok": the empty row is silently dropped and not named in the log (full_suite_row `next`s an empty cell, cycle.sh:1621). Reopen item 3: two rows with the same Purpose both log "PART full-suite-round-only-" (step 1 ok, step 2 FAIL): no distinct part names
1. CHANGELOG.md [ask 9] the gate-split `[Unreleased]` entry must be committed on the branch, since the new check tests/telemetry.test.sh:1540 ("CHANGELOG [Unreleased] has the gate-split entry") passes only against the uncommitted working-tree CHANGELOG.md (a paperwork path, scripts/lib.sh:61, so close-story never committed it), while the committed head fails it, as does any clean checkout such as CI's full-suite job - repro: `git show 0af5804:CHANGELOG.md | sed -n '/^## \[Unreleased\]/,/^## \[[0-9]/p' | grep -c 'Gate split (ADR-029)'` -> 0
2. scripts/cycle.sh:1620 [ask 9] a `Full suite ... (round-only)` row whose command cell is empty or missing must make a red step that names the row in suite.log, never a silent drop and never `SUITE: none` (owner reopen item 2, brief.md "After escalation"); this diff leaves full_suite_row unchanged (`if (lc == "" ...) next`), so a sole empty row still turns the gate off via cmd_suite's `SUITE: none` branch (scripts/cycle.sh:3060) - repro: `git diff efb4e9f..0af5804 --stat -- scripts/` is empty; probe a constitution with only `| Full suite B (round-only) | |` through full_suite_row -> exit 1, no row
3. scripts/cycle.sh:3083 [ask 9] a step number K beyond the row count must fail the step, and two rows with the same Purpose must get distinct PART names (scripts/cycle.sh:3097 derives pname from Purpose alone) (owner reopen item 3, brief.md "After escalation"); neither is in this diff, so step K still selects an empty row and records `ok` from `bash -c ""`, and duplicate Purposes still print identical PART lines - repro: `git diff efb4e9f..0af5804 -- scripts/cycle.sh` is empty

## Files
- tests/full-suite.sh
- tests/full-suite.test.sh
- scripts/suite-parts-check.sh
- docs/defects/test-gate-one-long-limit.md
- docs/defects/test-gate-one-long-limit.original.fixture
- docs/defects/test-gate-one-long-limit.neighbour.fixture
- docs/defects/INDEX.md
- .github/workflows/ci.yml
- scripts/cycle.sh
- tests/council.test.sh
- tests/cycle.test.sh
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- .claude/commands/vulyk-build.md
- tests/solo.test.sh
- tests/e2e.test.sh
- tests/model-profile.test.sh
- tests/telemetry.test.sh
- templates/plan.md
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- .claude/agents/cycle-clerk.md
- .claude/agents/lead-review.md
- .claude/commands/vulyk-review.md
- CLAUDE.md
- install.sh
- .claude/commands/vulyk-update.md
- docs/adr/029-gate-split.md
- docs/adr/001-cycle-state-contract.md
- docs/adr/023-fast-story-checks-full-suite-per-round.md
- docs/adr/024-no-reliance-on-background-commands-in-subagents.md

## Verification
`bash tests/full-suite.test.sh`
`bash tests/council.test.sh --part advance`
`bash tests/council.test.sh --part roster`
`bash tests/solo.test.sh`
`bash tests/model-profile.test.sh`
`bash tests/e2e.test.sh`
`bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part install-xp`
`bash tests/telemetry.test.sh --part constitution`
`bash tests/telemetry.test.sh --part constitution2`
`bash tests/telemetry.test.sh --part ysk`
`bash tests/telemetry.test.sh --part ysk-hook`
`bash tests/council.test.sh --part suite`
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part escalate`
`bash tests/council.test.sh --part replays`
`bash tests/council.test.sh --part replays2`
`bash tests/driver.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/council.test.sh --part walks`
`bash tests/council.test.sh --part walks2`
`bash tests/council.test.sh --part seats2`
`bash tests/council.test.sh --part roster2`
`bash tests/council.test.sh --part ceilings`
`bash tests/council.test.sh --part ceilings2`

## Red receipt
- command: bash tests/council.test.sh --part suite
- exit: 1
- tests: 21977ed578ff85375c87cf2d30475f3b16e76b2e2668b5d89b61e86c143be460 (tests/council.test.sh, tests/driver.test.sh, tests/e2e.test.sh, tests/full-suite.test.sh, tests/model-profile.test.sh, tests/solo.test.sh, tests/telemetry.test.sh)
- impl: e164ec75f5bf022f25b2c4b9604d5dec18342842c455c82706b3617d4aa5e34d
- stamped: 2026-11-03T00:48:57Z

```
SUITE: FAIL 0s - part full-suite-round-only- failed
::error::suite step beyond rows: a step past the row count must fail - exit=0 out=cycle: sxbeyond - round 1 suite step 3/3: ok 0s
{"ok":true,"verb":"suite","exit":0,"next":"dispatch:review","step":3,"steps":3,"done":true,"suite":"ok","status":{"spec":"docs/specs/sxbeyond","slug":"sxbeyond","stage":"03-built","next":"dispatch:review","briefed":true,"approved":true,"branch":"main","head":"8824f07","pack":"ecd71d438ed1","stories":{"todo":0,"in-progress":0,"done":1,"blocked":0},"wave":null,"wave_stories":[],"round":1,"ceiling":1,"tier":1,"open":true,"court":null,"missing":["review"],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":"docs/specs/sxbeyond/council/round-1","paused":false,"shipped":false,"since":null,"seat_attempt":{"review":1},"seats":["review"],"manual":[]}} log=head=9bf30da steps=3
STEP 1/3: ok 0s
STEP 2/3: ok 0s
STEP 3/3: ok 0s
PART  ok 0s cap 300s
SUITE: ok 0s
suite: no round-only full-suite row -> SUITE: none, done at once
  ok    no row -> SUITE: none, steps 0, done
```

## Implementation notes
- scripts/cycle.sh full_suite_row: an empty or missing command cell (also a row with no closing pipe) prints the row with an empty command instead of being dropped; `<fill in...>` and `none` still mean no suite (finding 2).
- scripts/cycle.sh cmd_suite: an empty command is a red step, `PART <name> FAIL 0s cap <C>s - no command in its row`; a sole empty row no longer reaches `SUITE: none`; a `steps` marker is ignored on an empty row (finding 2).
- scripts/cycle.sh cmd_suite: plain steps pick row K by number; K past the row count is the red part `step-<K>-no-row`; Purposes that normalise to one name get the step number appended, e.g. `full-suite-round-only-1` and `-2` (finding 3).
- tests/council.test.sh --part suite: the old "empty cell refused" parser case now expects a row with no command; new cases cover a sole empty row, a sole missing-cell row, a good row beside an empty one, duplicate Purposes and a step past the rows.
- CHANGELOG.md (paperwork, not in ## Files, so close-story does not stage it): the gate-split entry gains one sentence and is committed in its own commit after close-story (finding 1).
