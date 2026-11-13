---
story: beta-fixes-1113-02
spec: beta-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a NEEDS_CONTEXT return stops the build with no second dispatch
red_verified_at: 2026-11-13T07:58:45Z f5d1cc0ab17b5787c0083ca19fce7ea1b344d4f312380a8c089a29aea96efeb0
---

# The driver hands a worker's `NEEDS_CONTEXT` to the Queen instead of dispatching again

## Goal
`.claude/workflows/vulyk-cycle.js`, in `build()`. Today a story still listed after its worker returned is a
miss whatever the worker said: `reasonFor()` knows only an empty or thrown return, the story is dispatched again
with the retry note, and the second miss fails the run. After this story the driver reads the status token of
the worker's return (the report contract in `.claude/agents/worker-code.md` / `worker-test.md`, the same token
the worker writes to `returned:`). A still-listed story whose worker returned `NEEDS_CONTEXT` is not a miss: the
driver dispatches nothing more and ends the run with the result of plan.md `## Contracts` N1, naming each such
story file and carrying the worker's return text; `release` runs in `finally` as now. The driver has no file
access, so the Queen reads `## Findings` in the named story. `.claude/commands/vulyk-build.md` gains what she
does on `needs_context` (read `## Findings`, answer by revising the story under the existing
`vulyk(<slug>): revised <story-id>` rule, journal it, relaunch with a fresh stamp), and the driver paragraph of
`docs/cycle.md` says the same in a sentence or two.

## Requirements
> 2. Driver: a worker that returns `NEEDS_CONTEXT` stops the build with that story and its `## Findings` for the Queen, instead of being dispatched again as a miss.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- .claude/commands/vulyk-build.md
- docs/cycle.md

## Non-goals
- Do not change the retry model, the miss count, the two-miss stop, the leftover note, the checkpoint, `gate()`,
  the claim proof or the Fable-limit fallback. An empty or thrown return, and a `DONE` or `WALL` return with the
  story still listed, stay misses exactly as today.
- Do not reword the existing retry note or the miss and stop messages: other suites may assert them.
- Do not add a clerk verb, a `status --json` field or any file read to the driver; no `scripts/cycle.sh` edit
  (story 01 holds it in this wave).
- Do not edit `worker-code.md` or `worker-test.md`. If their return has no status token a program can find,
  stop and return `NEEDS_CONTEXT` naming what is missing.
- Do not match the word anywhere in the text: a `DONE` report that mentions `NEEDS_CONTEXT` in prose is not a stop.
- `docs/cycle.md`: the driver paragraph only. `vulyk-build.md`: the wake-up list only.

## Map slice
`memory/map/cycle.md` → The Workflow driver (build wave, miss, Claim / retry, checkpoint result shape);
`memory/map/agents-and-commands.md` → worker-code / worker-test (close, `NEEDS_CONTEXT`), `/vulyk-build` (hive
path, 0.50 `revised <story-id>` rule).

## Acceptance criteria
- [ ] Driver test, the original case: a wave of one story; its worker returns a `NEEDS_CONTEXT` report and the
  story is still listed. The story is dispatched exactly once, the result is `status: "needs_context"` with the
  story file and the worker's text (N1), and the claim is released. The failing label contains `a NEEDS_CONTEXT
  return stops the build with no second dispatch`.
- [ ] Neighbour: an empty return is still dispatched again on the retry model and a second miss stops the run;
  the existing miss, leftover and checkpoint tests pass unchanged.
- [ ] Neighbour: a worker whose report says `DONE` and mentions `NEEDS_CONTEXT` in a sentence, with its story
  closed, does not stop the run.
- [ ] A wave of three: one closes, one returns `NEEDS_CONTEXT`, one returns empty. The result names only the
  second; the third is not dispatched again in this run.
- [ ] A `NEEDS_CONTEXT` on a retry dispatch (after one plain miss) gives `needs_context`, not the two-miss failure.
- [ ] `vulyk-build.md` names the `needs_context` result and the steps above; `docs/cycle.md` matches the driver.
- [ ] `## Implementation notes` ends with one `CHANGELOG:` line.

