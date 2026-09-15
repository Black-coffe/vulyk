<!-- seat: review · model: unknown · round: 2 · head: 8b80941 · pack: 3a929636825c · attempt: 1 · recorded: 2026-09-15T18:43:03Z · verdict: PASS -->
VERDICT: PASS

Reviewed: branch vulyk/driver-hardening at 8b80941 vs base b74e13c (29 files), with the round-2 focus on the repair stories 06, 07, 08 over the round-1 findings. Scope: every touched file is named by a story (06: scripts/cycle.sh, tests/council.test.sh - lib.sh left untouched as its notes say; 07: .claude/workflows/vulyk-cycle.js, tests/driver.test.sh; 08: the four docs) or is cycle paperwork (story files, plan.md, journal.md, ROUND, scope.jsonl, anomalies.jsonl, council.jsonl, round-1 seat files) - no Law 3 violation. No docs/wiki/ exists; invariants checked against ADR-001/006/009 and memory/map/scripts.md Gotchas (taint stays path-anchored, the whitelist stays exact/one-level, cmd_claim same-stamp re-claim exits 0 at cycle.sh:2099-2102 so A9's track assignment holds). Ran only: the C4 revised regex directly against 13 name shapes (demo-14-title.md, docs/specs/demo/demo-14-title.md, demo/demo-14-title, a backslash path and a backticked name -> taint; bare demo-14, demo-14-title, demo-140.md, demo-14-title.mdx, xdemo-14-title.md -> clean) - it matches C4 revised exactly. Suites not re-run. Every round-1 Major (1-4) and Minor (5-12) is closed by the diff; the remaining findings are all new and minor.

## Critical

None.

## Major

None.

## Minor

1. E:/Projects/vulyk/scripts/cycle.sh:1621-1627 - plan - The self-mark journal line is appended before `git commit`; if the commit fails (cycle.sh:1653-1658, exit 2 `git commit failed`) the line stays and the retried attempt journals it a second time - C3 revised only promises "every exit-4 path leaves journal.md untouched". Condition: the self-mark line is appended once per closing story across every failing exit, including the commit-failure path.

2. E:/Projects/vulyk/scripts/cycle.sh:1626 with E:/Projects/vulyk/scripts/scope-check.sh:65-79 - plan - close-story leaves `docs/specs/<slug>/journal.md` uncommitted after a self-marked close (staging is scoped to files_of + story + scope.jsonl + anomalies.jsonl), and scope-check drops only the story file and anomalies.jsonl from its measurement, so the next story closed in the same wave records journal.md as an out-of-scope change in memory/stats/scope.jsonl (not a stop: close-story does not gate on scope-check's result). Condition: a sibling story's scope row is not polluted by the cycle's own journal line.

3. E:/Projects/vulyk/docs/specs/driver-hardening/plan.md:53 (C1 accepted cost) and E:/Projects/vulyk/docs/adr/011-driver-hardening.md decision 1 - plan - The accepted cost is understated: a close-story that really exited 4 behind a garbled relay is recovered as ok:true, `attempts` is not incremented (vulyk-cycle.js:238-256), and on the next iteration `wave_stories` still lists the story, so the driver dispatches the worker again as a fresh first attempt (sonnet, no retry note) before meeting the real exit 4 - one whole extra worker run and a two-miss bound of three dispatches, not merely a delayed exit 4. Condition: the record states the extra worker dispatch as the cost, or the close-story recovery counts the attempt.

4. E:/Projects/vulyk/.claude/workflows/vulyk-cycle.js:117 - plan - The recovery log line embeds the full `cmd`; for the inline-heredoc record-seat fallback (vulyk-cycle.js:266-270) that is the entire seat report plus the `VULYK_<stamp>_...` delimiter, in the driver's log. Story 02's identical-retry log line has the same shape. Condition: the log names the verb and its leading arguments only, never a heredoc body.

5. E:/Projects/vulyk/.claude/workflows/vulyk-cycle.js:119-121 - plan - A garbled `judge` whose real exit was 6 (ESCALATE) is recovered as ok:true with `status.next: escalated`, so the run returns the plain status object via TERMINAL instead of the `{...st, stop: {verb: 'judge', exit: 6}}` shape the direct path returns (vulyk-cycle.js:307); the Queen reads `next: escalated` either way. Condition: the record says the two return shapes differ on this path, or the recovery preserves the stop shape.

6. E:/Projects/vulyk/docs/adr/001-cycle-state-contract.md:93-95 - plan - The first amendment bullet labels verb-carried status "ADR-011 decision 1"; in ADR-011 that is decision 5 (decision 1 is the clerk retry). Story 08 fixed the taint bullet's label only. Condition: every ADR-001 pointer names the ADR-011 decision it describes.

7. E:/Projects/vulyk/docs/adr/011-driver-hardening.md decision 2 - plan - "Built" does not record the `-uall` change to open-round's dirty-tree listing (C2 addendum, cycle.sh:1865), though CHANGELOG does; story 08's acceptance named CHANGELOG only. Condition: ADR-011 decision 2 records the listing change and its rejected alternative (a directory form in the predicate).

8. E:/Projects/vulyk/docs/adr/011-driver-hardening.md decision 3 - plan - "Built" says a dirty result "journals ... and falls through", i.e. journal at the branch; as built (C3 revised, cycle.sh:1621-1627) the line is written once after verification is green, with `next: build:<wave>`. Story 08's acceptance named C1 and C4 revised only. Condition: decision 3 states the C3 revised placement and `next`.

9. E:/Projects/vulyk/memory/map/cycle.md:77-78 - plan - The map still says taint includes "a story id `<slug>-NN`"; librarian-owned, no story names it. Condition: the map is refreshed after merge so it matches ADR-011 decision 4.

10. E:/Projects/vulyk/tests/driver.test.sh scenario (ao) - plan - Asserts `Paused` on a recovery `status` line carrying `exit: 3`, a shape `cmd_status` never emits (`status` is pause-exempt and its object has no `exit` key, cycle.sh:469). Harmless and it does exercise the code path; the story's acceptance asked for it. Condition: the case (or its acceptance line) says the input is synthetic.

## Verification claims checked

- Story 07 "with only vulyk-cycle.js reverted to HEAD, each of the six new scenarios prints its own FAIL line": (ak)-(am) assert the verb is sent once and `calls[3]` is the status prompt - false under identical re-dispatch; (an) asserts `verbsOf === 'claim,status,judge,status,release'` - old code sends judge twice; (ao) same verb list - old code pauses on the second judge; (ap) asserts `next === 'green'` with a poll between - the pre-06 carriedStatus accepted the envelope and returned `next: error`. Claim holds per scenario.
- Story 06 C2 addendum case: the fixture untracks the only tracked learnings file and commits, so `memory/learnings/` collapses to `?? memory/learnings/` without `-uall`, which is_paperwork_path rejects - the `! grep 'working tree not clean'` assertion would fail on the pre-06 guard; the `sub/x.md` case proves the one-level rule survives `-uall`. Real assertions.
- Story 06 C3 revised cases assert exactly one self-mark line, `next: build:2` from the wave frontmatter, byte-identical journal on exit 4, and exit 2 with no new line after a green close - real; the commit-failure path (finding 1) is the one exit not covered.
- Story 06 C5 addendum: `c5_check` asserts `.status | has("ok") | not` on every carried object, and the probe stubs `cmd_status` (exit 1 + envelope) and asserts the byte-exact five-key line - real; the probe runs in the suite's scratch copy (cd "$T", council() = bash scripts/cycle.sh), not in the repo.
- Story 08: ADR-011 decision 4's regex and examples match cycle.sh:1184 byte for byte; the decision-5 key list matches cmd_status's printf at cycle.sh:469 (no leading `status,`); worker-code.md:18 and worker-test.md:21 carry the identical sentence; CHANGELOG lines name the status re-dispatch, `-uall` and `<slug>-NN-<title>.md`.
