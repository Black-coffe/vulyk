---
story: autonomous-cycle-13
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 5
blocked_by: [autonomous-cycle-11, autonomous-cycle-12]
---

# Release paperwork: `CHANGELOG.md` 0.12.0, `VERSION`, `CITATION.cff`, memory pointer

## Goal
The release describes itself: a `## [0.12.0]` entry in the house format that says what changed and why (with the evidence the decision rests on), `VERSION` and `CITATION.cff` agree on `0.12.0`, and the memory index points at the spec so the next session finds the council's paperwork.

## Requirements
> Мерж сам, публикация — нет. Система сама мержит vulyk/<slug> в default-ветку, обновляет CHANGELOG/версию/карту, печатает команду publish в лог и НЕ ждёт.

> Совет остаётся, переформулирован + все технические фиксы. Совет = усиленная слепая приёмка (3 места, 3 угла) вместо одного drone-acceptance; человеческий гейт убран как не ловивший ничего.

## Files
- CHANGELOG.md
- VERSION
- CITATION.cff
- memory/memory.md

## Non-goals
- Do not tag, push or publish; do not run `ship-check.sh --record` - `/vulyk-ship` does that on this spec.
- Do not edit the `## [0.11.0]` entry or any earlier one; do not rewrite the file header.
- Do not add a version-sync script or a CI check for `CITATION.cff`; sync the one field by hand.
- Do not write a `memory/map/` entry or a wiki note; one pointer line in `memory/memory.md` `## Learnings` (or a new `## Specs` line if that section exists) is the whole memory change.
- Do not summarise the ADR into the changelog; link it.

## Map slice
`docs/specs/autonomous-cycle/recon/scout-docs.md` §Answer 4 (CHANGELOG format: `## [X.Y.Z] - YYYY-MM-DD`, optional one-line summary, `### Added / Changed / Fixed / Removed / Notes / Upgrading` bullets with a bold lead phrase, file paths inline, no commit hashes as primary reference; `VERSION` single line; `CITATION.cff` `version:` stale at 0.9.5) and §Gotchas · `CHANGELOG.md:5-58` (the `## [0.11.0]` entry - match its density and voice) · `docs/specs/autonomous-cycle/plan.md` `## Goal`, `## Stories`, `## Tradeoffs` · `brief.md` `## Evidence the design rests on` (the numbers the entry cites).

## Acceptance criteria
- [ ] `CHANGELOG.md` gains `## [0.12.0] - <date>` above `## [0.11.0]` with: a one-line summary; `### Added` - the council (three seats, three angles, blind in a worktree at the pack commit, verdict by `scripts/cycle.sh judge`, ceiling 3, early escalation at half the asks, `memory/stats/council.jsonl`), the grill inside `/vulyk-plan` with `## Asks` and `**Briefed:**`, the Workflow driver `.claude/workflows/vulyk-cycle.js` with the session fallback, `scripts/cycle.sh` / `journal.sh` / `lib.sh`, `/vulyk-pause` / `/vulyk-resume`, `docs/specs/<slug>/journal.md`, the *Browser MCP* Profile row, `tests/council.test.sh`; `### Changed` - stage 05 is the council, `human-check.sh` is an override, `/vulyk-ship` merges locally and prints publish, `install.sh` pins the session and owns `.claude/workflows`, `ship-check.sh` reads `Briefed:` and the council row, `paperwork_only` in one place; `### Removed` - `drone-acceptance`, the mandatory owner look, the plan-approval stop in autonomous mode; `### Notes` - the evidence (0 REJECTED in 10 human rows across three hives in one week; 5 of 42 acceptance verdicts REJECTED, all substantive), the cost estimate, the rollback signal, ADR-001 linked; `### Upgrading` - `install.sh --upgrade` / `/vulyk-update`, the two allow rules, specs recorded under v0.11 keep working through the acceptance row.
- [ ] `VERSION` is `0.12.0`; `CITATION.cff` `version:` is `0.12.0` and its `date-released` (if present) is today.
- [ ] `memory/memory.md` has one pointer line to `docs/specs/autonomous-cycle/` naming the ADR and the journal, under 60 lines total.
- [ ] Every path named in the entry exists in the tree at the time of writing.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
