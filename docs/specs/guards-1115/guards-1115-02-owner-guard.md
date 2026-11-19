---
story: guards-1115-02
spec: guards-1115
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 1
blocked_by: []
red: required
red_reason: a subagent cannot write a run-state record
red_verified_at: 2026-11-16T08:07:33Z b2c7ef64080aabed48cc464260ee8811b07bcec0898a2c029e2e4f7c97dfc418
---

# owner-guard: run-state writes, and the owner's records under any spelling

## Goal
`.claude/hooks/owner-guard.sh` after this story (plan.md `## Contracts` R1, N1, F1, L1, O2):
1. **Run state (R1, private S1 tool half).** A subagent's Write, Edit or MultiEdit whose resolved path lies under the
   cycle's run state is denied. The Python half therefore runs on every subagent call of those tools.
2. **Script word (N1, private S2).** The Python half runs on every subagent Bash or PowerShell call. A verdict
   through `human-check.sh` and `cycle.sh briefed ... --go` are denied to a subagent however the script, the verdict
   or the flag is written.
3. **Plan record (private S11).** A subagent's shell command that can write a spec's `plan.md` is denied whatever
   names the file: a relative word after a changed directory, or a glob that can match it.
4. **Acceptance record (private S12).** A subagent's `git add` or `git commit` whose pathspec covers the record's
   folder without spelling the record, and a commit whose message carries a verdict word, are denied.
5. **No Python (F1).** A subagent's shell call is judged by a wider text filter than today's; the header says what
   that filter cannot see.
6. **Header (O2).** It ends with the list of what stays open, in general words; the card's `## Check` list equals it.

`model: opus`: judging shell text for the owner's records did not converge in spec `owner-guard-commit-fp`; the
rules here must be strict and still pass every flow of L1.
Private input, read first: `~/.vulyk/audits/known-defects-2026-11-15/` `security.md` S1 (option A), S2, S11, S12 and
`decisions.md` FINAL. Comments, labels and notes say what the hook refuses, never a form that still passes.
The hook is live while you edit it: a syntax error blocks every shell, Edit and Write call in this tree. Prototype
on a scratch copy with `--check`, stamp red against the tree, then apply edits that each leave the file runnable.

## Requirements
> 1. A subagent cannot forge or alter the cycle's run-state records (claim, approval, verification) through the named form classes: a write tool by any spelling of the path (resolved: letter case, dot-dot, trailing dot or space, a link); a shell writer, a spaced redirect or an in-place editor naming the path; an interpreter naming the path. The shell classes git-guard does not close in 0.54.0 are named open in its header, by class. So history, scope and verification checks read only what `cycle.sh` wrote (private S1, S13).
> 2. The owner-record guards cannot be walked around by spelling the guarded script or record differently (quoting, globbing, a variable, a directory pathspec, a changed directory) (private S2, S11, S12).
> 6. The header-named open forms are closed as answered above (private S6, S10), and each hook header lists exactly what it still leaves open, in general words, and says the guards stop accidents and shortcuts of a cooperative agent, not an adversary.
> 7. Every closed gap has a failing test with the original form and a neighbour form (Law 6), and no legitimate flow of the Queen, a worker or a council seat is denied (existing suites stay green).

## Files
- .claude/hooks/owner-guard.sh
- docs/defects/owner-words-by-builder.md
- tests/defects.test.sh

## Non-goals
- Do not touch `git-guard.sh` or `tests/maintenance.test.sh` (story 01, same wave): the shell half of R1 and the
  `cycle.sh` verb rule are built there. A git-guard case in `tests/defects.test.sh` that turns red is `NEEDS_CONTEXT`.
- Do not touch `.claude/settings.json`, `install.sh` (the matcher stays), `human-check.sh`, `cycle.sh`,
  `docs/hooks-reference.md`.
- The main session keeps today's text prefilter and the quote rule: no change to what it may do.
- No reading of what an interpreter's code does: an interpreter named beside the guarded file is a writer, as today.
- In the card change only the `## Check` list of open forms: no Never bullet, no status, no fixture (INDEX stays).
- In `tests/defects.test.sh` edit only the owner-guard block; synthetic names only (Acme, demo).

