---
story: v0-12-0-remainders-08
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-code
tracer: false
wave: 5
blocked_by: [v0-12-0-remainders-05, v0-12-0-remainders-15]
---

# `close-story` reads `returned:`, owns its commit, and matches a `&&` cell whole; `wave_stories` lists only ready stories

## Goal
A story closes only when its worker wrote `returned: DONE` (ADR-006), and only when its commit landed or the retry after a failed commit is accepted; `status --json` dispatches only stories whose blockers are done; a `## Commands` cell that itself contains ` && ` can be a verification line. The suite scenarios that prove each point belong to story 16; this story lands the code only.

## Requirements
> история с ответом NEEDS_CONTEXT/WALL не закрывается (M3)

> wave_stories не отдаёт заблокированную (LR31)

> close-story не оставляет done при падении коммита (r2m2)

> ячейка Commands с && матчится целиком (r2m9)

## Files
- scripts/cycle.sh
- tests/council.test.sh
<!-- listed so the verification command reaches this story's files (wave-check); the Non-goals forbid editing it -->

## Non-goals
- No edits to `tests/council.test.sh` - story 16 owns every scenario, including adding `returned: DONE` to the pre-existing `close-story` fixtures. Run the suite once, at the end, as `bash tests/council.test.sh | tail -3` (hundreds of lines, resent every turn). Expect the pre-existing `cstory*` scenarios to go red on the `returned:` gate until story 16 lands: name the red labels in `## Implementation notes` and confirm each is a `returned: missing` refusal, not another failure; any other red is a wall.
- Do not add `--stamp` or the DRIVER check (story 11); do not touch either driver, the worker agent files or `templates/story.md` (story 09).
- `close-story` never writes or clears `returned:`; never writes `blocked`.
- Do not widen the whitelist: the whole-line match against a cell comes first, then the per-segment match; keep the byte-for-byte rule and the `none — reviewed by lead-review` literal.
- Do not implement `repeat` (LR30, next circle); do not change `wave_story_json` keys.
- Do not touch `open-round`, `judge`, `record-seat`.
- Write `returned: DONE` as your last edit - your own `close-story` runs the gate you built; never write `status:` (story 09's rule).

## Map slice
`docs/adr/006-worker-status-channel.md` (the contract table's `cmd_close_story` row) · `plan.md` K1 (exit-4 shape), K5 · `memory/map/cycle.md` (`close-story` rule, `status --json` `next`, `wave_stories`) · `memory/map/scripts.md` gotchas (the whitelist is security-relevant) · round-3 `review.md` line 23 for lines at `3e200bb` (shifted by stories 01 and 05): `wave_stories` `:295`, `&&` split `:1305-1314`, `done` before `git_commit_or_fail` `:1409` vs `:1426`; ADR-006 context: `status:` case `:1343-1355`, scope-check `:1357`.

## Acceptance criteria
- [ ] M3/K5: after the `status:` case and before `scope-check.sh`: `returned: DONE` proceeds; `NEEDS_CONTEXT`, `WALL`, empty or anything else exits 4 with `next:"repair"` and `error:"returned <value>"` (`returned: missing` when the key is empty or absent), `status:` unchanged, no commit, no verification run.
- [ ] r2m2: `close-story --commit` whose commit fails (an `index.lock`) exits 2 with `error` naming the commit and leaves the story `todo|in-progress` on disk - `status: done` is written only after the commit lands; the retry after the lock is removed closes and commits; `status --json` then routes forward, never to `open-round` on a dirty tree.
- [ ] LR31: `wave_stories` lists only `todo`/`in-progress` stories of the wave whose `blocked_by` are all `done`; A (`todo`, blocked_by B) with B `blocked` yields `wave_stories: []`.
- [ ] r2m9: a `## Commands` cell `sh -c 'true && true'`: a `## Verification` line equal to it whole passes and runs; `sh -c 'true && true' && true` is refused naming the segment; the existing per-segment rule is otherwise unchanged.
- [ ] `bash -n scripts/cycle.sh` passes; one suite run through `tail -3`, with the red labels explained per the first non-goal.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
