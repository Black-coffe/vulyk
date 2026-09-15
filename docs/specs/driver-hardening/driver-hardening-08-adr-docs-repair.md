---
story: driver-hardening-08
spec: driver-hardening
status: todo
returned:
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 6
blocked_by: [driver-hardening-05, driver-hardening-06, driver-hardening-07]
---

# Repair: ADR-011 and the record match what stories 03, 06 and 07 built

## Goal
Round 1 review Majors 3 and 4 (the latter closed in plan.md `## Plan deltas` already - this story mirrors it), Minors 7, 8, 9, 11, plus the two contract revisions of wave 5. After this story ADR-011 states the `next`/`status.next` relation as built, quotes `cmd_status`'s key list byte for byte, attributes each defect where the brief does, names every `paperwork_only` caller the whitelist widening reaches as intended, records the revised clerk recovery (status re-dispatch for mutating verbs) and the taint shape `<slug>-NN-<title>.md`; `worker-test.md` carries the same true sentence as `worker-code.md`; CHANGELOG's ask 1 and ask 4 lines say what shipped.

## Requirements
> Нечитаемая строка от клерка — драйвер повторяет вызов один раз, потом останавливается.
> skills.json и memory/learnings/*.md — бумаги цикла: не блокируют открытие раунда, не старят его.
> Голый номер истории <slug>-NN — не утечка; утечка — файл истории и прежние пути.
> Меняющие глаголы cycle.sh возвращают next в своём JSON, драйвер опрашивает статус только на старте.

## Files
- docs/adr/011-driver-hardening.md
- docs/adr/001-cycle-state-contract.md
- .claude/agents/worker-test.md
- CHANGELOG.md

## Non-goals
- Do not change any code or test; if a sentence in the ADR can only be made true by changing code, return NEEDS_CONTEXT.
- Do not edit plan.md (the Queen's file), `docs/cycle.md` (story 05 found nothing false; nothing in wave 5 changes that), `memory/map/*`, `worker-code.md`.
- Do not rewrite ADR-011's structure or ADR-001's other amendments; edit the sentences named below and add lines, nothing more.
- Do not propose a `-uall`/whitelist policy beyond what story 06 built.

## Map slice
plan.md `## Contracts` C1 revised, C2 addendum, C3 revised, C4 revised, C5 addendum, C6 addendum, `## Plan deltas`; `council/round-1/review.md` Majors 3-4, Minors 7-9, 11; story 03, 06, 07 `## Implementation notes`; ADR-011 as story 05 wrote it; `.claude/agents/worker-code.md` return step (the sentence to mirror).

## Acceptance criteria
- [ ] Major 3: ADR-011's decision-5 invariant reads that a verb's top-level `next` is the verb's own value and equals `status.next` on a well-formed spec (Briefed/Approved present, pack current), with story 03's reason (an older driver ignores the key; deriving `next` from status changed fixtures).
- [ ] Minor 7: the quoted key list equals `cmd_status`'s printf key order exactly (no leading `status,`); the worker copies it from `scripts/cycle.sh`, not from plan.md.
- [ ] Minor 8: decision 2 lists every `paperwork_only` caller the widening reaches - `cycle.sh` staleness, `ship-check.sh` stage council/human staleness (two call sites), `human-check.sh` - as intended per the owner's "не старят его"; no code change.
- [ ] Minor 11: the Context paragraph attributes the clerk `]`, the dirty-tree refusals and the self-mark to launch / between waves, and only the taint false positive to round 6.
- [ ] C1 revised and C4 revised are recorded: decision 1 says a garbled relay of `branch`/`close-story`/`open-round`/`record-seat`/`judge` is recovered by one `status <spec> --json` dispatch (never the verb again), `status`/`claim`/`release` by one identical re-dispatch; decision 4's taint shape is `<slug>-NN[-<title>].md` with or without the `docs/specs/<slug>/` prefix, plus `<slug>/<slug>-NN`. ADR-001's 2026-09-15 amendment paragraph and its `record-seat` row say the same if they name the old `.md`-only shape; otherwise untouched.
- [ ] Minor 9: `worker-test.md` says `close-story reads this key; the driver never opens the story file`, identical to `worker-code.md`.
- [ ] CHANGELOG `## [Unreleased]`: ask 1 line names the status re-dispatch; ask 4 line names the `<slug>-NN-<title>.md` shape; ask 2 line notes the untracked-directory form.

## Verification
`none — reviewed by lead-review`

## Implementation notes

## Findings
