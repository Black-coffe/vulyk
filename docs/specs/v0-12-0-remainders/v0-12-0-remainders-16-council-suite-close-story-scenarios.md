---
story: v0-12-0-remainders-16
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-test
tracer: false
wave: 6
blocked_by: [v0-12-0-remainders-08]
---

# The council suite proves the four `close-story`/`wave_stories` fixes of story 08

## Goal
`tests/council.test.sh` gains the `cstoryr1..r4` scenarios for the `returned:` gate and one scenario each for the commit-owns-`done` rule, the ready-only `wave_stories` and the whole-cell `&&` match, each shown to fail against the `cycle.sh` from before story 08's commit and to pass against the branch. The code is already on the branch; this story is the evidence.

## Requirements
> история с ответом NEEDS_CONTEXT/WALL не закрывается (M3)

> wave_stories не отдаёт заблокированную (LR31)

> close-story не оставляет done при падении коммита (r2m2)

> ячейка Commands с && матчится целиком (r2m9)

## Files
- tests/council.test.sh

## Non-goals
- Do not edit `scripts/cycle.sh`. A scenario red against the branch is a wall: record the failing assertion under `## Findings` and return `WALL`; do not patch the script or weaken the assertion.
- Do not add scenarios for the semaphore (story 17) or touch stories 14/15's scenarios and probe entries.
- Do not restructure the suite's helpers; add scenarios in the existing shape and extend `run_wall_probes` with one more pinned version rather than writing a second runner.
- Do not use `git stash` or checkout to reach the pre-story script; the working tree stays untouched by the proof.
- Run the suite once, at the end, as `bash tests/council.test.sh | tail -3`.
- Write `returned: DONE` as your last edit; never write `status:` (story 09's rule).

## Map slice
`docs/adr/006-worker-status-channel.md` (`## How the tests prove it` - `cstoryr1..r4` exactly) · `recon/tests-ci-hooks-driver.md` §1 (`cstory*` fixtures, the fixture `## Commands` table, `lockfail1`, "To add one scenario") · `memory/map/cycle.md` (`close-story` rule, `status --json` `next`, `wave_stories`) · story 08 `## Acceptance criteria` and `## Implementation notes` · story 14 `## Implementation notes` (the `run_wall_probes` shape). The pre-story script is `git show <sha>^:scripts/cycle.sh` where `<sha>` is `git log -1 --format=%h --grep='story(v0-12-0-remainders-08)'`.

## Acceptance criteria
- [ ] `cstoryr1`: `returned: DONE`, verification `true` -> exit 0, `status: done`, exactly one new commit. `cstoryr2`: `returned: WALL`, verification `none — reviewed by lead-review` -> exit 4, last line `"error":"returned WALL"`, `next:"repair"`, `status:` still `in-progress`, no new commit. `cstoryr3`: key absent -> exit 4, `"error":"returned: missing"`. `cstoryr4`: `returned: NEEDS_CONTEXT` with a verification that touches a flag file -> exit 4 and the flag absent (verification never ran).
- [ ] The pre-existing `close-story` fixtures already carry `returned: DONE` (story 08); no line of those scenarios changes.
- [ ] r2m2 scenario: `close-story --commit` with `index.lock` present exits 2 with `error` naming the commit and the story file still reads `todo|in-progress`; lock removed, the retry exits 0 with `status: done` and one commit; `status --json` afterwards does not say `next:"open-round"` while the tree is dirty.
- [ ] LR31 scenario: story A `todo` with `blocked_by: [B]`, B `blocked`, both in one wave: `status --json` reports `wave_stories: []`; with B `done`, A is listed.
- [ ] r2m9 scenario: a fixture `## Commands` cell `sh -c 'true && true'`; a `## Verification` line equal to it whole closes the story; `sh -c 'true && true' && true` is refused with the segment named; `cstoryq`/`cstorybs` unchanged and green.
- [ ] Each scenario is proven to fail at the pre-story script without touching the working tree, in the `run_wall_probes` shape; `## Implementation notes` records the `FAIL` labels observed there and the `ok` labels on the branch - a scenario that is `ok` pre-story is recorded as observed, with the reason, never forced.
- [ ] `bash tests/council.test.sh` passes whole on the branch.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
