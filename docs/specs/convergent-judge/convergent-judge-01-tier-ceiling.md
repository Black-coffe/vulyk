---
story: convergent-judge-01
spec: convergent-judge
status: done
returned: DONE
tier: 2
worker: worker-code
model: opus
tracer: false
wave: 1
blocked_by: []
---

# Tier-scaled round ceiling (ask 1)

## Goal
A round's ceiling comes from the spec's tier - 1 for Tier 1, 2 for Tier 2, 3 for Tier 3 and 4 - instead of a flat 3, and `reopen` raises it by that same amount. The constitution and the cycle doc say so.

## Requirements
> потолок зависит от тира: Tier 1 — 1 раунд, Tier 2 — 2, Tier 3–4 — 3;

> Так с таким темпом можно и пять поставить циклов, и они все пять будут гонять.

## Files
- scripts/cycle.sh
- tests/council.test.sh
- tests/cycle.test.sh
- docs/cycle.md
- CLAUDE.md

## Non-goals
- Do not touch `cmd_judge`'s verdict rule beyond reading the ceiling it already reads from ROUND (:754) - anchors and no-progress are stories 02 and 04.
- Do not add a config knob or env var for the mapping; `tier_ceiling` is the one place it lives (plan `## Contracts`).
- Do not change the `CEILING` file's meaning: when it exists it still wins over the tier default.
- Do not edit `.claude/workflows/vulyk-cycle.js` - it holds no ceiling logic.

## Map slice
memory/map/cycle.md - "Staleness / ceiling / PAUSE-REOPEN-CEILING", "Required seats by tier".

## Acceptance criteria
- [ ] New `tier_ceiling <tier>` prints 1/2/3/3; `cmd_open_round` (:1901) uses it as the default when `council/CEILING` is absent, via `tier_of`; ROUND's `ceiling=` reflects it.
- [ ] `status` (:399) defaults to the same value when ROUND carries no `ceiling=`; `cmd_judge` (:754) likewise.
- [ ] `cmd_reopen` (:2009-2016) computes OLDCEIL with the tier default and writes OLDCEIL + `tier_ceiling`.
- [ ] Tests: Tier 1 RED round 1 → ESCALATE `ceiling`; Tier 2 RED at round 2 → ESCALATE `ceiling`; Tier 3 unchanged at 3; reopen on Tier 2 gives 4. Existing fixtures that write `ceiling=3` without `tier=` keep passing.
- [ ] CLAUDE.md:93 "three RED rounds" and docs/cycle.md:51,72 describe the tier ceiling (1/2/3, `+` the same per `reopen`).

## Verification
`bash tests/council.test.sh && bash tests/cycle.test.sh`

## Implementation notes
- scripts/cycle.sh: new `tier_ceiling` beside `required_seats_for_tier`; defaults in `status` and `cmd_judge` use `round_tier` (frozen tier=, else plan), `cmd_open_round` and `cmd_reopen` use `tier_of`. Reopen step = `tier_ceiling`, also the OLDCEIL default. Unparsable tier falls to 3.
- tests/council.test.sh: new Tier 1 / Tier 2 / reopen-to-4 block after oreopen1. Surprising: the `realverbs` walk (Tier 2, needs 3 RED rounds) broke; pinned its `council/CEILING` to 3 rather than retiering it (Tier 3 would change its dispatch set). Its reopen now lands at 5, which still admits rounds 4-5.
- tests/cycle.test.sh untouched: its only fixture writes `ceiling=3` explicitly and still passes.
- docs/cycle.md: line 74 "(three more rounds)" also reworded, same file, same fact.
- Re-dispatch 2026-09-23: found the change already on disk uncommitted; re-ran verification (green), no code edits. scope-check flags memory/learnings/* and memory/stats/skills.json - hook-written, not this story's.

## Findings
