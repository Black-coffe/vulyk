---
story: convergent-judge-06
spec: convergent-judge
status: done
returned: DONE
tier: 2
worker: worker-code
model: opus
tracer: false
wave: 4
blocked_by: [convergent-judge-02]
---

# Workflow driver hands the planner the anchor rule; no banner says "ceiling 3" (asks 1, 3)

## Goal
The Workflow driver's repair prompt (`.claude/workflows/vulyk-cycle.js:317-324`) asks `queen-planner` for the same thing the fallback driver does (`.claude/commands/vulyk-build.md:101`): a story only for a critical or major finding whose fix is local *and* carries `[ask N]` (N in the brief's `## Asks`) or `[regression]`; an `[unanchored]` finding never becomes a story and waits for `/vulyk-ship` step 5. The driver's own description string (`:3`, the banner a launched run announces) and the two narrative docs stop stating a flat ceiling of 3.

## Requirements
> BLOCK засчитывается, только если хоть одно блокирующее замечание помечено `ask N` или `regression`, иначе оно идёт как PASS, а замечания — в заметки к ship.

> Потолок раундов зависит от тира: Tier 1 — 1, Tier 2 — 2, Tier 3–4 — 3; reopen добавляет столько же.

> Заметил такую штуку, что в абсолютно любом проекте, где есть сидбулик, всегда он три цикла делает. Говорит: «Максимум три цикла». И он всегда три делает. Он никогда не делает один, никогда не делает два, всегда делает три.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- docs/pipeline.md
- docs/architecture.md

## Non-goals
- Do not add verdict, ceiling or anchor logic to the driver (ADR-001 invariant: it holds none) - the prompt text changes, nothing is parsed.
- Do not re-word `.claude/commands/vulyk-build.md:101` - it is the reference sentence; copy its rule, do not fork it.
- Do not touch the R30 stop (`repair landed nothing for round <N>`) or dispatch `queen-planner` twice for one round.
- Do not edit `scripts/cycle.sh`, `tests/council.test.sh`, ADR-001 or `docs/cycle.md` - story 05 owns them this wave.
- Do not change `CAPS`, phase order or any clerk call.

## Map slice
memory/map/cycle.md - "Drivers", "Report-path recording (v0.13.1) and the three dead-dispatch reasons"; memory/map/agents-and-commands.md - vulyk-build (repair row), queen-planner.

## Acceptance criteria
- [ ] The repair prompt in `vulyk-cycle.js` carries the vulyk-build.md:101 rule: one story per critical and per major finding whose fix is local and that carries `[ask N]` for an N in the brief's `## Asks`, or `[regression]`; an `[unanchored]` finding never becomes a story, it waits for `/vulyk-ship` step 5; never phrased as addressing asks that are not there. The `red`-empty branch still points at `<round_dir>/review.md` and names the review BLOCK / owner REJECTED as the cause.
- [ ] `tests/driver.test.sh` fails if the repair prompt loses `[ask N]`, `[regression]` or the `[unanchored]` exclusion, or if the description string regains a bare `ceiling 3`.
- [ ] `vulyk-cycle.js:3` description, `docs/pipeline.md:57` ("the ceiling (3)") and `docs/architecture.md:54` ("ceiling 3 rounds") state the tier ceiling (1/2/3, + the same per `reopen`); no flat 3 remains in the three files.

## Verification
`bash tests/driver.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- vulyk-cycle.js: the red-empty `ask` string now carries vulyk-build.md:101's anchor rule verbatim; the red-non-empty branch is unchanged (the reference sentence applies the rule only when `red` is empty). Description (:3) states the tier ceiling 1/2/3 + the same per reopen.
- driver.test.sh: new scenario (aj2) checks a BLOCK-only repair prompt for `[ask N]`, `[regression]`, the `[unanchored]` exclusion, `/vulyk-ship` step 5 and `round-1/review.md`; a static check fails on `ceiling 3` / `ceiling (3` in the description. Each of the four mutations (drop [ask N], drop [regression], drop the unanchored clause, restore `ceiling 3`) was applied separately and turned the suite red.
- docs/pipeline.md: besides :57, :22 (judge row) also said "ESCALATE `ceiling` past round 3" - fixed too, since the AC bars any flat 3 in the file. docs/architecture.md:54 wraps to two lines.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
