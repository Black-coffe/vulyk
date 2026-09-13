---
story: v0-12-0-remainders-04
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-code
tracer: false
wave: 1
blocked_by: []
---

# The report gates stop naming `drone-acceptance`, and a same-second override wins there too

## Goal
No live script or agent file tells anyone to re-dispatch `drone-acceptance`, an agent deleted in `7d243a9`; `ship-check.sh`'s override comparison accepts an override recorded in the same second as the record it outranks; `tests/cycle.test.sh` proves both.

## Requirements
> живые скрипты больше не шлют к drone-acceptance (LR26)

> оверрайд в ту же секунду побеждает (m-4)

## Files
- scripts/ship-check.sh
- scripts/acceptance-log.sh
- .claude/agents/drone-docs.md
- tests/cycle.test.sh

## Non-goals
- Do not delete `acceptance-log.sh` or its fallback path in `ship-check.sh` - pre-0.12 specs still read through it (map: scripts.md gotchas). Only the wording that names the agent changes.
- `scripts/cycle.sh:546` has the same-second defect on the council side; story 01 owns it. Do not touch `cycle.sh`.
- Do not edit any other agent or command file, `docs/`, or `memory/`.
- Do not "modernise" `ship-check.sh` stage 04+05 logic beyond the comparison operator.

## Map slice
`memory/map/scripts.md` (`ship-check.sh`, `acceptance-log.sh` legacy status, `human-check.sh`) · `memory/map/agents-and-commands.md` (`drone-acceptance` is gone; `drone-docs` owns map+wiki only) · `recon/tests-ci-hooks-driver.md` §1 (`tests/cycle.test.sh`: one repo walked 01->06) · `plan.md` `## Next circle` LR26 (`drone-docs.md:14`, `acceptance-log.sh:72`, `ship-check.sh:227`), m-4 (`ship-check.sh:190`).

## Acceptance criteria
- [ ] `grep -rn drone-acceptance scripts/ .claude/agents/` is empty; the three lines now point at the council (`/vulyk-review` for another round, `human-check.sh` for the owner's override) where an instruction is still needed, or are removed where the sentence was only about the dead agent.
- [ ] `ship-check.sh:190`: a `**Checked:**`/`human.jsonl` override with a timestamp equal to the council row's `ts` (same second) outranks the row (`>=`); `tests/cycle.test.sh` gains a step that records a GREEN council row and a REJECTED override in the same second and expects NOT READY, and the mirror (RED row, ACCEPTED same second) expects READY.
- [ ] `bash tests/cycle.test.sh` passes; the new step fails against `ship-check.sh` at `3e200bb` (state which line you reverted to check).
- [ ] `bash -n` passes on both scripts.

## Verification
`bash tests/cycle.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
