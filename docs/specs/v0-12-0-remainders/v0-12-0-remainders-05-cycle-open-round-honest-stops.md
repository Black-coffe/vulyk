---
story: v0-12-0-remainders-05
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-code
tracer: false
wave: 2
blocked_by: [v0-12-0-remainders-01]
---

# `open-round` stops honestly: every refusal names itself, the ceiling block carries its RED rows, the court commit is real

## Goal
`open-round` never reports a no-op it did not earn, refuses a blocked story by name, reads a round directory without `ROUND` as not open, writes the RED rows into the ceiling block, commits the court reduction without hooks or signing and fails loudly when that commit fails; every `ok:false` line in `cycle.sh` carries `error`, and exit 6 is `ok:true`/`escalated` from every verb.

## Requirements
> no-op ветка open-round коммитит незакоммиченный ROUND (r2m3)

> каждый ok:false несёт error, exit 6 значит одно и то же везде (r2m4/N-m1)

> блок потолка несёт RED-строки и имеет тест (r2m5, r2m6)

> коммит редукции суда без || true, с --no-verify и без подписи (r2m7/N-m2)

> open-round отказывает blocked-истории (r2m16)

> каталог раунда без ROUND не читается как открытый (N-m3)

## Files
- scripts/cycle.sh
- tests/council.test.sh

## Non-goals
- Do not touch `close-story`, `wave_stories` or the `&&` cell match (story 08), nor `attempts`/`row_exists`/`**Council:**` placement (story 01, already landed - build on it).
- Do not add a `next` value or change C3 keys; a blocked story is an exit-2 refusal (K1), not a new state.
- Do not change `judge`'s or `escalate`'s exit codes; only `open-round`'s exit-6 emit changes to `ok:true` (plan `## Assumptions`).
- Do not make `record-seat` or `pause` do anything new beyond carrying `error` on their `ok:false` lines.

## Map slice
`memory/map/cycle.md` (`open-round`, staleness/ceiling, court D5) · `plan.md` K1 (emit invariants - build exactly this), `## Assumptions` (exit 6, r2m16) · round-3 `review.md` line 23 for current lines: no-op branch `:1652-1653`, `ok:false` without `error` at `:78` (pause), `~:1228` (stale), `:1669`, `:1683`; `open-round` accepts `blocked` `:1591`; reduction commit `|| true` `:1488-1490`; a round dir without `ROUND` reads open `:108-118`; ceiling block `write_escalate_row_for_round` `:541-560` · `recon/tests-ci-hooks-driver.md` §1 (`oceil1`/`ceil1` fixtures, `mk_open_round`, `write_seat`, `lockfail1` for the index.lock pattern) · `plan.md` `## Next circle` r2m3-r2m7, r2m16, N-m1-m3.

## Acceptance criteria
- [ ] No-op branch: with `ROUND`/`journal.md` uncommitted (simulate a failed first `--commit` via `index.lock`, then remove it), a second `open-round --commit` commits them and exits 0; `git status --porcelain docs/specs/<slug>` is empty afterwards.
- [ ] A spec with a `status: blocked` story: `open-round` exits 2 with the K1 error naming the story id and file; nothing is created under `council/`.
- [ ] `council/round-N/` without `ROUND`: `status --json` says `open:false`, `next:"open-round"`; `open-round` rewrites `ROUND` in that directory (same N) rather than reporting a no-op or opening N+1.
- [ ] Ceiling block: a RED round N-1 judged with `red:[2,5]`, a code commit, then `open-round` at N = ceiling: the ESCALATE row carries `red:[2,5]`, the `## Needs a human` block has one `- ask <n>:` line per RED ask with the evidence clause, and `seats:` names the round directory; the STALE-fold ceiling path (`:1639-1647`) has its own scenario asserting the same.
- [ ] The court reduction commit runs `git -c commit.gpgsign=false commit --no-verify ...` with no `|| true`; a fixture pre-commit hook that exits 1 in the court's hooks path makes `open-round` exit 2 with `error` naming the reduction commit and the court is removed, never handed over.
- [ ] Every `emit` with `ok:false` in the file carries a non-empty `error` (grep the emit call sites; the suite asserts `jq -e '.ok or (.error|length>0)'` on every last line it captures); `open-round` at the ceiling emits `{"ok":true,...,"exit":6,"next":"escalated"}` exactly like `judge`/`escalate`.
- [ ] One suite scenario per bullet, each failing at `3e200bb`; the whole suite passes.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
