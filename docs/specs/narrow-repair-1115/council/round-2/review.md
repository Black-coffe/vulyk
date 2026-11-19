<!-- seat: review · model: claude-fable-5-2 · round: 2 · head: 5c370c2b · pack: e76871907df7 · attempt: 1 · recorded: 2026-11-15T23:40:41Z · verdict: PASS -->
VERDICT: PASS
SUITE: ok 180s - narrow repair round, steps 2 of 10
MODEL: claude-fable-5-2

## Critical
None.
## Major
None.
## Minor
- Round 1 blocking findings, all fixed in 264201f4..ed9d565f: the roster case now agrees with the round contract (tests/council.test.sh:4217-4223, `council:roster` ok in the log); `gate_log_round` (scripts/cycle.sh:4706) reads a no-step narrow round through the last round that ran steps, with an original and a neighbour case; one `FENCE_AWK` rule in cycle.sh, wave-check.sh, scope-check.sh, trace-check.sh and `fence_mask` in symbol-map.py, and stamp-red fences the output one backtick longer than its longest run (scripts/cycle.sh:2938).
- The round's gate re-ran step 2 only, and the repair's new cases live in steps 3, 4 and 6, so I ran them on the head, each alone under `run_capped 300`: `bash tests/council.test.sh --part round-scope` (234 s), `--part repair-scope` (99 s), `bash tests/cycle.test.sh --part red` (139 s), `--part gates` (23 s), `bash tests/symbol-map.test.sh` (138 checks): all exit 0; `bash scripts/defects-check.sh`: GREEN, 10 blocking checks.
- scripts/symbol-map.py:347 (ask 5) a script a test runs only inside a quoted command substitution (`out="$(bash scripts/trace-check.sh docs/specs/x)"`) is still no `exact` hit: `bash scripts/symbol-map.sh --exact scripts/trace-check.sh` lists no exact test, and the same holds for scripts/defects-check.sh, scripts/suite-parts-check.sh, scripts/hives-behind.sh, .claude/hooks/context-guard.sh and .claude/hooks/top-model-brief.sh (6 of 52 scripts and hooks; the four files the opus seat named in round 1 are exact now).
- scripts/symbol-map.py:445 the new "via a bash wrapper" rule makes every test that sources scripts/lib.sh an `exact` test of scripts/run-capped.py (2 exact tests on the base, 14 on the head), so `--fill-tests` on a story naming that file would add all 14 and a row for each.
- Story narrow-repair-1115-06 (`red: required`): the mark and the `## Red receipt` stand, and the tail shows the missing behaviour (close-story exit 4, "defect card dg fails on dfx/defects/dg.terms"), not a staged break; it covers the ask 9 case only, the last re-stamp.
