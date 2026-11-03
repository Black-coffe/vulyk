---
story: post-045-tails-02
spec: post-045-tails
status: todo
returned:
tier: 2
worker: worker-code
wave: 2
blocked_by: [post-045-tails-01]
red: required
---

# Gate tails: refusal without a log, TIMEOUT as FAIL, missing file, PART names, the hung part

## Goal
Five fixes from the round-4 judge, all in the round gate. (1) `record-seat` for `review`, with a round-only
full-suite row and no finished `suite.log` for the round's head, exits 2 naming `cycle.sh suite` (no attempt file,
not a re-ask); the fast-verification-07 check of a reviewer-reported SUITE line goes; `lead-review.md` stops
prescribing `SUITE: none`. (2) `judge` reads a stored `SUITE: TIMEOUT` as `SUITE: FAIL` (BLOCK, repair, never
`suite-timeout`); nothing in `scripts/` or `tests/` reads `VULYK_SUITE_TIMEOUT`; old suite-timeout rows keep their
status/reopen paths; ADR-029's fallback line is rewritten. (3) `suite-parts-check.sh` exits 2 on a path that is not a
readable regular file; the card's `## Known gap` is closed. (4) Purpose-built PART names are trimmed of edge hyphens.
(5) `full-suite.sh --step K` prints `PARTS K/S: <names>` first and PART lines in completion order; a stepped step
killed at 590 s gets `timed out after 590s - no end from: <names>` and the SUITE line carries those names.
Red receipt: the record-seat refusal (ask 1) - the test fails today with the MALFORMED re-ask text. Write the other
four tests in the same run and copy their failure lines into `## Implementation notes`.

## Requirements
> so a reviewer dispatched without the gate loops into re-asks instead of a clear refusal.
> judge still turns a legacy "SUITE: TIMEOUT" review line into ESCALATE suite-timeout when no round log exists, and cycle.sh:1167 still reads VULYK_SUITE_TIMEOUT for that note, though ADR-029 says it is no longer read.
> suite-parts-check.sh exits 0 on a missing or unreadable file
> PART names built from a Purpose keep a trailing hyphen ("full-suite-round-only-").
> A stepped step killed at 590 s reports "step K failed" without naming the part that hung.

## Files
- scripts/cycle.sh
- scripts/suite-parts-check.sh
- tests/full-suite.sh
- .claude/agents/lead-review.md
- docs/adr/029-gate-split.md
- docs/defects/test-gate-one-long-limit.md
- tests/council.test.sh
- tests/full-suite.test.sh

## Non-goals
- Do not remove `suite-timeout` as an escalation reason, its reopen path, or `escalate --reason suite-timeout`.
- Do not change the 300 s part cap, the 590 s call cap or the 70% growth rule.
- Do not edit `.claude/workflows/vulyk-cycle.js`: its gate already runs before the seats.
- Do not rewrite old council rounds or plan.md Needs-a-human blocks of other specs.

## Map slice
memory/map/scripts.md - cycle.sh suite / record-seat / judge; memory/map/tests.md - full-suite

## Acceptance criteria
- [ ] Round-only row, no suite.log: record-seat review exits 2, stderr names `cycle.sh suite`, no review.attempt file; after `cycle.sh suite`, the same report records with the log's SUITE line.
- [ ] A review.md with `SUITE: TIMEOUT 571s budget 540s` and no log judges as a BLOCK -> RED/repair, never ESCALATE suite-timeout; `grep -rn VULYK_SUITE_TIMEOUT scripts tests` is empty.
- [ ] `bash scripts/suite-parts-check.sh /no/such` exits 2; a readable file with no PART line exits 0; `defects-check.sh` audit still `ok test-gate-one-long-limit`.
- [ ] Row Purpose `Full suite (round-only)` logs `PART full-suite-round-only ...`; two equal Purposes still get distinct names.
- [ ] A stepped fixture whose step sleeps past a lowered call cap logs a STEP note naming the unfinished part, and the SUITE line names it.

## Verification
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part seats2`
`bash tests/council.test.sh --part escalate`
`bash tests/council.test.sh --part suite`
`bash tests/full-suite.test.sh`
`bash scripts/defects-check.sh [<arg>]`

## Implementation notes

## Findings
