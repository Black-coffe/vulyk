---
story: tails-1115-01
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 1
blocked_by: []
red: required
red_reason: an absolute story path closes like a relative one
red_verified_at: 2026-11-17T09:34:49Z 2258fc6494e8a7ce9fbdd57fadf9987e0cf2062bc2bb43e5095b8274395ca689
---

# close-story and the clerk line: absolute story paths, the commit subject, the executable bit, the red reason, a short dispatch line

## Goal
Eight tails in the cycle scripts and the driver. Evidence and fix direction per item: private
`~/.vulyk/audits/known-defects-2026-11-15/tails.md`, items T2, T3, T17, T23, T8, T67, T25, T94 (its line numbers
are of 3e145fb6).
1. T2: `close-story`, `stamp-red` and `scope-check.sh` make the story path repo-relative before anything reads it.
2. T3: the close commit's title is the first `# ` line after the closing `---` of the frontmatter.
3. T17: a mode change that exists only in the index survives the close commit.
4. T23: `stamp-red` counts `red_reason` only in lines that are not passing lines.
5. T8: the `--short` line carries the court relative to the repo root (plan.md `## Contracts` K1).
6. T67: the driver tells a reply cut off at a cap from a silent miss, only as `cc-facts.md` F6 records it.
7. T25: `commands_lint` names the round gate only for the full-suite row.
8. T94: the headers of `cycle.sh` and `lib.sh` say what the files hold today; the `lib.sh` header says that
   sourcing it turns on `set -u`.

`model: opus`: long-horizon, eight fixes across a 5000-line script and the driver. Marked red: new branches on the
close and red-receipt paths. Alone in its wave: it edits `close-story` (audit-fixes-1113, plan delta 2026-11-14).

## Requirements
> 3. The cycle, driver and clerk tails are fixed (cycle.sh, vulyk-cycle.js, lib.sh items in tails.md, including the long clerk line, the executable bit lost on close-story, the commit subject, the red-receipt staleness).
> 1. The six canary-found defects are fixed: wave-check on test paths that do not exist yet; scope-check and close-story with an absolute story path; the commit subject taken from story frontmatter; the busy check reading a neighbour hive's driver journal; a block check that prints only the hit now prints the fix; the routing docs/code mismatch on the black-box seat follows the owner's 2026-11-13 choice ("instead of") (T1-T6).
> 10. Every fix that code can check gets a failing test with the original case and a neighbour form; all suites green.

## Files
<!-- Functions, for sequencing with guards-1115. Touched: cycle.sh cmd_close_story (path at entry, title line, the
commit call), cmd_stamp_red (path at entry, the red_reason match only), short_line, file header; lib.sh
commands_lint, file header. Not touched: red_gate, state_get, state_put, verify_rec, verify_pause, the stamp-red
temp folder. -->
- scripts/cycle.sh
- scripts/scope-check.sh
- scripts/lib.sh
- .claude/workflows/vulyk-cycle.js
- tests/cycle.test.sh
- tests/driver.test.sh
- tests/e2e.test.sh

## Non-goals
- Do not touch `red_gate`, the run-state helpers, the verify records or the stamp-red temp folder: guards-1115.
- Do not move `set -u` out of `lib.sh` (37 sourcing files); the header names it and nothing else changes.
- No new verb, no change to what the clerk's and the workers' six verbs accept.
- Do not edit the seat agent files: the driver's dispatch text says the court path is relative to the project
  root. If `record-seat` or a seat cannot work with a relative court, return `NEEDS_CONTEXT` naming the line.
- Edit `tests/cycle.test.sh` only in parts `close`, `close2`, `red`, `red2`, `hooklog`. A test outside `## Files`
  that pins the old `commands_lint` sentence or an absolute court is `NEEDS_CONTEXT`, naming file and part.
- Fixtures use synthetic names; no host project name enters a test or a comment.
- Run `bash scripts/portability-check.sh scripts/cycle.sh scripts/scope-check.sh scripts/lib.sh` after each edit.

