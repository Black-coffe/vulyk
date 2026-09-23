---
story: convergent-judge-04
spec: convergent-judge
status: done
returned: DONE
tier: 2
worker: worker-code
model: opus
tracer: false
wave: 3
blocked_by: [convergent-judge-02]
---

# No-progress escalation (ask 2)

## Goal
When a round would be RED and an ask it holds RED (seat-evidenced or review-anchored) was also RED in round N-1, `judge` escalates at once with reason `no-progress` instead of opening another repair.

## Requirements
> один и тот же вопрос RED два раунда подряд → сразу ESCALATE `no-progress`;

> Так зачем было три цикла гонять и сотни тысяч токенов тратить?

## Files
- scripts/cycle.sh
- tests/council.test.sh
- docs/adr/001-cycle-state-contract.md
- docs/cycle.md

## Non-goals
- Do not compare review findings by text or `[regression]` lines - only ask numbers (plan A4).
- Do not trigger on an N-1 row that is STALE or ESCALATE, or when N-1 has no row.
- Do not change the rank of `override_red`, `env` or `half`; `no-progress` sits after `half`, before `ceiling`.
- Do not add a new verb; reuse `write_escalate_row_for_round` / the `## Needs a human` writer with the new reason.

## Map slice
memory/map/cycle.md - verdict rule, escalate helpers; cycle.sh `newest_row`/`row_exists`/`json_field` (:266-278), red-list sed (:434).

## Acceptance criteria
- [x] A row getter for `<slug> <round>` exists (no such helper today); round N's set (red_e ∪ review_asks) intersected with round N-1's (`red` ∪ `review_asks`, missing key = empty).
- [x] Non-empty intersection on an otherwise-RED round → ESCALATE, `escalate:"no-progress"`, `## Needs a human` names the repeated asks; `next` = `escalated`.
- [x] `escalate --reason` accepts `no-progress`; ADR-001 reason enum and docs/cycle.md's escalation row updated.
- [x] Tests: ask 3 RED in rounds 1 and 2 → round 2 ESCALATE `no-progress` (Tier 3 ceiling 3); ask 2 then ask 5 → RED/repair; N-1 STALE → no trigger; review `[ask 4]` twice → trigger.

## Verification
`bash tests/council.test.sh && bash tests/cycle.test.sh`

## Implementation notes
- scripts/cycle.sh: new `round_row <slug> <round>` (newest row of that round) and `json_num_array` (missing key = empty); `cmd_judge` computes `repeated` = (red_e ∪ review_asks) ∩ N-1's (red ∪ review_asks), only when N-1's newest row is RED; checked inside rule 4 before the ceiling, so rank is override_red, env, half, no-progress, ceiling. `## Needs a human` gains `- no progress: ask X RED in rounds N-1 and N`. `escalate --reason` accepts `no-progress`.
- tests/council.test.sh: 4 new cases (noprog1-4). Surprising: three existing ceiling fixtures (ceil1, oreopen1, tceil2) kept the same ask RED every round and hit no-progress first; they now rotate the RED ask so they still test the ceiling.
- ADR-001 (reason enum x4, verdict table row, amendment note) and docs/cycle.md (prose + escalation row) updated; both are CRLF in the working tree, which I kept.

## Findings
