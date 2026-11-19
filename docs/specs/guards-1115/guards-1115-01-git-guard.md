---
story: guards-1115-01
spec: guards-1115
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 1
blocked_by: []
red: required
red_reason: a subagent shell call on the run state is denied
red_verified_at: 2026-11-16T07:51:08Z cf9d4c4dbf6a864789d4a37c8f9c45a0ce9afc4eb4cd0df2bf56a06c3b245b31
---

# git-guard: run state, script word, history verbs, parser, fallback

## Goal
`.claude/hooks/git-guard.sh` after this story (plan.md `## Contracts` R1, N1, G2, F1, L1, O2), in this order:
1. **Run state (R1, private S1 shell half).** A subagent's shell command that touches the cycle's run state is denied
   unless it is a `cycle.sh` call with one of the six verbs; the reason names the Read tool for reading.
2. **Script word (N1, private S2 git-guard half).** The Python half runs on every subagent Bash or PowerShell call; the
   six-verb `cycle.sh` rule holds however the script or the verb is written.
3. **History verbs (G2, private S3, T14).** While a DRIVER holds a spec, a subagent is denied every git verb that
   stages, makes a commit, or moves a branch or HEAD. The DRIVER is looked up where the git command acts.
4. **Forms closed on the owner's answer (private S6).** A subagent is denied `tag -f`, `push --force` in its forms,
   and PowerShell's evaluate-a-string command.
5. **Parser (private S4).** The git verb is found whatever stands between `git` and the verb or in front of `git`,
   for every caller.
6. **No Python (F1, private S5).** The bash fallback reads an alias value that carries a shell function and keeps
   the subagent rules of items 1-3.
7. **Header (O2).** It ends with the list of what stays open, in general words; the card's `## Check` list equals it.

`model: opus`: seven changes in one parser that judges this build's own shell calls.
Private input, read first: `~/.vulyk/audits/known-defects-2026-11-15/` `security.md` S1 (option A), S2, S3, S4, S5,
S6, `tails.md` T14, `decisions.md` FINAL. Comments, labels and notes say what the hook refuses, never a form that
still passes.
The hook is live while you edit it: a syntax error blocks every shell call in this tree. Prototype on a scratch
copy with `--check`, stamp red against the tree, then apply edits that each leave the file runnable.
If the turn budget runs short, finish items 1-4 and 7 and return `NEEDS_CONTEXT` naming items 5-6.

## Requirements
> 1. A subagent cannot forge or alter the cycle's run-state records (claim, approval, verification) through the named form classes: a write tool by any spelling of the path (resolved: letter case, dot-dot, trailing dot or space, a link); a shell writer, a spaced redirect or an in-place editor naming the path; an interpreter naming the path. The shell classes git-guard does not close in 0.54.0 are named open in its header, by class. So history, scope and verification checks read only what `cycle.sh` wrote (private S1, S13).
> 2. The owner-record guards cannot be walked around by spelling the guarded script or record differently (quoting, globbing, a variable, a directory pathspec, a changed directory) (private S2, S11, S12).
> 3. During a build a subagent cannot change git history by the verbs on git-guard's list, not only `commit` and `add`; verbs outside the list are named open in the header, by class (private S3).
> 4. git-guard sees the git verb past the global options and command positions its tests pin, and keeps its subagent rules when Python is missing; a `cd` that does not take effect does not move its build-lock lookup, and an unresolved variable in a command word that names no guarded thing is not refused; the positions it misses are named open in the header, by class (private S4, S5, T14).
> 6. The header-named open forms are closed as answered above (private S6, S10), and each hook header lists exactly what it still leaves open, in general words, and says the guards stop accidents and shortcuts of a cooperative agent, not an adversary.
> 7. Every closed gap has a failing test with the original form and a neighbour form (Law 6), and no legitimate flow of the Queen, a worker or a council seat is denied (existing suites stay green).

## Files
- .claude/hooks/git-guard.sh
- docs/defects/work-discarded-by-git-verb.md
- tests/maintenance.test.sh

## Non-goals
- Do not touch `owner-guard.sh`, `tests/defects.test.sh` or the owner-record rules (story 02, same wave), nor
  `.claude/settings.json`, `install.sh`, `docs/hooks-reference.md`, `cycle.sh`.