## Map slice
`memory/map/scripts-guards.md` → Purpose, owner-guard.sh; `memory/map/cycle-state.md` → Cycle-owned run state;
`memory/map/cycle.md` → Files, one writer each.

## Acceptance criteria
- [ ] `--check`, subagent input: a Write and an Edit of a run-state record are denied (label contains `a subagent
  cannot write a run-state record`); neighbours: the same path reached through `..`, another letter case, or a link
  is denied; a Write to `.vulyk/reports/` and to a story file passes.
- [ ] For each of S2, S11 and S12 the original form and a neighbour form are denied to a subagent. Every new case
  fails on HEAD.
- [ ] Every flow of contract L1 passes for a subagent: reading a spec's `plan.md` with no writer in the command, a
  report written under `.vulyk/reports/` whose text names `plan.md`, a verdict word or a guarded script, the planner's
  Write of a `plan.md` whose marker lines hold the template placeholder, a loop that runs each test script.
- [ ] Main session input: every existing case of the block stays green, `human-check.sh <spec> <verdict> "<quote>"
  --commit` under the quote rule included; a main-session Write to the run state passes.
- [ ] Every Python launcher stubbed away: a subagent's spelled guarded call is denied naming the missing Python, a
  disguised form the text filter can see is denied, an unrelated subagent call passes.
- [ ] The header's last block lists what stays open (the main session's prefilter and tools the hook is not wired
  on among them), names nothing this story closed, and the card's `## Check` list equals it.
- [ ] `bash scripts/portability-check.sh .claude/hooks/owner-guard.sh` is clean.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line per ask (1, 2) that says
what the guard does now. -->
- `.claude/hooks/owner-guard.sh`: front half skips the keyword prefilter for a subagent (non-empty top-level `agent_id`), so the Python half reads every subagent Bash/PowerShell/Edit/Write/MultiEdit call; the main session's prefilter and rules are unchanged.
- Python: `run_state` (normpath + realpath, casefold, Windows trailing dot/space and `:stream` cut) denies a subagent tool write under `.vulyk/state/`; `shell_judge` reads shell text with `unwrap` (heredoc bodies cut by consumer kind, `$(...)`/backticks/`<(...)` judged as nested shell), variables from assignments and `for` lists, unknown expansions read as a glob.
- Script word (S2): `human-check.sh` with an argument that may be a verdict (`--check`/`--show` pass), `cycle.sh` with a verb that may be `briefed` and a later argument that may be `--go`; `bash -c`, `eval`, here-strings, `xargs` (adds an unknown argument), `bash -n` passes.
- Plan record (S11): a subagent write of any file whose name may be `plan.md` (redirect target, writer list, cp/mv target or source into a folder, interpreter beside it or fed a body naming it), regardless of directory or marker: the Edit tool is the way.
- Acceptance record (S12): `git add`/`commit` pathspec covering `memory/stats/human.jsonl` (record spelled too, folder, `.`, glob, `:/`, `-A`/`-u` without pathspec, `-a`, after `cd` / `-C`), commit message that may hold a verdict (variables, unknown value, `-F` file, whole command text de-quoted).
- Decision: a crash in the subagent reading is a deny (GUARDED set for every subagent call), as the guards fail closed.
- No-Python fallback: a subagent shell call is denied when its text names a guarded record, flag or script; a Write/Edit of the run state is denied too.
- Header: subagent rules added, old scattered "left open" sentences moved into one closing `Left open on purpose` block; the card's `## Check` carries the same bullets (only that list changed).
- `tests/defects.test.sh` (owner-guard block only): new section guards-1115-02 (run state incl. `..`, case, junction/link; S2/S11/S12 originals and neighbours; L1 flows; no-Python subagent; header/card list equality); the subagent `git add -u memory/stats` "passes" case became a main-session case (the subagent form is now an S12 neighbour, denied); the per-phrase header loops were replaced by the list checks.
- Repair after Queen answer: the two S11 `sed -i` hook-input strings moved into `SEDI_CD`/`SEDI_GLOB` with `# portable: hook input text, never run`, as `SEDI` does.
- Surprise: a prototype edit put an apostrophe into the single-quoted fallback deny printf and broke the script; caught on the scratch copy with `bash -n` before applying.
- CHANGELOG: owner-guard denies a subagent's Write, Edit or MultiEdit into the cycle's run state (`.vulyk/state/`), judged by the resolved path (`..`, links, letter case); the main session is unchanged.
- CHANGELOG: owner-guard reads every subagent shell call in Python: `human-check.sh` with a verdict, `cycle.sh briefed --go`, a shell write of a `plan.md` and a `git add`/`commit` that covers the acceptance record or carries a verdict are denied however the script, verdict, flag, file or pathspec is spelled (quotes, globs, variables, a changed directory, a folder pathspec); the header and card end with the same list of what stays open.

