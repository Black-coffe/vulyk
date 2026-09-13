---
story: autonomous-cycle-22
spec: autonomous-cycle
status: done
tier: 4
worker: worker-code
tracer: false
wave: 8
blocked_by: []
---

# The Workflow driver acts on exit codes, bounds its retries, and hands seats nothing they must not repeat

## Goal
`.claude/workflows/vulyk-cycle.js` reads every clerk result, not just `next`: a failed verb ends the run with the failure in the returned object, a malformed seat report is re-asked once with the gap named, a story whose verification stays red stops the run after two attempts, an empty seat report is still recorded, seat reports travel through a heredoc whose delimiter no seat can guess, seats receive `slug`/`round`/`court` and nothing else, a Tier 4 spec gets its second reviewer folded into the one `review` seat, and the Workflow API calls the file makes are verified against the platform docs and recorded.

## Requirements
> Workflow-скрипт + fallback в сессию

> Королева просыпается дважды: итоговый отчёт (мерж) или эскалация.

> the Workflow driver must act on each verb's exit code — escalating on 6 with a record on disk, surfacing 2 as a stop rather than a retry, re-asking a seat once on 4 — and `escalate` must be able to record an escalation for a round that was never dispatched.

> The two drivers must apply the same bound on a story whose verification stays red

> The same loop fires when a seat returns an empty report

> A blind seat's prompt must not contain a string C5 forbids it to repeat

> A seat report must reach `record-seat` through a channel that cannot terminate early (a file the clerk writes, or a per-call unique delimiter that `record-seat` refuses inside the body)

> the heredoc delimiter is per call and unguessable by the seat — `VULYK_<stamp>_<seat>_<attempt>`, where `stamp` is the run's shell-provided `args.stamp` (Workflow) or `date -u +%s` taken once at loop start (fallback) and never appears in any seat prompt

> The Workflow driver must dispatch the Tier 4 second reviewer and fold its verdict as `/vulyk-review` step 3 and the fallback's dispatch row do

> The Workflow API surface the driver uses (`parallel` over an array of thunks, `pipeline(list, f, g)` with a 3-arg shape, `phase()`, `agent()` options `agentType`/`model`/`effort`/`phase`) must be verified against the platform docs and the outcome recorded

## Files
- .claude/workflows/vulyk-cycle.js

## Non-goals
- No verdict, ceiling or staleness logic and no round counter: the per-story attempt map is a retry bound inside one run, nothing on disk depends on it, and it holds story file paths only.
- Do not read files, git or seat reports for content; the only prose read is the first line of a review report (`VERDICT: PASS|BLOCK`, the token story 24 makes mandatory) to fold two reviewers into one.
- Do not call `escalate` on `open-round` exit 6 — after story 21 `open-round` writes the record itself; the driver's job is to stop.
- Do not use `resumeFromRunId`, `Date`, `Math.random`, filesystem or shell APIs; the delimiter comes from `args.stamp` plus a counter.
- Do not edit the command files (story 23) or `cycle.sh`.

## Map slice
`.claude/workflows/vulyk-cycle.js` — `clerk()`, the `for(;;)` loop, the `build:`, `dispatch:`, `judge`, `repair` branches, `SEAT_AGENT` · `plan.md` delta 6: R5, R6, R9, R11, R12, R14 and the contract-amendments line (C3 `tier`, C11 `second_model`) · `## Contracts` C2 (last-line JSON, exit codes), C3, C11 · ADR-001 D2 "The Workflow driver" · `brief.md` `## Evidence` line 3 (the platform docs the API check reads).

