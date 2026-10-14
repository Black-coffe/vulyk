---
story: top-model-pin-01
spec: top-model-pin
status: done
returned: DONE
tier: 1
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# The gate-model pin comes from the constitution, and --floor judges it

## Goal
`constitution_pin()` reads one file, the constitution: `CLAUDE.vulyk.md` when it exists, else `CLAUDE.md`. The
`--floor` mode passes the resolved gate model through `below()` when a constitution pin or `VULYK_TOP_MODEL` decided
it. The resolver's header and `docs/model-cascade.md` say where the pin lives. `tests/telemetry.test.sh` holds the
original case and its neighbours.

## Files
- scripts/top-model.sh
- tests/telemetry.test.sh
- docs/model-cascade.md
- docs/defects/framework-fix-skips-live-hives.md
- docs/defects/README.md

## Non-goals
- Do not anchor the regex to a line shape or rewrite the constitution's `TOP_MODEL` sentence: the file choice closes
  the reported case.
- Do not swap a below-floor pin for `auto` or `opus` at resolution: `--floor` reports it.
- Do not edit any hive, and do not touch `lib.sh` `model_below_floor` (it classifies the ID correctly).

## Map slice
memory/map/scripts.md (`top-model.sh`)

## Acceptance criteria
- [x] Sidecar hive, `CLAUDE.md` with the prose line `` `TOP_MODEL = claude-opus-4-8` (per constitution) `` and
      `CLAUDE.vulyk.md` with `` `TOP_MODEL = auto` ``: `--explain` says `decided by: plan`, `--floor` exits 0 (today:
      `decided by: constitution`).
- [x] Sidecar hive whose `CLAUDE.vulyk.md` pins `fable`, `CLAUDE.md` without a pin, an unknown plan: the resolver
      prints `fable` (today: `opus`).
- [x] `CLAUDE.vulyk.md` pins `claude-opus-4-8`: `--floor` exits 1 with
      `below floor: gate model (constitution) = claude-opus-4-8 is opus 4.8, floor 5.5`.
- [x] `VULYK_TOP_MODEL=claude-sonnet-4-5`: `--floor` exits 1 naming `gate model (env)`.
- [x] A single-file hive (`CLAUDE.md` only) pinning `fable` still resolves `fable`, `--explain` naming `CLAUDE.md`.
- [x] Every existing case in `tests/telemetry.test.sh` stays green.
- [x] The owner's correction of 2026-10-14 (the fix does not reach a hive on an old version by itself) is a `text`
      card `docs/defects/framework-fix-skips-live-hives.md` with the quote verbatim (hive name as `<hive>`) and a
      README row; `bash scripts/defects-check.sh` stays green. The affected hive got its one-line fix the same day.

## Verification
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- `constitution_pin()` picks `CONST_FILE` (`$ROOT/CLAUDE.vulyk.md` if it exists, else `$ROOT/CLAUDE.md`) and greps
  that file only; the `REASON` names `${CONST_FILE##*/}`.
- In `floor`, one `below "gate model ($SOURCE)" "$MODEL"` when `$SOURCE` is `constitution` or `env`; a plan-chosen
  alias is never below (`model_below_floor` judges aliases only for an unreleased floor or an old Claude Code, which
  the frontmatter lines already report).
- The tests reuse the `FLOORHIVE` fixture before the line that pins `worker-code.md` below the floor; a small runner
  shared with `floorcheck` keeps the clean env in one place.
- Built 2026-10-14: `CONST_FILE` is set once before `constitution_pin()`; the `--floor` gate line sits right after the
  env loop. `tmrun` in the test carries the clean env for both `--floor` and the resolver, and also points
  `USERPROFILE` at the empty home: without it the resolver found the real profile through the Windows fallback and
  read a Max plan, which made the "sidecar pin honoured" case pass on the old code too.
- Red first: the new block run against the old `top-model.sh` failed 7 of 10 (the 3 that pass guard what already
  worked: a clean `--floor`, the single-file pin and its `--explain`); against the fix, 10 of 10. Full suite: 490 checks,
  0 failed. The `--help` range moved to lines 2-42 with the longer header.
- The affected hive's triggering line was removed there the same day (one commit on its current branch, not pushed).
