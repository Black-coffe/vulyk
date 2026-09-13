# ADR-004: Driver mutual exclusion via a DRIVER semaphore (decided, not built)

- Status: accepted (2026-09-13, owner: Andrei)
- Date: 2026-09-13
- Spec: docs/specs/autonomous-cycle (v0.12.0)

## Context

Plan delta 6, finding R27 (second reviewer M-7), quoted verbatim from
`docs/specs/autonomous-cycle/plan.md` `## Plan deltas`:

> **R27 · nothing serialises two drivers** (M-7; `cycle.sh:1147-1160`, no lock). "a second driver
> must be refused on a spec another driver holds, rather than proceeding into the same round
> directory, court and index."

Nothing in `cycle.sh` today stops two drivers — a Workflow run and a fallback session, or two
Workflow runs — from acting on the same spec concurrently: both would race into the same round
directory, the same court worktree, and the same git index.

## Options

None recorded — the delta states the chosen shape only, without listing alternatives that were
weighed.

## Decision

Quoted verbatim:

> Decided in principle, not built in this round: a gitignored `docs/specs/<slug>/DRIVER`
> semaphore written by a new `cycle.sh claim <spec> <stamp>` (`noclobber`; exit 2 `held by
> <stamp>` when another run holds it), released by `release`, `resume` and `pause`, honoured by
> `open-round`, `record-seat`, `judge` and `close-story` through a `--stamp` argument — a new
> verb on four verbs and both drivers, not a local fix.

This is a decision, not yet an implementation: the delta routes it to `## Next circle` rather
than to a wave-8/9/10 repair story, explicitly "not built in this round." It is recorded here so
the mechanism is not re-decided from scratch — and not silently reinvented differently — when a
future spec builds it.

## Consequences

- **Easier:** a future implementer has the mechanism's shape settled — a semaphore file, a
  `claim`/`release` verb pair keyed by a caller-supplied `stamp`, `noclobber` semantics, and the
  four existing verbs (`open-round`, `record-seat`, `judge`, `close-story`) plus both drivers
  that must honour it.
- **Harder / accepted debt:** until built, two drivers can still race on the same spec — this
  ADR records intent, it does not close the gap. Not recorded — the delta does not state how
  large that window is or how it should be mitigated in the interim.

## Invariants created

*(none yet — the invariant is created when the mechanism is built, not by this record of intent)*

## Revisit when

The mechanism described here is actually implemented — at that point this ADR should move from
recording intent to recording the built contract (file schema, verb signatures), or be folded
into ADR-001's D1/D2 tables the way `council/REOPEN` and `council/CEILING` were.
