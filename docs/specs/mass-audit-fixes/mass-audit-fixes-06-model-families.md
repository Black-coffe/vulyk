---
story: mass-audit-fixes-06
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: retry never runs on the judging family
---

# A missed story's retry never runs on the family that judges it; the model brief says less, once

## Goal
`.claude/workflows/vulyk-cycle.js` picks the retry model as the first of `[TOP, 'opus']` that is not the family
judging this round (`REVIEW` when passed, else `opus` at Tier 3; `TOP` at Tier 4, where the top reviewer runs on
it); when none is left the retry runs on `opus` and the run result carries `retry_same_family: true`.
`docs/model-cascade.md` lists every same-family case (solo Tier 1-2 under the default profile, repair stories,
the Tier 4 retry) instead of "one gap". `.claude/hooks/top-model-brief.sh` runs `top-model.sh` once and reuses
its output, and prints the dispatch sentence only when something differs from the default (floor not ok,
profile not chosen, a pin present). Ask 11: private audit (2026-11-08) findings I3, I7 (doc half; the CLAUDE.md
line is story 13's), O6. Marked red: a dispatch branch.

## Requirements
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- docs/model-cascade.md
- .claude/hooks/top-model-brief.sh
- tests/model-profile.test.sh

## Non-goals
- Do not change which model a first attempt, a reviewer or a seat runs on, and do not touch
  `scripts/model-profile.sh` or `scripts/top-model.sh`.
- Do not edit `CLAUDE.md` (the gap note there is story 13's, which must stay under the byte cap).
- Do not remove the litopys ask or change its stop condition (`session-start-brief.sh` is not in this story).

## Map slice
`memory/map/cycle.md` → The Workflow driver; `memory/map/agents-and-commands.md` → Commands (`/vulyk-build`
hive path, Profile-aware dispatch); `memory/map/scripts.md` → Entry points (`model-profile.sh`, `top-model.sh`).

## Acceptance criteria
- [ ] `tests/driver.test.sh`: economy (TOP=opus, REVIEW=opus) retries on the other high family; sonnet-builds
  Tier 4 (TOP=fable, REVIEW unset) retries on `opus`; Tier 3 with TOP=fable retries on `fable`; Tier 4 under
  sonnet-builds with REVIEW=opus records `retry_same_family: true` and retries on `opus`. The failing label
  contains `retry never runs on the judging family`.
- [ ] The existing "TOP falls back to opus" case still passes.
- [ ] `top-model-brief.sh` output on a default box (floor ok, profile set, no pin) is one line; with a pin or a
  floor miss it prints the model line; it calls `top-model.sh` once (counting stub in
  `tests/model-profile.test.sh`).
- [ ] `docs/model-cascade.md` names the three same-family cases and the retry rule in one short table.

## Verification
`bash tests/driver.test.sh`
`bash tests/model-profile.test.sh`

## Implementation notes

## Findings
