---
story: ab-run-fixes-09
spec: ab-run-fixes
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 4
blocked_by: [ab-run-fixes-07, ab-run-fixes-08]
red: required
red_reason: emit: a verb's JSON line carries now in epoch seconds
red_verified_at: 2026-11-08T23:05:13Z 164cf89bf19f8facd5c02c679e924e20a049313ea5538c82d0f99844ef58246a
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
4. `tests/council.test.sh`: the checks that compare whole verb lines or key lists (parts advance, driver, verbs: about :510, :549, :3809, :3813, :3876, :3898, :3907, :4364, :4371, :4380) drop `now` before comparing (e.g. `jq -c 'del(.now)'`, or the key list gains `now`). No assertion is weakened beyond that one field. Queen decision 2026-11-09 on the worker's NEEDS_CONTEXT; the narrower option (time only inside the status object) was rejected: it keeps :3809 flaky.

## Files
- scripts/cycle.sh
- .claude/commands/vulyk-build.md
- tests/cycle.test.sh
- tests/council.test.sh

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
- tests/cycle.test.sh (part gates): an ok `status` and a refused `status` (usage error) both end in a JSON line with an integer `now` within 5 s of `date +%s`; red receipt stamped on HEAD.
- scripts/cycle.sh `emit()`: `,"now":<date +%s>` goes after `next`/`error` and before `status`. `status` has to stay last because `advance` (cycle.sh, about line 3968) cuts the carried object off the end of the line (`${st%\}}`). I first put `now` at the very end, and that broke advance's carried status.
- scripts/cycle.sh `cmd_status`: added `"now":<date +%s>` after `pack`. The acceptance criterion runs `status | tail -1`, and that line is cmd_status's own printf, not emit(). It also lets the driver's main-loop `status --json` calls feed `verbNow`. I put it before the last seven keys so council.test.sh:4463 (`.[-7:]`) still holds.
- .claude/commands/vulyk-build.md step 3: `args` gains `launched_at`, which is `launched_at="$(date +%s)"` resolved right before the Workflow call.
- Not changed: `suite` and `advance` print their own lines (not through emit()), so they carry no top-level `now`. advance carries it nested under `status`. advance's key order is pinned by council.test.sh:4246.
- Checked: `cycle.test.sh --part gates` new case is green, and `driver.test.sh` passes 118/0.
- tests/council.test.sh (Req 4, the Queen's answer): the ten checks drop `now` before comparing (`jq -c 'del(.now)'`). At :3809 both sides drop it (`.status | del(.now)` and `del(.now)`). The C5 key list becomes `ok,verb,exit,next,now,status`. :549 now greps the last line only, because the `now`-stripped form exists only for that line. No other assertion changed.
- Targeted checks: `council.test.sh --part advance`, `--part driver` and `--part verbs` each exit 0 with no `::error`.

## Findings
- (Answered 2026-11-09: tests/council.test.sh added to `## Files` with Requirement 4; done above.) NEEDS_CONTEXT: Requirement 1 ("every verb's last JSON line gains `now`, ok or not") cannot pass alongside `tests/council.test.sh`, a file outside `## Files`. That file compares emit() lines byte for byte or by exact key list, and no position for the new field avoids it. Each of these fails or goes flaky with the field present:
  - part advance (this story's own verification line): :4364 and :4380 compare the whole close-story timeout line to a literal, and :4371 compares a real-PATH run against a stubbed run (two calls whose `now` can differ by a second). Run result: `::error::timeout`, `::error::stubbed timeout`, `::error::per-line cap`.
  - part driver (full only, run by the round): :3813 checks the key list `ok,verb,exit,next,status`; :3876, :3898 and :3907 compare literal lines; :3809 compares the carried `.status` with a second `status --json` call (`now` inside status, so flaky at a second boundary).
  - part verbs: :510 and :549 match the prefix `"next":"...","status":{`, which `now` before `status` breaks.
  Needed: add `tests/council.test.sh` to this story's `## Files` (or a sibling story) so these assertions can drop or ignore `now` (for example `jq -c 'del(.now)'` before comparing, and `del(.now)` on both sides of :3809). The alternative is to narrow Requirement 1 so that `now` reaches the driver only through the `status` object, and leaves emit() alone.

## Red receipt
- command: bash tests/cycle.test.sh --part gates
- exit: 1
- tests: 164cf89bf19f8facd5c02c679e924e20a049313ea5538c82d0f99844ef58246a (tests/council.test.sh, tests/cycle.test.sh)
- impl: 33d1464e4c81fdb70c06a7d648e93fa6da980145b6019541b0cca37e58114553
- stamped: 2026-11-08T23:05:13Z

```
::error::emit: a verb's JSON line carries now in epoch seconds - verb=status docs/specs/sib out={"spec":"docs/specs/sib","slug":"sib","stage":"01-spec","next":"briefed","briefed":false,"approved":false,"branch":null,"head":"3daa0db","pack":"62d51f9090c0","stories":{"todo":2,"in-progress":0,"done":1,"blocked":0},"wave":1,"wave_stories":[{"file":"docs/specs/sib/sib-01-s.md","story":"sib-01","worker":"worker-code","model":"","repeat":1},{"file":"docs/specs/sib/sib-02-s.md","story":"sib-02","worker":"worker-code","model":"","repeat":1}],"round":0,"ceiling":3,"tier":null,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}
::error::emit: a verb's JSON line carries now in epoch seconds - verb=status docs/specs/no-such-spec out=cycle: usage: scripts/cycle.sh status <spec-dir> [--json]
  ok    a block of > lines alone: each non-empty line's text, nothing past the next ## heading
  ok    briefed counts the quoted asks (it refused '## Asks missing or empty' before)
ab-run-fixes C6: status and every verb that derives it refuse a story status cycle.sh does not recognise
  ok    status: an unknown story status is an error (exit 2, the file and the value named)
  ok    a verb that derives status (repair) refuses the same way
  ok    the known values todo, in-progress, done, blocked behave as before
ab-run-fixes-09: every verb's last JSON line carries now, the epoch seconds the driver checkpoint reads
::error::emit: a verb's JSON line carries now in epoch seconds - verb=status docs/specs/sib out={"spec":"docs/specs/sib","slug":"sib","stage":"01-spec","next":"briefed","briefed":false,"approved":false,"branch":null,"head":"3daa0db","pack":"62d51f9090c0","stories":{"todo":2,"in-progress":0,"done":1,"blocked":0},"wave":1,"wave_stories":[{"file":"docs/specs/sib/sib-01-s.md","story":"sib-01","worker":"worker-code","model":"","repeat":1},{"file":"docs/specs/sib/sib-02-s.md","story":"sib-02","worker":"worker-code","model":"","repeat":1}],"round":0,"ceiling":3,"tier":null,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}
::error::emit: a verb's JSON line carries now in epoch seconds - verb=status docs/specs/no-such-spec out=cycle: usage: scripts/cycle.sh status <spec-dir> [--json]
{"ok":false,"verb":"status","exit":1,"next":"error","error":"usage"}
```
- Resolved by route (a), the Queen's call: I undid the cycle.sh `now` edits by hand and re-ran stamp-red, which went red on the gates check with no `now`, as intended. Then I restored the same edits byte for byte, checked against the saved diff.
