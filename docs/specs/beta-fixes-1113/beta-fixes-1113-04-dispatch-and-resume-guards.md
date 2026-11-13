---
story: beta-fixes-1113-04
spec: beta-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 2
blocked_by: [beta-fixes-1113-01, beta-fixes-1113-02]
red: required
red_reason: advance stops before dispatch on a verification line that is no Commands cell
red_verified_at: 2026-11-13T08:55:48Z bab91bf34765cf486e20f222aca043b307730a5b6c54e6c982f80887e9313377
---

# Two guards before a build starts: verification checked at dispatch, `resume` on the spec branch

## Goal
`scripts/cycle.sh`, on top of story 01. **Ask 3.** The segment check `close-story` applies to a story's
`## Verification` (each `&&` segment a `## Commands` cell or `none — reviewed by lead-review`; a `round-only` row
refused) becomes one function used by both verbs. `advance` calls it, before it ends on `next:"build:<W>"`, for
every story the wave lists; the first failing story stops it with exit 2 and the line of plan.md `## Contracts`
A1 (story file, close-story's own refusal text, the `try:` hints on stderr), so no worker is sent to a story it
could never close. **Ask 8.** `cmd_resume` reads the plan's `**Branch:**`; when HEAD is elsewhere and the tree
is clean it switches to that branch before it writes anything, and says so (`"switched"` on its last line, R1);
when the tree is dirty it refuses with exit 2 and names the paths. `.claude/commands/vulyk-resume.md` and
`docs/cycle.md` (the `advance` and `resume` paragraphs) say the same.

## Requirements
> 3. A wave's stories are checked before dispatch: a `## Verification` segment that is not a `## Commands` cell stops `advance` with the story named, before any worker runs.
> 8. `/vulyk-resume` (and the build it starts) switches to the spec branch when the tree is on another branch and clean, instead of failing the first launch.

## Files
- scripts/cycle.sh
- tests/council.test.sh
- tests/cycle.test.sh
- tests/solo.test.sh
- tests/e2e.test.sh
- .claude/commands/vulyk-resume.md
- docs/cycle.md

## Non-goals
- No second matcher: lift close-story's check, do not copy it, and do not loosen it. `close-story` keeps its
  exit codes, messages and hints byte for byte. No `scripts/lib.sh` or `wave-check.sh` edit.
- The check runs only when `advance` is about to end on `build:<W>`, for that wave's listed stories. Do not add
  it to `status`, `claim` or the driver, and do not make an empty `## Verification` a refusal.
- `resume` never runs `stash`, `checkout -f`, `switch -f`, `--discard-changes`, a checkout of paths, `reset` or
  `clean`; a dirty tree is only reported. Do not make `branch_guard` switch: every other verb still refuses.
- Do not change `pause`, the `PAUSE` file rule or what `resume` does when HEAD is already the spec branch or the
  plan has no `**Branch:**`.
- `tests/solo.test.sh`, `tests/e2e.test.sh` and suite parts other than council `advance` and cycle `safety`: edit
  only a fixture story's `## Verification` line (or its fixture constitution row) that the new check trips; name
  each in `## Implementation notes`. A tripped fixture in a suite outside `## Files`: `NEEDS_CONTEXT`.
- Do not undo story 01 (`finding_paths`, the narrow rule, the `red_reason` unquote).
- Fixtures use stand-ins (`Acme`, `vulyk/acme-spec`); no hive name or path.

## Map slice
`memory/map/cycle.md` → `advance` (ADR-013 D2), `status --json` `next`, Verbs (Branch guard; `close-story`:
segment rule, `try:` hint; `claim`), Staleness / PAUSE; `memory/map/scripts.md` → Entry points (`lib.sh` cell
helpers), Gotchas (anchored matches; bash 3.2); `memory/map/agents-and-commands.md` → `/vulyk-pause`/`-resume`.

## Acceptance criteria
- [ ] `--part advance`, the original case: a wave story whose `## Verification` holds a line that is no cell of
  the fixture's `## Commands`: `advance` exits 2, its last line is `ok:false` naming the story file and the
  segment, the `try:` lines are on stderr, and no `build:<W>` is returned. The failing label contains `advance
  stops before dispatch on a verification line that is no Commands cell`.
- [ ] `--part advance`, neighbours: a `round-only` segment stops it the same way; a wave whose stories all name
  cells, or `none — reviewed by lead-review`, returns `build:<W>` as before; with two bad stories the first is
  named; a bad line in a later wave does not stop the current one.
- [ ] `--part advance`: `close-story` on that story still refuses with the same text as before this story.
- [ ] `--part safety`, the original case: plan with `**Branch:** vulyk/acme-spec`, HEAD on the default branch,
  clean tree: `resume` exits 0, HEAD is `vulyk/acme-spec`, the last line carries `"switched"`, and the next
  `claim` passes the branch guard.
- [ ] `--part safety`, neighbours: a dirty tree (tracked edit; untracked file): exit 2, the message names the
  paths, HEAD and the files are untouched, `PAUSE` is still there; a `**Branch:**` that does not exist: exit 2
  naming it; already on the branch, or no `**Branch:**` line: as before.
- [ ] `bash scripts/portability-check.sh scripts/cycle.sh` and `bash scripts/prompt-check.sh --touched
  .claude/commands/vulyk-resume.md scripts/cycle.sh` are clean.
- [ ] `vulyk-resume.md` and `docs/cycle.md` state both rules; no sentence tells the Queen to switch by hand.
- [ ] Every new case fails on HEAD before the implementation; `## Implementation notes` ends with two
  `CHANGELOG:` lines.

## Verification
`bash tests/council.test.sh --part advance`
`bash tests/cycle.test.sh --part safety`
`bash tests/solo.test.sh`
`bash tests/e2e.test.sh`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->
- scripts/cycle.sh: `verify_cells_check` gains an optional third arg `<story>` (prefixes "<story>: " to its stderr and error text, empty for close-story/stamp-red, so their bytes are unchanged) and prints the `try:` hints for `advance` too; no second matcher.
- scripts/cycle.sh: `cmd_advance`, when `next` is `build:*`, reads each `"file"` of the carried status's `wave_stories` and runs `verify_cells_check advance <cmd-list> <file>`; the first failure exits 2 via close-story's own emit (A1). Only that wave's listed stories (todo-ready plus in-progress) are checked.
- scripts/cycle.sh: `cmd_resume` reads `**Branch:**` before any write; HEAD elsewhere: missing branch -> exit 2, dirty tree (`git status --porcelain -uall -z`) -> exit 2 naming the paths, else plain `git switch -q`, last line gains `"switched":"<B>"` (R1). `branch_guard` untouched.
- Decision: the spec's own `PAUSE`/`DRIVER` are left out of the dirty list (the cycle.test.sh fixture does not gitignore them, and a hive that does not either would never switch); everything else, paperwork included, counts as dirty.
- tests/council.test.sh `--part advance`: r18vc (original case + close-story's unchanged refusal), r18vr (round-only), r18vd (two bad, first named), r18ve (good wave 1 incl. `none — reviewed by lead-review`, bad wave 2 does not stop it); appends a round-only row to the fixture CLAUDE.md at the end of the part.
- tests/cycle.test.sh `--part safety`: acme/acmegone/acmenob fixtures on `vulyk/acme-spec`, HEAD on main: tracked and untracked dirt, missing branch, clean switch + claim, already-on-branch, no `**Branch:**`.
- Surprise: the first red receipt sealed a council assertion that expected a relative `CLAUDE.md` in close-story's stderr (the fixture prints an absolute path); fixed the assertion, then re-stamped against HEAD's cycle.sh (impl copied aside, HEAD's file written back, stamp-red, impl restored).
- solo.test.sh and e2e.test.sh: no fixture tripped the new check; not edited.
- .claude/commands/vulyk-resume.md, docs/cycle.md: both rules stated; no hand-switch instruction.
- CHANGELOG: `advance` checks every story of the wave it is about to dispatch against `## Commands` (close-story's own segment check) and stops with exit 2 naming the story, before any worker runs.
- CHANGELOG: `resume` switches a clean tree to the plan's `**Branch:**` (last line `"switched"`), and refuses a dirty one with exit 2 naming the paths, never stashing or forcing.

## Findings

## Red receipt
- command: bash tests/council.test.sh --part advance
- exit: 1
- tests: bab91bf34765cf486e20f222aca043b307730a5b6c54e6c982f80887e9313377 (tests/council.test.sh, tests/cycle.test.sh, tests/e2e.test.sh, tests/solo.test.sh)
- impl: 32ea2653e9f0af1dfc0c60b9b25d253c9cee7833767413280ccbdf5c27175e52
- stamped: 2026-11-13T08:55:48Z

```
::error::advance stops before dispatch on a verification line that is no Commands cell - exit=0 out=cycle: r18vc - advanced 0 step(s), next: build:1
  ok    the last seven keys (0.19 appends manual)
beta-fixes-1113-04 A1: advance checks every story of the wave it would dispatch against ## Commands, close-story's own check
::error::advance stops before dispatch on a verification line that is no Commands cell - exit=0 out=cycle: r18vc - advanced 0 step(s), next: build:1
{"ok":true,"verb":"advance","exit":0,"next":"build:1","steps":[],"rejected":[],"status":{"spec":"docs/specs/r18vc","slug":"r18vc","stage":"03-building","next":"build:1","briefed":true,"approved":true,"branch":"vulyk/r18ad","head":"2527a87","pack":"505869d54da3","now":1794560017,"stories":{"todo":1,"in-progress":0,"done":1,"blocked":0},"wave":1,"wave_stories":[{"file":"docs/specs/r18vc/r18vc-02-v.md","story":"r18vc-02","worker":"worker-code","model":"","repeat":1}],"round":0,"ceiling":3,"tier":2,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}} err=
  ok    close-story on that story refuses with its own text, as before
::error::round-only advance: exit=0 out=cycle: r18vr - advanced 0 step(s), next: build:1
{"ok":true,"verb":"advance","exit":0,"next":"build:1","steps":[],"rejected":[],"status":{"spec":"docs/specs/r18vr","slug":"r18vr","stage":"03-building","next":"build:1","briefed":true,"approved":true,"branch":"vulyk/r18ad","head":"a5b440f","pack":"165ae52e2ef3","now":1794560020,"stories":{"todo":1,"in-progress":0,"done":1,"blocked":0},"wave":1,"wave_stories":[{"file":"docs/specs/r18vr/r18vr-02-v.md","story":"r18vr-02","worker":"worker-code","model":"","repeat":1}],"round":0,"ceiling":3,"tier":2,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}}
::error::two bad: exit=0 out=cycle: r18vd - advanced 0 step(s), next: build:1
{"ok":true,"verb":"advance","exit":0,"next":"build:1","steps":[],"rejected":[],"status":{"spec":"docs/specs/r18vd","slug":"r18vd","stage":"03-building","next":"build:1","briefed":true,"approved":true,"branch":"vulyk/r18ad","head":"7b43ea9","pack":"7b8a648a54cc","now":1794560022,"stories":{"todo":2,"in-progress":0,"done":1,"blocked":0},"wave":1,"wave_stories":[{"file":"docs/specs/r18vd/r18vd-02-v.md","story":"r18vd-02","worker":"worker-code","model":"","repeat":1},{"file":"docs/specs/r18vd/r18vd-03-v.md","story":"r18vd-03","worker":"worker-code","model":"","repeat":1}],"round":0,"ceiling":3,"tier":2,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}}
  ok    neighbour: cells and 'none — reviewed by lead-review' return build:1; a bad line in wave 2 does not stop wave 1
```
