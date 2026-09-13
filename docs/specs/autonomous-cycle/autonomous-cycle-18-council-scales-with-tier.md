---
story: autonomous-cycle-18
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 7
blocked_by: [autonomous-cycle-17]
---

# The council scales with the tier: one seat for a button, four for an architecture

## Goal
The number of agents a task costs follows the tier the Queen assigned it, once, before any work. `cycle.sh` reads the spec's tier from `plan.md` and requires only the seats that tier calls for (C15): a Tier 1 change is one worker plus one Sonnet seat — two subagents — while Tier 3-4 keeps the full court and `lead-review`. The constitution's routing matrix states the agent count per tier so the Queen's tier call is visibly the scaling decision, and `docs/cycle.md` stops saying the council "does not shrink with tier".

## Requirements
> Модель и система должна чётко понимать сложность задачи. Если, например, задача — покрасить кнопку, переместить кнопку, — это базовые простые вещи, то тогда она не должна запускать 10 сабагентов, а это 1-2 сабагента

> То есть в зависимости от сложности задачи декомпозиция и количество воркеров умножается, и качество, и проверка, и всё остальное усиливается. То есть должна быть градация. И тут, наверное, королева должна принимать решение, как сильно она будет масштабировать Woolig на эту конкретную задачу.

> Tier 1+ — совет; Tier 0 — нет

## Files
- scripts/cycle.sh
- tests/council.test.sh
- CLAUDE.md
- docs/cycle.md

## Non-goals
- Do not add a second knob (a Profile row, a flag, an env var) for seat count — the tier IS the knob; the Queen already decides it per task in `/vulyk-plan` step 1.
- Do not change the verdict table (C6), the ceiling, the report contract (C5) or the driver (`.claude/workflows/vulyk-cycle.js` dispatches whatever `missing` lists — it needs no change; say so in CONCERNS if you find otherwise).
- Do not remove the council from Tier 1 — ask 11 keeps it; one seat is the floor.
- Do not touch `CLAUDE.md` outside the routing matrix table, the "Ceremony floor" paragraph and the `## The cycle` paragraph that says the council does not shrink with tier; keep the `VULYK:PROFILE`/`VULYK:COMMANDS` marker lines byte-identical (install.sh parses them).
- Do not touch `/vulyk-review.md` or `/vulyk-build.md` (story 09): their "every named seat" wording already follows `missing`.

## Map slice
`scripts/cycle.sh` — `cmd_status` (the `missing` list and `next: dispatch:<seats>`), `cmd_judge` (which seats it requires before judging, ABSENT/env rules), `cmd_record_seat` (accepted seat names), `round_field`/`ROUND` writer in `cmd_open_round` (a `tier=` line there is the cheapest place to freeze the tier for the round) · `scripts/lib.sh` `marker` (reads `**Tier:**`? — no: the tier line is `**Tier:** 4 · **Spec slug:** ...` on one line; parse `^\*\*Tier:\*\* *([0-4])`) · `tests/council.test.sh` — fixture plans (`templates/plan.md` copy; set the tier line per scenario) and the `dispatch:`/`judge` scenarios · `CLAUDE.md` `## Complexity routing` table and `## The cycle` (story 11's wording) · `docs/cycle.md` "Tiers and the cycle" section · plan.md `## Contracts` C3, C6, C10 and `## Plan deltas` entry 5 (C15).

## Acceptance criteria
- [ ] `cycle.sh` derives the spec's tier from the first `**Tier:**` line of `plan.md` (digit 1-4; absent or unparsable → 4, the safe floor, journaled once as a warning) and freezes it into `ROUND` as `tier=<n>` at `open-round`.
- [ ] Required seats by tier (C15): 1 → `sonnet`; 2 → `sonnet opus review`; 3 and 4 → `haiku sonnet opus review`. `status --json` `missing` lists only required seats still absent; `next` is `judge` as soon as none are missing; `judge` treats a non-required seat as optional (counted if recorded, never ABSENT); the `env` escalation ("all seats ABSENT") means all *required* seats.
- [ ] Tests: a Tier 1 fixture spec reaches `judge` after one `sonnet` report and goes GREEN with `na`/counts reflecting one seat; a Tier 2 fixture requires exactly `sonnet opus review`; a Tier 3 fixture requires all four; a plan without a parsable tier behaves as Tier 4. Existing scenarios (all Tier 4 fixtures today, or unparsable → 4) stay green; suite exit 0, no `::error::`.
- [ ] `CLAUDE.md` routing matrix: each tier row states the agents it costs (Tier 0: none; Tier 1: 1 worker + 1 seat; Tier 2: 2-4 workers + 2 seats + `lead-review`; Tier 3: 4-8 workers + 3 seats + `lead-review`; Tier 4: + `lead-architect` + second reviewer), and the `## The cycle` paragraph says the council shrinks by seat count with the tier and never to zero; marker lines unchanged (`grep -c 'VULYK:\(PROFILE\|COMMANDS\):\(START\|END\)' CLAUDE.md` = 4).
- [ ] `docs/cycle.md` "Tiers and the cycle" states the same gradation in one short table and names the tier call as the Queen's one scaling decision.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
