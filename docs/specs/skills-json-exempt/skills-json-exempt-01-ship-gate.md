---
story: skills-json-exempt-01
spec: skills-json-exempt
status: done
returned: DONE
tier: 1
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# The ship gate passes the hook-written skill counter (ask 1)

## Goal
`ship-check.sh` stage 03 reports `clean (hook-written stats pending: ...)` when the only dirty paths are
`memory/stats/anomalies.jsonl` and/or `memory/stats/skills.json`, and still fails on any other dirty path.

## Files
- scripts/ship-check.sh
- tests/cycle.test.sh

## Non-goals
- Do not change `scope-check.sh` or `is_paperwork_path`.
- Do not exempt `council.jsonl` or any other ledger.

## Map slice
`memory/map/scripts.md` - ship-check.

## Acceptance criteria
- [ ] skills.json alone dirty -> 03 clean, names it.
- [ ] anomalies.jsonl + skills.json dirty -> 03 clean, names both.
- [ ] skills.json + a real file dirty -> 03 not clean.
- [ ] council.jsonl alone dirty -> 03 still not clean.

## Verification
`bash tests/cycle.test.sh`

## Implementation notes
- `ship-check.sh` stage 03: `memory/stats/skills.json` joins `anomalies.jsonl` as a named pass-through; the Story 12 comment is replaced by the reversal and its reason.
- Found while building: `tests/cycle.test.sh` never failed on a piped `x | expect` (60 of them): `expect` ran in the pipe's subshell, so `fail=1` was lost and the suite exited 0 with `::error::` lines. A marker file now carries the failure to the exit. With the marker, the suite still passes on this tree (86 ok, 0 errors) and fails (exit 1, 2 errors) against the pre-change `ship-check.sh`.
- The old "skills.json alone dirty -> not clean" case was vacuous: the `scope-check` run just before it dirties `memory/stats/scope.jsonl`, and an earlier case leaves `anomalies.jsonl`. The case now restores both and asserts the precondition (skills.json the only dirty path) before judging.

## Findings
