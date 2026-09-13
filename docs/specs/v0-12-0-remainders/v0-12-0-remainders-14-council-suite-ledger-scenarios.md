---
story: v0-12-0-remainders-14
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-test
tracer: false
wave: 2
blocked_by: [v0-12-0-remainders-01]
---

# The council suite proves the six ledger fixes of story 01

## Goal
`tests/council.test.sh` gains one scenario per story 01 criterion - `attempts` counting, exact round match, `**Council:**` by C7, same-second override, atomic append, `note` through redact - each shown to fail against the `cycle.sh` of `3e200bb` and to pass against the one story 01 committed. The code is already on the branch; this story is the evidence.

## Requirements
> attempts считает попытки (LR19)

> номер раунда матчится точно (LR21, r2m1)

> **Council:** ложится по C7, не в EOF (LR25)

> оверрайд в ту же секунду побеждает (m-4)

> запись в леджер атомарна (m-10)

> note проходит redact (N-m7)

## Files
- tests/council.test.sh

## Non-goals
- Do not edit `scripts/cycle.sh`. If a scenario is red against the branch, that is a wall: record it under `## Findings` with the failing assertion and return `WALL`; do not patch the script or weaken the assertion.
- Do not add scenarios for `open-round`, `close-story` or the semaphore (stories 05, 08, 11 own those).
- Do not restructure the suite's helpers (`mk_spec`, `mk_round`, `write_seat`, `seat_report`, `expect`); add scenarios in the existing shape.
- Do not use `git stash` or checkout to reach `3e200bb`; the branch's working tree must stay untouched by the proof.

## Map slice
`memory/map/cycle.md` (`cmd_judge` verdict order, "Writes idempotently", D1 crash rules, `status --json` `open`) · `recon/tests-ci-hooks-driver.md` §1 (suite shape, helpers `mk_spec`/`mk_open_spec`/`mk_round`/`write_seat`/`write_review`, the slug-as-`spec`-key convention, "To add one scenario") · `docs/adr/001-cycle-state-contract.md` D1 row schema, C7 · story 01 `## Acceptance criteria` (the six behaviours, one scenario each).

## Acceptance criteria
- [ ] LR19 scenario: a round with one seat stored as `<seat>.md` and `<seat>.attempt-1.md` (a re-asked seat) judged; the row's `attempts` equals the file count, asserted for `judge` and for the STALE and ceiling writers where the fixture reaches them.
- [ ] LR21/r2m1 scenario: a closed round 10 (three `reopen`s or a fabricated `"round":10,` row in `council.jsonl` plus a `round 10` line in plan.md) and an open round 1: `status --json` reports `"open":true`, `judge` writes a round-1 row, and no `## Needs a human` reason for round 10 is mistaken for round 1.
- [ ] LR25 scenario: plan.md with a `**Council:**` line followed by `**Shipped:**` placeholder text; after `judge`, `escalate` and the ceiling path the new `**Council:**` line sits directly after the last existing one, not at EOF; `marker "$PLAN" Council` returns the newest; a second `judge` adds nothing.
- [ ] m-4 scenario: `human.jsonl` REJECTED row with `ts` equal to `ROUND.opened` to the second; `judge` reports the override, not the round's own verdict.
- [ ] m-10 scenario: the ledger writer's `printf >>` is the only write per row - assert by structure (e.g. `grep -c` of the append sites against the count of writers) or by a reader racing a 4 KB `note` row and seeing it absent or whole, never truncated; state in the scenario's label which proof is used.
- [ ] N-m7 scenario: a `note` carrying a token-shaped string (one of the shapes `scripts/redact.sh` masks, e.g. a `ghp_` or `sk-` prefix) lands in the row masked; the raw string is absent from `council.jsonl` and from plan.md.
- [ ] Each scenario is proven to fail at `3e200bb` without touching the working tree: the suite (or a `VULYK_CYCLE_SH` override / a second fixture copy) runs the same six scenarios with `git show 3e200bb:scripts/cycle.sh` copied into the fixture in place of `scripts/cycle.sh`, and `## Implementation notes` records the six `FAIL` labels observed there and the six `ok` labels on the branch.
- [ ] `bash tests/council.test.sh` passes whole on the branch; every pre-existing scenario unchanged.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
