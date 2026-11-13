---
story: beta-fixes-1113-05
status: done
returned: DONE
worker: worker-code
model: opus
wave: 3
blocked_by: []
red: required
red_reason: lead-review paperwork-only rule omits memory/stats/anomalies.jsonl
red_verified_at: 2026-11-13T10:07:34Z bf9129c2e366cf81bd7523e093946a393a0700548c4c4b5b0c1232318de33a90
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

## Implementation notes
- tests/council.test.sh: part `verbs` split into `verbs`, `verbs2` (narrow-round record), `verbs3` (ask 1 numbered-finding cases kept); shared helpers `fm_field_v`/`nr_full` defined for both. Local runs: verbs 54 s, verbs2 69 s, verbs3 112 s, all exit 0; cap 300 s unchanged.
- tests/council.test.sh: ask 5 check that lead-review's paperwork-only rule names `memory/stats/anomalies.jsonl` (sealed red).
- .claude/agents/lead-review.md: the paperwork-only head rule now also counts `memory/stats/anomalies.jsonl`, which every paperwork commit carries.

- Red receipt re-stamped: the test split landed after the first receipt; lead-review edit reverted, stamp-red rerun (impl hash unchanged), edit re-applied.

## Red receipt
- command: bash tests/council.test.sh --part verbs
- exit: 1
- tests: bf9129c2e366cf81bd7523e093946a393a0700548c4c4b5b0c1232318de33a90 (tests/council.test.sh)
- impl: f9bfeacc93d97db126a3964cccf6f6be9e9cfa24c5ad877149c205e828461cf2
- stamped: 2026-11-13T10:07:34Z

```
::error::lead-review paperwork-only rule omits memory/stats/anomalies.jsonl
  ok    unanchored BLOCK -> next green
  ok    row GREEN, review PASS, review_asks:[], note 'review BLOCK unanchored'
judge: review BLOCK tagged [ask 9] on a 3-ask brief -> unanchored -> GREEN
  ok    out-of-range [ask 9] / [ask 0] count as unanchored
judge: unanchored BLOCK does not mask a seat RED -> still RED
  ok    seat RED still repairs; review recorded PASS
status: an older row without review_asks still parses
  ok    status reads a pre-review_asks row
beta-fixes-1113 (ask 5): lead-review's paperwork-only head rule counts memory/stats/anomalies.jsonl, which every paperwork commit carries
::error::lead-review paperwork-only rule omits memory/stats/anomalies.jsonl
```
