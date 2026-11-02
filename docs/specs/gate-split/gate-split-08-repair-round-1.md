---
story: gate-split-08
status: todo
returned:
worker: worker-code
model: opus
wave: 4
blocked_by: []
red: required
red_reason:
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
