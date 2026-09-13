---
story: autonomous-cycle-26
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 11
blocked_by: []
---

# The Workflow driver fails closed: no verdict from a blank reviewer, every miss is bounded, every clerk line reaches the top

## Goal
`.claude/workflows/vulyk-cycle.js` never manufactures a verdict and never loops on silence. Two reviewer results are folded only when both open with `VERDICT:`; anything else reaches `record-seat` as a report that fails the contract, so the round ends in an attempt file and an `env` escalation where the surviving report is readable. A worker that returns nothing is a miss under the same two-attempt map as a red `close-story`. A round is repaired once per run; a `status` that still says `repair` for the same round ends the run. A `BadLine` raised while recording a seat propagates like every other one. The run refuses to start without a usable `args.stamp`.

## Requirements
> Workflow-скрипт + fallback в сессию

> Королева просыпается дважды: итоговый отчёт (мерж) или эскалация.

> Если после третьего раунда не пришли к решению единогласному или процент проблем критический, в красной зоне, то тогда всё, стоп и на человека, чтобы он принял решение.

> a `review` seat whose reviewer dispatches produced no report must not be recorded as a verdict at all — the round must reach `record-seat` with something that fails the report contract, or not reach it — and at Tier 4 a single surviving reviewer must be visible as such rather than folded with a blank.

> A worker that returns an empty report must count as a miss under the two-attempt bound

> a wave story whose worker returns nothing must be bounded by the same two-attempt rule a red verification is, and end the run with the story named rather than re-dispatching forever.

> A repair step that lands nothing must end the run, and the Workflow's repair prompt must name the `lead-review` BLOCK when `red` is empty

> a non-JSON clerk line during a seat recording must end the run with the raw line, the same as every other clerk call, rather than being absorbed by the stage that made it.

> an unset `args.stamp` also yields the constant `VULYK_undefined_<seat>_1`

> the Workflow refuses to start when `args.stamp` is missing or shorter than 12 characters (`stop:{verb:"launch", error}` before the first clerk call)

## Files
- .claude/workflows/vulyk-cycle.js

## Non-goals
- No verdict, ceiling or staleness logic: the fold checks a first line for a token, it does not decide what the round is; `st.review` is read from `status --json` (story 27 adds it), never inferred from `red`.
- Do not fabricate `VERDICT: BLOCK` for a blank reviewer — fail-closed is still a verdict nobody wrote. The failing report is the mechanism.
- Do not change the R6 rules already in the file (one re-ask on `record-seat` exit 4, two-strike `close-story`), the seat prompts, the review packet or the delimiter shape; do not touch `cycle.sh`, the command files (story 28) or the ADR (story 29).
- Do not treat `open-round` exit 6 or `record-seat` exit 3 specially (lead-review r2 minors 4 and 17 — next circle).
- No `Date`, `Math.random`, filesystem, shell or `resumeFromRunId`.

## Map slice
`.claude/workflows/vulyk-cycle.js` — `dispatchSeat`/`recordSeat`, `isBlock`, the tier-4 `parallel` fold, the `build:` branch (`attempts` map, `if (!reports[i]) continue`), the `dispatch:` branch (`pipeline` stages), the `repair` branch, the `Stop`/`BadLine` catch, the `args` read · `plan.md` delta 7: R28, R29, R30, R31, R32 and the contract-amendments line (C3 `review`, C11) · `## Contracts` C2, C3, C11 · `council/round-2/review.md` N-C1, N-M1, N-M2, N-M3, LR M3, LR M4 (the reviewers' line-by-line reading of the file).

## Acceptance criteria
- [ ] A top-level `function foldReviews(r1, r2)` (declaration form at column 0, closing `}` at column 0, self-contained — no call to any other helper) returns `VERDICT: BLOCK\n<r1>\n<r2>` or `VERDICT: PASS\n<r1>\n<r2>` only when the first line of each argument matches `/^VERDICT:\s*(PASS|BLOCK)\b/`; otherwise it returns `NO VERDICT: top=<first line or (no report)> · second=<first line or (no report)>` followed by both bodies (a null or empty body rendered as `(no report)`), and the tier-4 branch sends that string to `record-seat` unchanged. Harness, one command, prints `fold ok`:
  ```
  node -e "const s=require('fs').readFileSync('.claude/workflows/vulyk-cycle.js','utf8');const m=s.match(/^function foldReviews\([\s\S]*?^\}/m);if(!m)throw new Error('no foldReviews');const fold=new Function(m[0]+';return foldReviews;')();const first=r=>String(r).split('\n')[0];const ok=(c,w)=>{if(!c){console.error('FAIL '+w);process.exit(1)}};ok(first(fold('VERDICT: PASS\nA','VERDICT: BLOCK\nB'))==='VERDICT: BLOCK','either BLOCK');ok(first(fold('VERDICT: PASS\nA','VERDICT: PASS\nB'))==='VERDICT: PASS','both PASS');for(const [a,b,w] of [[null,null,'null,null'],[null,'VERDICT: PASS\nB','null,PASS'],['VERDICT: PASS\nA',null,'PASS,null'],['','VERDICT: PASS\nB','empty,PASS'],['prose\nVERDICT: PASS','VERDICT: PASS\nB','prose first']]){ok(!/^VERDICT:/.test(first(fold(a,b))),w)}ok(fold(null,'VERDICT: PASS\nB').includes('VERDICT: PASS\nB'),'survivor kept');console.log('fold ok')"
  ```
- [ ] Any seat's null report (a dead `agent()`, a throwing `parallel` thunk) is sent to `record-seat` as an empty body — the body passes through `?? ''` (or an equivalent null guard) before the heredoc; `String(null)` never reaches it.
- [ ] `build:` branch: a null or empty worker report increments the same `attempts` map a red `close-story` uses and skips `close-story`; on the second miss for the same `file` (a red `close-story` and an empty report count together, in any order) the run ends with `stop: { verb: 'build', file, error: 'worker returned no report' }`; `if (!reports[i]) continue` is gone.
- [ ] `dispatch:` branch: no `clerk()` call sits inside a `pipeline` stage — seats are dispatched under `parallel` and recorded one after another in plain loop code (the exit-4 re-ask stays per seat), so a `BadLine` reaches the one catch that returns its line; `grep -c 'pipeline(' .claude/workflows/vulyk-cycle.js` = 0, or every remaining stage is free of `clerk(`/`recordSeat(`.
- [ ] `repair` branch: a per-run `Set` of repaired round numbers; a second `next:"repair"` with the same `st.round` ends the run with `stop: { verb: 'repair', round, error: 'repair landed nothing for round <N>' }`; the planner prompt names `st.red` and `st.review`, and when `st.red` is empty says the RED is the review seat's BLOCK (or an owner `REJECTED`), points at `${st.round_dir}/review.md` and asks for one story per critical and per major finding whose fix is local; the wording "each addressing exactly one of those asks" is emitted only when `st.red.length > 0`.
- [ ] Before the first `clerk()` call: `typeof args.stamp !== 'string' || args.stamp.length < 12` → `return { stop: { verb: 'launch', error: 'args.stamp missing: launch with the 16-hex random stamp of /vulyk-build step 1' } }`; the top-of-file comment on `stamp` says "a per-run random value the seat is never told", not "unguessable".
- [ ] Story 06/22 greps still clean (`GREEN`, `RED`, `stale`, `paperwork` absent outside comments; `ceiling` only in `meta.description`; `worker-code` count 0; no `EOF` delimiter; `stamp` absent from every seat prompt); `node --check .claude/workflows/vulyk-cycle.js` passes; the file stays under ~200 lines — recorded, not gated.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
