---
story: gate-split-04
spec: gate-split
status: todo
returned:
tier: 3
worker: worker-code
model: opus
wave: 2
blocked_by: [gate-split-01, gate-split-02]
red: required
red_reason:
---

# cycle.sh suite: the round's gate runs once, in steps, into a log the judge reads

## Goal
A new verb `cycle.sh suite <spec-dir> [--commit] [--stamp S]` runs the open round's integration gate one step per call
into `council/round-N/suite.log`, keyed to ROUND `head=`, idempotent on resume, discarded on re-stamp. A stepped row
(Purpose has `steps`) runs `<cmd> --step K` under a 590 s call cap; any other round-only full-suite row (a hive's) is one
part under the 300 s part cap. Red parts (cap, growth) are decided by `scripts/suite-parts-check.sh`. `record-seat
review` takes the SUITE line from the finished log; `judge` routes `SUITE: FAIL` (a part at its cap included) to RED and
repair like any FAIL, never to `suite-timeout`; `repair` carries the red PART lines into `## Findings`. The council
`replays` part is cut in two here, since this story owns `tests/council.test.sh` in this wave.
Model: opus - a new verb inside the cycle's state machine (staleness, re-stamp, resume, judge routing) over ~3300 lines.

## Requirements
> 2. Тесты идут один раз за раунд, по шагам, до запуска проверяющих; проверяющие читают лог и могут перезапустить часть.
> 3. Часть, дошедшая до лимита, считается ошибкой этой части, владельца не зовут.
> 1. У каждой части тестов свой лимит не больше 300 с, шаг прогона влезает в один вызов, одного общего лимита больше нет.
> 5. solo, e2e, model-profile и длинные части telemetry и council разрезаны до ~100 с.

## Files
- scripts/cycle.sh
- tests/council.test.sh
- tests/cycle.test.sh

## Non-goals
- Do not edit the driver, the clerk, `lead-review` or the commands (`gate-split-05`), nor `CLAUDE.md` (`gate-split-06`).
- Do not add a `suite` value to `status --json` `next`: the callers loop `suite` until `done:true`.
- Do not delete the legacy `SUITE: TIMEOUT` / `suite-timeout` reading (old seat files, `council.jsonl` rows,
  `escalate --reason`); only stop producing it and stop advising a bigger budget (1289-1290).

## Map slice
memory/map/cycle.md `## Files, one writer each`, `## Verbs` (Full-suite line, Court setup), `## Staleness, PAUSE, seat
reports`, `## Seats by tier and the verdict`, `## Repair`; memory/map/scripts.md `## Key contracts`
(`is_paperwork_path`); plan.md `## Contracts` (Stepped row, `cycle.sh suite`, SUITE from the log, PART line);
scout report C:/Users/Andrei/AppData/Local/Temp/claude/E--Projects-vulyk/aeafb186-f7ba-4c02-b8a1-680b8386863e/scratchpad/gs/scout-round.md.

## Acceptance criteria
- [ ] `suite` refuses (exit 2) with no open round, exits 5 on a stale one, and keeps the pause/driver/branch guards
      of `open-round`. On an open round it runs exactly one unfinished step, appends `STEP K/S ...` and the step's
      PART lines, commits the log with `--commit`, and prints the plan's JSON last line with `done`, `step`, `steps`.
- [ ] After the last step the log ends with one `SUITE: ok|FAIL|none ...` line; a further call is a no-op with
      `done:true`. A log whose `head=` is not ROUND's is replaced; the re-stamp path (2786-2788) removes it.
- [ ] A plain row hitting `VULYK_PART_CAP` gets `PART <name> CAP ...` and the gate reads `SUITE: FAIL ... cut part
      <name>`; a part over 70% likewise (via `suite-parts-check.sh`). Exit 0: a FAIL is data, not a verb failure.
- [ ] `record-seat review` with a finished log writes the log's SUITE line into the seat file (inserting or
      replacing); without a log, a report missing its SUITE line is still MALFORMED (1647-1663).
- [ ] `judge`: SUITE FAIL from the log = BLOCK `[regression]` -> RED -> `repair`, whose `## Findings` hold the red
      PART lines; no new `suite-timeout` ESCALATE; old `SUITE: TIMEOUT` seat files still read as before.
- [ ] `tests/council.test.sh`: new part `suite` in `PARTS` (fixture constitution with a stepped row backed by a
      fixture runner and a plain row; small `VULYK_PART_CAP`), seats/escalate cases updated; `replays` split at 2905
      into `replays` | `replays2`, both `&& full`, each rebuilding what it reads from the shared helpers (91-213).

## Verification
`bash tests/council.test.sh --part suite`
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part escalate`
`bash tests/council.test.sh --part roster`
`bash tests/council.test.sh --part replays`
`bash tests/council.test.sh --part replays2`
`bash tests/cycle.test.sh`

## Implementation notes

## Findings
