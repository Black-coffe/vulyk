---
story: upgrade-findings-01
spec: upgrade-findings
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: runs only the backticked span
red_verified_at: 2026-11-10T20:40:08Z 625d55f3e9b3ac8274574e034f839502de5ea8c4bdba8f6f3285414f8b7a8bd6
---

# A `## Commands` cell runs its backticked command; the rest of the cell is a note

## Goal
One rule, in one place, for turning a `## Commands` cell into a command. `scripts/lib.sh` gains
`command_cell_shape`, `command_cell_cmd` and `commands_lint` (plan.md `## Contracts` B1), and every site that
strips backticks from a cell today goes through them: `full_suite_row` and the ready-line `try:` hint in
`scripts/cycle.sh`, `command_cell_exists`, `command_cell_round_only` and `verify_programs` in `scripts/lib.sh`,
the cell match in `scripts/wave-check.sh`. A cell with one span yields exactly that span; text outside it is a
note and is never run or matched. A cell with no span behaves as today. A round-only full-suite row with
several spans is a red part with the message `several backticked commands in one cell`, and the `try:` hint
skips such a row. In the matching lookups several spans stay what `templates/story.md` documents: each span is
offered (plan.md `## Assumptions`, first item). `templates/story.md` gains the note rule in that sentence.

## Requirements
> 6. B: a `## Commands` cell holding one backticked span runs exactly that span, and text outside it is a note; where one cell becomes one command (the full-suite row, close-story's ready-line suggestion) several spans are refused with a clear message, while a lookup that matches a story's line keeps offering each span (`templates/story.md`); no span keeps today's behaviour. The same rule holds in every lookup that copies a cell into a command (`full_suite_row`, `command_cell_exists`, `verify_programs`, `wave-check.sh`, close-story's ready-line suggestions), with a test using a row with a trailing note.

## Files
- scripts/lib.sh
- scripts/cycle.sh
- scripts/wave-check.sh
- tests/cycle.test.sh
- tests/council.test.sh
- templates/story.md

## Non-goals
- Do not call `commands_lint` from `install.sh` or `vulyk-update.sh`: story 04 does (wave 2).
- Do not change how a table row is split into cells (the `\|` escape), the `round-only` mark, or the
  `<name>` / `[<name>]` placeholder matching.
- Do not touch `verify_run`, `verify_resume_start`, stamp-red or `round_second` (stories 03 and 05 follow on
  this file).
- Do not edit `CLAUDE.md`: its rows already hold one span each (and the file sits at its byte cap).
- Do not edit the test suites outside cycle parts `close`, `gates` and council part `suite`.

## Map slice
`memory/map/cycle.md` → Verbs (`close-story`, `suite`: `full_suite_row`, stepped row); `memory/map/scripts.md`
→ Entry points (`lib.sh`, `wave-check.sh`), Gotchas (anchored matches; bash 3.2 / BSD).

## Acceptance criteria
- [ ] `--part suite` (council): a fixture constitution whose round-only row reads `` `sh suite.sh` (a note with
  spaces, "quotes" and a parenthesis) `` runs `sh suite.sh` and the log ends `SUITE: ok`; the failing label
  contains `runs only the backticked span`. A stepped row with a note builds `<span> --steps` and
  `<span> --step K` from the span. A round-only row with two spans is a red part naming `several backticked
  commands in one cell` and runs neither. A row with no backticks runs as today.
- [ ] `--part close` (cycle): a story whose verification line equals the span of a noted cell closes; a line
  equal to the note text, or to span plus note, is refused as today's non-cell; a cell with two spans still
  admits either; a refused line's `try:` hint prints spans only, never a note, and offers no several-span row.
- [ ] `--part gates` (cycle): `wave-check.sh` prints no `verify-cell` for a line matching a noted cell's span
  and still prints `verify-round-only` for a noted round-only row.