## Map slice
`memory/map/cycle.md` → Verbs (`--short`, Red receipt, `close-story`); `memory/map/cycle-suite.md` → The Workflow
driver; `memory/map/scripts.md` → Entry points (`lib.sh`, `scope-check.sh`), Gotchas.

## Acceptance criteria
- [ ] Part `close`: `close-story <absolute path>` on a story that closes green by its relative path closes the same
  way (exit 0, same committed paths; the story's own file and wave-mates' story files are not out of scope). The
  label contains `an absolute story path closes like a relative one`. Neighbours: `scope-check.sh` and `stamp-red`
  with an absolute path; on Git Bash both spellings of the root; a path outside the repo is refused with a reason.
- [ ] A `red: required` story that keeps the template's commented frontmatter lines closes with the subject
  `story(<id>): <its title>`. Neighbour: a `# ` comment line elsewhere in the frontmatter; a story with no title
  line keeps today's fallback.
- [ ] In a fixture repo with `core.fileMode=false`, a `## Files` path made executable only in the index is `100755`
  in the close commit. Neighbours: a path with a content change and no mode change keeps its mode; an index-only
  `-x` is kept too.
- [ ] Part `red`: `red_reason` found only in passing lines (first word `ok`) of a failing command exits 4, writes
  nothing and says so. Neighbours: the reason in a failing line stamps as before; in both kinds of line it stamps.
- [ ] `tests/driver.test.sh`: with a repo root 150 characters long (the longest Git for Windows still opens a court at) the `--short` line is at most 400 characters
  and its court is relative; the driver hands the seats that path with the rule to resolve it against the project
  root. Neighbour: a narrow round carries no court.
- [ ] T67 follows `docs/specs/tails-1115/cc-facts.md` F6. `confirmed`: a reply with the recorded marker is not a
  silent miss; the story is sent again once with a note that an earlier attempt stopped at its cap and left edits,
  and the run's result names it. `not confirmed`: no driver change, one notes line with the source.
- [ ] `commands_lint` says the round gate refuses a several-command cell only for the full-suite row; any other
  such row is told to split it, since `close-story` runs one command per cell.
- [ ] Every new case fails on HEAD; the notes list them.

## Verification
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part close2`
`bash tests/cycle.test.sh --part red`
`bash tests/cycle.test.sh --part red2`
`bash tests/cycle.test.sh --part hooklog`
`bash tests/cycle.test.sh --part gates`
`bash tests/e2e.test.sh`
`bash tests/driver.test.sh`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per item and a `DOCS: <file> - <sentence>` line for each doc sentence story 11 must change. -->
- Red receipt stamped on `--part close` (exit 1) after the driver fixture moved to the 150-character root; new cases red on HEAD: close (T2 x7, T3 x2, T17), close2 (T25), red (T23 x1 refusal + receipt, T2/T3 stamp-red + red-63 subject), gates (one line), driver (150 root, relative court, prompt rule, narrow round).
- scripts/lib.sh: `story_rel <root> <story>` (absolute path in /e/... or E:/... resolved by `pwd -P`, outside the root -> exit 1); commands_lint picks the reason by the full_suite_row test; header rewritten (holds today, `set -u` named).
- scripts/scope-check.sh: STORY made repo-relative right after `cd "$ROOT"`; outside the repo prints `scope-check: story file outside the repo: <path>`, exit 0 (it only reports).
- scripts/cycle.sh: `story_path_rel` at the entry of cmd_stamp_red and cmd_close_story (exit 2 `story file outside the repo: <path>`); title by awk after the frontmatter; close commit built in a temporary index (`git rev-parse --git-path vulyk-close-index`: read-tree HEAD + the real index's entries for OWN, removed paths force-removed) instead of `--only`, so an index-only mode survives under core.fileMode=false; `red_lines` drops `ok` lines before the red_reason match and a reason found only there gets its own refusal; short_line strips `$ROOT/` from court; header lists today's verbs and says haiku replaces opus.
- .claude/workflows/vulyk-cycle.js: the seat prompt says COURT is relative to the project root and to resolve it there; header comment updated. Seat agent files untouched; court-guard resolves a relative `cd` from the project root, so a seat can use it.
- T67: F6 is `not confirmed` (docs/specs/tails-1115/cc-facts.md F6: workflows.md says only that agent() resolves to null on a stop or an unrecoverable API error; the turn-cap result is undocumented): no driver change.
- Surprise: tests/e2e.test.sh part `red` (outside ## Files) goes red with the relative court; see ## Findings.
- tests/e2e.test.sh: the fake council-opus reads COURT up to the first `,` and joins it with FIX (a relative court); `--part red` green.
- CHANGELOG: close-story, stamp-red and scope-check take an absolute story path as the repo-relative one; one outside the repo is refused.
- CHANGELOG: the close commit's subject is the first `# ` line after the frontmatter, not a commented frontmatter line.
- CHANGELOG: close-story keeps a mode change staged only in the index (core.fileMode=false).
- CHANGELOG: stamp-red no longer counts red_reason in passing (`ok`) lines.
- CHANGELOG: the `--short` line carries the court relative to the repo root; the driver tells seats to resolve it against the project root.
- CHANGELOG: commands_lint names the round gate only for the full-suite row; other several-command rows are told close-story runs one command per cell.
- CHANGELOG: the cycle.sh and lib.sh headers say what the files hold today; lib.sh says sourcing it turns on `set -u`.
- DOCS: .claude/agents/council-opus.md, council-haiku.md - "Your dispatch names `COURT` (an absolute path)" is now a path relative to the project root (seat files were a non-goal here).
- DOCS: memory/map/cycle.md (`--short`) - the court key is relative to the repo root, not absolute.

