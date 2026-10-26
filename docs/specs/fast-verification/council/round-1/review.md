<!-- seat: review · model: claude-fable-5-1 · round: 1 · head: 12326b3 · pack: bec80b2bffbb · attempt: 1 · recorded: 2026-10-26T09:17:17Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-fable-5-1
SUITE: TIMEOUT 541s budget 540s

## Critical
1. CLAUDE.md:66 [regression] CLAUDE.md must stay within the cap tests/model-profile.test.sh:162 enforces (its size at baa5219, 7162 B without CR): the head is 7165 B and the suite is red, the base is 7159 B and green - repro: `bash tests/model-profile.test.sh` -> `::error::CLAUDE.md grew: 7165 B > 7162 B at baa5219`; base: `git show ee3e19b:CLAUDE.md | tr -d '\r' | wc -c` -> 7159.
## Major
1. tests/full-suite.sh:93 [ask 2] the full suite must end green on the box it was measured on: at the default `--jobs` the runner's own 28-way load pushes `tests/inject.test.sh:342` and `tests/intake.test.sh` past their 200 ms wall-clock medians (748, 934 and 687 ms this run; story 03's notes record the same), so `bash tests/full-suite.sh` prints `FAIL ... bash tests/inject.test.sh` and `FAIL ... bash tests/intake.test.sh` and never exits 0 here - run the latency-asserting suites outside the contended window (serially after the rest, or at a bounded jobs count) or the runner cannot pass whole - repro: `bash tests/full-suite.sh`.
## Minor
- scripts/cycle.sh:1149 judge reads only `SUITE: TIMEOUT`; a `VERDICT: PASS` review carrying `SUITE: FAIL` is GREEN, so ask 3's "a failure is never green" rests on the reviewer's prompt alone.
- The 425 s budget basis was measured with no other seat on the box; this round's run, with the opus seat alongside, hit the 540 s budget at 541 s with 16 of 31 jobs cut (council verbs/seats/ceilings/replays/walks/advance, cycle, nine telemetry parts) - measure the budget under round conditions or `suite-timeout` fires on the reference box every round.
- Ask 1's "минуту-две" is delivered as a <= 180 s target (telemetry parts 133-168 s, council parts 45-144 s per the story notes) and `bash tests/council.test.sh --quick` (~249 s) stays an unmarked row a story may name; the shrink is in the plan's Coverage note, not under `## Descoped`.
- .github/workflows/ci.yml drops the `cycle`, `council`, `driver` and `token-report` job names; if branch protection lists any as a required check, main cannot merge until the rule names `full-suite`.
