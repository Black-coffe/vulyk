<!-- seat: review · model: unknown · round: 1 · head: 8db9d3d · pack: 69dc98d46660 · attempt: 1 · recorded: 2026-09-24T08:05:41Z · verdict: BLOCK -->
VERDICT: BLOCK

Reviewed: branch vulyk/convergent-judge at 8db9d3d against base d13411f (merge-base with main). Stories 01-04, brief asks 1-5. Only `bash -n` was re-run on the two touched scripts (clean); the council/cycle/driver/telemetry suites are on the record from `close-story` and nothing in the diff made a specific case suspicious enough to replay.

Scope: every code file touched is named by a story. `memory/stats/scope.jsonl` and `memory/stats/anomalies.jsonl` ride in the story commits but both are in `is_paperwork_path` (`E:\Projects\vulyk\scripts\lib.sh:45-46`), hook-written - not a Law 3 violation. `.claude/workflows/vulyk-cycle.js` was deliberately left out of every story; two findings below come from that choice.

## Critical

None.

## Major

1. `E:\Projects\vulyk\scripts\cycle.sh:1999-2007` and `:2014` - `[unanchored]` - plan - With `tier_ceiling` returning 1 at Tier 1 and 2 at Tier 2, the existing "a STALE fold still counts toward the ceiling" rule (`write_stale_row` then `NEXTN -le CEILING`, and `ROUND_COUNT -lt CEILING`) means a Tier 1 spec whose round 1 goes STALE (one commit on the branch after a seat filed) is written ESCALATE `ceiling` with no verdict ever recorded, and a Tier 2 spec spends its whole repair budget on one STALE + one RED; nothing in plan A1, `## Plan deltas` or the ADR amendment says a folded round burns a tier's only round. Condition: a STALE-folded round must not consume a tier's judged-round budget, or the plan/ADR must record that it does and why. Severity assumes a commit landing during an open round after a seat has reported - zero STALE rows in VULYK's own 13-row ledger, so this bites in hives where the owner edits mid-round, not here.

2. `E:\Projects\vulyk\.claude\workflows\vulyk-cycle.js:317-324` - `[unanchored]` - plan - The workflow driver's repair prompt still asks `queen-planner` for "one story per critical and per major finding whose fix is local", with no anchor condition, while `.claude/commands/vulyk-build.md:101` (the fallback driver) now says an `[unanchored]` finding never becomes a story; in an anchored BLOCK the primary driver therefore still cuts repair stories for the unanchored findings, which is the token spend ask 3 and plan A6 set out to stop. Condition: both drivers must hand the planner the same rule - stories only for `[ask N]`/`[regression]` findings, unanchored ones held for `/vulyk-ship` step 5.

## Minor

3. `E:\Projects\vulyk\scripts\cycle.sh:2026` - worker - The `reopen` section header still reads "three more rounds after ESCALATE (D6)" in the function story 01 rewrote to add `tier_ceiling`. Condition: the comment must state the tier-sized step.

4. `E:\Projects\vulyk\docs\adr\001-cycle-state-contract.md:92,264,332,361` - plan - The governing ADR now contradicts itself: `ceiling=<3|6|...>` in the ROUND row, "C = ceiling from `ROUND` (3, +3 per `reopen`)" directly above the amended D4 table, "(three more rounds" and "three RED rounds -> ESCALATE `ceiling`; `reopen` -> ceiling 6" in Consequences, while the same file's 2026-09-23 amendments describe the 1/2/3 ceiling; story 01 did not name the ADR. Condition: every ceiling statement in ADR-001 must agree with `tier_ceiling`.

5. `E:\Projects\vulyk\docs\pipeline.md:57`, `E:\Projects\vulyk\docs\architecture.md:54`, `E:\Projects\vulyk\.claude\workflows\vulyk-cycle.js:3` - plan - "the ceiling (3)", "ceiling 3 rounds" and the driver's own description string `build -> council -> repair, ceiling 3` (the banner a launched run announces - the owner's "maximum three cycles" complaint) were outside every story's file list and still say 3. Condition: no shipped doc or driver banner may state a flat ceiling of 3.

