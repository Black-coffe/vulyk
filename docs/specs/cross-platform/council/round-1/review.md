<!-- seat: review · model: claude-fable-5-1 · round: 1 · head: d5b89f9 · pack: 942d320ecef5 · attempt: 1 · recorded: 2026-10-28T22:35:12Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-fable-5-1
SUITE: FAIL 433s

## Critical
1. CLAUDE.md:76 [regression] the full suite must be green: `bash tests/full-suite.sh` fails on `tests/model-profile.test.sh:165` with `CLAUDE.md grew: 7165 B > 7162 B at baa5219` (base b7e87b7 is 7153 B and passes; the head's `bash scripts/py.sh -m py_compile` cell makes it 7165 B; the test file is untouched by the branch, and the plan budgeted only the 7168 B cap of tests/maintenance.test.sh) - repro: `bash tests/model-profile.test.sh`
## Major
None.
## Minor
- tests/telemetry.test.sh:136 `treesum` still uses `md5sum`, absent on a stock macOS: on the macOS leg both sides come out empty and every "tree unchanged" comparison passes vacuously (ci.yml's own `md5sum` sites moved to `cksum`)
- scripts/lib.sh:98 `date_epoch` rejects fractional seconds (`2026-10-15T21:49:16.612Z`) that GNU `date -d` parsed on the base, so `week_of` returns empty for such a row on the head; today only `memory/stats/watcher.jsonl` carries that shape and `week_of` reads only `anomalies.jsonl`, so nothing live breaks
- scripts/portability-check.sh:102 the `array` rule sees only the literal `"${a[@]}"` form and only files with their own `set -u` line: an embedded `"RED: ${parts[*]}"` (fixed by hand in defects-check.sh) and a file that inherits `set -u` by sourcing lib.sh (tests/mods.test.sh) pass unscanned
- scripts/cycle.sh:2021 with no cap available `run_capped` prints `running bash uncapped` to stderr once per verification line in close-story and stamp-red, where the base was silent
