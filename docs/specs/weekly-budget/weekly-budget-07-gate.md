---
story: weekly-budget-07
spec: weekly-budget
status: todo
returned:
tier: 4
worker: worker-code
wave: 4
blocked_by: [weekly-budget-01, weekly-budget-03, weekly-budget-05]
red: required
red_reason:
---

# The reserve gate in `cycle.sh advance`, the one-command lift, the `budget` object in status

## Goal
`cycle.sh advance` calls `bash scripts/budget.sh gate --json` (with `--no-poll` when `measure-poller.json` says
`"decision": "no-poll"`) before any step that dispatches agents: a build wave, a council round, a repair. Exit 3 makes
`advance` write `<spec>/PAUSE` itself with the `budget:` first line from plan.md `## Contracts`, record `budget_pause`, and exit 3
through the existing `pause_guard`, so the driver's Paused path is unchanged. `cycle.sh resume <spec>` on a `budget:`-stamped
PAUSE runs `budget.sh override hold-lifted --spec <spec>`, journals the lift in the spec journal too, and `advance` does not
re-pause that spec in the same reset window. `status --json` and the `advance` result carry the `budget` object with the
resolved families (via `model-profile.sh --role` and `top-model.sh`). Test first (ADR-025).

## Requirements
> 5. (horizon) Резерв 10%: ниже - пауза, снятие одной командой; проверка перед сборкой и партией агентов.
> 4. Лестница: Fable->Opus, Opus->Sonnet (исполнители), пометка в отчёте; обратно при недорасходе.

## Files
- scripts/cycle.sh
- tests/cycle.test.sh

## Non-goals
- No new verb for the clerk (ADR-011): the gate lives inside `advance`, the lift inside `resume`.
- `budget.sh` never writes into the spec dir; `cycle.sh` alone writes `PAUSE` (ADR-028 invariant 7).
- `off`, `n/a`, `no-data` never pause: a warning line in the `advance` output, nothing else.
- `status` stays read-only and never polls (`state --json` only). No driver or command edit (story 08).
- An owner's own `PAUSE` (no `budget:` line) keeps today's `resume` behaviour exactly.

## Map slice
`memory/map/cycle.md` «Verbs», «`advance`», «`status --json` `next`», «Staleness, PAUSE, seat reports»; `memory/map/scripts.md`
«Key contracts» (exit codes, last line one JSON). ADR-028 §3, invariants 3, 7, 8.

## Acceptance criteria
- [ ] Cases in `tests/cycle.test.sh` with a stub `budget.sh` state: `reserve-pause` at `build:<wave>` -> `PAUSE` with the
      `budget:` line, exit 3, next mutating verb exit 3 · same at `open-round` and `repair` · `ok`/`warn`/`boost` -> no PAUSE ·
      `no-data` -> no PAUSE, warning in the JSON · `resume` on a budget PAUSE -> PAUSE gone, `hold-lifted` called with
      `--spec`, a journal line, and the next `advance` in the same window does not re-pause · `resume` on an owner PAUSE ->
      unchanged · `status --json` has `budget.state`, `budget.ladder.{gate,second,worker,review,seat,retry}`, `budget.reason` ·
      `VULYK_BUDGET=0` -> `budget.state` `off`, no gate call.
- [ ] The gate call sits under a time cap so the clerk's Bash call stays within the M3 ceiling.
- [ ] Last stdout line stays one JSON object on every path; exit codes keep their meanings.

## Verification
`bash tests/cycle.test.sh`

## Implementation notes

## Findings
