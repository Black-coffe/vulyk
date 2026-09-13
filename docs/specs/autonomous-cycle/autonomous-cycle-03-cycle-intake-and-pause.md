---
story: autonomous-cycle-03
spec: autonomous-cycle
status: done
tier: 4
worker: worker-code
tracer: false
wave: 2
blocked_by: [autonomous-cycle-01]
---

# `cycle.sh` intake: `record-seat`, `briefed`, `branch`, `pause`/`resume`, the PAUSE guard

## Goal
Seat reports reach disk only through `record-seat`, which validates the D3 contract, detects taint, keeps rejected attempts and marks a seat ABSENT after two; `briefed` and `branch` write their plan lines from the disk preconditions; `pause`/`resume` own the semaphore and every mutating verb refuses under it. All of it tested in `tests/council.test.sh`.

## Requirements
> Красный = хотя бы один BROKEN (ask из brief не работает, с доказательством: команда/вывод/URL) у любого из трёх или BLOCK от lead-review.

> Все «Принять» из таблицы входят в бриф: скрипт судит раунды, worktree-слепота, ## Asks, PAUSE, Briefed:, N/A, пороги.

> Только мини-гриль. После последнего ответа в гриле система идёт plan → build → совет → коммит без единого ожидания.

> Стори коммитятся на ветке vulyk/<slug> как сейчас (проверка — тест стори + scope-check).

## Files
- scripts/cycle.sh
- tests/council.test.sh

## Non-goals
- Do not implement `open-round`, `close-story`, `reopen` or the court worktree - story 04. Their stubs stay `exit 1`.
- Do not change the verdict rule or the row schema from story 01; `record-seat` only feeds `judge` the files it already reads.
- Do not edit `scripts/lib.sh`, `scripts/journal.sh` or any gate script.
- Do not add a `start-story` verb or write `status: in-progress` anywhere.
- No prose heuristics in taint detection: the four literal patterns of C5, case-sensitive, nothing more.

## Map slice
`docs/specs/autonomous-cycle/plan.md` `## Contracts` C2, C4, C5, C7, C8, C13 · `docs/adr/001-cycle-state-contract.md` D2 (verb table rows `briefed`, `branch`, `record-seat`, `pause`/`resume`; the exit-code line), D3 (report contract and the re-ask rule), D6 first paragraph · `docs/specs/autonomous-cycle/recon/scout-commands.md` §Answer 2 (the `drone-acceptance` report shape being replaced) and §Answer 3 (`lead-review` verdict is prose with `PASS`/`BLOCK`).

## Acceptance criteria
- [ ] `record-seat <spec> <N> <seat> [--model <id>] < report` with a valid C5 report writes `council/round-N/<seat>.md` with the C4 header (`attempt: 1`, `model:` from `--model`, else the report's `MODEL:` line, else `unknown`) and exits 0; requires an open round whose `ROUND.head` equals HEAD (else exit 2 / exit 5 `stale`).
- [ ] Each of these exits 4 with `"error":"MALFORMED: <what>"` and leaves `<seat>.attempt-1.md` instead of `<seat>.md`: a missing label; `ASK` numbers not exactly 1..A; `GREEN`/`RED` without `run:`+`saw:` or `url:`+`saw:`; `N/A` without `why:`; `VERDICT:` inconsistent with the ASK lines; a body naming `demo-01`, `plan.md`, `journal.md` or `council/`.
- [ ] Second attempt: an unevidenced `RED` is accepted as `<seat>.md` with the ask listed in a header field `unevidenced: 2,5`; `judge` (story 01) then counts it in `red_unevidenced`, not in `red`, and it does not trigger `half`; an unevidenced `GREEN` is rewritten as `N/A - why: unevidenced on attempt 2`. A third attempt exits 2: the seat is `ABSENT`.
- [ ] `record-seat … review` accepts a `lead-review` report of any shape, extracts `PASS`/`BLOCK` per C5 into the header (`verdict: PASS`), stores the whole text; a report with neither is exit 4.
- [ ] `briefed` exits 2 naming `## Asks` when the section is missing or empty; otherwise replaces the `**Briefed:**` placeholder with `**Briefed:** via grill, <owner>, <date>` (`--mode mini-brief|assumed` selects the C7 variant), writes the journal line, prints `next:"branch"`.
- [ ] `branch` exits 2 without Briefed or Approved; otherwise creates or checks out `vulyk/<slug>`, writes `**Branch:**`, journal, `next:"build:1"`.
- [ ] `pause [why]` creates `PAUSE` (first line per C4) and journals `paused`; `resume` removes it, journals, and prints `"stale":true` when HEAD moved while paused; both exempt from the guard.
- [ ] With `PAUSE` present, `briefed`, `branch`, `record-seat`, `judge`, `escalate` (and the story-04 stubs) exit 3 `{"ok":false,…,"next":"paused"}` before touching anything.
- [ ] `--commit` on `briefed`/`branch` commits as `vulyk(<slug>): briefed` / `vulyk(<slug>): branch vulyk/<slug>`.
- [ ] `tests/council.test.sh` gains a case per criterion, including "report naming `demo-01` -> tainted" and "unevidenced RED -> exit 4, then RED on attempt 2 and excluded from half".

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `record-seat` D3 validation is sed/case/string-list based (no bash arrays or `[[ =~ ]]`), matching `judge`'s existing idiom; ASK lines are re-parsed per pass via `ask_line_of`/`ask_verdict_of`/`ask_rest_of` rather than cached, cheap at the 40-line report cap.
- MALFORMED rejection (any attempt) writes `<seat>.attempt-K.md` and exits 4 via one shared `reject_seat_report()`, mirroring how `usage()` already both prints and exits; a third call finds `attempt-2.md` with no final file and exits 2 (seat ABSENT) before reading stdin.
- Attempt-2 leniency (D3) is scoped narrowly: only a GREEN/RED ask missing `run:+saw:`/`url:+saw:` gets the pass; a missing label, bad ASK numbering, `N/A` without `why:`, `VERDICT` inconsistency or taint still reject on attempt 2, exhausting the seat.
- `unevidenced:` (council seats) and `verdict:` (review) are extra ` · key: value` fields appended to the same C4 header via one `write_seat_file()`, not a schema change - `judge` still derives `red_unevidenced` itself from each ASK line's own evidence tokens, unchanged from story 01, per the story's Non-goal.
- `pause` writes a second `head=<sha7>` line under the C4 `<who> · <why> · <ts>` first line so `resume` can report `stale`; C4 only constrains the *first* line of `PAUSE`.
- `templates/plan.md` (story 02's file, not this story's) now carries a `**Briefed:**` placeholder mid-build (another worker's concurrent edit) - `briefed`/`branch` don't assume either way: they replace the marker line if one exists, else append, using the same "starts with `<`" placeholder rule as `marker()`.
- Pre-existing bug found and fixed in `tests/council.test.sh`'s `seat_report()`: `fold -w1 | while read` silently dropped the pattern's last character (no trailing newline), so a 3-char pattern only ever produced 2 `ASK` lines. Invisible to `judge` (it never checks ASK-line coverage against `A`) but fatal to `record-seat`'s D3 coverage check; replaced with a `${pattern:j:1}` index loop. No existing assertion depended on the dropped line (verified each affected fixture).

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