## Verification
`bash tests/driver.test.sh`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->
- `.claude/workflows/vulyk-cycle.js`: `statusOf()` reads the first line opening with `STATUS:` (report contract); `build()` collects still-listed NEEDS_CONTEXT stories, skips their miss, and throws a `Stop` with the N1 result after the loop.
- Decision: when a wave has both a NEEDS_CONTEXT story and a story on its second miss, `needs_context` wins (the two-miss stop is deferred to after the loop, unchanged otherwise), so the worker's question is not lost.
- `tests/driver.test.sh`: five cases; the original case, the wave of three and the retry case fail on HEAD; the two neighbours (empty retry, DONE mentioning NEEDS_CONTEXT) pass on HEAD by design.
- Surprise: an empty return on a retry model other than opus costs a ping dispatch, so the empty-neighbour case counts worker dispatches only.
- `vulyk-build.md` wake-up list gains the `needs_context` entry; `docs/cycle.md` driver paragraph gains two sentences.
- CHANGELOG: The Workflow driver no longer re-dispatches a worker that returned `NEEDS_CONTEXT`: the run ends with `status: "needs_context"`, the story file and the worker's report, and `/vulyk-build` tells the Queen to answer it in the story's `## Findings`, commit the revision and relaunch.

## Findings

## Red receipt
- command: bash tests/driver.test.sh
- exit: 1
- tests: f5d1cc0ab17b5787c0083ca19fce7ea1b344d4f312380a8c089a29aea96efeb0 (tests/driver.test.sh)
- impl: 37058163986fe5064ba843d9251198404531c4e19b7abd14f2dabe61c3e534e0
- stamped: 2026-11-13T07:58:45Z

```
::error::needs_context: a NEEDS_CONTEXT return stops the build with no second dispatch, names the story and its report, releases - got {"result":"","n":2,"seq":"advance docs/specs/demo --stamp 0123456789abcdef --claim | advance docs/specs/demo --stamp 0123456789abcdef | advance docs/specs/demo --stamp 0123456789abcdef | status docs/specs/demo --json | release docs/specs/demo 0123456789abcdef","mm":[{"n":2,"want":"release docs/specs/demo 0123456789abcdef","got":"advance docs/specs/demo --stamp 0123456789abcdef"}]}
  ok    checkpoint: no launched_at, no time source - the checkpoint does not fire and the driver runs on
  ok    checkpoint: no `now` in any verb answer - the checkpoint does not fire
::error::needs_context: a NEEDS_CONTEXT return stops the build with no second dispatch, names the story and its report, releases - got {"result":"","n":2,"seq":"advance docs/specs/demo --stamp 0123456789abcdef --claim | advance docs/specs/demo --stamp 0123456789abcdef | advance docs/specs/demo --stamp 0123456789abcdef | status docs/specs/demo --json | release docs/specs/demo 0123456789abcdef","mm":[{"n":2,"want":"release docs/specs/demo 0123456789abcdef","got":"advance docs/specs/demo --stamp 0123456789abcdef"}]}
  ok    needs_context: an empty return is still retried and the second miss stops the run
  ok    needs_context: a DONE report mentioning NEEDS_CONTEXT in prose is no stop
  ok    needs_context: a still-listed DONE mentioning NEEDS_CONTEXT is a plain miss and retried
::error::needs_context: a wave of three names only the NEEDS_CONTEXT story and dispatches nothing more - got {"result":"","n":5,"seq":"advance docs/specs/demo --stamp 0123456789abcdef --claim | advance docs/specs/demo --stamp 0123456789abcdef | advance docs/specs/demo --stamp 0123456789abcdef | status docs/specs/demo --json | release docs/specs/demo 0123456789abcdef"}
::error::needs_context: a NEEDS_CONTEXT on the retry gives needs_context, not the two-miss stop - got {"result":{"spec":"docs/specs/demo","slug":"demo","stage":"03","tier":3,"branch":"vulyk/demo","head":"h1","wave_stories":[{"file":"docs/specs/demo/demo-01-x.md","story":"demo-01","worker":"worker-code","model":"opus","repeat":1}],"round":0,"court":null,"round_dir":null,"since":null,"seat_attempt":{},"seats":[],"red":[],"next":"build:1","stop":{"verb":"build","file":"docs/specs/demo/demo-01-x.md","error":"worker returned, but docs/specs/demo/demo-01-x.md is still todo - close-story did not close it"},"fallbacks":[]},"n":2}
  ok    no queen-planner dispatch in any scenario
132 passed, 3 failed
```
