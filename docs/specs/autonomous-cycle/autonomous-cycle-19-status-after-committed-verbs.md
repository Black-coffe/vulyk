---
story: autonomous-cycle-19
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 8
blocked_by: []
---

# `status --json` tells the truth after every committed verb

## Goal
The driver interface stops lying: after `judge --commit` a RED round routes to `repair`, a stale open round says `open-round` with `stale:true`, a seat that exhausted both attempts leaves `missing`, a reopened spec is no longer terminal, `round_dir` names the open round, a non-required seat has one recorded value, and an unparsable tier is `null` (never a silent 4, never a journal write from `status`). One test walks the real verbs with `--commit` and asserts `status --json` after each step — the assertion both reviewers found absent.

## Requirements
> Потолок 3 раунда → стоп и зов человека

> получаем от наглядательной рады проблематику, идем, решаем, снова тесты, снова приемка, снова наглядовая рада

> After a committed RED judge, `status.next` must be `repair` until a non-paperwork commit lands (the same `paperwork_only` rule the `green` branch already uses at line 335), and a test must drive `open-round --commit` -> `record-seat` x4 -> `judge --commit` -> `status` and assert `repair`.

> the `repair` derivation must treat a RED row as current when only the cycle's own paperwork landed since the round's head, so that a RED round judged with `--commit` routes to `repair` and not to a fresh round.

> For an open round that `round_is_stale` reports stale, `status` must return `open-round` (never `dispatch:`/`judge`) and `stale:true` whether or not a seat file exists.

> `missing` must exclude a seat whose `<seat>.attempt-2.md` exists without `<seat>.md`, so `next` reaches `judge` and the `env` escalation is reachable through a driver.

> after `reopen`, `status` must route to `open-round` rather than remaining terminal.

> the plan template must offer Tier 1, and the default for an unparsable `**Tier:**` must not silently buy the largest court.

> `status` must not write to disk on any path.

> `round_dir` must name the open round's directory

> C3 gains `"tier":1|2|3|4|null` (the round's frozen tier while a round is open, else the plan's)

## Files
- scripts/cycle.sh
- tests/council.test.sh

## Non-goals
- Do not touch `record-seat`'s parsing, taint or evidence rules, the `half` threshold or the ABSENT verdict row — story 20 (the fixtures here write seat files directly through `write_seat`, as today).
- Do not change `open-round`'s ceiling record, `escalate`, `close-story`, git error handling or `lib.sh`'s whitelist — story 21.
- Do not add a default tier back under another name; `null` is the answer and `open-round`'s exit 2 is the stop.
- Do not edit the JS driver, the command files or `templates/plan.md` (stories 22, 23, 25).
- Do not change C2's verbs, exit codes or last-line JSON shape; this story changes what `status` derives, plus one new file `council/REOPEN` and one new key `tier`.

## Map slice
`scripts/cycle.sh` — `cmd_status` (the `next` first-match chain, `stale`, `round_dir`, `missing_required_seats`), `round_is_stale` (story 17), `tier_of`/`round_tier` (story 18), `cmd_reopen`, the row writers in `cmd_judge` and `write_stale_row` (the `""` value) · `tests/council.test.sh` — `mk_open_round`, `write_seat`, `seat_report`, `set_tier`, `expect` · `plan.md` `## Plan deltas` entry 6: R1, R2, R3, R7, R12, R21, R25 and the contract-amendments line · `## Contracts` C3, C4.

## Acceptance criteria
- [ ] `next` derivation (C3 amended): `repair` iff the newest row is RED and `round_is_stale`'s rule says only paperwork landed since the row's `head`; `open-round` on a RED row only when a non-paperwork commit landed; an open round that is stale (code moved since `ROUND.head`) yields `stale:true` and `next:"open-round"` with or without a seat file, never `dispatch:`/`judge`.
- [ ] `missing` lists a required seat only while neither `<seat>.md` nor `<seat>.attempt-2.md` exists; with every required seat recorded or exhausted, `next` is `judge`; `judge` then runs and writes a row with `<seat>:"ABSENT"` for the exhausted seat (the verdict it computes is story 20's business — assert only that it exits and the row exists).
- [ ] `reopen` writes `council/REOPEN` (one line `round=<N> · <ts>`) and `--commit` commits it; `status` says `escalated` only when the newest row is ESCALATE and no `REOPEN` names its round; after `reopen` it says `open-round`, and the next `open-round` opens round N+1 at the raised ceiling.
- [ ] `tier` key: the open round's frozen `tier=`, else the plan's `**Tier:**` digit, else `null`; with `null`, `next` is `open-round` and `open-round` exits 2 with `error` naming the `**Tier:**` line; `tier_of` no longer journals — `journal.md` is byte-identical before and after `status` on a plan without a Tier line.
- [ ] `round_dir` is `docs/specs/<slug>/council/round-N` of the open round while one is open, else of the newest row, else `null`; a non-required seat is written as `""` by `judge` and by the STALE fold alike (C4 seat enum `GREEN|RED|N/A|ABSENT|""`).
- [ ] Test "real verbs": fixture spec at Tier 2, `open-round --commit`, then `record-seat` per required seat through stdin (one evidenced RED on ask 2), `judge --commit`, then `status --json` asserts `next:"repair"`, `verdict:"RED"`, `red:[2]`, `round_dir` set; a commit to `src/x.txt` flips `status` to `next:"open-round"`; rounds 2 and 3 RED the same way, then `status` says `escalated`; `reopen --commit` then `status` says `open-round`; `open-round --commit` opens round 4.
- [ ] Test "stale open round": `open-round --commit`, commit `src/x.txt`, no seat file → `status` `stale:true`, `next:"open-round"`; same with a seat file present.
- [ ] Test "exhausted seat": two malformed haiku reports on a Tier 3 fixture → `status` `missing` without `haiku`; after sonnet, opus and review are recorded → `next:"judge"`; `judge` exits and the row carries `haiku:"ABSENT"`.
- [ ] Every existing check stays green; `bash tests/council.test.sh` exits 0 with no `::error::` line.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
