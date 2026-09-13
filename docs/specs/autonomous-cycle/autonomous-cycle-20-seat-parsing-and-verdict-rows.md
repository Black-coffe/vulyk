---
story: autonomous-cycle-20
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 9
blocked_by: [autonomous-cycle-19]
---

# One evidence rule, path-anchored taint, and the verdict rows the table was missing

## Goal
`record-seat` and `judge` read an `ASK` line the same way — evidence tokens found anywhere after the verdict, never cut at an interior ` - ` — so an evidenced GREEN is never downgraded and the header agrees with the row. Taint fires on the hive's own spec paths and story ids, not on the words `plan.md`, `journal.md` or `council/` wherever they appear, so a seat can name `vulyk-plan.md` or `journal.sh`'s output without losing an attempt. The verdict table gains the rows the reviewers found missing: a single evidenced RED is a repair on every brief size, and an ABSENT required seat with nothing RED is an `env` escalation, not a RED with nothing to repair. A RED judgement exits 0.

## Requirements
> Красный = хотя бы один BROKEN (ask из brief не работает, с доказательством: команда/вывод/URL) у любого из трёх или BLOCK от lead-review.

> 3 места, 3 модели, 3 разных угла

> Стори, implementation notes, отчёты воркеров — скрыты.

> One evidence rule, shared by `record-seat` and `judge`, must locate `run:`+`saw:` / `url:`+`saw:` / `why:` anywhere after the verdict token and never truncate at an interior ` - `; a test must carry ` - ` inside `saw:`.

> Taint must match paths under `docs/specs/<slug>/` (its own `plan.md`, `journal.md`, `council/`, `<slug>-NN` story files), not the bare words anywhere in the body.

> The plan must state whether one evidenced RED on a one- or two-ask brief is an escalation or a repair, and rule and test must match

> a round in which no ask is RED and `lead-review` passed, but a seat is ABSENT, must resolve to a verdict whose `next` action is defined and whose row carries something a repair can act on.

> D4 has no row for a required `review` that is ABSENT while every seat is GREEN

> `judge` on RED must not exit 4 with `"ok":true`

## Files
- scripts/cycle.sh
- tests/council.test.sh

## Non-goals
- Do not touch `cmd_status`'s derivations (story 19 landed them) beyond calling the shared evidence helper.
- Do not touch `open-round`, `escalate`, `close-story`, git handling or `lib.sh` — story 21.
- No prose heuristics: taint patterns are literal, case-sensitive and anchored on the spec's slug; the evidence rule is token presence, not sentence parsing.
- Do not change the C5 labels, the 40-line cap, the attempt-2 leniency (an unevidenced RED stays RED in `red_unevidenced`, an unevidenced GREEN becomes N/A) or the `review` seat's `PASS`/`BLOCK` extraction.
- Do not edit agents, commands, docs or the driver.

## Map slice
`scripts/cycle.sh` — `ask_line_of`/`ask_verdict_of`/`ask_rest_of` and the evidence checks in `cmd_record_seat` (story 03), the per-ask classification in `cmd_judge` (`red_e`/`red_u`, story 01), `taint_reason`, the `half` computation and the "conservative default" branch in `cmd_judge`, the RED exit at the end of `cmd_judge` · `tests/council.test.sh` — `seat_report` (patterns `G`/`R`/`?`), the taint and unevidenced scenarios of story 03, the `half`/`env` scenarios of story 01 · `plan.md` delta 6: R8, R9, R10, R16, R24 · `## Contracts` C5, C6 · ADR-001 D3, D4.

## Acceptance criteria
- [ ] One function classifies an `ASK <n>:` line for both verbs: after the verdict token, evidenced iff `run:` and `saw:` both occur, or `url:` and `saw:` both occur, anywhere in the remainder; `N/A` needs `why:`; text after an interior ` - ` is part of the evidence. Test: `ASK 2: GREEN - suite - run: bash t.sh saw: READY - 6/6 ok` is accepted at attempt 1 and judged GREEN; a header `unevidenced:` list and the row's `red_unevidenced` agree on the same fixture.
- [ ] Taint (C5 amended): rejected with `MALFORMED: tainted: <match>` when the body contains `docs/specs/<slug>/plan.md`, `docs/specs/<slug>/journal.md`, `docs/specs/<slug>/council/`, `<slug>/plan.md`, `<slug>/journal.md`, `<slug>/council/` or a word-bounded `<slug>-NN`; accepted when it contains only `vulyk-plan.md`, `<spec>/journal.md`, `docs/specs/other/plan.md`, the bare words `plan.md` / `journal.md` / `council/` or `demo-1`. Both lists are fixtures.
- [ ] `half` fires iff |RED_e| >= max(2, ceil(A/2)): fixtures with A = 1 (one evidenced RED → RED, `next:"repair"`, `escalate:null`), A = 2 (one RED → repair; two RED → ESCALATE `half`), A = 7 (3 RED → repair, 4 RED → `half`, unchanged).
- [ ] New D4 row, after `REJECTED` and before `half`: any required seat — review included — ABSENT while RED_e ∪ RED_u is empty and review is not BLOCK → ESCALATE, `escalate:"env"`, `note` naming the absent seats, `## Needs a human` listing their `attempt-1.md`/`attempt-2.md` paths. Fixtures: Tier 3 with haiku ABSENT + sonnet/opus GREEN + review PASS → `env`; review ABSENT + three GREEN seats → `env`; haiku ABSENT + ask 2 RED → RED, `next:"repair"`; every required seat ABSENT → `env` as before.
- [ ] `judge` on a RED verdict prints `{"ok":true,"verb":"judge","exit":0,"next":"repair"}` and exits 0; ESCALATE keeps exit 6; every fixture that asserted `exit=4` for a RED judgement is updated.
- [ ] Suite green, exit 0, no `::error::`.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