6. `E:\Projects\vulyk\scripts\cycle.sh:576-587` - plan - `review_anchor_asks` / `review_has_regression` read `[ask N]` and `[regression]` anywhere in the body after the header - a tag on a `minor` line, or the literal `[regression]` in prose ("no [regression] found"), holds a BLOCK - while the plan's `## Contracts` scopes the tag to "a list line under a critical or major heading"; the plan also handed the worker the body-wide regex, so this is the plan's own contradiction. Condition: the judge's anchor read and the contract's scope must be the same thing, stated once.

7. `E:\Projects\vulyk\scripts\cycle.sh:717` - worker - `write_escalate_row_for_round` records `review:"BLOCK"` for a report with no anchor (no downgrade), so the ESCALATE row written at the ceiling and a `judge` row for the same review disagree on `review`; the story's `## Implementation notes` mention it but the ADR row contract does not. Condition: the two row writers must apply one rule to `review`, or ADR-001 must say the ESCALATE row records the raw verdict.

8. `E:\Projects\vulyk\scripts\cycle.sh:906-909` - plan - `no-progress` looks only at round N-1's newest row, so RED ask 3 in round N-2, STALE round N-1, RED ask 3 again in round N is `repair`, not `no-progress`; plan A4 records the choice, but "the same ask RED two rounds running" (ask 2) reads naturally as two consecutive judged rounds. Condition: the comparison round must be the previous judged (non-STALE) round, or the ADR must state why a STALE fold resets the streak.

9. `E:\Projects\vulyk\tests\council.test.sh:1971-2002,2004-2050` - worker - Two named cases are untested: N-1 ESCALATE never triggers `no-progress` (story 04 non-goal; after `oreopen1`'s reopen the walk stops at "round-4 directory exists" without judging the same ask RED again), and the ESCALATE/STALE rows' `review_asks` key position (the C4 key-order assertion covers only the judge GREEN row; `noprog3` hand-writes its STALE row instead of exercising `write_stale_row`). Condition: a test must judge a round whose N-1 row is ESCALATE with a repeated ask and expect `repair`, and a test must assert the key order of a row `write_escalate_row_for_round` or `write_stale_row` actually produced.

10. `E:\Projects\vulyk\.claude\commands\vulyk-ship.md:16` - plan - Step 5 says "the newest `memory/stats/council.jsonl` row for this spec carries that note", which holds only when the downgraded round was the last one; findings of a downgraded BLOCK whose lines carry no tag at all (the `unanchr` fixture shape) are collected by neither the note clause nor the `[unanchored]` clause once a later round exists. Condition: step 5 must locate every round's row carrying `review BLOCK unanchored`, and gather that round's critical/major findings regardless of tag.

11. `E:\Projects\vulyk\install.sh:702-703` - worker - `grep -vF "$needle" "$file" > "$file.vulyktmp" || true` treats grep's exit 2 (read error) the same as exit 1 (every row seeded), then `cat` overwrites the hive's ledger with the empty temp file. Condition: a failed read must leave `council.jsonl` untouched; only a successful filter may be written back.

12. `E:\Projects\vulyk\.claude\commands\vulyk-review.md:56-57` - plan - The Tier 4 fold concatenates both reviewers' bodies, so a PASS reviewer's `[ask N]` tag anchors the other reviewer's BLOCK (story 02 notes it as surprising, plan A2 said nothing). Condition: only tags on the blocking reviewer's critical/major findings may anchor the folded BLOCK.

Coverage claims checked: story 01's "Tier 1 RED round 1 -> ESCALATE ceiling; Tier 2 RED at round 2 -> ESCALATE ceiling; reopen on Tier 2 gives 4" - each is asserted (`tceil1`, `tceil2`, `CEILING` = 4). Story 02's six cases and story 04's four cases each assert the row verdict, `review_asks`/`escalate` value and, where named, the `## Needs a human` line - not test theater. Story 03's byte-for-byte claim is a real `cmp` against the expected two-row file.
