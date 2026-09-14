---
story: v0-12-0-remainders-17
spec: v0-12-0-remainders
status: done
returned: DONE
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
- `tests/council.test.sh:30`: fixture `.gitignore` printf gains `docs/specs/*/DRIVER`.
- New "Story 17" section at the end of the file: `claim` (creation/idempotent/conflict/PAUSE), `release` (match/absent/mismatch), `pause`/`resume` (DRIVER removal + `driver released` journal line), and the gated-verbs scenario (`open-round`/`record-seat`/`judge`/`close-story`, no-stamp/wrong-stamp/right-stamp/PAUSE+DRIVER/no-DRIVER), reusing `mk_spec`/`mk_open_spec`/`set_tier`/`seat_report`/`council` exactly as the recon's "To add one scenario" describes.
- Extended `run_wall_probes` with a fourth pinned version, computed dynamically per the map slice (`PRESHA11="$(git -C "$SRC" log -1 --format=%h --grep='story(v0-12-0-remainders-11)')^"` = `ca0c74a^`, i.e. `30a6e3d`), with 4 new probe fns (`probe_claim`, `probe_release`, `probe_pauserelease`, `probe_gated`) - no restructuring of the runner itself, per Non-goals.
- One in-scope fix inside `run_wall_probes`'s own scratch-hive `.gitignore` printf (not the line-30 literal the criterion names): added `docs/specs/*/DRIVER` there too. Without it, `probe_gated`'s matching-stamp `open-round` call tripped the unrelated whole-tree "clean" precondition (`cycle.sh:1778`, `git status --porcelain` with no path scoping) on the untracked `DRIVER` file and failed for the wrong reason. Confirmed by reproducing the probe in an isolated fixture with and without the ignore line before touching the suite.
- One assertion fix in the gated-verbs scenario: `! grep -q '^\*\*Council:\*\*' plan.md` false-failed because `templates/plan.md`'s own placeholder line starts with the same marker; tightened to `! grep -qE '^\*\*Council:\*\* (GREEN|RED|ESCALATE|STALE) round'`.
- Pre-story (`ca0c74a^`/`30a6e3d`) observed labels: `probe_claim FAIL`, `probe_release FAIL`, `probe_pauserelease FAIL`, `probe_gated FAIL` (no `claim`/`release`/`DRIVER` code exists there at all - `usage` catches the unknown verb). Branch observed labels: `probe_claim ok`, `probe_release ok`, `probe_pauserelease ok`, `probe_gated ok` - each `ok` was observed, not forced.
- `bash tests/council.test.sh | tail -3` (whole run, final of three): exit 0, last lines `probe_release: ok` / `probe_pauserelease: ok` / `probe_gated: ok`, `grep -c '::error'` = 0 across the full transcript. Every pre-existing scenario (stories 14/15/16) unchanged and green.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
