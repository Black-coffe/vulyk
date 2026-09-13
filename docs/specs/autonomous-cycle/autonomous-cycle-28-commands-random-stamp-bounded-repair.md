---
story: autonomous-cycle-28
spec: autonomous-cycle
status: done
tier: 4
worker: worker-code
tracer: false
wave: 11
blocked_by: []
---

# The session driver matches again: a random stamp with honest words, an empty worker is a miss, one repair per round

## Goal
`/vulyk-build` and `/vulyk-review` take the heredoc stamp from `/dev/urandom`, not the clock, and say what the delimiter buys — a per-run random value the seat is never told, around a report that still travels as free text in the clerk's prompt. The fallback's `build:<wave>` row counts a worker that returns nothing as a miss under the two-strike rule; its `repair` row dispatches `queen-planner` once per round, names `red` and `review`, and stops when the next `status` still says `repair`. The wake-up step understands the driver's new stops (`build` with a `file`, `repair`, `launch`).

## Requirements
> Где Workflow недоступен — сегодняшняя петля в сессии, но через те же скрипты.

> Потолок 3 раунда → стоп и зов человека

> The `record-seat` heredoc delimiter must carry entropy a seat cannot bound from its own clock

> the delimiter must come from a value a seat cannot bracket from its own clock — or the two command files and R11 must say what the construction actually buys ("a per-run value the seat is not told", not "cannot guess").

> `stamp` is `od -An -tx1 -N8 /dev/urandom | tr -d ' \n'` (16 hex characters) taken once by the launcher — `/vulyk-build` step 1 for both drivers, `/vulyk-review` step 2 — and never `date`

> A worker that returns an empty report must count as a miss under the two-attempt bound

> A repair step that lands nothing must end the run, and the Workflow's repair prompt must name the `lead-review` BLOCK when `red` is empty

> The fallback's `repair` row carries the same bound and the same prompt.

## Files
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md

## Non-goals
- Do not put verdict, ceiling or staleness logic into prose; `review` and `red` are read off `status --json` (story 27), never derived.
- Do not touch the JS driver (story 26), `cycle.sh`, `vulyk-pause.md`, `vulyk-resume.md` or `docs/command-reference.md` (lead-review r2 minor 10 — next circle).
- Do not resolve who refuses a `blocked` story on relaunch (minor 16), the `briefed` disagreement (minor 15) or the `03-building` journal stage (minor 18) — next circle; leave those sentences as they are.
- Do not add a `$RANDOM` fallback or a second stamp source; one line, one source.

## Map slice
`.claude/commands/vulyk-build.md` — step 1 (the `stamp=` line, the Workflow `args`, the "no report body can guess" sentence), step 2 rows `build:<wave>` and `repair`, step 4 (the `stop` object) · `.claude/commands/vulyk-review.md` — step 2 (`stamp=`), step 3's delimiter sentence · `plan.md` delta 7: R29, R30, R31 and the contract-amendments line · `## Contracts` C3, C11, C12 · ADR-001 D2 "The fallback driver".

## Acceptance criteria
- [ ] Both files: `stamp="$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')"`, taken once (build: step 1, before the launch or the loop; review: step 2); `grep -n 'date -u +%s' .claude/commands/vulyk-build.md .claude/commands/vulyk-review.md` is empty; the Workflow launch passes `stamp` in `args` as before.
- [ ] Both files: the sentence "a delimiter no report body can guess or contain" is gone; in its place: the report travels as free text inside the clerk's prompt, and the delimiter `VULYK_<stamp>_<seat>_<attempt>` is a per-run random value the seat is never told — what keeps the body from ending the heredoc early; `grep -n 'cannot guess\|no report body can guess' .claude/commands/vulyk-build.md .claude/commands/vulyk-review.md` is empty.
- [ ] `build:<wave>` row: a worker that returns nothing (empty final message, aborted, timed out) is a miss under the same two-strike count as a red `close-story` — `close-story` is not run on it; first miss: the story stays for the next `status`; second for the same story (missed or red, in any order): `status: blocked`, a `## Findings` line naming the miss, `lead-architect` consult, stop.
- [ ] `repair` row: `queen-planner` is dispatched once per round number; its prompt names `red` and `review` from `status --json`, and when `red` is empty says the RED is the review seat's BLOCK (or an owner `REJECTED`), points at `<round_dir>/review.md` and asks for one story per critical and per major finding whose fix is local; when the next `status` still says `repair` for the same round, the loop stops, prints `repair landed nothing for round <N>` and the journal tail.
- [ ] Step 4 (wake-up): a `stop` carrying `file` — whatever its `verb` — applies the blocked / `lead-architect` rule; `stop.verb` `repair` or `launch` prints `stop.error` and the journal tail and stops (a `launch` stop means step 1 passed no stamp — fix the launch, do not relaunch blindly); everything else as story 23 left it.
- [ ] `vulyk-review.md` step 3 still dispatches exactly `missing` (R20) with the Tier 4 fold; only the stamp line and the delimiter sentence change.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- Both files: `stamp="$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')"` replaces `date -u +%s`, one line each, no `$RANDOM` fallback (R31).
- Both files: "a delimiter no report body can guess or contain" replaced with "the report travels as free text inside the clerk's prompt" + "a per-run random value the seat is never told" framing, in the dispatch/record-seat prose (R31).
- `vulyk-build.md` `build:<wave>` row: an empty/aborted/timed-out worker report is now a miss under the same two-attempt bound as a red `close-story`, with `close-story` skipped for that miss; first/second miss language now covers all three miss kinds in any order (R29).
- `vulyk-build.md` `repair` row: bounded to one `queen-planner` dispatch per round number; prompt now names `red`/`review` from `status --json` and states the review-seat BLOCK explicitly when `red` is empty; a repeat `repair` for the same round stops the loop and prints `repair landed nothing for round <N>` + journal tail, instead of looping forever (R30).
- `vulyk-build.md` step 4 wake-up: generalized the blocked/`lead-architect` rule to any `stop` carrying `file` (`close-story` or `build`, R29), and added explicit handling for `stop.verb` `repair` (R30) and `launch` (R31's stamp guard) - both print `stop.error` + journal tail with no `file`.
- `vulyk-review.md`: only the step 2 stamp line and step 4 delimiter sentence changed, matching the same R31 wording; step 3's `missing`-only dispatch (R20) was left untouched, as scoped.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
