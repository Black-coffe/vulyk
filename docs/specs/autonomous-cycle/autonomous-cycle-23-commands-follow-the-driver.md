---
story: autonomous-cycle-23
spec: autonomous-cycle
status: done
tier: 4
worker: worker-code
tracer: false
wave: 8
blocked_by: []
---

# The session side matches the driver: stop on failure, one bound, safe heredocs, seats by tier, honest pause

## Goal
`/vulyk-build`'s fallback loop and wake-up step apply the same rules story 22 gives the Workflow — stop on any failed verb, two attempts per story then `blocked` plus a `lead-architect` consult, re-ask a malformed seat once, record an empty report, an unguessable heredoc delimiter, no round directory in a seat's prompt — and pass `second_model` at launch. `/vulyk-review` dispatches the seats `status --json` lists in `missing`, so a Tier 1 spec costs one seat on demand too. `/vulyk-pause` says what really happens to a seat in flight.

## Requirements
> Где Workflow недоступен — сегодняшняя петля в сессии, но через те же скрипты.

> Человек может включиться на любом этапе, если у него есть желание, но пока он сам желания не проявляет, система должна максимально быть автономной.

> то тогда она не должна запускать 10 сабагентов, а это 1-2 сабагента

> a driver must end the run on any `"ok":false` clerk result instead of looping

> The two drivers must apply the same bound on a story whose verification stays red

> the Queen at wake does what the fallback does in-session: marks the story `blocked`, consults `lead-architect`, stops

> A blind seat's prompt must not contain a string C5 forbids it to repeat

> the heredoc delimiter is per call and unguessable by the seat — `VULYK_<stamp>_<seat>_<attempt>`, where `stamp` is the run's shell-provided `args.stamp` (Workflow) or `date -u +%s` taken once at loop start (fallback) and never appears in any seat prompt

> the on-demand round must dispatch the seats the round's frozen tier requires, the same list the driver reads from `missing`.

> a seat report produced before the pause must survive it, or D6 and `/vulyk-pause`'s wording must say the report is lost.

> the docs must say the seat is re-dispatched.

## Files
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- .claude/commands/vulyk-pause.md

## Non-goals
- Do not put verdict, ceiling or staleness logic into prose; every branch stays `case "$next"` on `status --json`, and a stop is a stop — the Queen reads `error`, she does not retry the verb.
- Do not rewrite the JS driver (story 22) or describe its internals here beyond the launch args.
- Do not add a lock or claim step (delta 6, R27 — next circle).
- Do not touch `vulyk-plan.md`, `vulyk-ship.md` (m-9 is next circle), `vulyk-status.md`, `vulyk-evolve.md`, `vulyk-bootstrap.md` or `vulyk-resume.md`.
- Do not change the journal-line rule: every terminal message on a state change is still the `journal.sh` stdout line.

## Map slice
`.claude/commands/vulyk-build.md` — step 1 (launch args, mode detection), step 2 rows `build:<wave>`, `dispatch:<seats>`, `judge`, `repair`, the wake-up step · `.claude/commands/vulyk-review.md` — steps 2-3 (what it reads from `status --json`, whom it dispatches, the Tier 4 fold) · `.claude/commands/vulyk-pause.md:12-14` · `plan.md` delta 6: R5, R6, R9, R11, R19, R20 and the contract-amendments line (C3 `tier`, C11 `second_model`) · `## Contracts` C2, C3, C11, C12, C15 (delta 5) · ADR-001 D2 "The fallback driver", D6.

