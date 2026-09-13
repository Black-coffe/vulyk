# ADR-003: Shared cycle helpers live in scripts/lib.sh, not per-script copies

- Status: proposed
- Date: 2026-09-13
- Spec: docs/specs/autonomous-cycle (v0.12.0)

## Context

From `docs/specs/autonomous-cycle/plan.md` `## Tradeoffs`, quoted verbatim:

> **Chosen: extract `pack_fingerprint` / `paperwork_only` into `scripts/lib.sh`** (story 01
> creates it, story 02 migrates `ship-check.sh`, `human-check.sh`, `acceptance-log.sh`,
> `release-check.sh`). **Rejected: a fifth copy in `cycle.sh`.** The ADR's last invariant -
> "`paperwork_only()` lists every file the cycle writes" - is checked by one whitelist or by
> three that must agree by hand; v0.12.0 already changes that whitelist in two scripts and adds
> a third consumer, and a missed copy is exactly the STALE-cycle bug the owner's `human.jsonl`
> evidence shows (3 re-records after paperwork commits). The cost: `tests/cycle.test.sh` copies
> one more file into its synthetic repo, `install.sh` ships it for free (`scripts` is `OWNED`),
> and a script can no longer be dropped into a hive alone - which nothing does.

Before this spec each gate script (`ship-check.sh`, `human-check.sh`, `acceptance-log.sh`)
carried its own copy of `pack_fingerprint` and `paperwork_only`. v0.12.0 both changes the
`paperwork_only` whitelist (twice) and adds `cycle.sh` and `release-check.sh` as new consumers,
turning a two-copy drift risk into a five-copy one.

## Options

1. **Extract into `scripts/lib.sh`, sourced by every consumer** — chosen.
2. **A fifth copy inline in `cycle.sh`.** Rejected: the ADR-001 invariant that
   `paperwork_only()` lists every file the cycle writes "is checked by one whitelist or by three
   that must agree by hand"; a missed copy reproduces the STALE-cycle bug already observed live
   (3 re-records after paperwork commits, per `human.jsonl`).

## Decision

`scripts/lib.sh` exports `pack_fingerprint`, `paperwork_only` and `marker` (per plan `## Contracts`
C1, also `now_ts` and `slug_of`). Story 01 creates it; story 02 migrates `ship-check.sh`,
`human-check.sh`, `acceptance-log.sh` and `release-check.sh` to source it; `cycle.sh` sources it
from the start (C1). One whitelist, one set of helpers, five consumers.

## Consequences

- **Easier:** a whitelist or fingerprint change is made once and every consumer picks it up;
  the exact STALE-cycle drift class the delta cites cannot recur through a missed copy.
- **Harder / accepted debt:** `tests/cycle.test.sh` must copy one more file into its synthetic
  repo; a script can no longer be dropped into a hive in isolation — "which nothing does" is the
  delta's own justification for accepting this, but it is now load-bearing: any future script
  meant to be hive-portable on its own cannot use these helpers without also shipping `lib.sh`.
  `install.sh` ships `lib.sh` for free because `scripts/` is already `OWNED`.

## Invariants created

- `pack_fingerprint`, `paperwork_only` and `marker` have exactly one implementation, in
  `scripts/lib.sh`; no script may carry its own copy.
- `paperwork_only()`'s whitelist is edited in one place for every consumer to observe the
  change simultaneously.

## Revisit when

Not recorded — the delta does not name a trigger for reopening this decision.
