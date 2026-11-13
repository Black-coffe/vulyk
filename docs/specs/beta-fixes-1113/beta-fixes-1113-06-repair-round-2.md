---
story: beta-fixes-1113-06
status: done
returned: DONE
worker: worker-code
model: opus
wave: 4
blocked_by: []
red: required
red_reason: resume did not switch to the spec branch named only on that branch
red_verified_at: 2026-11-13T13:43:16Z 8982f420903cc7b53ef66dfebe9997ec5ae93a18479329b30fd0cfe88b2e70c4
---

# Repair round 2

## Goal
Make the asks and findings council round 2 left RED pass, and change nothing else.

## Requirements
> 8. `/vulyk-resume` (and the build it starts) switches to the spec branch when the tree is on another branch and clean, instead of failing the first launch.

## Findings
ASK 8: RED - resume switches to the spec branch from a clean tree instead of failing the first launch - run: plan approved and journaled on main, `cycle.sh branch <spec> --commit` (creates vulyk/<slug>, writes the Branch line there only), `git switch main` (clean), `cycle.sh resume <spec>`, then `cycle.sh advance <spec> --stamp S --claim` saw: resume exit 0, no "switched", still on main, next "branch", and it left the spec's journal modified on main; the first launch then exit 2 "git checkout failed ... Your local changes to the following files would be overwritten by checkout" (control without resume: the same launch exits 0 on vulyk/<slug>). The brief's stated form passes: when the other branch's plan copy names the branch, resume says "switched":"vulyk/<slug>" and the launch gives build:1; detached HEAD switches; a dirty tree exits 2 naming the paths, nothing stashed
1. tests/cycle.test.sh:920 [regression] suite `tests/cycle.test.sh` parts `close` (line 920) and `red` (line 1932) must each run to their end under 70% of their 300 s cap (210 s) inside the gate's step, by splitting the parts and not by raising the cap or the 70% line: the round's log reads `STEP 3/9: FAIL 242s`, `PART cycle:close ok 217s cap 300s`, `PART cycle:red ok 240s cap 300s` and `SUITE: FAIL 1326s - cut part cycle:close, cut part cycle:red`, and `bash scripts/suite-parts-check.sh docs/specs/beta-fixes-1113/council/round-2/suite.log` prints `cut part cycle:close: 217s of cap 300s (grew)` and `cut part cycle:red: 240s of cap 300s (grew)` (exit 1); base evidence: docs/specs/beta-fixes-1113/council/round-1/suite.log at `head=09c0321d` reads `STEP 3/9: ok 187s`, `PART cycle:close ok 164s cap 300s`, `PART cycle:red ok 185s cap 300s`; rerun alone on this tree under `run_capped 300`, `bash tests/cycle.test.sh --part red` gave exit 0, 62 ok, no `::error::`, 169 s and `--part close` gave exit 0, 63 ok, no `::error::`, 149 s, so no check fails and the time is contention: the split of `council:verbs` into three parts (tests/council.test.sh:23) shifted the job list by two, so step 3 now starts `council:suite2` (132 s) and `council:suite3` (160 s) beside the two cycle parts where round 1 had `driver` (1 s) and `e2e:green` (27 s) (card test-gate-one-long-limit)
- [regression] PART cycle:close ok 217s cap 300s
- [regression] PART cycle:red ok 240s cap 300s

## Files
- scripts/cycle.sh
- tests/council.test.sh
- tests/cycle.test.sh
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- .claude/commands/vulyk-build.md
- docs/cycle.md
- scripts/telemetry.sh
- tests/telemetry.test.sh
- docs/telemetry.md
- .claude/agents/lead-review.md
- .claude/commands/vulyk-plan.md
- tests/maintenance.test.sh
- scripts/handoff-window-check.py
- tests/solo.test.sh
- tests/e2e.test.sh
- .claude/commands/vulyk-resume.md

## Verification
`bash tests/cycle.test.sh --part red`
`bash tests/cycle.test.sh --part safety`

## Red receipt
- command: bash tests/cycle.test.sh --part safety
- exit: 1
- tests: 8982f420903cc7b53ef66dfebe9997ec5ae93a18479329b30fd0cfe88b2e70c4 (tests/cycle.test.sh)
- impl: 690f34f7e84a63043c5efab3d6c336b4111c89e9a94f85c83a17f3db2b09c44d
- stamped: 2026-11-13T13:43:16Z

```
::error::resume did not switch to the spec branch named only on that branch - exit=0 head=main out=cycle: acmebr - resumed
  ok    the next claim passes the branch guard
  ok    neighbour: already on the spec branch, resume as before
  ok    neighbour: no **Branch:** line, resume as before
beta-fixes-1113 (ask 8): resume finds the spec branch that only that branch's plan copy names
  ok    branch --commit wrote the **Branch:** line on vulyk/acmebr only; main is clean
::error::resume did not switch to the spec branch named only on that branch - exit=0 head=main out=cycle: acmebr - resumed
{"ok":true,"verb":"resume","exit":0,"next":"branch","stale":false,"held":""}
::error::claim after a branch-only resume: exit=0 out=cycle: acmebr - claimed by rsbrstamp
{"ok":true,"verb":"claim","exit":0,"next":"claimed","now":1794577394}
  ok    neighbour: a vulyk/<slug> whose plan copy names no branch is not switched to
```

## Implementation notes
- scripts/cycle.sh: cmd_resume, with no **Branch:** in the checked-out plan, takes vulyk/<slug> when that branch exists and its own plan.md copy (git show) names it; the existing clean/dirty switch logic then runs unchanged.
- tests/cycle.test.sh part safety: ask 8 repro (branch --commit, back to main, resume switches, claim passes) plus a neighbour: a vulyk/<slug> whose plan copy names no branch is not switched to.
- tests/cycle.test.sh: part close split into close + close2 (trust/hand/blk/verify-resume sections), part red into red + red2 (wave-check, repair mark, body red: line); the stray and red fixture preambles are shared blocks, so a full run executes the same lines in the same order. Checks: close 28 + close2 35 = 63, red 48 + red2 14 = 62, same as before; under 5 parts in parallel locally close 67 s, close2 71 s, red 125 s, red2 63 s.
- docs/cycle.md, .claude/commands/vulyk-resume.md: one sentence each on the branch-only plan copy.
- tests/council.test.sh left as is: the split of the cycle parts answers the finding without touching the council parts.
