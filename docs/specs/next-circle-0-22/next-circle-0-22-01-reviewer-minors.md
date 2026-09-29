---
story: next-circle-0-22-01
spec: next-circle-0-22
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# Reviewer minors and the README line (ask 1)

## Goal
ADR-010 records that `skills-json-exempt` (0.21.1) reversed its Story 12 line for `skills.json`. The
failure marker of `tests/cycle.test.sh` lives outside the throwaway fixture repo, so a first failure never
dirties later stage-03 cases or gets committed by `git add -A`. The stale "only anomalies.jsonl is the
pass-through path" label is corrected. README's roadmap gains the v0.21 line.

## Requirements
> (1) закрыть три минорных замечания ревьюера и добавить строку v0.21 в README

## Files
- docs/adr/010-anomaly-telemetry-contract.md
- tests/cycle.test.sh
- README.md

## Non-goals
- Do not rewrite ADR-010's history: append a dated reversal note beside the Story 12 passage.
- Do not change any `expect` case besides the label.

## Map slice
`memory/map/scripts.md` - ship-check stage 03.

## Acceptance criteria
- [ ] ADR-010 near line 180 points at `docs/specs/skills-json-exempt` and says the gate now passes `skills.json`.
- [ ] The marker is a path outside the fixture repo (e.g. `mktemp` beside `$T`, cleaned by the trap); a forced failure still exits 1.
- [ ] README's roadmap has a `[x] v0.21.0 / v0.21.1` line before the 1.0.0 line.

## Verification
`bash tests/cycle.test.sh`

## Implementation notes

## Findings
