---
story: beta-fixes-1113-02
spec: beta-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a NEEDS_CONTEXT return stops the build with no second dispatch
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

## Findings
