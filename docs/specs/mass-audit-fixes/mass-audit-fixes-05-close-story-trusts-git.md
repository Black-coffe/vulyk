---
story: mass-audit-fixes-05
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
model: opus
wave: 1
blocked_by: []
red: required
red_reason: blocks differ from the approved version
red_verified_at: 2026-11-09T13:27:20Z be1bff86924459d2038609d49fcea606f06214460f2181fd0d4f89b324d57d39
---

# close-story reads its gate blocks from the story's approved commit; a close is a commit

## Goal
ADR-032 D1 and D2 in `scripts/cycle.sh`, with the fixtures of two suites moved onto the new rule. D1:
`approved_rev <story>` finds the newest commit touching the story whose subject is a paperwork subject
(`vulyk(<slug>): ...` / `chore(vulyk-<slug>): ...`); `close-story` (after the `returned:` check, before
scope-check) and `stamp-red` (before anything) compare `## Verification` (with `repeat:`), `## Files` and `red:`
of `git show <sha>:<story>` with the working copy through `verify_of`, `files_of`, `fm_red`, and refuse (exit
4, `story blocks differ from the approved version (<sha7>): <blocks>`) on any difference; no baseline at Tier
3-4 is exit 2, at Tier 1-2 or with no tier a stderr note. D2: `cmd_status` counts a `done` story as done only
when `git log --format=%s -- <spec>/` holds `story(<id>):` (or `chore(story-<id>):`), else it is in-progress;
`close-story` on a `done` story with a clean tree and no close commit takes the self-marked path and, green,
commits with `--allow-empty` and journals `closed over a hand-committed tree`. Private audit (2026-11-08)
findings G1, G2, I6. `model: opus`: long-horizon, two suites' fixtures (18 sites) move with the rule and the
gate's semantics need judgment at every site. Marked red: a security gate.

## Requirements
> 12. close-story reads `## Verification`, `## Files` and `red:` from the story's approved version in git and refuses when the working copy differs in them; a story marked done without close-story's own commit is not closed.

## Files
- scripts/cycle.sh
- tests/cycle.test.sh
- tests/council.test.sh

## Non-goals
- Do not add a state file, a `closed:` line or a hash field (ADR-032 rejected options 4 and 5).
- Do not change the driver (`vulyk-cycle.js`), `state.sh`, `scope-check.sh` or `wave-check.sh`: D2 is designed
  so that `wave_stories` and `left.has` need no change.
- Do not write `briefed --go`, the block-card call, `stamp-red --baseline`, `verify_files_hash` or the
  `git add` check: stories 08 and 10 own those parts of `cycle.sh` in later waves.
