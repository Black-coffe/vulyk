<!-- seat: review · model: claude-fable-5-1 · round: 3 · head: 1452a59 · pack: 398c12ba8464 · attempt: 1 · recorded: 2026-10-29T12:28:03Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-fable-5-1
SUITE: FAIL 505s

## Critical
1. tests/full-suite.test.sh:112 [regression] the suite's own test must hold inside the parallel full suite: the check "the slow job is killed at the budget" expects `TIMEOUT [0-2]s` for a 1 s budget under the python cap (dead timeout/gtimeout stubs) and saw `TIMEOUT 3s` in `bash tests/full-suite.sh` on both measured runs (549 s with my probes beside it, 505 s idle; `full suite: 49 ok, 1 failed, jobs 12`), while `bash tests/full-suite.test.sh` alone exits 0 on the head and on the base 5e0aae1; base-side: round-2 review.md records `SUITE: ok 414s` on 860ce1c, the first commit of this range - repro: `bash tests/full-suite.sh; grep -n -A3 'slow job not capped' <logs dir>/*.log`
## Major
None.
## Minor
- scripts/portability-check.sh:307 the `case-in-subst` rule counts any shell word `case` inside a `$( )`, so `n="$(grep -c case "$f")"` and `x="$(printf "%s" case)"` are hits (planted file: 2 hits, rc 1); the tree holds none today (`portability-check: ok (81 files, 1 allowed)`), a future one needs a `# portable:` bypass
- macOS not executed here: the awk-via-ENVIRON, `(pat)`, `read_cards` and `paste -` fixes were read and driven under the BSD-awk stub, the gate's three new fixtures (each 2 hits, rc 1), `defects-check.sh` GREEN, `paperwork_only` on 4c37cd6..1452a59 (rc 0) and 5e0aae1..1452a59 (rc 1), `descope_not_in_brief` with an empty and a filled old list, and a fresh install whose CLAUDE.md is byte-identical to 5e0aae1's install.sh - the plan's "Queen re-runs macOS CI before ship" is the only run on the real target
- docs/specs/cross-platform/cross-platform-07-mac-product.md:84 the red receipt's tail shows the suite's closing red-receipt lines, not the `::error::fresh install under BSD awk` line; `red_reason` names the missing behaviour, so no staged break, but the tail alone does not show it
