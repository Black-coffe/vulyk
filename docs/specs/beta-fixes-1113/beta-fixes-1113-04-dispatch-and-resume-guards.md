---
story: beta-fixes-1113-04
spec: beta-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
wave: 2
blocked_by: [beta-fixes-1113-01, beta-fixes-1113-02]
red: required
red_reason: advance stops before dispatch on a verification line that is no Commands cell
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

## Findings
