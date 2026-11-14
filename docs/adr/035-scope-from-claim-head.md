# ADR-035: A story's scope is counted from its wave's claim head; the head moves only through `reanchor`

- Status: proposed
- Date: 2026-11-14
- Spec: docs/specs/audit-fixes-1113 (ask 8, stories 09 and 13; contract S1)

## Context
Plan delta, 2026-11-14:

> story 11 NEEDS_CONTEXT: the new scope check (S1) counted the Queen's hook-bit commit b0721b25,
> made between two driver runs, as the worker's out-of-scope edit. The Queen re-recorded the
> wave's claim head, journaled. Root fix: story 13 adds `cycle.sh reanchor`
> (journaled, main session only), so a recorded head never moves by hand again.

The rule the delta builds on is contract S1 of the same plan: "`claim` writes `head=<sha>` for the wave into the
cycle's run state, once per wave. `close-story` at Tier 3-4 counts scope from it: files changed between that head
and the working tree, plus untracked ones, less the story's `## Files`, paperwork, and same-wave siblings' declared
paths and story files. No record: exit 2 `no claim head recorded for wave <W>`." Its reason, from `## Assumptions`
(ask 8): "At Tier 3-4 a close with no recorded claim head refuses (a missing input is never a pass). Tier 1-2
keeps today's uncommitted-only check with one stderr note."

## Options
1. Three small records, each failing closed on its own (claim head, approved sha, changed lines) (chosen).
2. One ledger of every commit `cycle.sh` makes, read by the scope check, the approval lookup and the paperwork
   rule alike. Rejected in the plan's `## Contracts`: "a local ledger lost with the run state would stale every
   open verdict"; three smaller records "fail closed one at a time".

## Decision
At Tier 3-4, `close-story` measures a story's scope from the head `claim` recorded for its wave, so an edit outside
`## Files` counts whether it is committed or not. A missing record refuses the close. A recorded head moves only
through `cycle.sh reanchor`, which writes a journal line and is a main-session verb (git-guard does not list it for
a subagent; see ADR-032's 2026-11-14 amendment). A commit the main session makes between driver runs is out of
the worker's scope until the head is reanchored.

## Consequences
Not recorded beyond the delta: a main-session commit made mid-wave needs a `reanchor` before the wave's next close.

## Invariants created
- At Tier 3-4, scope is counted from the wave's recorded claim head; with no head the close refuses.
- The run-state claim head is written by `claim` and moved only by `reanchor`, with a journal line; never by hand.
- `reanchor` is not on the list of `cycle.sh` verbs a subagent may run.

## Revisit when
Not recorded.
