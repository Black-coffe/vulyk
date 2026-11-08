---
story: ab-run-fixes-09
spec: ab-run-fixes
status: todo
returned:
tier: 3
worker: worker-code
model: opus
wave: 4
blocked_by: [ab-run-fixes-07, ab-run-fixes-08]
red: required
red_reason: emit: a verb's JSON line carries now in epoch seconds
---

# The driver checkpoint fires live: `now` in every verb answer, `launched_at` from `/vulyk-build`

## Goal
Story 05's ask (the driver hands control back at a boundary after ~50 minutes, so the Queen's cache survives) is not
live after story 08: the driver now compares `args.launched_at` with the `now` of the last verb answer, and neither
exists today (story 08 `## Findings`). Supply both, so the checkpoint fires in a real run.

## Requirements
1. `scripts/cycle.sh` `emit()`: every verb's last JSON line gains `"now":<epoch seconds>` (`date +%s`), ok or not.
   Field order and every existing field stay; nothing that parses these lines breaks.
2. `.claude/commands/vulyk-build.md` Hive step 3: resolve `launched_at="$(date +%s)"` right before the Workflow call
   and pass it in `args` beside `stamp`, `top_model`, `second_model` (the line story 08's `## Findings` names).
3. A test in `tests/cycle.test.sh`: a verb's last line parses as JSON and carries an integer `now` within a few seconds
   of the shell's clock (the red: it fails on HEAD).

## Files
- scripts/cycle.sh
- .claude/commands/vulyk-build.md
- tests/cycle.test.sh

## Non-goals
- No change to `.claude/workflows/vulyk-cycle.js` (story 08 already reads `launched_at` and `now`).
- No other change to `emit()` callers or to the JSON contract beyond the one added field.

## Map slice
`scripts/cycle.sh`: `emit()` (around line 69-83). `.claude/commands/vulyk-build.md`: Hive step 3.

## Acceptance criteria
- `bash scripts/cycle.sh status docs/specs/ab-run-fixes | tail -1` carries `"now":` with the current epoch seconds.
- `/vulyk-build` Hive step 3 passes `launched_at`.
- The driver suite and the council verb tests stay green with the new field.

## Verification
`bash tests/cycle.test.sh --part gates`
`bash tests/driver.test.sh`
`bash tests/council.test.sh --part advance`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
