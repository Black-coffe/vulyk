---
story: mass-audit-fixes-05
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
model: opus
wave: 1
blocked_by: []
red: required
red_reason: blocks differ from the approved version
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

## Findings
