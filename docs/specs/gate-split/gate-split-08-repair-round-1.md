---
story: gate-split-08
status: done
returned: DONE
worker: worker-code
model: opus
wave: 4
blocked_by: []
red: required
red_reason: ::error::suite split rows: the second row did not run
red_verified_at: 2026-11-02T22:33:48Z edc7a4c66012383c91897528adb63954c4829a7d8a1aa269b98e29a3c89b3932
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 9. В проектах на VULYK свой «полный прогон» можно разбить на несколько строк-частей с лимитом 300 с на каждую, и при обновлении об этом сказано.

## Findings
ASK 9: RED - a hive can split its full run into several 300 s part rows, and the upgrade says so - run: full_suite_row on a CLAUDE.md with rows "Full suite unit (round-only) | bash a.sh" and "Full suite e2e (round-only) | bash b.sh" saw: only "Full suite unit (round-only)<TAB>bash a.sh". The awk does `exit` at the first match and cmd_suite reads that one row (S=1), so b.sh never runs. The install.sh:1520-1523 upgrade note and the ADR text both promise "you may list several such rows (each one part)"; the council suite tests delete every other Full suite row, so this case is never tested
1. tests/full-suite.test.sh:171-177 [regression] suite full-suite, check "a job inside the cap is ok": the runner test must not depend on a trivial job ending inside a 1 s window, because under VULYK_PART_CAP=1 on the uncapped path tests/full-suite.sh:154 reads `secs -ge PART_CAP` on whole-second SECONDS, so under the round's contention `mark` measured 1s and came out `PART mark CAP 1s cap 1s` (round log line 34, part log /tmp/tmp.oBaKnOGzuT/29.log); it passes alone, so the round gate is red at random - repro: `bash tests/full-suite.test.sh` inside a loaded step (alone: green).
2. scripts/cycle.sh:3473 [regression] suite maintenance, check "portability-check: the tree exits 0" (2 failed): scripts/cycle.sh must pass the card shell-needs-gnu-or-bash4 gate, but the comment added inside cmd_repair's multi-line `findings="$(` puts an unpaired apostrophe ("round's") inside a $( ), which bash 3.2 reads as an open quote, and the gate now reports 8 case-in-subst hits at cycle.sh:3583-3779; base is clean - repro: `bash scripts/portability-check.sh scripts/cycle.sh` (8 hits) vs `git show b054df7:scripts/cycle.sh > /tmp/c.sh && bash scripts/portability-check.sh /tmp/c.sh` (ok).
1. scripts/cycle.sh:1619 [ask 9] the round gate must run every `Full suite ... (round-only)` row of a hive's `## Commands` as its own capped part, but full_suite_row exits at the first matching row and cmd_suite (scripts/cycle.sh:3042, 3058) sets S=1, so a hive that splits its row as install.sh:1517-1518 and .claude/commands/vulyk-update.md step 6 tell it to never runs its second and later rows and still records SUITE: ok - repro: a constitution with rows `| Full suite unit (round-only) | \`bash a.sh\` |` and `| Full suite e2e (round-only) | \`bash b.sh\` |` -> full_suite_row prints only `bash a.sh`.
2. scripts/cycle.sh:1613-1617 [regression] the `## Commands` row parser that cmd_suite executes must take exactly the second cell and refuse an empty one: `c = substr(line, i + 1)` keeps every later cell, so `| Full suite (round-only) |  | echo PWNED |` yields the command `| echo PWNED` where base refused the empty cell (`c ~ /^\|/` -> next, `git show b054df7:scripts/cycle.sh` full_suite_row_round_only: not found, SUITE: none), and `| Full suite (round-only) | \`bash t.sh\` | echo PWNED |` yields `bash t.sh | echo PWNED`, which cmd_suite runs through `bash -c` (scripts/cycle.sh:3060-3087) - repro: source full_suite_row from both revisions and feed those two three-column rows.
- [regression] PART full-suite FAIL 39s cap 300s
- [regression] PART maintenance FAIL 84s cap 300s

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

## Implementation notes
- scripts/cycle.sh full_suite_row: prints every matching row (no `exit` at the first); splits the row into cells with `\|` masked, command = exactly cell 2, an empty cell 2 is refused, later cells dropped.
- scripts/cycle.sh cmd_suite: with several rows S = row count and step K runs row K as one capped plain part; the `steps` marker is read only when there is a single row (a stepped runner among split rows runs plain).
- scripts/cycle.sh cmd_repair: comment "the round's own gate" reworded so no apostrophe sits inside the `$(` block (portability-check: ok, 0 hits).
- tests/full-suite.test.sh: the uncapped block asks only that the mark job ran and got a PART line (ok or CAP), not that it ended inside 1 s; its started marker is cleared first.
- tests/council.test.sh --part suite: a two-row split case and three parser cases (empty cell 2, a third cell, an escaped pipe).
- The two `[regression] PART ... FAIL` findings were the round's red parts from finding 1 (full-suite) and finding 2 portability (maintenance); not rerun here beyond portability-check and full-suite.test.sh.

## Red receipt
- command: bash tests/council.test.sh --part suite
- exit: 1
- tests: edc7a4c66012383c91897528adb63954c4829a7d8a1aa269b98e29a3c89b3932 (tests/council.test.sh, tests/driver.test.sh, tests/e2e.test.sh, tests/full-suite.test.sh, tests/model-profile.test.sh, tests/solo.test.sh, tests/telemetry.test.sh)
- impl: 9337609a15b09d3b1fda5d120ba3dd3548324a4787cdc73b972e2251a552523e
- stamped: 2026-11-02T22:33:48Z

```
{"ok":true,"verb":"suite","exit":0,"next":"dispatch:review","step":1,"steps":1,"done":true,"suite":"ok","status":{"spec":"docs/specs/sxsplit","slug":"sxsplit","stage":"03-built","next":"dispatch:review","briefed":true,"approved":true,"branch":"main","head":"bdba48d","pack":"efab022b16f1","stories":{"todo":0,"in-progress":0,"done":1,"blocked":0},"wave":null,"wave_stories":[],"round":1,"ceiling":1,"tier":1,"open":true,"court":null,"missing":["review"],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":"docs/specs/sxsplit/council/round-1","paused":false,"shipped":false,"since":null,"seat_attempt":{"review":1},"seats":["review"],"manual":[]}} log=head=c34e6c8 steps=1
STEP 1/1: ok 0s
PART full-suite-unit-round-only- ok 0s cap 300s
SUITE: ok 0s
suite: the row parser takes exactly the second cell and refuses an empty one (gate-split-08, finding 2)
::error::suite row parser: an empty command cell gave 'Full suite (round-only)	| echo PWNED' (exit 0)
::error::suite row parser: a three-cell row gave 'Full suite (round-only)	bash t.sh | echo PWNED'
  ok    an escaped pipe stays inside the second cell
suite: no round-only full-suite row -> SUITE: none, done at once
  ok    no row -> SUITE: none, steps 0, done
```
