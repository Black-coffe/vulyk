# The skill counter no longer blocks the ship gate (plan)

**Tier:** 1 · **Spec slug:** `skills-json-exempt` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-010 (hook-written stats; this spec reverses its Story 12 line for `skills.json`), ADR-011
**Depends on:** v0.21.0 (`5163fe3`)

## Goal
`ship-check.sh` stage 03 already passes a tree dirty only in the hook-written `anomalies.jsonl`. The
`PostToolUse(Skill)` hook rewrites `memory/stats/skills.json` the same way, outside any commit, on
every Skill call - and since 0.21.0 maintenance runs through the Skill tool - so it joins the pass-through,
named. Any other dirty path still blocks.

## Assumptions
- A1. Only stage 03 of `ship-check.sh` changes. `scope-check` keeps counting `skills.json` (ADR-010
  A18); that is the scope gate's own decision and not this ask.
- A2. The owner delegated the reversal of ADR-010's Story 12 line to the Queen on 2026-09-29 (brief).

## Stories

**Wave 1**
- `skills-json-exempt-01-ship-gate` — stage 03 passes `skills.json` like `anomalies.jsonl`; the test flips.

## Contracts
- none

## Integration gate
`bash tests/cycle.test.sh`

## Descoped

*(empty)*

## Plan deltas

**Approved:** <owner, date>
**Briefed:** via mini-brief, Andrei, 2026-09-29
**Branch:** <written by /vulyk-build before wave 1>
**Checked:** <written by scripts/human-check.sh>
**Council:** <written by scripts/cycle.sh judge/escalate>
**Shipped:** <written by scripts/ship-check.sh --record>
