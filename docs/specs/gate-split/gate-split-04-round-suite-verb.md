---
story: gate-split-04
spec: gate-split
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 2
blocked_by: [gate-split-01, gate-split-02]
red: required
red_reason: suite: no open round must exit 2
red_verified_at: 2026-11-02T20:37:20Z 04226509b2d076261fbf445605f406e2368bb837511d79706091c0e2af1977e9
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
- templates/plan.md
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

## Implementation notes
- tests/council.test.sh: red test written (new part `suite`, a seats case for record-seat with a suite.log, the escalate plan-line assert, `replays` split into `replays` | `replays2`); scripts/cycle.sh not touched yet - no red receipt.
- tests/council.test.sh (attempt 2): `sx_open` takes a tier; the `sxfail` judge case opens at Tier 2 (ceiling 2) so its first RED routes to `repair`, not a ceiling ESCALATE (Tier 1 ceiling is 1). `--part suite` is red for the declared reason (17 `::error` lines, the first `suite: no open round must exit 2 - exit=1`). scripts/cycle.sh still untouched: no red receipt.
- scripts/cycle.sh: new verb `suite` (cmd_suite + suite_log_line/suite_cut_names/suite_red_parts/suite_verdict/suite_emit), dispatched beside `reopen`; guards pause/driver/branch, no open round exit 2, stale exit 5.
- scripts/cycle.sh: `full_suite_row` returns the row (purpose TAB command, `\|` unescaped); `full_suite_row_round_only` now wraps it, same rule.
- scripts/cycle.sh: record-seat review drops every reported SUITE: line and puts the finished log's line under VERDICT; repair copies the log's red PART lines as `- [regression] PART ...`; build_round deletes suite.log (re-stamp); the legacy suite-timeout note no longer advises a bigger budget.
- Decision: the runner's own STEP line is not copied (only its PART lines), the verb writes its own `STEP K/S`; a step is FAIL on a non-zero exit or a red suite-parts-check on its PART lines; SUITE reasons are cut parts, then failed parts, else failed steps.
- Decision: a stepped row whose `--steps` gives no count writes `SUITE: FAIL 0s - <cmd> --steps gave no step count` (data, exit 0) rather than refusing; a plain row's output is discarded (the reviewer reruns a part).
- templates/plan.md (plan delta 3): Integration gate comment now says the suite runs once per round via `cycle.sh suite`, step by step, 300 s per part, a red part is cut; no VULYK_SUITE_TIMEOUT.
- Surprise: gawk read `/\\\|/` as an alternation matching the empty string; `/\\[|]/` is used.