## Acceptance criteria
- [ ] Every clerk object is checked: `ok:false` → `return { ...st, stop: { verb, exit, error } }` and the run ends — except `record-seat` exit 4 (re-dispatch that one seat once with the original prompt plus "Your previous report was rejected: <error>", record again, then continue whatever the result) and `close-story` exit 4 (first time: continue; second time for the same `file` in this run: `return { ...st, stop: { verb: 'close-story', file, error } }`).
- [ ] A seat's report is always sent to `record-seat`, empty or not (the `report &&` guard is gone).
- [ ] The heredoc delimiter is `VULYK_${args.stamp}_${seat}_${attempt}`; the string `EOF` no longer appears as a delimiter; `args.stamp` appears in no seat prompt.
- [ ] Seat prompts are built from `st.slug`, `st.round`, `st.court` only; the `lead-review` prompt carries `st.round_dir`, `st.spec`, `st.branch`, `st.head` and the same three pointers `/vulyk-review` step 3 gives (the spec directory with its stories and plan, the branch to diff, ADR-001).
- [ ] `args` are `{ spec, top_model, second_model, stamp }`; when `st.tier === 4` the `review` seat is `parallel` of `lead-review` at `args.top_model` and `lead-review` at `args.second_model`, folded to `VERDICT: BLOCK` if either first line says BLOCK, recorded once as `VERDICT: <folded>` followed by both reports; at other tiers one `lead-review` as today.
- [ ] `parallel`, `pipeline`, `phase`, `agent` (options `agentType`, `model`, `effort`, `phase`) and `log` are checked against the Workflow page of the platform docs the brief's Evidence names; each call is fixed to the documented shape; `## Implementation notes` records the URL, the date, and what changed — or that the docs were unreachable and the calls were left as they are.
- [ ] The forbidden-string grep of story 06 is still clean (`GREEN`, `RED`, `stale`, `paperwork` absent outside comments; `ceiling` only in `meta.description`); `grep -c 'worker-code'` = 0; the file stays under ~160 lines; `node --check .claude/workflows/vulyk-cycle.js` passes where node exists — recorded, not gated.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- Every clerk() result off briefed/branch/open-round/judge is checked; `ok:false` throws a `Stop` carrying `{...st, stop:{verb,exit,error}}`, caught once at the bottom (mirrors the existing `BadLine` pattern) instead of a `return` at each of the four call sites.
- `record-seat` exit 4: re-dispatch the same seat once via `dispatchSeat(seat, st, note)` with the rejection appended, record again, and never check the second result - matches "continue whatever the result" verbatim.
- `close-story` exit 4: a top-level `attempts` Map (story file -> count) persists across loop iterations; first failure continues (story stays open, next status poll re-routes it), second failure for the same file throws `Stop` with `{verb:'close-story', file, error}` (no `exit` key - distinct shape from the generic case).
- Heredoc delimiter is now `` `VULYK_${stamp}_${seat}_${attempt}` `` (attempt 1 then 2 on retry); literal `EOF` delimiter removed entirely; verified by grep (none left) and that `stamp` appears nowhere in `seatPrompt`/`reviewPrompt`.
- Blind seat prompt trimmed to slug/round/court (dropped `round_dir`, which was leaking to council seats before this story - R9); `reviewPrompt` gained `round_dir`, `spec`, `branch`, `head` plus prose naming the same three pointers `/vulyk-review` step 3 gives.
- Tier 4: `dispatchSeat` runs `lead-review` twice in `parallel` (`top_model`, `second_model`) when `st.tier === 4`, folds via `isBlock()` (first line only, `^BLOCK\b` or `^VERDICT:\s*BLOCK\b`) to `VERDICT: <folded>\n<r1>\n<r2>`, one `record-seat … review` either way. Other tiers: unchanged single `lead-review` at `top_model`.
- `args` gained `second_model` (read as `SECOND`, used only in the tier-4 branch).
- R14 (corrected 2026-09-13 by story 29; corrected again 2026-09-13 by story v0-12-0-remainders-03, per round-3 review X-M2/X-m4): the public-page fetch stays on record as history — `https://code.claude.com/docs/en/workflows`, read 2026-09-13, confirmed `agent()` returning `null` and was silent on the other three shapes. Beyond that page, this session's own Claude Code ships the Workflow tool's script reference (the `workflow-authoring` skill text, read 2026-09-13), and it documents all three: `parallel` — "A thunk that throws (or whose agent errors) resolves to `null` in the result array - the call itself never rejects"; `pipeline` — "A stage that throws drops that item to `null` and skips its remaining stages"; and `phase` as a documented `agent()` option (`agent(prompt, opts?: {label?, phase?, schema?, model?, effort?, isolation?, agentType?})`), recommended specifically inside `parallel()`/`pipeline()` stages — exactly where `dispatchSeat` (`vulyk-cycle.js:85-94`) uses it. The earlier "mismatch, flagged below" verdict on `phase` and the "they stay unverified by VULYK rather than confirmed" verdict on the two throw behaviours are both withdrawn: all three are documented, not gaps.
- Dropped `ceiling` from the top-of-file comment (line 12) - the tightened grep in this story's own acceptance criteria (unlike story 06's) requires it absent even in comments; the word now appears only in `meta.description`, which C11 fixes verbatim.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
