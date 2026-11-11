# Handoff offered at 70/80/90% of the real window (plan)

**Tier:** 1 · **Spec slug:** `handoff-1m` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** docs/hooks-reference.md (handoff hook)
**Depends on:** main at 616a3c2e

## Goal
The handoff hook speaks first at 70% of the session's real window, then at 80% and 90%, and learns a 1M window
from any recent statusLine report for the same model when this session's own report is missing.

## Assumptions
- "Same model" compares the model id with any `[1m]` suffix dropped; the newest report for that model wins,
  up to 30 days old. A machine that mixes 200k and 1M variants of one model may borrow the wrong one; a pin in
  `.claude/handoff.config.json` (`context_limit`) still overrides.
- Rolling the hook out to the other projects on this machine is a step after the merge, outside this repo.

## Stories

**Wave 1**
- `handoff-1m-01` — thresholds 70/80/90, same-model window, offer from level 1, card + check + fixtures

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all. Approved is the owner's
word, the stop at Tier 2-4; Briefed is written by `cycle.sh briefed` instead, at Tier 1 ("via
mini-brief"), with `--go`, or in no-question mode ("assumed"). Either closes stage 02. Council and
Checked close stages 04+05 together: a GREEN council row is enough on its own, and Checked is the
owner's override in either direction, newest timestamp wins. No line of this comment may start with
a marker: the scripts read the first line that does.

There is no default tier: `cycle.sh open-round` refuses to open a round while the `**Tier:**` line above
is missing or unparsable.
-->
**Approved:** <owner, date - stage 02, the unconditional gate. /vulyk-build refuses without this line.>
**Briefed:** via mini-brief, Andrei, 2026-11-11
**Branch:** vulyk/handoff-1m
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** GREEN round 1, 2026-11-11, at 3e2b79da, pack 4e522bdd5bd8
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
