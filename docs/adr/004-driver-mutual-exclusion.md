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

**Amendment, 2026-10-16:** `pause` and `resume` no longer release the claim. Only `release` and the driver's own
exit path (`vulyk-cycle.js` `finally`) remove `DRIVER`. A claim removed while a worker was still in flight let a second
driver claim the spec and overwrite that worker's files in a live hive (study `hive-feedback-2026-10`, finding 5).
`resume` now reports the holder (`"held"` in its JSON) and every `held by` refusal names the `release` command. The
liveness oracle is the caller's task list, not a heartbeat: a worker can run for an hour without a `cycle.sh` call,
so no heartbeat age tells a live driver from a dead one. If a `/clear` ever hides a running Workflow from the task
list, the Queen will call it dead and the old defect returns by that door; `claimed=` is the only evidence on disk.
A claim file with no stamp is a broken claim no driver can hold, and `resume` clears it.

**Amendment, 2026-10-19 - accepted (owner: Andrei, spec `ship-safety`, 0.31.0):** `claim` also refuses, exit 2, naming both
branches, when the plan records a `**Branch:**` and the checkout stands on another (`docs/specs/ship-safety`,
0.31.0; brief ask 5: "cycle.sh отказывает и называет обе ветки, если захват ... запущены не на ветке спеки").
It refuses and never switches branches itself. With no `**Branch:**` yet (a fresh `claim` before `branch`), there
is nothing to compare and the guard does not apply. As ADR-001's 2026-10-19 amendment records, the guard
has no off switch. This closes the gap where ADR-001 carries rows for `branch`, `close-story` and `open-round` but
`claim`'s contract lives here.

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
