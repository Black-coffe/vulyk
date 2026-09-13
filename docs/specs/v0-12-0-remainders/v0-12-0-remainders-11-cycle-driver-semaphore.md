---
story: v0-12-0-remainders-11
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-code
tracer: false
wave: 5
blocked_by: [v0-12-0-remainders-08]
---

# The DRIVER semaphore: `claim`/`release`, `--stamp` on four verbs

## Goal
`cycle.sh` refuses a second driver on a spec another driver holds, as ADR-004 decided: `claim <spec> <stamp>` writes a gitignored `docs/specs/<slug>/DRIVER` under `noclobber`, `release` removes it, `pause`/`resume` release it, and `open-round`, `record-seat`, `judge`, `close-story` refuse with `held by <stamp>` when the file exists and `--stamp` is absent or differs.

## Requirements
> Второй драйвер на том же спеке получает отказ — семафор DRIVER через cycle.sh claim/release (M-7, решено в дельте 6).

## Files
- scripts/cycle.sh
- tests/council.test.sh
- .gitignore

## Non-goals
- Do not gate `escalate`, `reopen`, `briefed`, `branch`, `status`; do not require `--stamp` when no `DRIVER` exists (hand runs and the whole existing suite must pass unchanged).
- Do not add `driver` to `status --json`, do not add a `next` value, do not commit the file (`--commit` is not accepted by `claim`/`release`).
- Do not touch either driver or command file (story 13); do not edit `install.sh` (story 07 shipped the gitignore entry).
- Do not redesign ADR-004: the file name, the verb pair, `noclobber`, the four verbs and the release points are fixed; only K3's details are yours.
- Set `returned: DONE` in this story's own frontmatter before returning (story 08's gate is live).

## Map slice
`docs/adr/004-driver-mutual-exclusion.md` (the decision, verbatim) · `plan.md` K3 (build exactly this), K1 (`held by` is an `ok:false` with `error`) · `memory/map/cycle.md` (PAUSE guard order: every mutating verb calls `pause_guard` first; verbs table) · `recon/tests-ci-hooks-driver.md` §1 (`mk_open_spec`, `mk_open_round`, `write_seat`); the fixture `.gitignore` is the literal at `tests/council.test.sh:30` (`printf '.vulyk/\ndocs/specs/*/PAUSE\n' > .gitignore`) - add `docs/specs/*/DRIVER` there · `recon/tests-ci-hooks-driver.md` §5 (`lib.sh` has no atomic helper - `noclobber` lives in `cycle.sh`).

## Acceptance criteria
- [ ] `claim`: creates `DRIVER` (`stamp=`, `claimed=` lines) with `set -o noclobber`; a second `claim` with the same stamp exits 0; a different stamp exits 2 with the K3 error naming the holder and the `release` command; under PAUSE exits 3.
- [ ] `release`: matching stamp or absent file -> exit 0, file gone; mismatch -> exit 2 `held by <other>`.
- [ ] `pause` and `resume` remove `DRIVER` if present and journal `driver released`.
- [ ] With `DRIVER` held by `aaaa...`: `open-round`, `record-seat`, `judge`, `close-story` each exit 2 `held by aaaa...` without `--stamp` or with `--stamp bbbb...`, and proceed with `--stamp aaaa...`; the check runs after `pause_guard` and before any write. With no `DRIVER`, all four behave as before with or without `--stamp`.
- [ ] `.gitignore` gains `docs/specs/*/DRIVER`; the fixture `printf` at `tests/council.test.sh:30` gains the same line; `git status --porcelain` after a `claim` in the fixture repo is empty.
- [ ] Suite scenarios for each bullet; the pre-existing suite passes unchanged; `bash -n` passes.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