## Findings
- NEEDS_CONTEXT (T25): `tests/cycle.test.sh` part `gates` (line 843, case "upgrade-findings-01: ... commands_lint names noted
  and several rows only") pins the old sentence for its row 'Two' (`sh a.sh` or `sh b.sh`, not the full-suite row):
  `2 backticked commands in one cell (the round gate refuses it as a full-suite row; split it)`. T25 must change that
  row's line to the split-it wording, and the story allows edits to `tests/cycle.test.sh` only in parts close, close2,
  red, red2, hooklog, so the change leaves part `gates` red (and part `gates` is not in `## Verification`). Question: may
  this story edit that one expected line in part `gates` (and run `--part gates` in `## Verification`)? No other test
  pins the old sentence or an absolute court (grep of tests/). Nothing was edited before this question.
- Queen (2026-11-17): yes. Change that one expected line in part `gates` of `tests/cycle.test.sh` to the split-it
  wording T25 gives that row, and nothing else in part `gates`; `--part gates` is added to `## Verification`.
- NEEDS_CONTEXT (T8, driver criterion): on Git for Windows a 200-character repo root cannot hold a court, so the real
  `advance` dispatch line (the one that carries `court`) cannot be made at that root. Measured 2026-11-17 in a fixture
  with a 200-character root: `open-round` exits 2 `worktree add failed`; `git worktree add` itself dies with
  `fatal: '$GIT_DIR' too big` for every slug length tried (1, 10, 20, 30, 40), since git refuses a `GIT_DIR` (the court
  path + `/.git`) over about 220 characters there, and the court is `<root>/.vulyk/court/<slug>/round-<n>` (root + 23 +
  slug). On Linux and macOS the same fixture works. The build-phase lines (claim, release, status, close-story) are made
  fine at the 200-character root, and on HEAD they are all under 400 characters already. Question: which form should
  the driver test take? (a) Recommended: the fixture runs at a 200-character root for every line; where git refuses the
  court there (Git for Windows), the dispatch-phase lines (advance-dispatch, suite, status-dispatch) come from a second
  fixture at the longest root git holds a court at with this slug (about 150), and the test asserts both the 400 cap and
  the relative court on every line it made, printing which root each came from. (b) Shorten nothing, run the whole
  fixture at the longest court-capable root on every platform (about 150 on Windows, 200 elsewhere). (c) Keep 200 on
  every platform and accept that `tests/driver.test.sh` is red on Windows (then close-story cannot run here).
  State: test edits written (`tests/cycle.test.sh` parts close, close2, red, the one gates line;
  `tests/driver.test.sh` 200-character fixture), uncommitted; no implementation edit; stamp-red not run.
- Queen (2026-11-17): (b), the simpler one: one fixture at a 150-character root on every platform (no second
  fixture, no per-platform length); the 400-character cap and the relative court are checked on every line. The
  criterion above now says 150.
- NEEDS_CONTEXT (re-stamp, 2026-11-17): the e2e fake seat edit is made (`tests/e2e.test.sh` line 160-161: COURT matched up to the first `,`, joined with FIX; `bash tests/e2e.test.sh --part red` all checks passed). close-story then exits 4 `test changed after red receipt: re-run stamp-red` (scope-check: declared 7, changed 7, out of scope 0). The implementation is already green, so per the Queen's note the Queen re-stamps from base; nothing committed.

## Red receipt
- command: bash tests/cycle.test.sh --part close
- exit: 1
- tests: 2258fc6494e8a7ce9fbdd57fadf9987e0cf2062bc2bb43e5095b8274395ca689 (tests/cycle.test.sh, tests/driver.test.sh, tests/e2e.test.sh)
- impl: 7bb5b3e9594c1acf6801916c02753f62b4e2133e4e9e26705ea4ce0a5eadeccb
- stamped: 2026-11-17T09:34:49Z

```
::error::close-story: an absolute story path closes like a relative one - exit=4 committed=[docs/specs/stray/stray-60.md memory/stats/scope.jsonl stray-abs-60.txt ] relative=[docs/specs/stray/stray-NN.md memory/stats/scope.jsonl stray-abs-NN.txt ] out=cycle: close-story - note: no approved record for /tmp/tmp.D46NfSPZrl/docs/specs/stray/stray-61.md; its working copy stands
::error::close-story: an absolute story path closes like a relative one by the drive-letter spelling of the root (<temp>/tmp.D46NfSPZrl) - exit=4 out=cycle: close-story - note: no approved record for <temp>/tmp.D46NfSPZrl/docs/specs/stray/stray-63.md; its working copy stands
cycle: close-story - note: Tier unset keeps no claim head: the scope check counts the uncommitted diff only
scope-check: stray-66 - declared 1, changed 1, out of scope 0
cycle: stray-66 - closed, verification green
{"ok":true,"verb":"close-story","exit":0,"next":"branch","now":1794907695,"status":{"spec":"docs/specs/stray","slug":"stray","stage":"02-approved","next":"branch","briefed":true,"approved":true,"branch":null,"head":"ce66da4","pack":"d396067aa56d","now":1794907695,"stories":{"todo":0,"in-progress":14,"done":10,"blocked":0},"wave":null,"wave_stories":[],"round":0,"ceiling":3,"tier":null,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}}
tails-1115-01 (T17): with core.fileMode=false the close commit keeps a mode change made only in the index
::error::close-story: an index-only mode change survives the close commit - exit=0 modes(a b c)=100644 100644 100755  status= out=cycle: close-story - note: no approved record for docs/specs/stray/stray-67.md; its working copy stands
cycle: close-story - note: Tier unset keeps no claim head: the scope check counts the uncommitted diff only
scope-check: stray-67 - declared 3, changed 3, out of scope 0
cycle: stray-67 - closed, verification green
{"ok":true,"verb":"close-story","exit":0,"next":"branch","now":1794907699,"status":{"spec":"docs/specs/stray","slug":"stray","stage":"02-approved","next":"branch","briefed":true,"approved":true,"branch":null,"head":"b64cf3a","pack":"a8b1dbeea4b4","now":1794907699,"stories":{"todo":0,"in-progress":14,"done":11,"blocked":0},"wave":null,"wave_stories":[],"round":0,"ceiling":3,"tier":null,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}}
```
