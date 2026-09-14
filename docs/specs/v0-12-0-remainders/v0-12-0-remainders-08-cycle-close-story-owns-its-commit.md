---
story: v0-12-0-remainders-08
spec: v0-12-0-remainders
status: done
returned: DONE
tier: 4
worker: worker-code
tracer: false
wave: 5
blocked_by: [v0-12-0-remainders-05, v0-12-0-remainders-15]
---

# `close-story` reads `returned:`, owns its commit, and matches a `&&` cell whole; `wave_stories` lists only ready stories

## Goal
A story closes only when its worker wrote `returned: DONE` (ADR-006), and only when its commit landed or the retry after a failed commit is accepted; `status --json` dispatches only stories whose blockers are done; a `## Commands` cell that itself contains ` && ` can be a verification line. The new scenarios that prove each point belong to story 16; this story lands the code plus the one-line `returned: DONE` repair of the pre-existing `close-story` fixtures, so the suite is green at its own close.

## Requirements
> история с ответом NEEDS_CONTEXT/WALL не закрывается (M3)

> wave_stories не отдаёт заблокированную (LR31)

> close-story не оставляет done при падении коммита (r2m2)

> ячейка Commands с && матчится целиком (r2m9)

## Files
- scripts/cycle.sh
- tests/council.test.sh
<!-- edited only to add returned: DONE to the existing close-story fixtures (plan delta 2026-09-14) -->

## Non-goals
- Attempt 3 on the kept diff: `git diff scripts/cycle.sh` first - the four fixes are on disk and read correct; keep what holds. In `tests/council.test.sh` the only edit is one line `returned: DONE` directly after `status:` in each fixture heredoc the suite passes to `close-story` (`grep -n 'council close-story' tests/council.test.sh`; attempt 2 named `cstory1/2/3/5/6/q/bs`) - no new scenario, no changed assertion; story 16 owns every scenario. Run the suite once, at the end, as `bash tests/council.test.sh | tail -3` (hundreds of lines, resent every turn); any red is a wall.
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
- [ ] `bash -n scripts/cycle.sh` passes; `bash tests/council.test.sh` green whole - every pre-existing `close-story` fixture carries `returned: DONE` and passes as before.

## Verification
`bash tests/council.test.sh`

## Implementation notes
- `scripts/cycle.sh` `cmd_close_story`: added the `returned:` gate (M3/K5) right after the
  `status:` case, before `scope-check.sh` - `DONE` proceeds, anything else (`WALL`,
  `NEEDS_CONTEXT`, empty/absent) exits 4 with `next:repair`, `error:"returned <value>"` /
  `"returned: missing"`; `status:` and `returned:` are never touched by this gate.
- `cmd_close_story` `--commit` path (r2m2): moved `status: done` and its `git add` to happen
  right before the commit attempt; a failed `git commit` now reverts the `status:` line back to
  its pre-close value (`todo`/`in-progress`) before exiting 2, so a failed commit never leaves
  `done` uncommitted on disk. Non-`--commit` path unchanged (still sets `done` unconditionally).
- Verification whitelist (r2m9): `command_cell_exists` is now tried against the whole
  `## Verification` line first; only a line that is not itself a literal `## Commands` cell
  falls through to the existing per-`&&`-segment check.
- `wave_stories` (LR31): `status --json`'s per-wave loop used to collect every `todo` **and**
  `in-progress` file in the wave into `WAVE_STORIES` once any story was ready, including
  not-yet-ready `todo` stories whose `blocked_by` wasn't done. Now only the already-collected
  `ready` list (blockers-done todo files) plus all `in-progress` files of the wave are used.
- Verification: `bash tests/council.test.sh | tail -3` (full run also captured, not just the
  tail) - 16 red `::error::` lines, all in the pre-existing `cstory1/cstory2/cstory3/cstory5/
  cstory6/cstoryq/cstorybs` `close-story` scenarios (none of which set `returned:` in their
  fixtures yet - story 16's job). Every one traces to the same root cause: `close-story` now
  exits 4 with `error:"returned: missing"` before scope-check/commit/open-round run, so the
  downstream assertions in those same scenarios (status stays todo, scope.jsonl entry,
  commit message, open-round's story-count) cascade red from that one refusal, not a distinct
  failure. No other scenario in the ~465-line run went red.
- Fixture repair (plan delta): added `returned: DONE` right after `status: todo` in every
  `close-story` fixture heredoc in `tests/council.test.sh` - `cstory1`, `cstory2`, `cstory3`,
  `cstory4`, `cstoryq`, `cstorybs`, `cstory5`, `cstory6` (8 fixtures; `cstory4`'s `&&`-segment
  fixture was also going through `close-story` though not named in the earlier grep). The
  `pauseall` fixture used at line 982 needs no fix - `pause_guard` runs before the `returned:`
  gate. Full run: `bash tests/council.test.sh` exits 0, zero `::error::` lines end to end.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
- 2026-09-14 · blocked by the driver (run wf_54420cc4, wave 5): two `close-story` exit 4 in a row,
  both `error:"bash tests/council.test.sh"` (red verification). Not a code wall - a wave-order
  defect: this story's `returned:` gate makes `close-story` refuse every existing council-suite
  fixture (none sets `returned:`), and the fixtures are story 16's job in wave 6. The story's own
  verification cannot go green before 16 lands. Worker diff sits uncommitted in `scripts/cycle.sh`.
- 2026-09-14 · unblocked by plan delta (fixture repair moved into this story); attempt 3 on the kept diff.
