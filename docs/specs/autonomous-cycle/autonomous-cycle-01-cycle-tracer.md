---
story: autonomous-cycle-01
spec: autonomous-cycle
status: done
tier: 4
worker: worker-code
tracer: true
wave: 1
blocked_by: []
---

# Tracer: `cycle.sh status` + `judge` over fixtures, `journal.sh`, `lib.sh`, the council test

## Goal
The state contract exists and is proven before anything is wired to it: `scripts/cycle.sh` derives `status --json` from disk and computes a round verdict with `judge` (calling `escalate` when the rule says so), writing the `council.jsonl` row, the `**Council:**` line and a journal line; `scripts/journal.sh` writes the one-line-per-state-change journal; `scripts/lib.sh` holds the shared functions; `tests/council.test.sh` walks hand-written fixtures through every row of the verdict table and runs in CI.

## Requirements
> Если после третьего раунда не пришли к решению единогласному или процент проблем критический, в красной зоне, то тогда всё, стоп и на человека, чтобы он принял решение.

> Красный = хотя бы один BROKEN (ask из brief не работает, с доказательством: команда/вывод/URL) у любого из трёх или BLOCK от lead-review.

> Все «Принять» из таблицы входят в бриф: скрипт судит раунды, worktree-слепота, ## Asks, PAUSE, Briefed:, N/A, пороги.

> docs/specs/<slug>/journal.md — одна строка на каждую смену состояния (время, стадия, что произошло, что дальше), пишет скрипт journal.sh — из Workflow, из сессии, отовсюду одинаково.

> Новый memory/stats/council.jsonl: раунды до зелёного, эскалации

## Files
- scripts/lib.sh
- scripts/cycle.sh
- scripts/journal.sh
- tests/council.test.sh
- .github/workflows/ci.yml

## Non-goals
- Do not implement `record-seat`, `open-round`, `close-story`, `reopen`, `briefed`, `branch`, `pause`, `resume` - story 03/04. Register the verb names in the `case` with `exit 1` usage stubs so the CLI surface is visible.
- Do not create or remove git worktrees; `judge` only removes a court directory if `ROUND.court` names an existing path (a `rm -rf` guard is enough here; story 04 does `git worktree remove`).
- Do not touch `ship-check.sh`, `human-check.sh`, `acceptance-log.sh`, `release-check.sh`, `state.sh` or `tests/cycle.test.sh` - story 02 migrates them to `lib.sh`. `lib.sh` is created here and consumed here only.
- Do not validate seat reports beyond what `judge` needs (the `VERDICT:` line, `ASK <n>:` verdicts and evidence tokens); full D3 validation is `record-seat`'s job.
- No model calls, no prose parsing outside the labelled lines.

## Map slice
`docs/specs/autonomous-cycle/plan.md` `## Contracts` C1-C4, C6, C7, C9, C13 · `docs/adr/001-cycle-state-contract.md` D1, D4 · `docs/specs/autonomous-cycle/recon/scout-scripts.md` §Key types (the functions to copy verbatim into `lib.sh`: `ship-check.sh:21-37`, `:42-56`, `:59-64`) and §Answer 5 (how `tests/cycle.test.sh` builds its synthetic repo - mirror it).

