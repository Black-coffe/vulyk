---
story: fable-review-remainders-05
spec: fable-review-remainders
status: todo
returned:
tier: 3
worker: worker-test
tracer: false
wave: 2
blocked_by: [fable-review-remainders-02]
model: sonnet
---

# The council suite's probes fail the suite, LR31 goes red pre-fix, release and `--file` are proven

## Goal
`tests/council.test.sh` stops being print-only where it claims proof: `run_wall_probes` sets `fail=1` on any non-`ok` `[branch]` result, every pinned copy goes through `pin_cycle` with a printed reason and `fail=1` when it cannot be produced, and `PIN_MUST_FAIL` asserts that a named probe is `FAIL` at its pinned sha. The LR31 scenario (`lr31w` and `probe_lr31wall`) puts a ready story and a not-ready `todo` in one wave and asserts `wave_stories` names only the ready one, red at `eb3203a`. Two new scenarios: `release` under PAUSE exits 0; `record-seat --file` records the file and refuses a missing one with exit 2 `file:`.

## Requirements
> Сценарий LR31 в tests/council.test.sh краснеет против до-фиксового cycle.sh: готовая и неготовая (todo с незакрытым блокером) истории в одной волне, `wave_stories` называет только готовую.
> Пробы «shown to fail at <sha>» роняют сьют (fail=1) при результате не `ok` на ветке и при недоступном пиннед-источнике (`git show` с обработкой ошибки и напечатанной причиной)
> ADR-001 называет release в списке исключений; сценарий в сьюте это фиксирует.
> сьют проверяет вариант с файлом.

## Files
- tests/council.test.sh

## Non-goals
- Do not edit `scripts/cycle.sh`, `ci.yml` (story 01 owns `fetch-depth: 0`) or any ADR. A scenario red against the branch is a WALL: record the assertion under `## Findings`, return `WALL`; never weaken it.
- Do not restructure the 20 `probe_*` functions or the scenarios of stories 14-17 beyond the LR31 pair; the harness change is in `run_wall_probes` and the four pinned-copy sites only.
- Do not use `git stash` or a checkout to reach a pre-fix script; the pinned copies are `git show` output, as today.
- Do not read the suite end to end: locate by `grep -n` (`run_wall_probes`, `lr31w`, `probe_lr31wall`, `git -C "$SRC" show`, `PRESHA11`, `record-seat`, `claim under PAUSE`).
- Run the suite once, at the end, with `timeout: 600000` on the Bash call, through `2>&1 | tail -n 5`; keep a transcript file for `grep -c '::error'` if the tail is not clean.
- Write `returned: DONE` as your last edit; never write `status:`.

## Map slice
`plan.md` C1, C4, C5 (the exact line shapes, `pin_cycle`, `PIN_MUST_FAIL`, the JSON to assert) · `recon/install-and-suite.md` §"tests/council.test.sh probe machinery" (harness `:1-22`, `lr31w :1387-1421`, `probe_lr31wall :2409-2439`, `run_wall_probes :2084-2133`, the four pinned sites `:2030, :2358, :2461, :2687`) · `recon/driver-and-cycle.md` §"`scripts/cycle.sh` record-seat / judge" (existing record-seat scenarios `:646-896`, `probe_release :2649-2690`, `claim under PAUSE :2490`) · story 02 `## Implementation notes` · `docs/specs/v0-12-0-remainders/v0-12-0-remainders-17-*.md` `## Implementation notes` (the probe shape and the `.gitignore` gotcha).

## Acceptance criteria
- [ ] `run_wall_probes`: a `[branch]` probe result other than `ok` sets `fail=1` (shown by temporarily forcing one probe to `FAIL` in a scratch copy of the suite and observing exit 1; record the command); pinned results print as today and, for names in `PIN_MUST_FAIL`, a result other than `FAIL` sets `fail=1`.
- [ ] `pin_cycle <sha> <dest>` wraps all four `git -C "$SRC" show` sites; a bad sha (shown in a scratch copy with a fake sha) prints `  [<sha>] unavailable: <reason>` and the suite exits 1; an empty `$PRESHA11` prints the C5 reason line and sets `fail=1`. The suite's last statement is `exit "$fail"`.
- [ ] `lr31w`: wave 1 holds story A `todo` with no blockers (or blockers all `done`) and story B `todo` with `blocked_by` naming a `blocked` or `todo` story; `wave_stories` lists exactly A; when B's blocker becomes `done`, both. `probe_lr31wall` mirrors it; `PIN_MUST_FAIL="probe_lr31wall"` beside the `eb3203a` run; the pinned line prints `FAIL`, the branch line `ok`.
- [ ] `release` scenario: a claimed then paused spec: `release <spec> <stamp>` exits 0 with `ok:true`, `DRIVER` gone; the foreign-stamp case still exits 2 `held by`; `claim under PAUSE exits 3` untouched.
- [ ] `record-seat --file` scenario: a valid council report written to a file under the fixture's `.vulyk/reports/...` records the seat (seat file bytes equal the stdin-recorded twin); `--file` on a missing path exits 2 with `error` exactly `file: <path>` and writes no attempt file; an empty file behaves as missing.
- [ ] `bash tests/council.test.sh` exits 0 on the branch; every pre-existing scenario unchanged; `grep -c '::error'` on the transcript is 0.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
