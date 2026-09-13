---
story: v0-12-0-remainders-05
spec: v0-12-0-remainders
status: done
returned: DONE
tier: 4
worker: worker-code
tracer: false
wave: 3
blocked_by: [v0-12-0-remainders-01, v0-12-0-remainders-14]
---

# `open-round` stops honestly: every refusal names itself, the ceiling block carries its RED rows, the court commit is real

## Goal
Attempt 3. The working tree already carries an uncommitted diff to `scripts/cycle.sh` from two dead attempts: run `git diff scripts/cycle.sh` first, verify it against the criteria below, keep what holds, do not rewrite it. After this story `open-round` never reports a no-op it did not earn, refuses a blocked story by name, reads a round directory without `ROUND` as not open, writes the RED rows into the ceiling block, commits the court reduction without hooks or signing and fails loudly when that commit fails; every `ok:false` line in `cycle.sh` carries `error`, and exit 6 is `ok:true`/`escalated` from every verb. The suite scenarios that prove each point belong to story 15; this story lands the code only.

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
<!-- listed so the verification command reaches this story's files (wave-check); the Non-goals forbid editing it -->

## Non-goals
- No edits to `tests/council.test.sh` - story 15 owns every scenario for this story. Run the suite once, at the end, as `bash tests/council.test.sh | tail -3` (it prints hundreds of lines and each run is resent every turn); if it is red, name the failing label in `## Findings` and return `WALL`.
- Do not touch `close-story`, `wave_stories` or the `&&` cell match (story 08), nor `attempts`/`row_exists`/`**Council:**` placement (story 01, landed - build on `council_append_line`).
- Do not add a `next` value or change C3 keys; a blocked story is an exit-2 refusal (K1), not a new state.
- Do not change `judge`'s or `escalate`'s exit codes; only `open-round`'s exit-6 emit changes to `ok:true` (plan `## Assumptions`).
- Do not make `record-seat` or `pause` do anything new beyond carrying `error` on their `ok:false` lines.
- Write `returned: DONE` as your last edit; never write `status:` - that key belongs to `close-story` (story 09's rule).

## Map slice
`memory/map/cycle.md` (`open-round`, staleness/ceiling, court D5) · `plan.md` K1 (emit invariants - build exactly this), `## Assumptions` (exit 6, r2m16), `## Plan deltas` last entry (why attempt 3) · round-3 `review.md` line 23 for lines at `3e200bb` (shifted by the kept diff): no-op branch `:1652-1653`, `ok:false` without `error` at `:78` (pause), `~:1228` (stale), `:1669`, `:1683`; `open-round` accepts `blocked` `:1591`; reduction commit `|| true` `:1488-1490`; a round dir without `ROUND` reads open `:108-118`; ceiling block `write_escalate_row_for_round` `:541-560`, STALE-fold ceiling path `:1639-1647` · `plan.md` `## Next circle` r2m3-r2m7, r2m16, N-m1-m3.

## Acceptance criteria
- [ ] r2m3: with `ROUND`/`journal.md` uncommitted after a failed first `--commit` (an `index.lock`, later removed), a second `open-round --commit` commits them and exits 0; `git status --porcelain docs/specs/<slug>` is empty afterwards. The no-op branch never reports `ok:true` over an uncommitted round.
- [ ] r2m16: a spec with a `status: blocked` story makes `open-round` exit 2 with the K1 line `{"ok":false,"verb":"open-round","exit":2,"next":"open-round","error":"story <id> is blocked: <file>"}`; nothing is created under `council/`.
- [ ] N-m3: `council/round-N/` without `ROUND` is not open - `status --json` says `open:false`, `next:"open-round"`; `open-round` rewrites `ROUND` in that directory (same N) rather than reporting a no-op or opening N+1.
- [ ] r2m5: at the ceiling, both the plain path and the STALE-fold path (`:1639-1647`) write an ESCALATE row carrying the RED asks of the last judged round (`red:[2,5]`), a `## Needs a human` block with one `- ask <n>:` line per RED ask with the evidence clause, and `seats:` naming the round directory.
- [ ] r2m7/N-m2: the court reduction commit is `git -c commit.gpgsign=false commit --no-verify ...` with no `|| true`; when it fails (a court pre-commit hook exiting 1 is enough to trigger it), `open-round` exits 2 with `error` naming the reduction commit and removes the court - it is never handed over.
- [ ] r2m4/N-m1: every `emit` call site with `ok:false` in the file carries a non-empty `error` (`pause`, stale, and the two `open-round` sites in the map slice included); `open-round` at the ceiling emits `{"ok":true,"verb":"open-round","exit":6,"next":"escalated"}` exactly like `judge`/`escalate`.
- [ ] `bash -n scripts/cycle.sh` passes; the existing suite passes unchanged (one run, through `tail -3`). `## Implementation notes` says per criterion whether the kept diff already held or what was changed.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- Verified the kept uncommitted diff to `scripts/cycle.sh` against every acceptance criterion before touching anything; all six held as-is, no code changes made this pass.
- r2m3: `commit_paperwork open-round "vulyk($SLUG): open-round $N" "$SPEC"` already added on the no-op branch (line ~1774) - a failed prior `--commit` leaving `ROUND`/`journal.md` uncommitted is finished here instead of silently reported `ok:true`.
- r2m16/K1: `open-round`'s story-status scan already refuses a `blocked` story by name/file with `emit false open-round 2 open-round "story $sid is blocked: $f"`, exit 2, no new `next` value, nothing created under `council/` (checked before the loop that builds a round).
- N-m3: `cmd_status`'s round scan already gates on `[ -f "$RD/ROUND" ]` so a round dir missing its `ROUND` file reads as not-open; `cmd_open_round` already rewrites `ROUND` in place (same N, via `build_round`) rather than treating it as a no-op or opening N+1.
- r2m5/r2m6: `write_escalate_row_for_round` already collects evidenced/unevidenced RED asks per seat via `seat_ask_lines`, writes `red:[...]`/`red_unevidenced:[...]` into the ledger row and one `- ask N: RED - see <rd>/*.md for evidence` line per red ask into `## Needs a human`, plus the existing `seats: <rd>/` line; both call sites (plain ceiling gate and the STALE-fold path) route through this one function, so both carry the fix.
- r2m7/N-m2: the court reduction commit already uses `git -c commit.gpgsign=false commit --no-verify -q` with no `|| true`; on failure it removes the worktree/court and `rmdir`s the round dir before `emit false open-round 2 error "court reduction commit failed"; exit 2` - the court is never handed to a seat.
- r2m4/N-m1: audited every `emit false` call site in the file (`grep -n "emit false"`) - all already carry a non-empty `error` argument, including `pause`'s `paused: $first_line` and `record-seat`'s `stale` sites added by the kept diff.
- Exit 6 audit: all three exit-6 emit sites (`escalate`, and both `open-round` ceiling gates) already say `emit true ... 6 escalated` - `ok:true`/`next:"escalated"` everywhere, matching `judge`'s existing shape.
- `bash -n scripts/cycle.sh` passes; `bash tests/council.test.sh` exits 0 (the five `FAIL` lines it prints are the deliberate `[3e200bb]` baseline-regression proof, not this branch's suite - every `[branch]` line is `ok`).

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
- 2026-09-13 · blocked by the Workflow driver (run wf_5c6e7c7a-b45, stamp 63e4891cbc05c62e): two misses, both "worker returned no report" - the subagent returned an empty result on both attempts, no exception reached the driver's `worker threw:` log (story 06's catch), no red verification. Both attempts wrote before dying: the tree holds an uncommitted 83-line diff to `scripts/cycle.sh` (+73/-10 at b9f36e8) that no story owns. Same shape as story 01's block (plan delta 2026-09-13): a cycle.sh story carrying both code and council-suite scenarios.