## Findings
- close-story exit 4: `defect card shell-needs-gnu-or-bash4 fails on tests/defects.test.sh` (`portability-check:
  tests/defects.test.sh:883: sed-i: for c in "cd docs/specs/acme-demo && sed -i 's/<the owner word>/yes/' plan.md" \`).
  The hit is hook-input text inside the new S11 case list (never run); lines 884 (`sed -i ... acme-d*/plan.md`) hold
  the same form. Everything else is green (defects/intake/inject suites passed locally before close; scope 3 of 3).
  Proposed fix, not applied (the gate says a card decision is not mine): move those two strings into variables on
  their own lines with the same bypass the block already uses for `SEDI` (`# portable: hook input text, never run`),
  then rerun close-story.
- Queen answer 2026-11-16 (NEEDS_CONTEXT): apply your proposed fix: move the two `sed -i` strings of lines 883-884
  into variables on their own lines with `# portable: hook input text, never run`, as `SEDI` already does; they
  are hook input, never run, which is the case the card's `# portable:` comment exists for. No card change. Then
  rerun close-story. Story 01 waits on this: close yours first.

- close-story exit 4 after the Queen-ordered fix: `test changed after red receipt: re-run stamp-red`. The only test edit
  since the receipt is the one ordered above (tests/defects.test.sh lines 883-886: the two S11 `sed -i` strings moved
  into `SEDI_CD`/`SEDI_GLOB` with `# portable: hook input text, never run`; case text unchanged, portability-check
  clean). The implementation is already green, so stamp-red cannot see a red against this tree; per protocol I do not
  stash or revert the implementation. Needs: a re-stamp from base (revert impl, stamp-red, re-apply), or the Queen's
  call on the receipt.

## Red receipt
- command: bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh
- exit: 1
- tests: b2c7ef64080aabed48cc464260ee8811b07bcec0898a2c029e2e4f7c97dfc418 (tests/defects.test.sh)
- impl: 49da45dded0dca535beee3d797a5e2696b3d653f92ac5a96b60fba42fc1fab40
- stamped: 2026-11-16T08:07:33Z

```
::error::owner guard: a subagent cannot write a run-state record - Write
::error::owner guard: a subagent cannot write a run-state record - Edit
::error::owner guard: a subagent cannot write a run-state record - MultiEdit, a relative path
  ok    owner guard: with no Python an unrelated subagent call passes
::error::owner guard: the header ends with the open list and the card's ## Check list equals it
::error::owner guard: the open list names the main session's text prefilter
::error::owner guard: the open list names the tools the hook is not wired on
  ok    owner guard: the open list names a spelling form (glob, variable, changed directory) only for the main session or no Python
  ok    owner guard: the header is clean for portability-check
--- this tree's library: green, one info line per .scrub-revs commit (audit-fixes-1113-12)
  ok    defects-check on this tree is green, no ESCAPE (story 04's masked quote of command-injection-follows-cwd)
  ok    the audit of this tree prints one info line per listed commit
defects.test.sh: FAILED
```
