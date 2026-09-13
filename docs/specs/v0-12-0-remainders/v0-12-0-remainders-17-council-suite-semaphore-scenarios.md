---
story: v0-12-0-remainders-17
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-test
tracer: false
wave: 8
blocked_by: [v0-12-0-remainders-11]
---

# The council suite proves the DRIVER semaphore of story 11

## Goal
`tests/council.test.sh` gains one scenario per story 11 criterion - `claim`, `release`, `pause`/`resume` release, the four gated verbs with and without `--stamp` - plus the fixture `.gitignore` line so a claimed fixture repo stays clean, each scenario shown to fail against the `cycle.sh` from before story 11's commit and to pass against the branch. The code is already on the branch; this story is the evidence.

## Requirements
> Второй драйвер на том же спеке получает отказ — семафор DRIVER через cycle.sh claim/release (M-7, решено в дельте 6).

## Files
- tests/council.test.sh

## Non-goals
- Do not edit `scripts/cycle.sh` or the repo `.gitignore`. A scenario red against the branch is a wall: record the failing assertion under `## Findings` and return `WALL`; do not patch the script or weaken the assertion.
- Do not touch stories 14/15/16's scenarios and probe entries; do not restructure the helpers - extend `run_wall_probes` with one more pinned version.
- Do not use `git stash` or checkout to reach the pre-story script; the working tree stays untouched by the proof.
- Run the suite once, at the end, as `bash tests/council.test.sh | tail -3`.
- Write `returned: DONE` as your last edit; never write `status:` (story 09's rule).

## Map slice
`plan.md` K3 (the exact errors and exit codes to assert) · `docs/adr/004-driver-mutual-exclusion.md` · `recon/tests-ci-hooks-driver.md` §1 (`mk_open_spec`, `mk_open_round`, `write_seat`, "To add one scenario"); the fixture `.gitignore` is the literal at `tests/council.test.sh:30` (`printf '.vulyk/\ndocs/specs/*/PAUSE\n' > .gitignore`) - add `docs/specs/*/DRIVER` there · story 11 `## Acceptance criteria` and `## Implementation notes` · story 14 `## Implementation notes` (the `run_wall_probes` shape). The pre-story script is `git show <sha>^:scripts/cycle.sh` where `<sha>` is `git log -1 --format=%h --grep='story(v0-12-0-remainders-11)'`.

## Acceptance criteria
- [ ] `claim` scenario: first `claim` exits 0 and `DRIVER` holds `stamp=` and `claimed=` lines; same stamp again exits 0; a different stamp exits 2 with `error` containing `held by <first>` and `cycle.sh release`; under PAUSE exits 3 with `next:"paused"`.
- [ ] `release` scenario: matching stamp -> exit 0, file gone; absent file -> exit 0; mismatch -> exit 2 `held by <other>`, file kept.
- [ ] `pause`/`resume` scenario: each removes an existing `DRIVER` and `journal.md` gains a `driver released` line.
- [ ] Gated verbs scenario: with `DRIVER` held by `aaaa...`, each of `open-round`, `record-seat`, `judge`, `close-story` exits 2 `held by aaaa...` with no `--stamp` and with `--stamp bbbb...`, leaving no new file, row or commit; with `--stamp aaaa...` each proceeds; with no `DRIVER`, each proceeds with or without `--stamp`. A paused spec with a held `DRIVER` answers exit 3, not `held by`.
- [ ] The fixture `printf` at `tests/council.test.sh:30` gains `docs/specs/*/DRIVER`; `git status --porcelain` after a `claim` in a fixture repo is empty.
- [ ] Each scenario is proven to fail at the pre-story script without touching the working tree, in the `run_wall_probes` shape; `## Implementation notes` records the `FAIL` labels observed there and the `ok` labels on the branch - an `ok` pre-story is recorded as observed, with the reason, never forced.
- [ ] `bash tests/council.test.sh` passes whole on the branch; every pre-existing scenario unchanged.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
