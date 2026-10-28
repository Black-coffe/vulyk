# Memory triage is offered, not run (plan)

**Tier:** 1 · **Spec slug:** `memory-triage-offer` · **Brief:** [brief.md](brief.md)
**Governed by:** docs/adr/021-rules-tree.md amendment 2026-10-28 (D15)
**Depends on:** 0.41.0 (`1eaa4a8`)

## Goal
The size signal stays; who decides to spend the context changes: the owner, asked once, instead of the Queen's
silent maintenance run.

## Assumptions
- The line keeps the `memory triage (MEMORY.md <n> lines, <k> KB of 200 lines / 25 KB)` text, so the docs and map stay true.

## Stories

**Wave 1**
- `memory-triage-offer-01-ask-first` — the brief prints its own ask-once line for the memory triage; docs follow.

## Contracts
none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas
**Briefed:** via mini-brief, Andrei, 2026-10-28
**Branch:** vulyk/memory-triage-offer