- Do not touch agent or command prose (`revised <story-id>` is story 13's).
- Every test-file edit (the helper, the 12 `cycle.test.sh` and ~9 `council.test.sh` fixture sites, the new
  cases) happens before `stamp-red`; the sealed tests are not edited after the receipt.

## Map slice
`memory/map/cycle.md` → Files one writer each, Verbs (close-story, stamp-red, Red receipt), `status --json`
`next`, Staleness; `memory/map/scripts.md` → Entry points (`lib.sh`), Gotchas (anchored string matches).

## Acceptance criteria
- [ ] One helper in each suite (`tests/cycle.test.sh`, `tests/council.test.sh`) writes a `done` fixture story
  and commits it under `story(<id>): <title>`; every hand-written `status: done` fixture (`cycle.test.sh`
  lines near 73, 185, 207, 218, 270, 294, 305, 738, 1273, 1447, 1475-1476; `council.test.sh` `mk_spec` and the
  sites near 2164, 4063, 4122, 4140, 4223, 4437-4438, 4749-4750, 4762) goes through it, and every part of both
  suites stays green.
- [ ] A Tier 3 story committed under `vulyk(<slug>): plan` whose working copy swaps a `## Verification` line
  for the `none` literal, widens `## Files`, or drops `red: required` gets exit 4 naming the blocks and the
  short sha; `returned:`, `## Findings`, `red_reason:` and notes may differ freely. The label contains
  `blocks differ from the approved version`.
- [ ] A Tier 3 untracked story gets exit 2 `no approved version in git`; a Tier 1 untracked story closes with
  one stderr note. A story revised and committed as `vulyk(<slug>): revised <id>` closes against the revision.
- [ ] `status --json` lists a `done` story with no close commit as in-progress and `next` stays `build:<wave>`
  / `close-story:<file>`; after a `story(<id>):` commit it is done.
- [ ] `close-story` on a hand-marked, hand-committed story runs the gates and writes an `--allow-empty` close
  commit with the journal line; a failing verification there is exit 4, not "already done".
- [ ] `tests/council.test.sh` C3 case (self-marked `done` with a dirty diff) still passes with the new path.

## Verification
`bash tests/cycle.test.sh --part ship && bash tests/cycle.test.sh --part close && bash tests/cycle.test.sh --part red`
`bash tests/council.test.sh --part verbs && bash tests/council.test.sh --part close`

## Implementation notes
- scripts/cycle.sh: `approved_rev`, `story_blocks_guard` (D1, called in close-story after `returned:` and in stamp-red after the guards), `close_subjects` + `has_close_commit` (D2, in `cmd_status` and close-story's done path).
- D1 compares the three blocks through `verify_of`/`files_of`/`fm_red`, CR stripped on both sides; a `git show` that fails yields an empty baseline and so refuses (fail closed).
- D2 hand-committed close: the journal line goes into the close commit (`$SPECDIR/journal.md` staged), because an empty `--allow-empty` commit is pruned from `git log -- <spec>/` and status would never see it; `--allow-empty` stays as the fallback.
- `story_status_for_id` (blockers) still reads the raw `done`; only status counts and the wave walk use D2, as the ADR names.
- tests: one `done_story` helper per suite (writes or flips, commits alone under `story(<id>): <title>`); sites also found beyond the listed ones: cycle `man_story`, council r18rp heredocs; site 185 now commits the deletion of its fixture; site 738's `git checkout` restore dropped (the commit leaves a clean tree).
- New cases in cycle part close: D1 (none literal, widened Files, dropped red: for close-story and stamp-red, free fields, revision, Tier 3/Tier 1 untracked) and D2 (status in-progress/next, hand-committed close commit + journal, failing verification exit 4, already done after).
- Surprise: `sed_inplace` with several files leaves a `.bak` of all but the last (it removes only `${!#}.bak`); the new cases call it per file.
- Built and run against both suites (every part) in a scratch copy of the repo before stamp-red, so the sealed tests needed no edit after the receipt.

## Findings

## Red receipt
- command: bash tests/cycle.test.sh --part ship && bash tests/cycle.test.sh --part close && bash tests/cycle.test.sh --part red
- exit: 1
- tests: be1bff86924459d2038609d49fcea606f06214460f2181fd0d4f89b324d57d39 (tests/council.test.sh, tests/cycle.test.sh)
- impl: 6d691c8bb9f99af64ebc85d3a98d2afe699e85938fe95bdac8ab880c059efa0f
- stamped: 2026-11-09T13:27:20Z

```
::error::a ## Verification swapped for none: story blocks differ from the approved version - exit=2 out=scope-check: trust-01 - declared 1, changed 0, out of scope 0
::error::a widened ## Files: story blocks differ from the approved version - exit=0 out=scope-check: trust-01 - declared 2, changed 0, out of scope 0
::error::red: required dropped: story blocks differ from the approved version - exit=0 out=scope-check: trust-02 - declared 1, changed 0, out of scope 0
::error::hand-committed close: exit=0 log=hand-marked done out=cycle: hand-01 - already done, nothing to close
{"ok":true,"verb":"close-story","exit":0,"next":"build:2","now":1794230749,"status":{"spec":"docs/specs/hand","slug":"hand","stage":"01-spec","next":"build:2","briefed":true,"approved":true,"branch":"vulyk/demo","head":"8f15471","pack":"2dcb248740cc","now":1794230748,"stories":{"todo":1,"in-progress":0,"done":2,"blocked":0},"wave":2,"wave_stories":[{"file":"docs/specs/hand/hand-03.md","story":"hand-03","worker":"worker-code","model":"","repeat":1}],"round":0,"ceiling":3,"tier":null,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}}
::error::after the story(<id>) commit the story is done - expected '"stories":{"todo":1,"in-progress":1,"done":1,"blocked":0}' in:
        {"spec":"docs/specs/hand","slug":"hand","stage":"01-spec","next":"build:2","briefed":true,"approved":true,"branch":"vulyk/demo","head":"8f15471","pack":"2dcb248740cc","now":1794230749,"stories":{"todo":1,"in-progress":0,"done":2,"blocked":0},"wave":2,"wave_stories":[{"file":"docs/specs/hand/hand-03.md","story":"hand-03","worker":"worker-code","model":"","repeat":1}],"round":0,"ceiling":3,"tier":null,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}
  ok    and the next wave's build lists the hand-marked story too
::error::wave_stories keeps the hand-marked story - expected '"file":"docs/specs/hand/hand-02.md"' in:
        {"spec":"docs/specs/hand","slug":"hand","stage":"01-spec","next":"build:2","briefed":true,"approved":true,"branch":"vulyk/demo","head":"8f15471","pack":"2dcb248740cc","now":1794230749,"stories":{"todo":1,"in-progress":0,"done":2,"blocked":0},"wave":2,"wave_stories":[{"file":"docs/specs/hand/hand-03.md","story":"hand-03","worker":"worker-code","model":"","repeat":1}],"round":0,"ceiling":3,"tier":null,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}
::error::hand-marked failing verification: exit=0 out=cycle: hand-02 - already done, nothing to close
{"ok":true,"verb":"close-story","exit":0,"next":"build:2","now":1794230750,"status":{"spec":"docs/specs/hand","slug":"hand","stage":"01-spec","next":"build:2","briefed":true,"approved":true,"branch":"vulyk/demo","head":"8f15471","pack":"2dcb248740cc","now":1794230750,"stories":{"todo":1,"in-progress":0,"done":2,"blocked":0},"wave":2,"wave_stories":[{"file":"docs/specs/hand/hand-03.md","story":"hand-03","worker":"worker-code","model":"","repeat":1}],"round":0,"ceiling":3,"tier":null,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}}
  ok    a story closed by close-story stays already done
```
