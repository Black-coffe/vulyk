# ADR-038: A story that edits `close-story` or `claim` in `scripts/cycle.sh` runs alone in its wave

- Status: proposed
- Date: 2026-11-14
- Spec: docs/specs/audit-fixes-1113 (story 09, cut into 09, 13 and 14)

## Context
Plan delta, 2026-11-14:

> story 09 missed twice at the turn cap (both workers built in a scratchpad copy).
> lead-architect (Fable) cut it by ask into three serial stories, each alone in its wave because each
> rewrites `close-story`/`claim`: 09 (ask 8, wave 3), 13 (ask 9, wave 5), 14 (ask 10, wave 6); the
> own-fixtures gate item moved to story 12. Contracts S1/A1/P1 unchanged. The workers' untested diff is a
> reference to port by hand, by line range. Invariant: a story that edits `close-story` or `claim` in
> `scripts/cycle.sh` runs alone in its wave.

The plan's `## Assumptions` (Self-hosting) gives the mechanism: "This repo closes its stories with the scripts
being edited. [...] A wave-mate's close can also meet a script or a test suite mid-edit".

## Options
none recorded - the delta states the chosen shape only

## Decision
A story whose `## Files` change `close-story` or `claim` in `scripts/cycle.sh` is the only story of its wave.
Several such changes are cut into serial stories, one per wave.

## Consequences
Not recorded beyond the delta: such a change costs a wave of its own.

## Invariants created
- No wave holds a story that edits `close-story` or `claim` in `scripts/cycle.sh` together with any other story.

## Revisit when
Not recorded.
