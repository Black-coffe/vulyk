---
story: autonomous-cycle-17
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 6
blocked_by: [autonomous-cycle-15]
---

# A round is stale only when code moved, never when the cycle's own paperwork was committed

## Goal
Every staleness decision in `cycle.sh` goes through one helper built on `paperwork_only` from `lib.sh`, so `open-round --commit`, `record-seat --commit`, `judge --commit` and a `**Council:**` line commit never make a round STALE; only a commit that touches something outside the paperwork whitelist does. The real loop — open a round, commit, record three seats, judge — runs end to end without a false STALE.

## Requirements
> `record-seat`'s staleness check and `status --json`'s `stale` field compare the round's recorded `head` to the current HEAD with plain equality, not through `paperwork_only`; so the first `record-seat` after a real `open-round --commit` (which itself moves HEAD by one paperwork commit) reads the round as STALE although no code moved.

> every place `cycle.sh` decides "stale" — `record-seat`, `status` (`stale`, and the `next` derivation `green`/`open-round` on GREEN gone stale), `open-round`'s STALE-row fold — uses one helper `round_is_stale <spec> <N>` built on `paperwork_only` from `lib.sh`, so a commit touching only plan.md, journal.md, `council/*`, `memory/stats/*.jsonl` never stales a round

## Files
- scripts/cycle.sh
- tests/council.test.sh

## Non-goals
- Do not change the `paperwork_only` whitelist in `scripts/lib.sh` (story 01/C1 owns it); if a path the cycle writes is missing from it, report the path in CONCERNS instead of widening the list here.
- Do not change the C3 object's keys or the C2 verbs, exit codes or last-line JSON; this story changes how `stale` is computed, not what is emitted.
- Do not touch `ship-check.sh`'s own head/paperwork logic (story 02) — it already uses `paperwork_only`; this story brings `cycle.sh` to the same rule.
- Do not remove `--commit` from any verb.

## Map slice
`scripts/cycle.sh` — the three staleness sites: `cmd_record_seat` (its head comparison), the `status` builder (`stale` field and the `next` derivation for `green` vs `open-round`), `cmd_open_round` (the STALE-row fold when HEAD moved) · `scripts/lib.sh` — `paperwork_only <root> <from> <to>` and its whitelist (C1) · `scripts/ship-check.sh` — the existing "HEAD or paperwork-only since" pattern to mirror · `tests/council.test.sh` — the `open-round` and `record-seat` scenarios (fixture repos, `expect()`), plan.md `## Contracts` C2, C3, C4.

## Acceptance criteria
- [ ] `scripts/cycle.sh` has one function `round_is_stale` (or equivalently named, one definition) that returns "stale" iff the round's recorded `head` differs from HEAD **and** `paperwork_only <root> <head> HEAD` is false; `record-seat`, `status` and `open-round` all call it and contain no other `head == HEAD` comparison for staleness.
- [ ] Test: in a fixture repo, `open-round --commit` then `record-seat` for one seat exits 0 and writes `<seat>.md` at attempt 1; `status --json` shows `stale:false` and `next` still `dispatch:...` for the missing seats.
- [ ] Test: after `record-seat --commit` (a paperwork commit), `status --json` still shows `stale:false`.
- [ ] Test: a commit that changes a tracked non-paperwork file (e.g. `src/x.txt` in the fixture) after `open-round` makes `status --json` show `stale:true`, `record-seat` exit 5, and the next `open-round` fold a STALE row and open round N+1 — the existing behaviour, now only for real code moves.
- [ ] The whole suite stays green (`bash tests/council.test.sh` exit 0, no `::error::` lines).

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
