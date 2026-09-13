---
story: v0-12-0-remainders-08
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-code
tracer: false
wave: 3
blocked_by: [v0-12-0-remainders-05]
---

# `close-story` reads `returned:`, owns its commit, and matches a `&&` cell whole; `wave_stories` lists only ready stories

## Goal
A story closes only when its worker wrote `returned: DONE` (ADR-006), and only when its commit landed or the retry after a failed commit is accepted; `status --json` dispatches only stories whose blockers are done; a `## Commands` cell that itself contains ` && ` can be a verification line.

## Requirements
> история с ответом NEEDS_CONTEXT/WALL не закрывается (M3)

> wave_stories не отдаёт заблокированную (LR31)

> close-story не оставляет done при падении коммита (r2m2)

> ячейка Commands с && матчится целиком (r2m9)

## Files
- scripts/cycle.sh
- tests/council.test.sh

## Non-goals
- Do not add `--stamp` or the DRIVER check (story 11); do not touch either driver, the worker agent files or `templates/story.md` (story 09).
- `close-story` never writes or clears `returned:`; never writes `blocked`.
- Do not widen the whitelist: the whole-line match against a cell comes first, then the per-segment match; keep the byte-for-byte rule and the `none — reviewed by lead-review` literal.
- Do not implement `repeat` (LR30, next circle); do not change `wave_story_json` keys.
- Do not touch `open-round`, `judge`, `record-seat`.
- Set `returned: DONE` in this story's own frontmatter before returning - your own `close-story` runs the gate you built.

## Map slice
`docs/adr/006-worker-status-channel.md` (the contract table's `cmd_close_story` row; `## How the tests prove it` - `cstoryr1..r4` exactly) · `plan.md` K1 (exit-4 shape), K5 · `memory/map/cycle.md` (`close-story` rule, `status --json` `next`, `wave_stories`) · `memory/map/scripts.md` gotchas (the whitelist is security-relevant) · round-3 `review.md` line 23: `wave_stories` `:295`, `&&` split `:1305-1314`, `done` before `git_commit_or_fail` `:1409` vs `:1426`; ADR-006 context: `status:` case `:1343-1355`, scope-check `:1357` · `recon/tests-ci-hooks-driver.md` §1 (`cstory*` fixtures, the fixture `## Commands` table, `lockfail1`).

## Acceptance criteria
- [ ] After the `status:` case and before `scope-check.sh`: `returned: DONE` proceeds; `NEEDS_CONTEXT`, `WALL`, empty or anything else exits 4 with `next:"repair"` and `error:"returned <value>"` (`returned: missing` when empty), `status:` unchanged, no commit, no verification run.
- [ ] Suite: `cstoryr1` (DONE, `true` -> exit 0, `status: done`, one commit); `cstoryr2` (WALL, `none — reviewed by lead-review` -> exit 4, `"error":"returned WALL"`, `status:` still `in-progress`, no new commit); `cstoryr3` (key absent -> `returned: missing`); `cstoryr4` (NEEDS_CONTEXT with the flag-file command -> exit 4 and the flag absent). Every pre-existing `close-story` fixture gains `returned: DONE`.
- [ ] `close-story --commit` with `index.lock` present: exit 2 with `error` naming the commit, the story still `todo|in-progress` on disk; after removing the lock the retry closes and commits; `status --json` then routes forward, never to `open-round` on a dirty tree.
- [ ] `wave_stories` lists only `todo`/`in-progress` stories of the wave whose `blocked_by` are all `done`; A (`todo`, blocked_by B) with B `blocked` yields `wave_stories: []`.
- [ ] A fixture cell `sh -c 'true && true'`: a `## Verification` line equal to it whole passes and runs; `sh -c 'true && true' && true` is refused naming the segment; `cstoryq`/`cstorybs` still pass.
- [ ] One suite scenario per bullet failing at `3e200bb`; suite passes; `bash -n` passes.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
