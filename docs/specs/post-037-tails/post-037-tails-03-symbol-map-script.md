---
story: post-037-tails-03
spec: post-037-tails
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
---

# symbol-map: the bash-runs-python edge, no fixtures, ranked mentions, missing-first, `--exact`, measured speed

## Goal
After this story `scripts/symbol-map.py` (through `scripts/symbol-map.sh`) (a) links a `.py` that a bash script runs as `exact` in both directions; (b) never lists a path with a `fixtures` segment after a `tests`/`test` segment, in any section; (c) orders path mentions code, ADR, other docs, then the root `CHANGELOG.md`/`CLAUDE.md`/`README.md`, so the cap of 5 is no longer spent on those three; (d) prints every missing input's `## <path>` / `  ! missing` block before any other block, so it survives the 1536-byte cap; (e) takes `--exact`, which prints each section's `exact` lines and one `  textual  <N> not shown` line for the rest (the planner hand-off); (f) is profiled on a bash input and the cheap fixes the profile shows are made, with before/after figures in `## Implementation notes`. `docs/specs/symbol-map/replay.py` runs `symbol-map.py` through `sys.executable` so MSYS bash never expands its arguments. Fixtures and cases in `tests/symbol-map.test.sh` cover (a)-(e).

## Requirements
> 3. `scripts/symbol-map.sh`: a `.py` run from a bash script shows as linked; `tests/fixtures/**` never shows; path mentions list code, ADR and tests before `CHANGELOG.md`, `CLAUDE.md`, `README.md`.
> 4. symbol-map speed on a bash input is profiled and the cheap fixes made, before/after figures recorded.
> 6. The planner hand-off from symbol-map is tighter: `exact` lines plus counts of the rest.
> 7. The council's round-1 minors on symbol-map are checked and the live ones fixed (`! missing` lost past the byte cap, `replay.py` glob expansion under MSYS bash, any path under a `tests/` segment counting as a test).

## Files
- scripts/symbol-map.py
- scripts/symbol-map.sh
- tests/symbol-map.test.sh
- tests/fixtures/symbol-map/**
- docs/specs/symbol-map/replay.py

## Non-goals
- No on-disk cache, no C extension, no tree-sitter/ctags/LSP, no JS/TS/PHP edges, no git co-change, no close-time gate: all rejected in `docs/specs/symbol-map/plan.md` `## Rejected`.
- No hard time limit in any test; the figures are recorded, not asserted.
- Do not change the default (non-`--exact`) output shape beyond (a)-(d): same sections, same `exact`/`textual` words, same cap and tail line, same exit codes.
- Do not drop the "any path under a `tests/` or `test/` segment is a test" rule; the fixtures exclusion is the fix for the live case. Do not edit `docs/specs/symbol-map/replay.md` or re-score the in-sample replay.
- Do not touch `.claude/commands/*`, `.claude/agents/*`, `README.md`, `docs/command-reference.md` (story 04's files), `CLAUDE.md`, or `memory/map/*.md`.
- Create new `.py` files with the Write tool, never a Bash heredoc (CR-byte hazard on this box).

## Map slice
`memory/map/scripts.md`: `## Entry points` (`symbol-map.sh` bullet: sections, `exact`/`textual`, scope, cap 1536 at symbol-map.py:22, exit codes), `## Tests` (`tests/symbol-map.test.sh` runs on copies of `tests/fixtures/symbol-map/{python,bash}` and `replay.py`). Contracts `--exact`, `Path-mention ranking`, `Bash-runs-python edge` in `docs/specs/post-037-tails/plan.md` `## Contracts`; the 0.37 `Output` and `Languages` contracts in `docs/specs/symbol-map/plan.md`.

## Acceptance criteria
- [ ] Fixture: a bash script in `tests/fixtures/symbol-map/bash/` runs a sibling `.py` as `"$(dirname "$0")/<name>.py"`, and a second one as `"$DIR/<name>.py"` after `DIR="$(cd "$(dirname "$0")" && pwd)"`; the test asserts the `.py` appears `exact` under `imported` of the `.sh` and the `.sh` `exact` under `importers` of the `.py`.
- [ ] Fixture: a tracked file under `tests/fixtures/<x>/` inside a fixture repo that both sources the input and names its path; the test asserts no line of any section names it, and that `bash scripts/symbol-map.sh scripts/lib.sh` run in this repo prints no `tests/fixtures/` path.
- [ ] Fixture: an input mentioned by `CHANGELOG.md`, `CLAUDE.md`, `README.md`, `docs/adr/001-x.md`, `src/other.py` and `tests/test_other.py`; the test asserts the `path mentions` order code/tests, ADR, then the three root files, and that with 6 mentions the `... 1 more` tail hides one of the three root files, never the ADR or code.
- [ ] `bash scripts/symbol-map.sh <big-input> <big-input2> nope.sh` with a cap-cutting output starts with `## nope.sh` / `  ! missing`, ends with the `... N more` tail, exit 1 (the round-1 repro `scripts/lib.sh scripts/cycle.sh scripts/nope.sh` as a test case on fixture-sized inputs).
- [ ] `--exact`: on the python fixture the output shows the `exact` lines as before and one `  textual  <N> not shown` line per section that had textual lines; a section with only textual lines prints only its count line; `--help` names `--exact`; the unknown-flag path still exits 2.
- [ ] `replay.py` invokes `[sys.executable, <repo>/scripts/symbol-map.py, ...]`, not the `.sh` wrapper; the existing replay case in `tests/symbol-map.test.sh` still passes.
- [ ] `## Implementation notes` holds: the profile's top three cumulative entries before the fixes, what was changed, and the median of 3 `time` runs on `scripts/lib.sh` and on `scripts/symbol-map.py` before and after, on this box.
- [ ] `git diff --stat` touches only paths under `## Files`.

## Verification
`bash tests/symbol-map.test.sh`

## Implementation notes

## Findings
