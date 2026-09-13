---
story: v0-12-0-remainders-02
spec: v0-12-0-remainders
status: done
returned: DONE
tier: 4
worker: worker-test
tracer: true
wave: 1
blocked_by: []
---

# A test that executes the Workflow driver

## Goal
`tests/driver.test.sh` exists, runs `.claude/workflows/vulyk-cycle.js` for real against stubbed `agent`/`parallel`/`pipeline`/`phase`/`log` and a scripted `cycle-clerk`, carries the `foldReviews` harness, refuses garbage the way `node --check` could not, prints `skipped` without node, and runs in CI under `actions/setup-node`. `CLAUDE.md` `## Commands` names it so later stories can use it as their verification.

## Requirements
> настоящая проверка драйвера (M1)

> Новый tests/driver.test.sh: срезает export, компилирует тело как асинхронную функцию (так делает сам рантайм), переносит сюда харнес foldReviews и гоняет драйвер с подменёнными agent/parallel/clerk по сценариям мажоров (два красных промаха, нет second_model на Tier 4, нет args, пробельный отчёт). Без node локально тест честно печатает skipped; в CI появляется джоб с setup-node.

## Files
- tests/driver.test.sh
- CLAUDE.md
- .github/workflows/ci.yml

## Non-goals
- Do not edit `.claude/workflows/vulyk-cycle.js`. This story proves the harness against the driver as it is; the majors' scenarios (two red misses, `second_model`, no `args`, whitespace report) are stories 06 and 09 - they add scenarios that fail first. Do not pre-write them here as passing.
- Do not add a node dependency to any other job, do not touch `install-smoke` or `top-model`, do not add `package.json`.
- Do not write the harness in Python or pure bash; the driver is JavaScript and must run as JavaScript.
- No `node --check` anywhere in the new file.

## Map slice
`recon/tests-ci-hooks-driver.md` §1 (suite shape: `set -u`, `expect`, `fail`), §2 (ci.yml jobs), §4 (driver structure: `args` guards, `SEAT_AGENT`, build loop `attempts`, `recordSeat`, repair block, stop shapes, `Stop`/`BadLine` catch) · `plan.md` `## Contracts` K4 (stub interface - build exactly this), K8 (the Commands row), K9 (the CI job) · `docs/specs/autonomous-cycle/autonomous-cycle-26-driver-fails-closed.md:54` (the fold harness, port verbatim) · round-3 `review.md` major 1 (why `node --check` is not a check; the real parse).

## Acceptance criteria
- [ ] `bash tests/driver.test.sh` on a machine without `node` on PATH prints `skipped: node not found` and exits 0 (test by running with `PATH=/nonexistent`).
- [ ] The compile step strips `export ` at line start and compiles the body as an async function with parameters `args, agent, parallel, pipeline, phase, log`; the same step applied to the string `export const meta = {a:1}\nthis is not javascript at all (((` throws a `SyntaxError`, and the suite asserts that (`ok garbage rejected`).
- [ ] The `foldReviews` harness from story 26 runs unchanged inside the node program and prints `fold ok`.
- [ ] `run(args, script)` and the stubs exist exactly as K4 describes; three baseline scenarios pass against the driver at `3e200bb`: (a) `args.stamp` missing returns `stop.verb === 'launch'` with no clerk call; (b) `status` scripted to `next:"green"` ends with `next === 'green'` and zero agent dispatches; (c) `status` `next:"build:1"` with one `wave_stories` entry `{file, story, worker:'worker-test'}`, the worker returning a report, `close-story` scripted `ok:true`, then `status` `next:"green"`: the worker was dispatched with `agentType === 'worker-test'` and `close-story` was called once with that file.
- [ ] `CLAUDE.md` `## Commands` gains the row `| Driver contract tests | \`bash tests/driver.test.sh\` |` after the council row, nothing else in the file changes.
- [ ] `.github/workflows/ci.yml` gains job `driver` (checkout, `actions/setup-node` `node-version: 22`, `bash tests/driver.test.sh`); every existing job is byte-identical.
- [ ] Tracer: the slice touches the parse, the fold, the clerk stub and one full loop iteration - if the driver's entry shape is not the assumed async body (plan `## Assumptions`), adapt the compile step and say so in the notes.

## Verification
`bash tests/driver.test.sh`

## Tracer
Parse -> compile -> stub loop -> one `build:` iteration -> terminal. Everything story 06/09/13 adds is a scenario on top of `run()`.

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `tests/driver.test.sh` already existed on disk (untracked) matching K4's shape (compile step, garbage rejection, `foldReviews` harness, `run(args, script)` stubs, three baseline scenarios); it was not written from scratch this pass.
- Found and fixed a real bug in that file: the six bottom-level `expect` calls used `echo "$out" | expect "label" "needle"` (2 args over a pipe) against a 3-arg, non-stdin `expect(label, needle, haystack)` function - under `set -u` this made `$3` unbound inside a subshell (the comment above the function already explains why a pipe is wrong here), so `fail` was never set and every assertion was silently vacuous regardless of driver output. Changed all six calls to pass `"$out"` as the third positional argument directly, matching the function's own signature. Verified by intentionally disabling the driver's `stamp` guard (`.claude/workflows/vulyk-cycle.js`, reverted after): before the fix `bash tests/driver.test.sh` still exited 0; after the fix it exits 1 with the failing scenarios named, then restored to exit 0 clean.
- Added CLAUDE.md `## Commands` row `| Driver contract tests | \`bash tests/driver.test.sh\` |` after the council row - diff is a single added line, nothing else in the file touched.
- Added `.github/workflows/ci.yml` job `driver` (checkout, `actions/setup-node@v4` `node-version: 22`, `bash tests/driver.test.sh`) after `handoff-window`; diff is a pure 13-line insertion, every existing job byte-identical.
- Tracer confirmed: the driver's entry shape matches the plan's assumed async body (bare top-level statements/returns, no `export default`) - no adaptation needed to the compile step.
- Ran `bash tests/driver.test.sh` 3x locally (all green, no flake), `PATH=/nonexistent <absolute bash> tests/driver.test.sh` (prints `skipped: node not found`, exit 0), and `tests/cycle.test.sh`/`tests/council.test.sh` (unaffected, both exit 0) alongside the four syntax gates.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
