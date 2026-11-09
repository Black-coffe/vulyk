---
story: mass-audit-fixes-06
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: retry never runs on the judging family
red_verified_at: 2026-11-09T12:59:15Z 4e4b76745fbd701270dbc5bf924077800292b35b2254818765d3be02b9af8461
---

# A missed story's retry never runs on the family that judges it; the model brief says less, once

## Goal
`.claude/workflows/vulyk-cycle.js` picks the retry model as the first of `[TOP, 'opus']` that is not the family
judging this round (`REVIEW` when passed, else `opus` at Tier 3; `TOP` at Tier 4, where the top reviewer runs on
it); when none is left the retry runs on `opus` and the run result carries `retry_same_family: true`.
`docs/model-cascade.md` lists every same-family case (solo Tier 1-2 under the default profile, repair stories,
the Tier 4 retry) instead of "one gap". `.claude/hooks/top-model-brief.sh` runs `top-model.sh` once and reuses
its output, and prints the dispatch sentence only when something differs from the default (floor not ok,
profile not chosen, a pin present). Ask 11: private audit (2026-11-08) findings I3, I7 (doc half; the CLAUDE.md
line is story 13's), O6. Marked red: a dispatch branch.

## Requirements
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- docs/model-cascade.md
- .claude/hooks/top-model-brief.sh
- tests/model-profile.test.sh
- scripts/top-model.sh

## Non-goals
- Do not change which model a first attempt, a reviewer or a seat runs on, and do not touch
  `scripts/model-profile.sh`. `scripts/top-model.sh` gains one additive mode (`--brief`: the explain lines and
  the floor lines from one run) and nothing else: its existing modes print what they print today.
- Do not edit `CLAUDE.md` (the gap note there is story 13's, which must stay under the byte cap).
- Do not remove the litopys ask or change its stop condition (`session-start-brief.sh` is not in this story).

## Map slice
`memory/map/cycle.md` → The Workflow driver; `memory/map/agents-and-commands.md` → Commands (`/vulyk-build`
hive path, Profile-aware dispatch); `memory/map/scripts.md` → Entry points (`model-profile.sh`, `top-model.sh`).

## Acceptance criteria
- [ ] `tests/driver.test.sh`: economy (TOP=opus, REVIEW=opus) retries on `opus` with `retry_same_family: true`
  (no other family is left in `[TOP, 'opus']`; `docs/model-cascade.md` lists it as a same-family case); sonnet-builds
  Tier 4 (TOP=fable, REVIEW unset) retries on `opus`; Tier 3 with TOP=fable retries on `fable`; Tier 4 under
  sonnet-builds with REVIEW=opus records `retry_same_family: true` and retries on `opus`. The failing label
  contains `retry never runs on the judging family`.
- [ ] The existing "TOP falls back to opus" case still passes.
- [ ] `top-model-brief.sh` output on a default box (floor ok, profile set, no pin) is one line; with a pin or a
  floor miss it prints the model line; it calls `top-model.sh` once (counting stub in
  `tests/model-profile.test.sh`).
- [ ] `docs/model-cascade.md` names the three same-family cases and the retry rule in one short table.

## Verification
`bash tests/driver.test.sh`
`bash tests/model-profile.test.sh`

## Implementation notes
- `.claude/workflows/vulyk-cycle.js`: `RETRY` constant replaced by `retryModel(st.tier)`; judges are `[REVIEW || opus]` at Tier 1-3, `[TOP, REVIEW]` at Tier 4 (the 4th test case needs REVIEW counted at Tier 4 too); a same-family pick sets `retry_same_family: true` on every return path.
- `scripts/top-model.sh`: explain body moved into `explain_lines()`; `--brief` = explain lines then the floor block (and its exit); `--help` range bumped one line for the new usage line; other modes byte-identical (diffed against HEAD).
- `.claude/hooks/top-model-brief.sh`: one `--brief` run split into explain/floor lines; dispatch sentence only on floor miss, profile not chosen (or no model-profile.sh), or an env/constitution pin.
- `docs/model-cascade.md`: the "one gap" sentence became the retry rule plus a same-family table (solo Tier 1-2, repair stories, the retry with no family left, and the existing Tier 4 second-reviewer gap).
- Tests: driver red test kept from the earlier attempt; brief checks in `tests/model-profile.test.sh` use a counting stub hive.

## Findings
- NEEDS_CONTEXT (worker, 2026-11-09): the AC "top-model-brief.sh calls top-model.sh once" cannot be met inside
  `## Files`. The brief needs two things only top-model.sh computes: the gate model and its source (pin detection,
  `--explain`) and the floor verdict (`--floor`, the 80-line scan). Each is a separate mode of `top-model.sh`, and the
  Non-goals forbid touching it. Options: (a, recommended) add `scripts/top-model.sh` to `## Files` for a combined mode
  (e.g. `--brief`: the explain lines plus the floor lines in one run, one fork for both), lifting that Non-goal;
  (b) the hook copies the pin check (env `VULYK_TOP_MODEL`, `TOP_MODEL =` in the constitution) and calls only
  `--floor`, a second copy of resolver logic the hook header says lives in top-model.sh; (c) accept two calls and
  drop that AC clause (the two `model-profile.sh` calls can still become one). The driver half is unblocked: the red
  test for the retry rule is already in `tests/driver.test.sh` (uncommitted, red for the stated reason, 3 of 4 new
  checks fail); stamp-red was not run, since it would seal `tests/model-profile.test.sh` before its brief test exists.
- AC wording: "economy (TOP=opus, REVIEW=opus) retries on the other high family" has no such family under the Goal's
  `[TOP, 'opus']` list; the new test asserts the Goal's rule (opus + `retry_same_family: true`). Confirm.
- Queen ruling (2026-11-09): (a) taken: `scripts/top-model.sh` added to `## Files` for an additive `--brief`
  mode, Non-goal narrowed to that; economy AC rewritten to the Goal's rule (opus + `retry_same_family: true`).
  Keep the uncommitted red test in `tests/driver.test.sh`; run stamp-red once both test files hold their tests.

## Red receipt
- command: bash tests/driver.test.sh
- exit: 1
- tests: 4e4b76745fbd701270dbc5bf924077800292b35b2254818765d3be02b9af8461 (tests/driver.test.sh, tests/model-profile.test.sh)
- impl: 194bfe2c0423b93fb0c5308557fc278d32d1f4f0f68c935ae6aaed08e0e91e5a
- stamped: 2026-11-09T12:59:15Z

```
::error::retry never runs on the judging family: economy (TOP=opus, REVIEW=opus) has no other high family - opus, retry_same_family recorded - got {"m":["sonnet","opus"]}
::error::retry never runs on the judging family: sonnet-builds Tier 4 (TOP=fable judges) retries on opus - got {"m":["sonnet","fable"]}
  ok    retry never runs on the judging family: Tier 3 with TOP=fable (opus judges) retries on fable
  ok    checkpoint: after a wave, before the gate and the seats
  ok    checkpoint: after one gate step, before the next
  ok    checkpoint: after the gate finished, before the seat dispatch
  ok    checkpoint: a terminal state returns as itself, no checkpoint
  ok    checkpoint: 50 min after launched_at by the verb clock, the default fires
  ok    checkpoint: 49 min, the default does not fire
  ok    checkpoint: no launched_at, no time source - the checkpoint does not fire and the driver runs on
  ok    checkpoint: no `now` in any verb answer - the checkpoint does not fire
  ok    no queen-planner dispatch in any scenario
122 passed, 3 failed
```
