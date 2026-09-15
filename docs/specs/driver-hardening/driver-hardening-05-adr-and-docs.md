---
story: driver-hardening-05
spec: driver-hardening
status: todo
returned:
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 4
blocked_by: [driver-hardening-01, driver-hardening-02, driver-hardening-03, driver-hardening-04]
---

# ADR-011, ADR-001 pointers, cycle docs and CHANGELOG for the five fixes

## Goal
The record catches up with the code. A new `docs/adr/011-driver-hardening.md` (from `templates/adr.md`) holds the five decisions with the alternative each `## Answers` line rejected: verb JSON carries the post-verb `status` and the driver's poll rule; the taint rule is the story file, not the bare id; `close-story` tolerates a self-marked `done` on a dirty tree; the clerk is re-asked once on a non-JSON line; `skills.json` and `memory/learnings/*.md` are paperwork. ADR-001 gains a dated amendment paragraph so its D2 rows (`close-story` precondition, `record-seat` taint clause, the "driver is a `while` over `status --json`" sentence) and its invariant "a seat report that names a story id ... is tainted" point at ADR-011 instead of contradicting the code. `docs/cycle.md` is corrected only where it now misstates; CHANGELOG gets an `## Unreleased` block.

## Requirements
> Меняющие глаголы cycle.sh возвращают next в своём JSON, драйвер опрашивает статус только на старте.
> Голый номер истории <slug>-NN — не утечка; утечка — файл истории и прежние пути.

## Files
- docs/adr/011-driver-hardening.md
- docs/adr/001-cycle-state-contract.md
- docs/cycle.md
- CHANGELOG.md

## Non-goals
- Do not edit `memory/map/*` or `docs/wiki/*` - `drone-docs` refreshes the map after merge.
- Do not rewrite ADR-001's Options, Context or the 2026-09-13 amendments; add one dated paragraph under `### Amendments` and adjust only the four spots named in Goal.
- Do not touch `docs/token-economy.md`, `docs/model-cascade.md`, `README.md`, `CLAUDE.md`, any agent or command file.
- Do not describe savings the plan did not claim: the CHANGELOG line says three polls per round, not "a third of calls" (plan A5).
- Do not invent a version number; the block header is `## [Unreleased]`, `/vulyk-ship` names the version.
- `docs/cycle.md`: if nothing in it is now false (plan-time grep found only the `paperwork_only` mention at line 71), leave it untouched and say so in Implementation notes.

## Map slice
plan.md `## Contracts` C1-C7, `## Tradeoffs`, A1-A8; the merged diffs of stories 01-04 (`git log --oneline -4` on the branch and their `## Implementation notes`); ADR-001 D2 table and "Invariants created"; ADR-006 "Invariants created" (`status:`/`blocked` ownership - still true, cite it); `templates/adr.md`; CHANGELOG top entry for the house style.

## Acceptance criteria
- [ ] ADR-011 exists, status `proposed`, spec `docs/specs/driver-hardening`, and states for each of the five decisions: the decision as built, the rejected alternative from `## Answers`, the file and function that holds it, and one invariant; C5's key list and C6's poll rule are quoted, not paraphrased.
- [ ] ADR-001: the amendment paragraph is dated 2026-09-15 and names ADR-011; the `close-story` row, the `record-seat` taint clause, the driver sentence and the taint invariant no longer contradict the shipped behaviour.
- [ ] CHANGELOG `## [Unreleased]` has one line per ask under `### Fixed` (asks 1-4) and `### Changed` (ask 5), each naming the file it changed.
- [ ] `docs/cycle.md` either unchanged with a note, or changed only on a sentence that was false.

## Verification
`none — reviewed by lead-review`

## Implementation notes

## Findings
