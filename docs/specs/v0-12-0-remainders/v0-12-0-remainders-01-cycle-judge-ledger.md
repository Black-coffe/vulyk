---
story: v0-12-0-remainders-01
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-code
tracer: false
wave: 1
blocked_by: []
---

# `judge`/`escalate` count, match and write the ledger correctly

## Goal
The ledger row and its plan-line mirror are right after any number of rounds: `attempts` counts attempts, a round-number match never matches a longer number, the `**Council:**` line lands where C7 says, the append is atomic, an owner override in the same second as the round still wins, and `note` passes through `scripts/redact.sh`.

## Requirements
> attempts считает попытки (LR19)

> номер раунда матчится точно (LR21, r2m1)

> **Council:** ложится по C7, не в EOF (LR25)

> оверрайд в ту же секунду побеждает (m-4)

> запись в леджер атомарна (m-10)

> note проходит redact (N-m7)

## Files
- scripts/cycle.sh
- tests/council.test.sh

## Non-goals
- Do not unify the three seat-scan copies (`cmd_judge`, `write_stale_row`, `write_escalate_row_for_round`) into one helper - r2m8 is next circle. Fix `attempts` in each copy.
- Do not touch `open-round`'s ceiling block, the court, `close-story` or `status` derivations (stories 05, 08).
- Do not change the `council.jsonl` schema, key order or the `**Council:**` line text (C4, C7) - only where the line is written and what `attempts` holds.
- `ship-check.sh:190` has the same same-second defect; story 04 owns it. Do not edit it here.

## Map slice
`memory/map/cycle.md` (`cmd_judge` verdict order, "Writes idempotently", D1 crash rules) · `memory/map/scripts.md` (`redact.sh`, `marker`) · `docs/adr/001-cycle-state-contract.md` D1 row schema, C7 · `recon/tests-ci-hooks-driver.md` §1 (helpers `mk_round`, `write_seat`, `seat_report`, how to add a scenario) · round-3 `review.md` line 23 for current lines: `attempts` `:753-754`, `row_exists` `:185-188`, `escalate_row_exists`/reason grep `:520-523`,`:583`, `**Council:**` appends `:574`,`:767`,`:786`,`:1558`; `plan.md` `## Next circle` LR19, LR21, LR25, r2m1, m-4, m-10, N-m7.

## Acceptance criteria
- [ ] `attempts` in a row equals the number of `record-seat` calls that produced a stored file for the round (`<seat>.md` and every `<seat>.attempt-K.md`), in all three writers; a seat re-asked once counts 2, not 1.
- [ ] `row_exists`, `escalate_row_exists` and the `reason` grep match `"round":N` and `round N` as whole numbers: with a closed round 10 and an open round 1 (three `reopen`s in the fixture, or a fabricated row), `status --json` reports `open:true` and `judge` writes a round-1 row.
- [ ] `**Council:**` is written after the last existing `**Council:**` line, or in place of the placeholder when none exists, in `judge`, `escalate`, the STALE fold and the ceiling block; `marker "$PLAN" Council` then returns the newest line, and a second `judge` is still idempotent.
- [ ] The ledger append is one `printf`/`echo` of the whole row to the file opened once (or a temp file + `mv`), never a sequence of partial writes; a row of 4 KB written while another process reads the file is either absent or whole.
- [ ] A `human.jsonl` REJECTED row whose `ts` equals `ROUND.opened` to the second outranks the round (`>=`, not `>`); the suite scenario writes both with the same timestamp.
- [ ] `note` reaches the row through `scripts/redact.sh`; a note containing a token-shaped string (the shapes `redact.sh` masks) lands masked; `tests/council.test.sh` copies `redact.sh` into the fixture if it does not already.
- [ ] `tests/council.test.sh` gains one scenario per bullet above that fails at `3e200bb` and passes after; the whole suite passes; `bash -n scripts/cycle.sh` passes.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
