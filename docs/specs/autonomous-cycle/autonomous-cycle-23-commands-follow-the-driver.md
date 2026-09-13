---
story: autonomous-cycle-23
spec: autonomous-cycle
status: todo
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

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