- [ ] `--part gates` (cycle): `commands_lint` on a fixture prints exactly one line per `noted` and per
  `several` row in the B1 wording and nothing for `none` / `one` rows; an empty or missing `## Commands`
  table prints nothing, exit 0.
- [ ] `bash scripts/portability-check.sh scripts/lib.sh scripts/cycle.sh scripts/wave-check.sh` is clean
  (awk values through `ENVIRON`, no `-v` with cell text).
- [ ] Fixtures use synthetic rows only (`sh suite.sh`, `Acme`); no hive row is copied.
- [ ] close-story's ready-line suggestion does not skip a several-span row silently: it names the row and says why it is not offered. (Queen, coverage gap ask 6)

## Verification
`bash tests/council.test.sh --part suite`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part gates`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->
- `scripts/lib.sh`: `cell_awk` (the one rule as awk functions), `command_cell_shape`, `command_cell_cmd`, `commands_rows`, `commands_lint`; `command_cells` now reads `commands_rows` (span only, never the note; each span of a several cell).
- `commands_rows` splits a row as `full_suite_row` did (second cell exactly, `\|` kept); a 3+-cell row now offers its second cell's span, where the old sed offered nothing.
- `scripts/cycle.sh`: `full_suite_row` reads `commands_rows`; a several row prints `<purpose>\t\tseveral`, which `cmd_suite` turns into `PART <name> FAIL 0s cap 300s - several backticked commands in one cell`.
- `verify_cell_hint` walks rows: a noted row offers its span; a matching several row prints `not offered: row '<Purpose>': <N> backticked commands in one cell`.
- `scripts/wave-check.sh` unchanged: its cell match is `command_cell_exists`, which now goes through the rule. `verify_programs` unchanged: it reads `## Verification` lines (backticks stripped by `verify_of`), never a cell.
- `templates/story.md`: one clause on the note rule. Tests: council `suite` (noted plain, noted stepped, two spans, bare, parser), cycle `close` (stray-11..17), cycle `gates` (wnote wave-check, commands_lint).

## Findings

## Red receipt
- command: bash tests/council.test.sh --part suite
- exit: 1
- tests: 625d55f3e9b3ac8274574e034f839502de5ea8c4bdba8f6f3285414f8b7a8bd6 (tests/council.test.sh, tests/cycle.test.sh)
- impl: 1f251c214b03cb36335e914a5dd87ee4de385553a2eb9247ed527e26a26c4403
- stamped: 2026-11-10T20:40:08Z

```
::error::suite row parser: a noted cell runs only the backticked span - gave 'Full suite (round-only)	sh t.sh (a note, "quoted")'
::error::suite noted row: runs only the backticked span - exit=0 out=cycle: sxnoted - round 1 suite step 1/1: FAIL 0s
::error::suite noted stepped row: runs only the backticked span - exit=0 out=cycle: sxnotedstep - round 1 suite already finished: SUITE: FAIL 0s - bash fx-runner.sh (two steps; a note) --steps gave no step count (exit 2)
  ok    sole row '| Full suite (round-only) |  |' -> STEP FAIL, a PART line names the row, SUITE: FAIL
  ok    sole row '| Full suite (round-only) |' -> STEP FAIL, a PART line names the row, SUITE: FAIL
  ok    unit=true + e2e empty -> steps 2, the e2e row is named FAIL, SUITE: FAIL
suite: a step beyond the row count fails, two rows with one Purpose get distinct PART names (gate-split-10 finding 3)
  ok    two rows named 'Full suite (round-only)' -> PART full-suite-round-only-1 and PART full-suite-round-only-2, the verdict names the failed one
  ok    step 3 of a log over 2 rows -> STEP 3/3 FAIL, PART step-3-no-row, SUITE: FAIL
suite: a stepped step killed at its call cap names the parts that never ended, in the STEP note and the SUITE line (post-045-tails ask 5)
  ok    the hung part is named in the STEP note and the SUITE line, the ended one is not
suite: no round-only full-suite row -> SUITE: none, done at once
  ok    no row -> SUITE: none, steps 0, done
```
