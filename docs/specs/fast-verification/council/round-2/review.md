<!-- seat: review · model: claude-fable-5-1 · round: 2 · head: 3bb9d7d · pack: 429959fb505e · attempt: 1 · recorded: 2026-10-26T12:25:59Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-fable-5-1
SUITE: TIMEOUT 541s budget 540s

## Critical
None.
## Major
1. scripts/cycle.sh:1648 [regression] record-seat must accept `SUITE: none` when the round-only `Full suite / build` row carries no runnable command (`<fill in>` or `none`, the forms install.sh:255-262 ships to every hive and tells the owner to write), because `full_suite_row_round_only` matches the Purpose cell alone and every attempt then exits 4 MALFORMED, so the required review seat can never be recorded in such a hive - repro: `printf '## Commands\n| Full suite / build (round-only) | `<fill in>` |\n' > /tmp/c.md; bash -c 'source <(sed -n "/^full_suite_row_round_only()/,/^}/p" scripts/cycle.sh); full_suite_row_round_only /tmp/c.md; echo rc=$?'` -> `rc=0`, then cycle.sh:1648-1654 rejects the report; base: `git show 9788d68:scripts/cycle.sh | grep -c 'SUITE: none'` -> 0, record-seat recorded it.
## Minor
- tests/full-suite.sh: under this round's load (the opus seat's serial loop of council walks / telemetry install / cycle / council --quick plus an unrelated hive's close-story on the box) the run hit the budget at 541 s with 39 of 40 jobs ok and only `tests/intake.test.sh` cut (started last at ~524 s, killed at 16 s); slowest jobs cycle.test.sh 293 s, council replays 271 s, walks 246 s, seats 226 s - the worker's recorded 421 s beside one council run holds for a lighter box; the budget stays the owner's call, not a repair.
- tests/telemetry.test.sh:143 a builder that dies inside `install_cache` leaves `$ICACHE.lock` behind and every other part of the run waits 300 s and then fails with "never built" - a stale lock (older than the run, or whose holder is gone) could be reclaimed.
- Round-1 findings: Critical 1 (CLAUDE.md cap) fixed, model-profile.test.sh ok 77 s in the suite; Major 1 (latency suites under load) fixed, inject ok 22 s alone at the end; judge `SUITE: FAIL` -> BLOCK, `SUITE: none` vs round-only row and suite-timeout+RED -> repair all covered in council `--part escalate` (ok 172 s in the suite); the 16 telemetry and 11 council parts ran green in the suite.
