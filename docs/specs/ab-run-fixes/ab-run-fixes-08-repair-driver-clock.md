---
story: ab-run-fixes-08
spec: ab-run-fixes
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 3
blocked_by: [ab-run-fixes-07]
red: required
red_reason: driver: the script reads no clock (Date.now / new Date refused like the Workflow runtime)
red_verified_at: 2026-11-08T22:47:06Z 8cb4e5ae53440f2c4dbd7d23129a3cb34e2905cd418c54099d0f31d3f3cda061
---

# Driver: the checkpoint without a clock read in the script

## Goal
Story 05 (e1b2597) added the 50-minute checkpoint with `Date.now()` (`.claude/workflows/vulyk-cycle.js:72`, `:97`).
The Workflow runtime refuses it at launch: `Error: Date.now() / new Date() are unavailable in workflow scripts
(breaks resume). Stamp results after the workflow returns, or pass timestamps via args.` (2026-11-09, run
wf_904b0c18-ea3, 0 agents run). `tests/driver.test.sh` stayed green because its sandbox has a clock. Keep the
checkpoint (story 05's C10), take the time from outside the script, and make the test sandbox refuse a clock read
the way the runtime does.

## Requirements
1. `vulyk-cycle.js` contains no `Date.now()`, `new Date(` or `Date(` call. The elapsed time comes from outside the
   script: a launch time passed in `args` (the Queen passes it) compared with a time a verb already returns, or
   any other source that is not a clock read in the script. If no time source is available, the checkpoint does not
   fire (and the driver still runs); say which in `## Implementation notes`.
2. `tests/driver.test.sh`: the sandbox that runs the driver throws on `Date.now()` and `new Date()` with the runtime's
   message, so a clock read fails the suite. The red test is a driver run under that sandbox (it fails on HEAD).
3. The checkpoint behaviour from story 05 stays: past `checkpoint_min`, the next wave, gate step or seat dispatch
   is not started and the run returns `{status:"checkpoint", next, elapsed_min, fallbacks}`.
4. If `vulyk-build` must pass a new arg (a launch time), name the exact line in `## Findings` for the Queen: the
   command file is not in this story's files.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh

## Non-goals
- No change to `scripts/cycle.sh` (story 07 holds it) or to the leftover re-dispatch from story 05.

## Map slice
`.claude/workflows/vulyk-cycle.js`: `CHECKPOINT_MIN`, `STARTED`, `boundary()`, `Checkpoint` (lines 20-22, 71-98, 308).

## Acceptance criteria
- `grep -nE 'Date\.now|new Date|Date\(' .claude/workflows/vulyk-cycle.js` finds nothing.
- `tests/driver.test.sh` fails on HEAD e1b2597's driver (the clock read) and passes after the fix, the checkpoint
  cases included.

## Verification
`bash tests/driver.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- .claude/workflows/vulyk-cycle.js: `Date.now()` gone; elapsed = `args.launched_at` (epoch seconds) against the `now` (epoch seconds) of the last verb answer `ask()` parsed; `epoch()` keeps null/'' from reading as 0; header comment rewritten.
- Which: today no time source reaches the driver live. No `cycle.sh` verb emits `now`, and `/vulyk-build` passes no `launched_at`, so the checkpoint does not fire and the driver runs on (tested: no launched_at, no `now`).
- tests/driver.test.sh: the driver is compiled with a `Date` parameter and run under a Proxy that throws the runtime's message on `Date.now()`, `new Date()` and `Date()`; first check is a plain run under it (the red, on the e1b2597 driver); the C10 cases now carry `launched_at` + verb `now`; new cases: 50 min fires (elapsed_min 50), 49 min does not, no launched_at / no `now` never fires.
- Rejected: asking the clerk to run `date +%s` (cycle-clerk runs only cycle.sh/journal.sh, and it costs one clerk call per boundary).

## Findings
- For the Queen (Req 4), `.claude/commands/vulyk-build.md` step 3, line 64-65: `args: {spec: "docs/specs/<slug>", stamp, top_model, second_model}` should gain `launched_at` (the output of `date +%s` run right before the Workflow call), for example `args: {spec: "docs/specs/<slug>", stamp, top_model, second_model, launched_at}`.
- The checkpoint needs a second input to fire live: a verb answer (at least `advance` and `suite`) carrying `"now":<epoch seconds>` in its last JSON line. That is a `scripts/cycle.sh` change, a non-goal of this story (story 07 holds the file). Until both land, the 50-min checkpoint is off live; only the node harness proves it.

## Red receipt
- command: bash tests/driver.test.sh
- exit: 1
- tests: 8cb4e5ae53440f2c4dbd7d23129a3cb34e2905cd418c54099d0f31d3f3cda061 (tests/driver.test.sh)
- impl: 059f3ae00737b6fd706b7d9067278d88538dd19d99d56575a4b0a4a0cec58e97
- stamped: 2026-11-08T22:47:06Z

```
::error::driver: the script reads no clock (Date.now / new Date refused like the Workflow runtime) - got "Date.now() / new Date() are unavailable in workflow scripts (breaks resume). Stamp results after the workflow returns, or pass timestamps via args."
  ok    static: no all-caps shouting
  ok    static: no per-agent cap or model table, no maxTurns option
  ok    static: the description states no flat ceiling 3
::error::driver: the script reads no clock (Date.now / new Date refused like the Workflow runtime) - got "Date.now() / new Date() are unavailable in workflow scripts (breaks resume). Stamp results after the workflow returns, or pass timestamps via args."
FAIL harness threw: Error: Date.now() / new Date() are unavailable in workflow scripts (breaks resume). Stamp results after the workflow returns, or pass timestamps via args.
    at Proxy.refuse ([stdin]:19:30)
    at eval (eval at compile ([stdin]:15:27), <anonymous>:74:22)
    at run ([stdin]:127:24)
    at [stdin]:145:21
    at process.processTicksAndRejections (node:internal/process/task_queues:103:5)
```
