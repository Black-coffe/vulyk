---
story: fast-verification-03
spec: fast-verification
status: done
returned: DONE
tier: 3
worker: worker-test
wave: 2
blocked_by: [fast-verification-01, fast-verification-02]
---

# `tests/full-suite.sh`: every suite at once, one budget, measured

## Goal
One script runs the whole suite - every `tests/*.test.sh`, the two split suites as their `--list-parts` parts - in
parallel under one budget, `VULYK_SUITE_TIMEOUT` (default 540 s), with a `--jobs` cap, and prints one line per job
and one summary line. Its contract test proves the ok/FAIL/TIMEOUT paths with stub suites. CI runs it uncapped. The
story ends with two real measurements written into `plan.md` `## Integration gate`.

## Requirements
> 2. Полный набор запускается одним скриптом, все наборы разом, и проходит целиком внутри 9 минут; ревьюер запускает его один раз на раунд.

## Files
- tests/full-suite.sh
- tests/full-suite.test.sh
- .github/workflows/ci.yml
- docs/specs/fast-verification/plan.md

## Non-goals
- Do not edit `lead-review.md` or `cycle.sh` (story 06 teaches the reviewer and the judge to read the result).
- Do not edit `CLAUDE.md`: the rows `bash tests/full-suite.sh` (round-only) and `bash tests/full-suite.test.sh`
  exist since story 01.
- Do not hardcode the suite list, add a retry, a flake detector, or per-suite budgets.
- Do not re-cut a slow part yourself: a part that breaks the budget is a `NEEDS_CONTEXT` naming the part and its time.

## Map slice
memory/map/scripts.md `## Key contracts` (exit codes), `## Gotchas` (the `timeout 5 true` probe); plan.md
`## Contracts` `Runner`; scout-suites.md `## Running two copies at once`.

## Acceptance criteria
- [ ] `bash tests/full-suite.sh` follows the plan's `Runner` contract: job list from the glob plus `--list-parts`,
      `--list` prints the job commands and runs nothing, `--jobs N` (default core count, `nproc` else 4), one
      `ok|FAIL|TIMEOUT <seconds>s <command>` line per job, tail 20 of each failed log, the summary line, exit 0/1/124
      with TIMEOUT outranking FAIL, logs kept and named on non-zero exit.
- [ ] At the budget the runner kills running jobs, marks them and every unstarted job `TIMEOUT`, and still prints
      the summary; `VULYK_SUITE_TIMEOUT=0` runs uncapped; without a working `timeout` binary jobs run uncapped and
      an over-budget job is still reported `TIMEOUT` by its measured time.
- [ ] `tests/full-suite.test.sh` (< 30 s) drives the runner through `VULYK_SUITES` with stub scripts: all ok -> exit
      0 and the summary; one failing -> `FAIL` line, tail, exit 1; one sleeping past `VULYK_SUITE_TIMEOUT=2` ->
      `TIMEOUT` line, exit 124 even beside a FAIL; `--jobs 1` runs them one at a time (prove by timestamps or a
      lock file). This is the test that fails when the budget or exit-code logic breaks.
- [ ] MEASURED, not estimated: `bash tests/full-suite.sh` on this box with default `--jobs`, all jobs at once, is
      under 540 s; the wall, the core count and the date go into `plan.md` `## Integration gate` (replace the
      `<W>`/`<cores>`/`<date>` placeholders). Over 540 s = the story is not done (`NEEDS_CONTEXT` naming the slowest
      jobs with their times).
- [ ] Second measurement `--jobs 4` on the same box, written beside the first with the gap; the note says whether it
      fits the budget and makes no claim beyond that run.
- [ ] `ci.yml`: one job runs `VULYK_SUITE_TIMEOUT=0 bash tests/full-suite.sh`; the per-suite steps it covers (cycle,
      council, driver, e2e, solo, maintenance, telemetry, token-report) are removed; bash -n, top-model,
      handoff-window and install smoke stay. The YAML parses (check with the tool CI itself uses, locally).

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/full-suite.test.sh`

## Implementation notes
- Runner and contract test came from the dead run's wip commit c4dc7c2; kept as is except the test. The old budget
  scenario put the "unstarted" job behind a FAIL that freed its slot at 0 s, so it started before the budget: split
  into hang+FAIL (`--jobs 2`, exit 124) and hang+queued (`--jobs 1`, never starts). Per-job seconds are matched as
  `<N>s` (a job can cross a second boundary). Mutations watched failing: 1 outranking 124, no `timeout` kill.
- CI: one `full-suite` job (fetch-depth 0, node 22, `VULYK_SUITE_TIMEOUT=0`) replaces cycle, council, driver
  (driver/e2e/solo/maintenance), the telemetry suite step and token-report; the inbox-bundle check stays in
  `telemetry-inbox`. YAML parsed with PyYAML locally (no actionlint on this box).
- Measurements (plan.md `## Integration gate`): default 28 jobs 425 s; `--jobs 4` hit the 540 s budget.
- Not the runner's, seen in both runs: `council --part verbs` fails on wave-mate 04's wip test (scope-check names
  `CLAUDE.vulyk.md`); `model-profile` fails on CLAUDE.md 7165 B > 7162 B (story 01). In the 28-job run only,
  inject/intake fail their 200 ms latency medians (360-444 ms under load); both pass at `--jobs 4`.

## Findings