- The main session's rules stay as they are for items 1-4; item 5 reaches every caller.
- Do not close the other header-named forms (text handed to a shell through a pipe or a here-string, an encoded
  command, further wrappers): they stay open and named.
- In the card change only the `## Check` list of open forms: no Never bullet, no status, no fixture (INDEX stays).
- In `tests/maintenance.test.sh` edit only the git-guard block. Bash 3.2 in the fallback; Python stays in the heredoc.

## Map slice
`memory/map/scripts-guards.md` → Purpose, git-guard.sh; `memory/map/cycle-state.md` → Cycle-owned run state;
`memory/map/cycle.md` → Files, one writer each (DRIVER).

## Acceptance criteria
- [ ] `--check`, subagent input: for each of S1-S4 and S6 the original form and a neighbour form are denied; the
  first case's label contains `a subagent shell call on the run state is denied`. Every new case fails on HEAD.
- [ ] Every flow of contract L1 passes for a subagent, a report written with a heredoc whose text names the run
  state included.
- [ ] Item 3: with a DRIVER in the session's repo, a commit in an unrelated scratch repository passes (T14 original);
  a command that reaches the held repo by `cd`, `-C` or an option or environment word naming it is denied, and one
  whose target cannot be read counts as held. With no DRIVER the item-3 verbs pass; `git update-index --chmod` and
  git reads always pass.
- [ ] Item 5: each S4 form is denied wherever its plain twin is (subagent; main session on a dirty tree).
- [ ] Every Python launcher stubbed away: the S5 form is denied for any caller; a subagent input is denied the
  item-3 verbs under a DRIVER, a `cycle.sh` verb outside the six, and a run-state command; `git status` passes.
  The test comparing the two verb lists stays green.
- [ ] Main session input: every case of items 1-4 passes as before.
- [ ] The header's last block lists what stays open, names nothing this story closed, and the card's list equals it.
- [ ] `bash scripts/portability-check.sh .claude/hooks/git-guard.sh` is clean.

## Verification
`bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line per ask (1, 2, 3, 4, 6)
that says what the guard does now. -->
- `.claude/hooks/git-guard.sh`: prototyped on a scratch clone, then copied in with one write after the red receipt.
  Header rewritten. Its last block is the open-forms list. The no-op heredoc layout is unchanged.
- Bash front: a subagent skips the text prefilter (`agent_id` read with a builtin regex). The fallback gets `fb_sub`
  (run state, cycle.sh word, shell script word, checked by text), `fb_held` (DRIVER from the JSON cwd upward) and
  `HIST_VERBS`. `fb_scan` treats a `git` word in the verb slot as a new git call (S5) and skips redirections.
- Python parser: `as_code` replaces `drop_heredocs` and `quoted`. It tracks quotes across lines and cuts comments
  up to the newline, so a `<<` inside a comment starts no heredoc. `redirections()` takes redirects out of every
  segment and keeps their targets. `>&`/`&>` are masked as `\x01` so shlex does not split on the `&`. The
  `command`/`exec`/`time` options are skipped, and PowerShell `$x = <cmd>` is read as `<cmd>`.
- R1: `touches_state` resolves each path word and redirect target with realpath. It expands globs and variables
  assigned in the same command. Echo/printf words and the grep pattern count as text. A cd into the state is
  denied. `takes_text` plus a regex over the raw command covers `-c`/`-e` code and stdin scripts for shells and
  interpreters.
- N1: `judge_run` handles the shell script word or the command word. It removes quotes (shlex) and resolves
  variables from `x=`, `export`, PowerShell `$x =` and `for` lists. A glob is matched against cycle.sh. An
  unresolved name is denied. Exceptions: a shell that only checks syntax (`-n`), and an unresolved PowerShell
  command word, which there can be an expression (`$LASTEXITCODE -ne 0`). A stamp-red argument that is not
  literal is denied.
- G2: `rewrites_history` holds the verb list. `git_places` reads `--git-dir`/`--work-tree`/`GIT_DIR`/
  `GIT_WORK_TREE`, including an earlier `export`. `driver_held` is checked per place, and an unreadable or
  missing place counts as held (T14: `here`, not the session cwd).
- S6: `forced_remote` (tag -f, push -f/--force/--force-with-lease/--mirror/`+ref`); `iex`/`Invoke-Expression` as a
  command word, PowerShell or fed to pwsh.
- `docs/defects/work-discarded-by-git-verb.md`: in `## Check`, the old "Not covered" sentence is replaced by the
  "Left open" list, identical to the header. The rest of the card is unchanged.