## Findings
- stamp-red refused twice with `not red: timed out after 300s` on the verification line `bash tests/cycle.test.sh` (calls on 2026-11-02, the second resumed at line 5). Measured alone: `bash tests/cycle.test.sh` took 309 s, exit 0, with wave-mate gate-split-03 running on the same tree. Under gate-split-02's per-line cap (VULYK_VERIFY_TIMEOUT never above 300) this line cannot pass here, so neither stamp-red nor close-story can finish. The `suite` part is red for the declared reason (`suite: no open round must exit 2`). Question: replace that line with per-part lines (`bash tests/cycle.test.sh --part <topic>`, which needs a `Cycle part` row in `## Commands`, gate-split-06's file), drop it (this story's cycle.test.sh changes are nil so far), or re-dispatch once the wave is idle?
- Attempt 2 (2026-11-02, wave idle: gate-split-01..03 committed, nothing else running on the tree): `bash tests/cycle.test.sh` alone took 307 s, exit 0, 0 errors (measured by a direct run, not stamp-red). It sits at the 300 s per-line cap in both measurements (309 s, 307 s), so `stamp-red`/`close-story` cannot pass this line here and the story is still blocked on the same choice; stamp-red was not re-run (the two earlier refusals and this measurement already decide it). Recommended: gate-split-06 lands a `Cycle part` row (`bash tests/cycle.test.sh --part <topic>`) in `## Commands` first and this story's `## Verification` replaces the line with the eight part lines (`ship hooklog gates manual close bsd safety red`); the alternative is dropping the line (this story changes nothing in tests/cycle.test.sh; its council paths are covered by the council parts), leaving cycle.sh's close-story/stamp-red regression check to the round-only full suite. Neither edit is this worker's to make.
- Queen ruling (2026-11-02, plan delta 1): the `bash tests/cycle.test.sh` line is dropped (307-309 s, over the 300 s line cap; no `Cycle part` row exists). The round's stepped suite runs all eight cycle parts. Keep the red test as written and take the red receipt.
- Attempt 3 (2026-11-02): red receipt taken; cycle.sh implemented; `--part suite`, `seats`, `roster`, `replays`, `replays2` exit 0. close-story fails on `bash tests/council.test.sh --part escalate`, one `::error::plan.md`: the sealed test's clause `! grep -qF 'VULYK_SUITE_TIMEOUT' docs/specs/suto1/plan.md` greps the whole fixture plan.md, which is copied from `templates/plan.md`, and line 37 of that template says `per round under VULYK_SUITE_TIMEOUT (default 590 s)`. The plan line cycle.sh writes is right (`- suite: 571 s, budget 540 s - an old SUITE: TIMEOUT report: cut the part that ran long (cycle.sh suite caps each part)`, no VULYK_SUITE_TIMEOUT in it). templates/plan.md is gate-split-06's file (wave 3), not this story's. Question: (a, recommended) narrow the sealed assertion to the `## Needs a human` block (`! sed -n '/^## Needs a human/,$p' docs/specs/suto1/plan.md | grep -qF VULYK_SUITE_TIMEOUT`) and accept the receipt as is (a re-stamp cannot be red now, the implementation is green); (b) move templates/plan.md line 37 into this story's ## Files; (c) drop the `--part escalate` line until gate-split-06 lands.
- Attempt 4 (2026-11-02): no ruling on attempt 3's question yet; nothing changed (`templates/plan.md:37` still names `VULYK_SUITE_TIMEOUT`, `tests/council.test.sh:2412` still greps the whole fixture plan.md). `bash tests/council.test.sh --part escalate` rerun alone: 74 s, the same one `::error::plan.md`, every other case ok. The implementation in scripts/cycle.sh is complete and uncommitted (the diff from attempt 3); the red receipt is intact. Editing the sealed test after the receipt with a green implementation is the `test changed after red receipt` path, and `templates/plan.md` is outside `## Files`, so the choice (a)/(b)/(c) above is still the Queen's; close-story not rerun (it would stop on the same line).
- Queen ruling (plan delta 3): `templates/plan.md` joins this story's `## Files` (moved from gate-split-06). Rewrite its line 37 comment: the suite runs once per round via `cycle.sh suite`, step by step, 300 s per part, a red part is cut; no `VULYK_SUITE_TIMEOUT`. Do not touch the sealed test; then close-story.

## Red receipt
- command: bash tests/council.test.sh --part suite
- exit: 1
- tests: 04226509b2d076261fbf445605f406e2368bb837511d79706091c0e2af1977e9 (tests/council.test.sh)
- impl: 7f2a07ee68c52cdd848742176466213dcbab3273d7a6760de9ec72ab6d6452f6
- stamped: 2026-11-02T20:37:20Z

```
{"ok":false,"verb":"suite","exit":1,"next":"error","error":"usage: scripts/cycle.sh <verb> <spec-dir> [...]"}
  ok    open-round's re-stamp in place removed the log and committed the removal
suite: a plain row is one part under VULYK_PART_CAP - at the cap it is PART <name> CAP and SUITE: FAIL - cut part <name>
::error::suite plain cap: exit=1 out=cycle: usage: scripts/cycle.sh <verb> <spec-dir> [...]
{"ok":false,"verb":"suite","exit":1,"next":"error","error":"usage: scripts/cycle.sh <verb> <spec-dir> [...]"} log=cat: docs/specs/sxcap/council/round-1/suite.log: No such file or directory
::error::suite plain ok: exit=1 out=cycle: usage: scripts/cycle.sh <verb> <spec-dir> [...]
{"ok":false,"verb":"suite","exit":1,"next":"error","error":"usage: scripts/cycle.sh <verb> <spec-dir> [...]"}
suite: no round-only full-suite row -> SUITE: none, done at once
::error::suite none: exit=1 out=cycle: usage: scripts/cycle.sh <verb> <spec-dir> [...]
{"ok":false,"verb":"suite","exit":1,"next":"error","error":"usage: scripts/cycle.sh <verb> <spec-dir> [...]"}
```
