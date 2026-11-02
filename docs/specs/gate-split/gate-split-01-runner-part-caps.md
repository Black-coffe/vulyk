---
story: gate-split-01
spec: gate-split
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason:
---

# Runner: a 300 s cap per part, steps, PART lines, growth check, SKIP, CI

## Goal
`tests/full-suite.sh` stops running every job under one `VULYK_SUITE_TIMEOUT` budget. Each job (a suite, or one
`--part` of a suite with `--list-parts`) is a part with its own hard cap (`VULYK_PART_CAP`, default and maximum 300 s);
parts are grouped into steps of at most `--jobs` parts started together; `--steps` and `--step K` expose them for
`cycle.sh suite`. Every part prints a PART line with its time. A part at its cap is a FAIL "cut part X"; a part over
70% of its cap is a FAIL too, decided by the new `scripts/suite-parts-check.sh`, which becomes the `check:` of card
`test-gate-one-long-limit` with the original case and a neighbour-form fixture. Exit 77 + `SKIP:` reads as SKIP,
counted apart, a failure under `VULYK_STRICT_SKIP=1`. CI runs the same caps on every OS that runs the suite.

## Requirements
> 1. У каждой части тестов свой лимит не больше 300 с, шаг прогона влезает в один вызов, одного общего лимита больше нет.
> 3. Часть, дошедшая до лимита, считается ошибкой этой части, владельца не зовут.
> 4. Часть дольше 210 с даёт красную проверку заранее, и карточка получает настоящую проверку.
> 7. CI с теми же 300 с на часть, время частей видно на Linux, macOS и Windows.
> 8. Тест без нужного инструмента показывается как SKIP, а в CI SKIP считается ошибкой.
> Лучше разбить на 10 шагов гейтов дробными лимитами по 300, по 100, по 200 секунд, нежели гонять по 20-30 мин. и постоянно упираться в лимиты.

## Files
- tests/full-suite.sh
- tests/full-suite.test.sh
- scripts/suite-parts-check.sh
- docs/defects/test-gate-one-long-limit.md
- docs/defects/test-gate-one-long-limit.original.fixture
- docs/defects/test-gate-one-long-limit.neighbour.fixture
- docs/defects/INDEX.md
- .github/workflows/ci.yml

## Non-goals
- Do not cut any test file into parts (`gate-split-02`, `gate-split-03`) and do not touch `scripts/cycle.sh` (the round
  gate is `gate-split-04`).
- Do not keep `VULYK_SUITE_TIMEOUT` as a fallback total budget, and never raise a cap above 300 s.
- Do not edit `CLAUDE.md`: the row rename is `gate-split-06`.

## Map slice
memory/map/scripts.md `## Tests`, `## Key contracts`, `## Gotchas`; docs/defects/README.md `## Statuses`, `## Fixtures`,
`## The gate`; plan.md `## Contracts` (PART line, suite-parts-check, SKIP, Runner CLI).

## Acceptance criteria
- [ ] Each part runs under `run_capped` at `VULYK_PART_CAP` (default 300); `VULYK_PART_CAP` above 300 exits 2; a part
      that hits the cap prints `PART <name> CAP <N>s cap <C>s - cut part <name>` and the run exits 1, never 124.
- [ ] `--steps` prints S; `--step K` runs only step K's parts (at most `jobs`, started together; latency jobs alone,
      last) and ends `STEP K/S: ok|FAIL <N>s`; the plain run executes steps 1..S in sequence and ends
      `SUITE: ok|FAIL <N>s parts=<n> skip=<n> fail=<csv>`. Step membership is the same across calls for one `jobs`.
- [ ] `scripts/suite-parts-check.sh <file>` follows the plan contract: exit 1 on a CAP line, a cap over 300, or N over
      70% of C; exit 0 on input with no PART line and on a path that is not a readable file (`defects-check.sh <arg>`
      runs every block check on any argument); exit 2 only with no argument. The runner calls it after each step; a
      growth line fails the run.
- [ ] Card `test-gate-one-long-limit`: `status: block`, `check: bash scripts/suite-parts-check.sh <arg>`, `fixtures:`
      the original case first (the 2026-11-02 run: one budget of 905 s, `solo` at 377 s, written as PART lines with
      `cap 905s`) and a neighbour form (per-part caps, one part at 215 s of 300). `bash scripts/defects-index.sh`
      regenerates `INDEX.md`; `bash scripts/defects-check.sh` is green (both fixtures fail the check).
- [ ] A job exiting 77 with a `SKIP:` line is a `SKIP` PART line, counted apart; with `VULYK_STRICT_SKIP=1` it fails.
- [ ] `ci.yml`: no `VULYK_SUITE_TIMEOUT`; `VULYK_STRICT_SKIP=1` on every job that runs `tests/full-suite.sh`; the PART
      lines reach the job log on each OS that runs it (recon question 4: if Windows runs no suite job, say so in
      `## Implementation notes`, do not add one).
- [ ] `tests/full-suite.test.sh` covers: a part at its cap is FAIL (exit 1, not 124), a part over 70% fails, a cap
      over 300 is refused, `--steps`/`--step K`, a 77 job is SKIP and strict SKIP fails. Keep its timing cases short
      (caps of 1-3 s against fixture suites, as today at lines 38-39, 67-70, 178).

## Verification
`bash tests/full-suite.test.sh`
`bash scripts/defects-check.sh`

## Implementation notes

## Findings
