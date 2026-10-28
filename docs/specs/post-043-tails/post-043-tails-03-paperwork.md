---
story: post-043-tails-03
spec: post-043-tails
status: todo            # todo | done | blocked - close-story writes done, a driver writes blocked
returned:              # written by whoever builds the story, as its last edit: DONE | NEEDS_CONTEXT | WALL
tier: 2
worker: worker-code
wave: 2
blocked_by: [post-043-tails-01]
---

# Paperwork: architecture.md wording, two old specs closed

## Goal
`docs/architecture.md` says "Those five" after naming five agents. `upgrade-keeps-host-edits` reads as shipped by
0.29.0 and superseded, with its one story `done`, so `state.sh` and `/vulyk-status` stop showing it as open.
`self-learning` carries its 0.19.0 `**Shipped:**` line. Text only: no `red:` mark (owner, brief item 1).

## Requirements
> 5. Бумаги отдельной историей без красной квитанции: «Those four» в architecture.md; upgrade-keeps-host-edits закрыта через --record как заменённая 0.29.0; self-learning получает строку 0.19.0.

## Files
- docs/architecture.md
- docs/specs/upgrade-keeps-host-edits/upgrade-keeps-host-edits-01.md
- docs/specs/upgrade-keeps-host-edits/plan.md
- docs/specs/self-learning/plan.md
- memory/stats/ship.jsonl

## Non-goals
- Do not fill `**Approved:**` of upgrade-keeps-host-edits: it was never approved.
- Do not write a `**Shipped:**` line by hand: `scripts/ship-check.sh --record` writes it (commands in plan.md `## Assumptions`).
- Do not edit the `except ... carries` sentence of architecture.md: prompt-check parses the keepers from it.
- No other spec's paperwork (constitution-merge, handoff-ownership stay approved and open).

## Map slice
none

## Acceptance criteria
- [ ] `docs/architecture.md` names five keepers and says "Those five".
- [ ] `bash scripts/state.sh` then `.claude/state.json`: upgrade-keeps-host-edits `stage` 06-shipped, `todo` 0; the `**Shipped:**` line names 0.29.0 and 5239eb0.
- [ ] `docs/specs/self-learning/plan.md` ends with a `**Shipped:** 0.19.0` line naming b6d61e9.
- [ ] prompt-check over the repo still prints `prompt-check: ok`.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
