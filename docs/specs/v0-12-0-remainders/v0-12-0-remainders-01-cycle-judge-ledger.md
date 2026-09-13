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
Attempt 3. The working tree already carries an uncommitted diff to `scripts/cycle.sh` from two dead attempts: run `git diff scripts/cycle.sh` first, verify it against the criteria below, keep what holds, do not rewrite it. After this story the ledger row and its plan-line mirror are right after any number of rounds: `attempts` counts attempts, a round-number match never matches a longer number, the `**Council:**` line lands where C7 says, the append is atomic, an owner override in the same second as the round still wins, and `note` passes through `scripts/redact.sh`. The suite scenarios that prove each point belong to story 14; this story lands the code and one fixture line.

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
- No new scenarios in `tests/council.test.sh` - story 14 owns them. Touch only the one `cp` line at `tests/council.test.sh:27` (the fixture copy list).
- Do not unify the three seat-scan copies (`cmd_judge`, `write_stale_row`, `write_escalate_row_for_round`) into one helper - r2m8 is next circle. Fix `attempts` in each copy.
- Do not touch `open-round`'s ceiling block logic, the court, `close-story` or `status` derivations (stories 05, 08) beyond routing their `**Council:**` write through the shared helper.
- Do not change the `council.jsonl` schema, key order or the `**Council:**` line text (C4, C7) - only where the line is written and what `attempts` holds.
- `ship-check.sh:190` has the same same-second defect; story 04 owns it. Do not edit it here.

## Map slice
`memory/map/cycle.md` (`cmd_judge` verdict order, "Writes idempotently", D1 crash rules) · `memory/map/scripts.md` (`redact.sh`, `marker`) · `docs/adr/001-cycle-state-contract.md` D1 row schema, C7 · round-3 `review.md` line 23 for lines at `3e200bb`: `attempts` `:753-754`, `row_exists` `:185-188`, `escalate_row_exists`/reason grep `:520-523`,`:583`, `**Council:**` appends `:574`,`:767`,`:786`,`:1558`; `plan.md` `## Next circle` LR19, LR21, LR25, r2m1, m-4, m-10, N-m7.

## Acceptance criteria
- [ ] LR19: `attempts` in a row equals the number of `record-seat` calls that produced a stored file for the round (`<seat>.md` plus every `<seat>.attempt-1.md`/`.attempt-2.md`), in all three copies (`cmd_judge`, `write_stale_row`, `write_escalate_row_for_round`); a seat re-asked once counts 2, not 1.
- [ ] LR21/r2m1: `row_exists`, `escalate_row_exists` and the `## Needs a human` reason grep match the round exactly - the JSON anchor is `"round":N,` with the trailing comma, the prose anchor is `round N` as a whole word; a closed round 10 never satisfies a check for round 1.
- [ ] LR25: one `council_append_line` helper writes `**Council:**` after the last existing `**Council:**` line, or in place of the placeholder when none exists (C7); `judge`, `escalate`, the STALE fold and the ceiling block all call it; `marker "$PLAN" Council` returns the newest line and a second `judge` is still idempotent.
- [ ] m-4: a `human.jsonl` REJECTED row whose `ts` equals `ROUND.opened` to the second outranks the round (`>=`, not `>`).
- [ ] m-10: each ledger row reaches `council.jsonl` as one `printf ... >>` of the whole row (or a temp file + `mv`), never partial writes. Confirm whether `3e200bb` already does this for every writer or fix it, and say which in `## Implementation notes`.
- [ ] N-m7: `note` reaches the row through a `redact_note` helper that pipes through `scripts/redact.sh`; a token-shaped string lands masked.
- [ ] The suite fixture at `tests/council.test.sh:27` also copies `scripts/redact.sh` into the fixture repo (without it `redact_note` pipes into a missing script and blanks every note in the suite).
- [ ] The existing suite passes unchanged; `bash -n scripts/cycle.sh` passes.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
- 2026-09-13 · blocked by the Workflow driver (run wf_e1124ab4-a8a, stamp ab76efbc552c7ce3): two misses, both "worker returned no report" - the worker-code subagent returned an empty result on attempt 1 and again on attempt 2 (per-agent journal: `.claude/projects/.../subagents/workflows/wf_e1124ab4-a8a/journal.jsonl`). Neither attempt was a red verification. Both attempts wrote before dying: the working tree holds an uncommitted 82-line diff to `scripts/cycle.sh` (+63/-19, `git diff --stat` at 39dfbfa) that no story owns and no worker reported. Story 02 (same wave) returned `STATUS: DONE` on its attempt 2 but was never closed: its files (`tests/driver.test.sh` untracked, `CLAUDE.md` +1, `.github/workflows/ci.yml` +13) sit uncommitted beside the cycle.sh diff.