## Acceptance criteria
- [ ] `scripts/lib.sh` defines `pack_fingerprint`, `paperwork_only` (whitelist per C1), `marker`, `now_ts`, `slug_of`; sourcing it twice is harmless.
- [ ] `bash scripts/cycle.sh status docs/specs/demo --json` prints exactly one JSON object with every C3 key; with no rounds and all stories done it says `next: "open-round"`; with `round-1/ROUND` and no row it says `open: true`, `round: 1`, `missing` listing the absent seats and `next: "dispatch:..."`; with all four seat files it says `next: "judge"`.
- [ ] `judge` on a round with fixture seats `GGGGGGG` x3 and review `PASS` appends a `council.jsonl` row `verdict:"GREEN"` (keys in C4 order), a `**Council:** GREEN round 1, …` line after the plan's `**Council:**` placeholder, and a journal line `… · 04-council:GREEN · …`; the last stdout line is `{"ok":true,"verb":"judge","exit":0,"next":"green"}`.
- [ ] One seat with an evidenced RED on ask 2 -> row `verdict:"RED"`, `red:[2]`, `next:"repair"`; the plan line ends ` - red: 2`.
- [ ] Rounds 1-3 each RED (fixtures) -> `judge` on round 3 writes `verdict:"ESCALATE"`, `escalate:"ceiling"`, appends `## Needs a human` per C7 and says `next:"escalated"`; on round 2 it does not.
- [ ] 4 of 7 asks RED in one round -> `ESCALATE`, `escalate:"half"`, regardless of round number.
- [ ] Three seats `ABSENT` (`<seat>.attempt-2.md` present, `<seat>.md` absent) -> `ESCALATE`, `escalate:"env"`.
- [ ] Every seat `N/A` with `why:` and review `PASS` -> `GREEN`, `na:3`.
- [ ] A `memory/stats/human.jsonl` row `REJECTED` with `ts` newer than `ROUND.opened` -> `RED`, `next:"repair"`, even with all-GREEN seats.
- [ ] Deleting the `**Council:**` line and re-running `judge` restores only that line; the row is not duplicated; deleting the journal line restores only the journal line.
- [ ] `judge` on a round with a seat missing and not `ABSENT` exits 2 with `"error"` naming the seat.
- [ ] `bash scripts/journal.sh docs/specs/demo 03-building "wave 1 dispatched" "close stories"` creates `journal.md` with the header and appends the C9 line; the same line is on stdout.
- [ ] `PAUSE` present -> `judge` exits 3 with `next:"paused"`, writes nothing.
- [ ] `.github/workflows/ci.yml` gains job `council` running `bash tests/council.test.sh` on `ubuntu-latest`, shaped like job `cycle` (`ci.yml:89-96`).
- [ ] `tests/council.test.sh` covers every criterion above and exits non-zero on the first failed `expect`.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh`

## Tracer
Layers this slice must touch: shared library (`lib.sh`) -> state derivation from disk (`status`) -> verdict rule (`judge`/`escalate`) -> the three writes (row, plan line, journal) -> the test harness the rest of the epic extends -> CI. If the fixture walk shows the `next` vocabulary or the row schema cannot carry what a driver needs, report it in `INTERFACES` before story 03/04 build on it.

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `lib.sh`: the three functions copied verbatim from `ship-check.sh`; `paperwork_only`'s whitelist extended per C1 on one line, matching the original's style.
- `cycle.sh judge`'s "current round" is always the highest-numbered `council/round-N` dir; a round with a `council.jsonl` row already is re-judged idempotently (recomputes the same verdict from the same seat files, then fills in only whichever of row/plan-line/journal-line is missing) rather than tracked by a separate "which round is open" pointer.
- `judge` reads `red_e`/`red_u` (evidenced vs. unevidenced RED) directly from each seat's `ASK <n>:` lines (run:/saw: or url:/saw: = evidenced) - full D3 validation (MALFORMED, taint, re-ask) stays out of scope for `record-seat` (story 03) as the non-goals say; an ask RED without evidence still counts toward the round's RED verdict but not toward the `half` escalation threshold.
- exit code 4 ("malformed / red verification" per C2's legend) is used for both `record-seat`'s future MALFORMED and `judge`'s RED verdict - the story text names both under one code and no acceptance criterion states judge's RED exit code explicitly, so this is a reading, not a given.
- `escalate` is implemented as an alias of `judge`'s full computation (same function, different label in the JSON `"verb"` field) since the one place it would differ - `open-round` exiting 6 before any round is judged - needs `open-round` (story 04). Flagging per the story's Tracer note.
- `cmd_status`'s `build:<wave>`/`close-story:<file>` split (build wins when a wave still has a ready `todo`; close-story only when a wave's `todo` is exhausted but an `in-progress` story remains) is a reading of C3's prose, which lists them without spelling out precedence - not exercised by this story's acceptance criteria (all fixtures use `status: done` stories) but present so story 03/04 status calls don't regress on it. Same for `compute_stage`: a best-effort mirror of `state.sh`'s ladder plus the council/paused stages, not read by anything else yet and not covered by an acceptance criterion.
- `.github/workflows/ci.yml`: added job `council` immediately after `cycle`, same shape (checkout, one `run: bash tests/...`).

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