- `tests/maintenance.test.sh`, git-guard block only. The old header-list check now reads the new last block and
  asserts the closed forms are gone. A header/card equality check was added. A new section adds batch helpers:
  `gbatch` and `nopyb` write all inputs in one Python call and run each check with no subshell, to keep the line
  under its cap.
- Note on "every new case fails on HEAD": every new deny case fails on HEAD. The pass cases (L1, main session "as
  before", no DRIVER) and the three "holds as on HEAD" string cases pass on HEAD by design.
- Surprise: owner-guard (story 02, live in this tree) refused two Python heredoc edits of the test file as
  "may write a plan.md". I used the Edit tool instead.
- Timing: `bash tests/maintenance.test.sh` measured 268 s in the scratch clone before the batch helpers, under a
  300 s line cap. The guards part went from 90 s to 121 s.
- CHANGELOG: ask 1 - git-guard denies a subagent's shell call on the run state `.vulyk/state/` (path word, redirect,
  cd, or code handed to a shell or interpreter, by resolved path); the reason names the Read tool.
- CHANGELOG: ask 2 - git-guard reads a subagent's every shell call: the script or program name is read after quote
  removal, with variables resolved and globs matched, and an unreadable one is denied ("spell the script path").
- CHANGELOG: ask 3 - under a DRIVER, git-guard denies a subagent every git verb that stages, makes a commit, or
  moves a branch or HEAD, judged in the repository the command acts on (a scratch repo passes).
- CHANGELOG: ask 4 - git-guard finds the git verb past comments, redirections and `time`/`command`/`exec` options
  for every caller; with no Python its fallback keeps the subagent rules for the run state, cycle.sh and history
  verbs, and reads an alias that defines a shell function.
- CHANGELOG: ask 6 - git-guard denies a subagent `tag -f`, a forced push and `Invoke-Expression`; its header ends
  with the list of what stays open, and the card carries the same list.

## Findings
- close-story exit 4 on `bash tests/maintenance.test.sh`: 1205 checks, 2 failed. Both failures are the guards
  part's tree-wide portability check (`portability-check: the tree exits 0`, `... prints its ok line`). It
  reports `tests/defects.test.sh:883` and `:884` (`sed-i`, a bare `sed -i` inside test-case strings). That file
  is wave-mate story 02's (uncommitted, returned NEEDS_CONTEXT), outside this story's `## Files`. Every check
  this story added or changed passes. Needed: story 02 adds a `# portable: <reason>` or rewords those two lines
  (or the file leaves the tree), then close-story for this story is rerun as it is.
- Queen answer 2026-11-16 (NEEDS_CONTEXT): story 02 rewrites lines 883-884 of `tests/defects.test.sh` with a
  `# portable:` comment in this same relaunch; do not touch that file. Rerun close-story unchanged. If it fails only
  on those two lines again, story 02 has not closed yet: wait a few minutes and rerun (up to three tries) before
  returning. Concern 4 (owner-guard denying your Python heredoc edits) goes to the council review, not this story.

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: cf9d4c4dbf6a864789d4a37c8f9c45a0ce9afc4eb4cd0df2bf56a06c3b245b31 (tests/maintenance.test.sh)
- impl: 3f218433216891af2e20507b5e91863b9d71b728ca84631414715814d927eab2
- stamped: 2026-11-16T07:51:08Z

```
::error::git-guard: a subagent shell call on the run state is denied: echo wave.1=abc >> .vulyk/state/dv/claim - expected exit 1, got 0: 
::error::git-guard: a subagent shell call on the run state is denied: cat .vulyk/state/dv/claim - expected exit 1, got 0: 
::error::git-guard: a subagent shell call on the run state is denied: cp x .vulyk/state/dv/approved - expected exit 1, got 0: 
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 1205 checks, 114 failed
```
