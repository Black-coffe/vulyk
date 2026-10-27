---
story: post-037-tails-03
spec: post-037-tails
status: done
returned: DONE
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
- Files: scripts/symbol-map.py, scripts/symbol-map.sh (usage comment), tests/symbol-map.test.sh, docs/specs/symbol-map/replay.py, new fixtures tests/fixtures/symbol-map/bash/{scripts/run-tool.sh,scripts/run-helper.sh,scripts/tool.py,scripts/helper.py,tests/fixtures/sample/use.sh} and tests/fixtures/symbol-map/mentions/**.
- (a) `sh_edges` also walks shell words on lines holding `.py`: a word ending `.py` with a `$`-prefix (`$(dirname "$0")/`, `$DIR/`, `${BASH_SOURCE[0]%/*}/`) or a literal after `python`/`python3`/`exec`/`$VAR` resolves through the existing `sh_resolve`. A `.py` input now asks for shell edges too.
- (b) `is_fixture()` filtered in `ok()`, so every section drops it; edge resolution itself is unchanged (a fixture still counts in the unique-basename fallback).
- (c) `mention_rank()` sorts path mentions before the cap. The ranking fixture's input is a dotfile (`etc/.toolrc`, no stem) so the test and the code file are not claimed earlier by the stem-word tests/importers sections and all 6 mentions reach `path mentions`.
- (d) missing blocks are moved to the front in `main()` before the cap; non-missing keep input order.
- (e) sections are built as (name, exact rows, textual paths) and rendered per mode; exact rows keep today's (uncapped) behaviour, textual rows are capped or folded to `  textual  <N> not shown`.
- Profile before (`python -m cProfile -s cumtime scripts/symbol-map.py scripts/lib.sh`, warm): top cumulative below main: `block` 0.322 s, `edges` 0.233 s (all Python and bash files parsed for a bash input), `py_edges` 0.146 s (44 ast parses, `ast.walk` 0.090 s); `sh_edges` 0.079 s, 0.061 s of it own time on the per-line regex. A cold first run was 5.3 s, all in `_io.open` (784 files, OS file cache), not fixable in the script.
- Fixes: edges are parsed per kind on first need (a bash input parses no Python, a non-Python/bash input parses nothing); `sh_edges` skips comment lines outright and runs the source regex only on lines that can hold it. Profile after: `block` 0.130 s, `edges` 0.049 s.
- Timing, median of 3 (`time python scripts/symbol-map.py <f>`, warm, this box): scripts/lib.sh 0.264 s -> 0.170 s; scripts/symbol-map.py 0.271 s -> 0.233 s.
- Replay (`.vulyk/symbol-map-replay/cases.json`, local, glob cases): case 6 lines 29 -> 35, case 8 31 -> 32, case 17 26 -> 19; totals hits 3/13 both, noise 663 -> 659. The after figures include this story's other changes (fixture exclusion, ranking, py edges), not the glob fix alone.

## Findings
