---
story: beta-fixes-1113-05
status: todo
returned:
worker: worker-code
model: opus
wave: 3
blocked_by: []
red: required
red_reason:
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 5. `lead-review` no longer reports a `suite.log` head that differs from the reviewed head only by paperwork commits.

## Findings
1. tests/council.test.sh:728 [regression] suite `tests/council.test.sh` part `verbs` must run to its end under 70% of its 300 s cap (210 s) with the ask 1 cases kept, by splitting the part and not by raising the cap: the round's log reads `PART council:verbs ok 243s cap 300s` and `SUITE: FAIL 1240s - cut part council:verbs`, and `bash scripts/suite-parts-check.sh docs/specs/beta-fixes-1113/council/round-1/suite.log` prints `cut part council:verbs: 243s of cap 300s (grew)`; a rerun of `bash tests/council.test.sh --part verbs` on this tree gave exit 0, every check ok, 234 s; base evidence: `PART council:verbs ok 160s cap 300s` with `SUITE: ok` in docs/specs/busy-no-transcripts/council/round-1/suite.log (163 s in post-052-tails round 1), so the six `nb_red` fixtures the branch added to the part carry the growth (card test-gate-one-long-limit)
1. .claude/agents/lead-review.md:62 [ask 5] the paperwork-only rule must also count `memory/stats/anomalies.jsonl`, which `commit_paperwork` adds to every paperwork commit (scripts/cycle.sh:1030), so a head that differs from the log's head only by such commits is not reported: in this very round `git diff --name-only 09c0321d 95ed9ea2` lists `docs/specs/beta-fixes-1113/council/round-1/ROUND`, `docs/specs/beta-fixes-1113/journal.md` and `memory/stats/anomalies.jsonl` (commits `open-round 1` and `journal checkpoint`), and the delivered sentence still makes the reviewer write the head Minor the ask removes
- [regression] PART council:verbs ok 243s cap 300s

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
`bash tests/council.test.sh --part verbs`
`bash tests/council.test.sh --part advance`
