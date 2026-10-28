---
story: suite-row-upgrade-01
spec: suite-row-upgrade
status: done
returned: DONE
tier: 1
worker: worker-code
wave: 1
blocked_by: []
---

# The upgrade names a missing canonical full-suite row; /vulyk-update renames it

## Goal
`install.sh --upgrade` (and `--check`) prints one line when the hive's Commands block has no row whose Purpose cell
names the full suite and carries `round-only` - the same predicate `full_suite_row_round_only` in `cycle.sh` uses,
minus the runnable-command clause (an unfilled row is already reported by fill-status). `/vulyk-update` tells the
Queen to rename the hive's own full-suite row, whatever its language, to `Full suite / build (round-only)`, keeping
its command, and to add none where the hive has no full suite. Report 7.3 gets a note that 0.36.0 shipped the split;
ADR-023 is accepted.

## Requirements
> 1. Апгрейд улья сообщает, когда в его таблице команд нет строки `Full suite / build (round-only)`, и /vulyk-update приводит строку полного набора хозяина к этому канону, команда остаётся его; тест фиксирует пример с `Full test suite`.
> 2. Устаревший п. 7.3 в architecture-passport поправлен: разделение уже выпущено в 0.36.0.
> 3. ADR-023 принят.

## Files
- install.sh
- .claude/commands/vulyk-update.md
- tests/telemetry.test.sh
- docs/specs/architecture-passport/report.md
- docs/adr/023-fast-story-checks-full-suite-per-round.md

## Non-goals
- Do not make `install.sh` rewrite a filled Commands block: the hive's table is the owner's; the rename is the Queen's step with the owner's yes.
- Do not widen the cycle.sh / wave-check predicates to other spellings or languages.
- Do not touch any hive in this story.

## Map slice
memory/map/ install.sh section (upgrade, report_fill_status).

## Acceptance criteria
- [ ] A plain `--upgrade` of a fresh install prints no note (the release row is canonical).
- [ ] A hive whose row reads `Full test suite` gets the note; so does a neighbour form `Full suite / build` without `round-only`, and a non-English row (`Повний набір тестів`).
- [ ] The note appears for both `CLAUDE.md` and `CLAUDE.vulyk.md` constitutions, and only when the Commands markers exist.
- [ ] `/vulyk-update` step 6 names the rename, keeps the command, and says what to do when no full-suite row exists.
- [ ] Report 7.3 item 2 and ADR-023 status updated.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/telemetry.test.sh --part constitution`

## Implementation notes
- install.sh: `report_full_suite_row` beside `report_fill_status`, called in the CLAUDE.md and sidecar branches; the awk predicate is cycle.sh's `full_suite_row_round_only` read inside the markers, without its runnable-command clause.
- tests: the `constitution` part pulls the function out of install.sh with `sed` + `eval` (no install run per variant); three row spellings, a markerless block, and a sidecar `--upgrade --check` end to end.
- vulyk-update step 6 names the rename, the wave-check pass on open specs, and the no-row case. Report 7.3 got a dated note; ADR-023 Status accepted.

## Findings
