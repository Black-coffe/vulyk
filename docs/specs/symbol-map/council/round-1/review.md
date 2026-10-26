<!-- seat: review · model: claude-fable-5-1 · round: 1 · head: fe41a19 · pack: 3fd2e984986b · attempt: 1 · recorded: 2026-10-26T20:33:59Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-fable-5-1
SUITE: ok 438s

## Critical
None.
## Major
1. .claude/commands/vulyk-plan.md:27 [ask 3] the recon run must reach every candidate file before its output goes to the planner: one call on N files stops after 1-3 blocks under the per-run 1536-byte cap, so the line must run the script once per candidate file (or re-run until no `inputs not shown` tail remains) or the cap must apply per block, and plan.md `## Descoped` is empty while story 03 `## Findings` leaves it open - repro: `bash scripts/symbol-map.sh scripts/lib.sh scripts/cycle.sh scripts/wave-check.sh scripts/model-profile.sh scripts/top-model.sh scripts/redact.sh scripts/ship-check.sh scripts/release-check.sh` prints 2 blocks and `... N more (6 inputs not shown)`; docs/specs/symbol-map/replay.md:169 records the cap cutting 8 of the 9 stories with an unfound path after 1-3 of 8-73 inputs.
## Minor
- scripts/symbol-map.py:833 a missing input whose block falls past the cap exits 1 with no `! missing` line left in the output - repro: `bash scripts/symbol-map.sh scripts/lib.sh scripts/cycle.sh scripts/nope.sh` ends with `... 9 more (1 inputs not shown)`, rc 1.
- docs/specs/symbol-map/replay.py:236 on Windows the MSYS bash expands glob arguments handed over by Python's subprocess into file lists (`tests/*.test.sh` arrives as 14 args), so the 3 of 23 local cases whose `files` carry globs get extra inputs and inflated `lines printed`; this is story 03's uninvestigated `84 > 56` finding and should be stated in replay.md or the globs escaped.
- scripts/symbol-map.py:654 every path under a `tests/` segment counts as a test, so fixture scripts such as `tests/fixtures/symbol-map/bash/scripts/run.sh` land under `tests:` of real inputs (see the `scripts/lib.sh` run above).
