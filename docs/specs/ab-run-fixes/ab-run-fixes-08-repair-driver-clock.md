---
story: ab-run-fixes-08
spec: ab-run-fixes
status: todo
returned:
tier: 3
worker: worker-code
model: opus
wave: 3
blocked_by: [ab-run-fixes-07]
red: required
red_reason: driver: the script reads no clock (Date.now / new Date refused like the Workflow runtime)
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

## Findings