## Acceptance criteria
- [ ] `vulyk-build.md` step 1: the Workflow launch passes `second_model` (`opus` beside a Fable top model, `sonnet` beside an Opus one, unless `plan.md`'s Tier 4 sentence names another) and `stamp` from `date -u +%s`; the fallback takes the same `stamp` once at loop start.
- [ ] Fallback loop: any verb whose last line says `"ok":false` stops the loop and prints its `error` — except `record-seat` exit 4 (re-ask that seat once, naming `error` verbatim; record again; continue) and `close-story` exit 4 (first: the story stays for the next `status`; second for the same story: set `status: blocked`, append the error to its `## Findings`, consult `lead-architect`, stop — never open the council on a blocked pack).
- [ ] `dispatch:<seats>` row: a seat is given `slug`, `round` and the court path only — never the round directory; `lead-review` alone gets `round_dir` and its packet; every `record-seat` heredoc uses the delimiter `VULYK_<stamp>_<seat>_<attempt>` and never `EOF`; an empty report is still piped to `record-seat`.
- [ ] Wake-up step (after a Workflow run): when the returned object carries `stop`, print its `error`; if `stop.verb` is `close-story`, apply the blocked/`lead-architect` rule above; otherwise print the journal tail and stop; `escalated` prints `## Needs a human` verbatim as today (after story 21 `open-round` at the ceiling writes it).
- [ ] `vulyk-review.md` step 3 dispatches exactly the seats `status --json` lists in `missing` (a Tier 1 spec: `sonnet` only; `lead-review` only when `review` is missing), with the same delimiter and no-round-dir rules; the Tier 4 second reviewer and the stricter-verdict fold stay as written.
- [ ] `vulyk-pause.md` states that a seat already running finishes, its report is refused by `record-seat` under PAUSE and discarded, and the seat is re-dispatched after `/vulyk-resume`; the "recorded once you resume" sentence is gone.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `stamp` changed from an ISO timestamp to `date -u +%s` in both `vulyk-build.md` step 1 and `vulyk-review.md` step 2, resolved once per run/round and fed into the new heredoc delimiter `VULYK_<stamp>_<seat>_<attempt>`, replacing the literal `EOF` in every `record-seat` call in both files (R11).
- `second_model` added to `vulyk-build.md` step 1's Workflow `args` and its resolution rule (opus/Fable, sonnet/Opus, plan.md override) written out there and reused by reference from `vulyk-review.md` step 3's existing second-reviewer pairing text (R12).
- `dispatch:<seats>` (build) and the seat-dispatch step (review) now hand a blind seat only `slug`, `round`, `court` - never `round_dir`; `round_dir` plus the packet stays `lead-review`-only (R9/lead-review 10).
- Fallback loop gains one stated rule ahead of the table: any verb's `"ok":false` stops the loop, prints `error`, and is journaled by the command itself (`03-building`) since no `cycle.sh` failure path writes `journal.md` on its own - except `open-round`'s ceiling exit 6, which now journals its own ESCALATE per R5 (verified: `cmd_close_story`, `cmd_branch`, `cmd_record_seat*`, `cmd_open_round`'s precondition exits at `scripts/cycle.sh:1078-1090,700-711,960-990,1239-1288` write no journal line; `emit`/`exit` only).
- `build:<wave>` row: two-strike rule on a story now ends the whole loop on the second miss (mark `blocked`, append error to `## Findings`, dispatch `lead-architect`, stop) instead of "move on to the rest of the wave" - R6 withdraws story 06's in-script-retry criterion and requires the same bound both drivers share.
- `vulyk-build.md` step 4 (wake-up) rewritten around the Workflow's returned `stop:{verb,file,error}` object (C11/R6): `stop.verb === "close-story"` applies the same blocked/`lead-architect` rule as the fallback; any other `stop` prints `error` and the journal tail; no `stop` falls through to the existing terminal-`next` reporting, `escalated` unchanged (R5 makes it reliable from either `judge` or `open-round`).
- `vulyk-review.md` step 2-3: reads `missing` from `status --json` (already tier-scoped by `required_seats_for_tier`/`missing_required_seats`, `scripts/cycle.sh:131-154`) and dispatches only those seats; Tier 4 second reviewer now conditioned on `review` being in `missing` too (R20).
- `vulyk-pause.md`: dropped "finishes and its result is recorded once you resume" (false per `pause_guard` in `cmd_record_seat`, `scripts/cycle.sh:966`, which exits 3 before writing anything); states a worker's edits survive (only its `close-story` call waits) but a seat/`lead-review` report is discarded and the seat is re-dispatched from zero on resume (R19/M-8, minor 28).
- Did not touch `.claude/workflows/vulyk-cycle.js`, `scripts/cycle.sh` or `CLAUDE.md` (Non-goals); cited their behavior by the delta's R5/R6/R9/R11/R12/R20 decisions rather than current text where those files are mid-repair by concurrent stories 19-22.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
