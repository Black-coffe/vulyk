---
story: skills-json-exempt-01
spec: skills-json-exempt
status: todo
returned:
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

## Findings
