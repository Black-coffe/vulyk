---
story: post-045-tails-02
spec: post-045-tails
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 2
blocked_by: [post-045-tails-01]
red: required
red_reason: record-seat review without suite.log must exit 2 naming cycle.sh suite
red_verified_at: 2026-11-03T13:10:04Z 8509b62cd7793174b858190cdc038a6446f84a22228aa14114752de3eeee9f1b
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
`bash scripts/defects-check.sh`

## Implementation notes
- Ask 1, `scripts/cycle.sh` `cmd_record_seat_review`: the gate check comes first. With a round-only full-suite row and no finished log keyed to the round head, it exits 2 with `no suite.log for round N at head H - run cycle.sh suite <spec> first, then record the same report again`. No attempt file is written; `advance --ingest` stops on it (not 4, so it is not a re-ask). The fast-verification-07 block checking the reviewer's own SUITE line is gone. `lead-review.md` now says to write no SUITE line when there is no log.
- Ask 2: `judge` reads `^SUITE: (FAIL|TIMEOUT)` as the reviewer's BLOCK (note `review PASS with SUITE: TIMEOUT`). Gone: `suite_secs`/`suite_budget`, the `suite-timeout` branch of the verdict rule, its note and its `- suite:` Needs-a-human line. `escalate --reason suite-timeout`, `escalate_reruns_round` and the status/reopen paths are untouched. Old-row reopen tests now build the row by hand (`legacy_suto_row`). ADR-029 Consequences was rewritten.
- Ask 3: `suite-parts-check.sh` exits 2 with `suite-parts-check: no such file: <path>` when the path is not a readable regular file. Every caller passes a file that exists (cycle.sh: `suite_cut_names`, the step tmp; full-suite.sh: `$pl`). The card's `## Known gap` got a dated closing line.
- Ask 4: `part_slug` in `cmd_suite` trims edge hyphens; the duplicate count uses the same function, and a duplicate becomes `<name>-K`.
- Ask 5: with `--step K`, `full-suite.sh` prints `PARTS K/S: <names>` first, then polls the `.rc` files once a second, so PART lines come out in completion order. The `fail=` summary keeps job-list order (an existing check, `fail=hang,bad`, holds it). A job that dies with no rc file counts as `1 0`, so the loop never waits forever. The job subshell's stdout goes to /dev/null, so a killed step does not wait on it. In `cmd_suite`, a stepped step at its cap writes `timed out after <cap>s - no end from: <names>`, and `suite_verdict` puts `step K/S no end from: <names>` into the SUITE line. New `VULYK_STEP_CAP` can only lower the 590 s call cap (clamped, for tests).
- Red receipt re-stamped once, with the owner's choice («Перештамповать от базы»). After the first stamp, two lines of the sealed test proved wrong: rlog3 (seats2) still expected the old MALFORMED for a log keyed to another head, and the hung-part case expected `step 1` where the SUITE line has always said `step K/S`. Steps taken: implementation saved as a patch and reverted to base, the two lines fixed, stamp-red run again (red on ask 1; impl hash 95e9be… equals the first stamp, i.e. the base), the patch applied back.
- Red lines before the implementation: escalate `::error::record-seat review without suite.log must exit 2 naming cycle.sh suite - SUITE: none: exit=4 ... MALFORMED`; full-suite.test `::error::--step K must print PARTS K/S: <names> first - got: PART mark ok 0s cap 300s`, `::error::PART lines must come in completion order - got: PART slow ok 3s cap 10s|PART ok ok 0s cap 10s`, `::error::a missing file -> exit 2 - exit 0, want 2`; suite part `::error::suite plain cap` / `suite plain ok` / `suite split rows` / `suite empty row` (trailing-hyphen names), `::error::suite hung step: the part that never ended must be named - ... step 1/1: ok 31s`.
- `## Verification` line `bash scripts/defects-check.sh [<arg>]` (the cell copied verbatim at plan time) cannot run: bash reads `<arg>` as a redirect. It is now `bash scripts/defects-check.sh` (audit), which the cell admits as zero arguments. wave-check passed the verbatim copy as a byte match.
- Not checked: the Workflow driver (`vulyk-cycle.js`) is not edited (non-goal). Its gate runs before the seats, so the new exit 2 can only fire there if the gate was skipped.

## Findings

## Red receipt
- command: bash tests/council.test.sh --part escalate
- exit: 1
- tests: 8509b62cd7793174b858190cdc038a6446f84a22228aa14114752de3eeee9f1b (tests/council.test.sh, tests/full-suite.test.sh)
- impl: 95e9be2358ff1f4d4a858f1100d4b096bea7c539313ad6285c71d4453d408045
- stamped: 2026-11-03T13:10:04Z

```
escalate --reason suite-timeout passes the usage check
  ok    escalate --reason suite-timeout -> exit 6, row reason suite-timeout
open-round: the court's reduction is committed inside the worktree - clean status, HEAD:plan.md no longer resolves, stays inside the court (R15)
  ok    the court's orientation git status is clean
  ok    HEAD:docs/specs/courtred1/plan.md no longer resolves inside the court
  ok    the main repo's HEAD carries only open-round's own commit - the court's reduction commit stayed inside the court
open-round: a path that fits the hive but passes MAX_PATH inside the court still builds a clean court (Windows: Filename too long)
  ok    open-round builds the court
  ok    the long-path file is checked out in the court
  ok    and the court's reduction left its status clean
```
