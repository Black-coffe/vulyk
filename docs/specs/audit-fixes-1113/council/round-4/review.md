<!-- seat: review · model: claude-fable-5-2 · round: 4 · head: 278706ec · pack: c204ad9ef3c7 · attempt: 1 · recorded: 2026-11-14T08:34:27Z · verdict: PASS -->
VERDICT: PASS
SUITE: ok 1183s
MODEL: claude-fable-5-2

## Critical
None.
## Major
1. .claude/hooks/owner-guard.sh:13 [unanchored] carried from rounds 2 and 3 unchanged (the diff does not touch the file): the header must name every shell form the plan.md rewrite check (owner-guard.sh:435) leaves open, or the check must cover them (card safeguard-bypassable-or-late) - repro and base evidence: Major 1 of docs/specs/audit-fixes-1113/council/round-2/review.md.
## Minor
- Round 3's blocking finding is fixed: tests/telemetry.test.sh:1956-2171 splits `wiring` into `wiring` and `wiring2` over one shared fixture block, the cap and the 70% line are untouched, and the round-4 log has `PART telemetry:wiring ok 126s` and `PART telemetry:wiring2 ok 147s` inside step 6 (`STEP 6/10: ok 182s`); `bash scripts/suite-parts-check.sh docs/specs/audit-fixes-1113/council/round-4/suite.log` exits 0. The diff moves lines and removes no assertion; the one rewritten check (line 2009, `--check ... writes nothing`) compares against a copy taken right after `--check` and can still fail. `bash scripts/defects-check.sh` is GREEN (10 blocking checks). Story 16 is `red: none` in its approved version (the `revised` commit 8827f063), so no red receipt is due.
- tests/telemetry.test.sh:2132 run as `--part wiring2`, the `tgt` row of the guard loop now reads a fresh install; at the base it read `$TGT` after the old-form rewire upgrade, so the matcher and `onFailure` of the three guard entries after a rewire are asserted only in a whole-file run, which the gate does not make.
- docs/specs/audit-fixes-1113/council/round-4/suite.log three parts of step 6 still sit close to the 210 s line (`telemetry:install-xp2` 182 s, `install-xp` 178 s, `install` 173 s); a slower run can cut one of them as it cut `wiring`.
- docs/specs/audit-fixes-1113/audit-fixes-1113-06-install.md:113 and audit-fixes-1113-10-install-wiring-and-allow-list.md:87 still name `--part wiring` for the M1 and W1 checks that now live in `wiring2` (closed stories, paperwork only).
