---
story: fable-review-remainders-08
spec: fable-review-remainders
status: done
returned: DONE
tier: 3
worker: worker-code
tracer: false
wave: 4
blocked_by: [fable-review-remainders-06, fable-review-remainders-07]
model: opus
---

# The driver's third reason comes from the verbs, not from the report's prose (round-1 critical 1, major 3, minor 7)

## Goal
`.claude/workflows/vulyk-cycle.js` stops grepping a return for `STATUS:` / `VERDICT:` (story 07's `MARKER`, `:30-33`, and the decision at `:184-193`). ADR-006's invariant is restored: every non-empty worker return goes to `close-story`, and `worker returned no report` is what the driver calls a `close-story` exit 4 whose `error` is `returned: missing` - the channel ADR-006 built for a worker that returned text without finishing. For a seat or the reviewer the string is logged when `record-seat` answers exit 4 on a non-empty return, before the existing single re-ask. `tests/driver.test.sh` proves it: story 07's `STATUS: DONE` / `VERDICT: PASS` fixture prepends come back out (the `:190-199` scenario is again "the driver did not read the prose"), story 06's four content-check scenarios (v2, v3, x2, y3) are rewritten to reach the string through the clerk stub, and the attempt-2 `--file` path is asserted once (minor 7).

## Requirements
> Драйвер различает три причины провала диспатча - исключение (`worker threw`), пустой ответ (подозрение на кэп ходов, с именем агента и его maxTurns), текст без отчёта - для воркеров, сидов совета и ревьюера; tests/driver.test.sh это проверяет.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh

## Non-goals
- Do not amend ADR-006 or ADR-001 C11 and do not touch `.claude/agents/worker-code.md:18` / `worker-test.md:21`: their sentence ("`close-story` and the driver read this key, never your report's prose") becomes true again by this story; editing it is the rejected route.
- Do not edit `.claude/commands/vulyk-build.md` (story 09, same wave).
- Do not change the other two reasons, `CAPS`, the `{threw}` catch, K2's stop shape, the two-miss rule, the retry prompt, `foldReviews`, or the `--file`-then-heredoc record flow (C2). The empty case is still classified before any clerk call and still goes to `record-seat` for a seat.
- No `test -s`, no reading the story file, no new clerk call: the reason is read from the JSON the clerk already returns (`exit` and `error`), which is not prose parsing (ADR-001 D2: "the last stdout line is always one JSON object so no driver parses prose").
- A `close-story` exit 4 with any other `error` (`returned WALL`, `returned NEEDS_CONTEXT`, a verification line) keeps today's handling: the `error` text is the miss reason as before.
- Do not add a Tier 4 fold scenario; the fold's `record-seat` exit 4 keeps today's handling with no new log line.
- Write `returned: DONE` as your last edit; never write `status:`.

## Map slice
`plan.md` C3 as amended by the 2026-09-14 round-1 delta (`## Plan deltas`, second entry) · `council/round-1/review.md` critical 1, major 3, minor 7 · `docs/adr/006-worker-status-channel.md` (the contract table, "The fallback driver under this decision", "How the tests prove it") · `recon/driver-and-cycle.md` §"Driver" · story 03 and 07 `## Implementation notes` (where `reasonFor`, `MARKER`, `record` live) · story 06 `## Implementation notes` (scenarios v2, v3, x2, y3 and the fixture list).

## Acceptance criteria
- [ ] No regex over a dispatch return exists in the driver other than the empty/whitespace test: `grep -n 'STATUS:\|VERDICT:' .claude/workflows/vulyk-cycle.js` finds only comments, if anything.
- [ ] A worker return that is a non-empty string always reaches `close-story` (one clerk call), whatever its text. Exit 4 with `error === 'returned: missing'` sets `lastError` = `worker returned no report`, one `log()` line of that text, and `stop.error` = the same string after a second such miss; `close-story` is called once per miss. Exit 4 with another `error` behaves exactly as before this story.
- [ ] A worker return without any `STATUS:` line and a clerk answering `{ok:true}` closes the story with no miss and no `returned no report` line (ADR-006's third driver scenario, now again what the suite asserts).
- [ ] A seat or single reviewer whose return is non-empty and whose `record-seat` (the `--file` try or the heredoc fallback) answers exit 4 logs `seat <seat> returned no report` / `reviewer returned no report` once, then re-asks once as today; an empty return logs only the `returned empty` line and no second reason.
- [ ] `tests/driver.test.sh`: the seven story-07 marker prepends are removed and every pre-existing scenario passes unchanged; v2/v3/x2/y3 reach their string through the clerk stub (`{ok:false,exit:4,error:'returned: missing'}` for the worker, `{ok:false,exit:4,error:'MALFORMED'}` for a seat/reviewer); the mixed scenario (`''` then a non-report) stops with the second miss's string and calls `close-story` once; the record call after an exit 4 re-ask is asserted to carry `--file .vulyk/reports/demo/round-1/sonnet.attempt-2.md`.
- [ ] `bash tests/driver.test.sh` exits 0 on the branch; `## Implementation notes` names the lines where the two reasons are derived and which scenarios changed.

## Verification
`bash tests/driver.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `.claude/workflows/vulyk-cycle.js`: `MARKER` deleted; `reasonFor` (`:27-39`) now returns null for any non-empty string, and `NO_REPORT(who)` (`:32`) is the shared string. Worker reason derived at `:188-196` from `close-story`'s exit 4 + `error === 'returned: missing'`; seat/reviewer reason at `:247-250` from `record-seat`'s exit 4 on a return the classifier called usable (`reason === null`), logged before the existing single re-ask.
- `tests/driver.test.sh`: the seven story-07 prepends (lines 193/219/240/256/324/342/418) reverted; v2/v3 rewritten around a `{exit:4,error:'returned: missing'}` clerk stub (v2 asserts two close-story calls, v3 exactly one); x2/y3 rewritten around a shared `malformed` `record-seat` stub and now assert the re-ask; new x3 proves an empty seat return + exit 4 logs only the turn-cap reason; scenario (c) now asserts ADR-006's third scenario (no `STATUS:` line, close-story ok, nothing logged); scenario (z) asserts `--file .vulyk/reports/demo/round-1/sonnet.attempt-2.md` (minor 7).
- Decision: `foldReviews`' `^VERDICT:` regexes (`:104-113`) stay - the non-goals forbid touching them, so AC1's grep still finds those four lines; they parse a *review report the driver itself folds*, not a dispatch return's liveness.
- Surprise: `git diff` also shows `.claude/commands/vulyk-build.md` and `plan.md` as modified; neither was touched by this story (story 09 shares the wave, plan.md was dirty at branch state). `scope-check.sh` flags them for that reason.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
