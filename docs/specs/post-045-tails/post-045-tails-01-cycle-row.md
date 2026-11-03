---
story: post-045-tails-01
spec: post-045-tails
status: todo
returned:
tier: 2
worker: worker-code
wave: 1
blocked_by: []
---

# Cycle row by part, inside the byte cap

## Goal
The constitution's `Cycle` row names a run that fits the 300 s line cap: `bash tests/cycle.test.sh --part <topic>`.
The bytes come from the VULYK-only label `Model profile tests` -> `Model profile`; `tests/model-profile.test.sh`
asserts the new row. CLAUDE.md stays under the 7168 B test (CR stripped).

## Requirements
> Строка Cycle в CLAUDE.md: этот прогон сам дольше лимита 300 с. Чтобы разбить его на части, нужно около 20 байт, а в лимите ADR-016 свободно только 12.

## Files
- CLAUDE.md
- tests/model-profile.test.sh

## Non-goals
- Do not touch Laws, Routing or any other row's wording; do not raise the 7168 B cap.
- Do not add a second `Cycle (round-only)` row: the round gate already runs cycle by part.

## Map slice
memory/map/tests.md - model-profile, cycle

## Acceptance criteria
- [ ] `grep -c '^| Cycle |' CLAUDE.md` is 1 and its cell is `bash tests/cycle.test.sh --part <topic>`.
- [ ] `tr -d '\r' < CLAUDE.md | wc -c` is below 7168; the bsd part's byte check passes.
- [ ] model-profile.test.sh passes against the renamed row.

## Verification
`bash tests/model-profile.test.sh`
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
