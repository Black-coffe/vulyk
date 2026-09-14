---
story: v0-12-0-remainders-11
spec: v0-12-0-remainders
status: done
returned: DONE
tier: 4
worker: worker-code
tracer: false
wave: 7
blocked_by: [v0-12-0-remainders-08, v0-12-0-remainders-16]
---

# The DRIVER semaphore: `claim`/`release`, `--stamp` on four verbs

## Goal
`cycle.sh` refuses a second driver on a spec another driver holds, as ADR-004 decided: `claim <spec> <stamp>` writes a gitignored `docs/specs/<slug>/DRIVER` under `noclobber`, `release` removes it, `pause`/`resume` release it, and `open-round`, `record-seat`, `judge`, `close-story` refuse with `held by <stamp>` when the file exists and `--stamp` is absent or differs. The suite scenarios belong to story 17; this story lands the code and the repo `.gitignore` line only.

## Requirements
> Второй драйвер на том же спеке получает отказ — семафор DRIVER через cycle.sh claim/release (M-7, решено в дельте 6).

## Files
- scripts/cycle.sh
- .gitignore
- tests/council.test.sh
<!-- listed so the verification command reaches this story's files (wave-check); the Non-goals forbid editing it -->

## Non-goals
- No edits to `tests/council.test.sh` - story 17 owns the scenarios and the fixture `.gitignore` line. Run the suite once, at the end, as `bash tests/council.test.sh | tail -3`; it must stay green (no `DRIVER` exists in any fixture, so nothing is gated).
- Do not gate `escalate`, `reopen`, `briefed`, `branch`, `status`; do not require `--stamp` when no `DRIVER` exists (hand runs and the whole existing suite must pass unchanged).
- Do not add `driver` to `status --json`, do not add a `next` value, do not commit the file (`--commit` is not accepted by `claim`/`release`).
- Do not touch either driver or command file (story 13); do not edit `install.sh` (story 07 shipped the gitignore entry).
- Do not redesign ADR-004: the file name, the verb pair, `noclobber`, the four verbs and the release points are fixed; only K3's details are yours.
- Write `returned: DONE` as your last edit (story 08's gate is live); never write `status:` (story 09's rule).

## Map slice
`docs/adr/004-driver-mutual-exclusion.md` (the decision, verbatim) · `plan.md` K3 (build exactly this), K1 (`held by` is an `ok:false` with `error`) · `memory/map/cycle.md` (PAUSE guard order: every mutating verb calls `pause_guard` first; verbs table) · `recon/tests-ci-hooks-driver.md` §5 (`lib.sh` has no atomic helper - `noclobber` lives in `cycle.sh`).

## Acceptance criteria
- [ ] `claim`: creates `DRIVER` (`stamp=`, `claimed=` lines) with `set -o noclobber`; a second `claim` with the same stamp exits 0; a different stamp exits 2 with the K3 error naming the holder and the `release` command; under PAUSE exits 3.
- [ ] `release`: matching stamp or absent file -> exit 0, file gone; mismatch -> exit 2 `held by <other>`.
- [ ] `pause` and `resume` remove `DRIVER` if present and journal `driver released`.
- [ ] With `DRIVER` held by `aaaa...`: `open-round`, `record-seat`, `judge`, `close-story` each exit 2 `held by aaaa...` without `--stamp` or with `--stamp bbbb...`, and proceed with `--stamp aaaa...`; the check runs after `pause_guard` and before any write. With no `DRIVER`, all four behave as before with or without `--stamp`.
- [ ] `.gitignore` gains `docs/specs/*/DRIVER`.
- [ ] `bash -n scripts/cycle.sh` passes; one suite run through `tail -3` is green.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `scripts/cycle.sh`: added `driver_stamp`/`driver_guard` helpers next to `pause_guard`; new `cmd_claim`/`cmd_release` verbs (noclobber write, PAUSE-gated, no `--commit`); `open-round`/`record-seat`/`close-story`/`judge` now parse `--stamp` and call `driver_guard` right after `pause_guard`, before any write.
- `cmd_judge` guards only when invoked as the real `judge` verb (`VERBLABEL="judge"`), not when `cmd_escalate` reuses it internally as `escalate` - keeps escalate ungated per Non-goals.
- `pause`/`resume` remove `DRIVER` when present and journal a `driver` stage line "driver released", ahead of their existing journal writes.
- `.gitignore`: added `docs/specs/*/DRIVER`.
- Verified manually (temp git repos): claim/claim-same-stamp/claim-conflict/release-match/release-mismatch/PAUSE-blocks-claim/four-verbs-gated-with-and-without-`--stamp`/pause+resume release DRIVER - all matched acceptance criteria.
- `bash tests/council.test.sh` (no `tests/council.test.sh` edits made, per Non-goals): exit 0, all scenarios `ok` including the story-11-adjacent `probe_returned`/`probe_r2m2wall`/`probe_lr31wall`/`probe_r2m9wall` checks on the current `branch` snapshot (the `eb3203a` snapshot's expected `FAIL`s are the suite's own negative control, unrelated to this story).

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
