# ADR-002: The council scales with the tier, never to zero

- Status: accepted (2026-09-13, owner: Andrei)
- Date: 2026-09-13
- Spec: docs/specs/autonomous-cycle (v0.12.0)

## Context

Plan delta 5 (2026-09-13), quoted verbatim from `docs/specs/autonomous-cycle/plan.md` `## Plan
deltas`:

> **trigger:** the owner, while confirming `## Asks` — a thirteenth ask, verbatim in `brief.md`:
> "Модель и система должна чётко понимать сложность задачи. Если, например, задача — покрасить
> кнопку, переместить кнопку, — это базовые простые вещи, то тогда она не должна запускать 10
> сабагентов, а это 1-2 сабагента". Today a Tier 1 spec gets one worker plus three council seats
> plus `lead-review` plus clerks — five or more agents for a one-line change.

The council contract (ADR-001 D2/D4/C10) was written seat-count-agnostic: every round dispatches
`council-haiku`, `council-sonnet`, `council-opus` and `lead-review` regardless of how small the
underlying change is. The owner's ask makes that a defect, not a feature, for the low end of the
tier range.

## Options

Quoted verbatim from the same delta:

1. **A new knob beside the tier.** Rejected: "two scales for one judgement drift apart."
2. **Skip the council on Tier 1 entirely.** Rejected: "ask 11 says Tier 1+ gets a council."
3. **Make seats optional per Profile row.** Rejected: "the Queen already decides complexity per
   task, a per-hive setting cannot."
4. **Scale the required seat set directly off the tier the Queen already assigns** — chosen.

## Decision

Contract **C15 — required seats by tier**, read from `plan.md`'s `**Tier:**` line:

> Tier 1 → `sonnet` only, no `review` (one worker + one seat = two subagents); Tier 2 → `sonnet`,
> `opus`, `review`; Tier 3-4 → `haiku`, `sonnet`, `opus`, `review` (Tier 4 adds the second
> reviewer as today). `status --json` `missing` lists only the required seats; `judge` needs only
> those; a recorded non-required seat is accepted and counted; the ceiling and the verdict table
> are unchanged.

The tier is the Queen's own call, made once before any work — "the decision how far to scale the
hive is the Queen's tier call, made once, before any work."

## Consequences

- **Easier:** a Tier 1 fix costs two subagents instead of five-plus; the routing matrix states
  the per-tier agent cost directly, so the cost of a tier choice is visible before dispatch.
- **Harder / accepted debt:** not recorded — the delta does not discuss a cost on the existing
  verdict machinery beyond "the ceiling and the verdict table are unchanged."
- A recorded seat that was not required is still accepted and counted toward the verdict — the
  delta states this but does not explain the asymmetry (why over-dispatching is tolerated while
  under-dispatching is not); not recorded.

## Invariants created

- Required seats for a round are a function of the round's frozen tier (C15), never a fixed set
  and never a separate per-hive knob.
- The council never shrinks to zero seats at any tier — Tier 1 keeps one required seat
  (`sonnet`).
- `missing` (and therefore what `judge` waits for) is computed against the required set only; an
  extra, non-required seat report is accepted, not rejected.

## Revisit when

Not recorded — the delta does not name a trigger for reopening this decision.
