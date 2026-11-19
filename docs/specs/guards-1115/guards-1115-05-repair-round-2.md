---
story: guards-1115-05
status: done
returned: DONE
worker: worker-code
model: opus
wave: 4
blocked_by: []
red: required
red_reason: git-guard r2: a subagent's commit after a cd that does not take effect is denied under a DRIVER
red_verified_at: 2026-11-16T12:34:29Z 5275ccbffe03c9b872dd536ac436ef8de1d2d9dab18d8b6a13b25d7cb1e73038
---

# Repair round 2

## Goal
Make the asks and findings council round 2 left RED pass for this hook, and change nothing else.

## Requirements
> 1. A subagent cannot forge or alter the cycle's run-state records (claim, approval, verification) through the named form classes: a write tool by any spelling of the path (resolved: letter case, dot-dot, trailing dot or space, a link); a shell writer, a spaced redirect or an in-place editor naming the path; an interpreter naming the path. The shell classes git-guard does not close in 0.54.0 are named open in its header, by class. So history, scope and verification checks read only what `cycle.sh` wrote (private S1, S13).
> 3. During a build a subagent cannot change git history by the verbs on git-guard's list, not only `commit` and `add`; verbs outside the list are named open in the header, by class (private S3).
> 4. git-guard sees the git verb past the global options and command positions its tests pin, and keeps its subagent rules when Python is missing; a `cd` that does not take effect does not move its build-lock lookup, and an unresolved variable in a command word that names no guarded thing is not refused; the positions it misses are named open in the header, by class (private S4, S5, T14).
> 6. The header-named open forms are closed as answered above (private S6, S10), and each hook header lists exactly what it still leaves open, in general words, and says the guards stop accidents and shortcuts of a cooperative agent, not an adversary.
> 7. Every closed gap has a failing test with the original form and a neighbour form (Law 6), and no legitimate flow of the Queen, a worker or a council seat is denied (existing suites stay green).

## Findings
ASK 1: RED - run-state records cannot be forged through the named classes - run: owner-guard.sh write paths and git-guard.sh shell forms as a subagent: write tools GREEN; some shell spellings of a run-state write still pass (forms private).
ASK 3: RED - during a build a subagent runs only read-list git verbs - run: git-guard.sh as a subagent in a folder holding a DRIVER: still a deny list, no read list, so verbs off the history list pass (forms private).
ASK 4: RED - git verb found in every command position, past every global option - run: git-guard.sh as a subagent over many positions: most found, but some nested-command and quoting contexts still hide the verb (forms private).
ASK 6: RED - header-named forms closed, headers exact and worded for a cooperative agent - run: git-guard.sh with 27 forced-tag, forced-push and iex forms; grep -i "adversar|cooperative" over .claude/hooks saw: all 4 forced-tag, 13 push and 5 iex forms denied, a plain tag passes (closed as answered); but zero matches for the cooperative-agent sentence in any hook header, and the open lists omit the forms asks 1, 4 and 5 measured open
ASK 7: RED - a test per closed gap with a neighbour, no legitimate flow denied - run: the three test parts above; court-guard.sh on a seat's own flows saw: parts green (730 checks 0 failed; 279 ok; runstate 15 ok), but court-guard denies a seat writing its report by a relative path into the reports folder (the absolute spelling passes) and a Read of a file in its own court spelled in another letter case, and the classes named in asks 1, 3, 4, 5 have no test because they are not closed
1. tests/full-suite.sh:172 [regression] the full suite must end with every part under 70% of its cap: the round 2 log (`docs/specs/guards-1115/council/round-2/suite.log`, steps 4, 6 and 8 FAIL) cuts `cycle:red` at 213 s, `telemetry:install-xp2` at 212 s and `telemetry:edits` at 213 s of a 300 s cap, each with every check ok - base: the round 1 log on the same code shows 183 s, 186 s and 179 s and `SUITE: ok 1336s`; my rerun `bash -c '. scripts/lib.sh && run_capped 300 bash tests/cycle.test.sh --part red'` ended rc 0 in 182 s with no error line, so the red is run time on three parts that sit within 30 s of the 210 s line (card `test-gate-one-long-limit`: a part that grows toward its cap is split).
1. .claude/hooks/git-guard.sh:999 [regression] under a DRIVER the hook must judge a `git commit` of a subagent in the folder the shell really stands in, so a `cd` segment that never takes effect must not move the DRIVER lookup at :1037-1057 off the held repository - base: `git show c5724761:.claude/hooks/git-guard.sh` :593-595 looked it up from the session cwd; unfixed since round 1 (`git diff --quiet 4cda5d6f 0713fe33 -- .claude scripts tests` exits 0: the round changed no code).
2. .claude/hooks/git-guard.sh [ask 1] a subagent shell call that spells a run-state path in full must be refused whatever is glued to that word: some shell spellings of a run-state write that the parser does not split still exit 0 in git-guard and in owner-guard (forms: private review N1).
3. .claude/hooks/git-guard.sh:757 [ask 2] a `cycle.sh` verb outside the six must be refused for a subagent under every spelling of the call: a shell option that takes a value (:757), a verb handed in by xargs (:915), the shell or the whole command held in a variable, and a globbed or variable script word behind a wrapper (:417) still pass both hooks (round 1 line 3, unchanged).
6. .claude/hooks/git-guard.sh [ask 3] under a DRIVER a subagent must be refused every verb that stages, makes commits or moves refs: verbs off the history list (plumbing, imports, ref writers) still exit 0 in `--check` with a DRIVER present (forms: private review).
7. .claude/hooks/git-guard.sh [ask 4] the hook must find the git verb past further global-option, alias, variable, redirect, substitution and prefix shapes, and refuse a subagent a git call it cannot resolve: several such shapes still let a discarding verb through (forms: private review N6).
10. .claude/hooks/owner-guard.sh:665 [ask 7] an ordinary subagent call that names no guarded thing must pass: `names_plan` (:665-673, used at :899 and :1199) still refuses interpreter inline code or a heredoc holding a lone `*`, `**` or `$name`, :900-902 a redirect, tee, touch, cp or in-place sed whose target is a bare variable or a wide glob, and git-guard.sh:906-911 any Bash command word holding an unresolved variable - `--check` on the base copies exits 0 for each, on the head 1 (round 1 line 9, unchanged), and no class of lines 1-9 has its failing test yet.
11. .claude/hooks/git-guard.sh:79 [ask 6] the open list of each header must name every form the hook lets through and say that the guards stop accidents and shortcuts of a cooperative agent, not an adversary: the forms of lines 2-9 stand in none of the three lists (git-guard.sh:79-94, owner-guard.sh:70-88, court-guard.sh:34-41), and `grep -n -i -e cooperative -e adversar .claude/hooks/git-guard.sh .claude/hooks/owner-guard.sh .claude/hooks/court-guard.sh` prints nothing.
12. docs/specs/guards-1115/plan.md:199 [ask 1] the narrowing of asks 1, 3, 4 and 5 made in brief.md by e79addd1 must have its `## Descoped` lines in plan.md (what was dropped, why, the owner line quoted): the section still reads `*(empty)*`, and the owner line stands only in the `## Answers` of the brief.
- [regression] PART cycle:red ok 213s cap 300s
- [regression] PART telemetry:install-xp2 ok 212s cap 300s
- [regression] PART telemetry:edits ok 213s cap 300s

Queen answers (2026-11-16, before the build; the owner chose «Ремонт классами + сузить вопросы (Рекомендую)» after
round 1 and «Теперь в ремонт классами (Рекомендую)» after round 2):
- Round 2 judged the round-1 code unchanged (no repair had run). This story is that repair, for both rounds' findings.
- Fix by class, not by spelling: resolve a path once (letter case, dot-dot, trailing dot or space, links) and judge
  the resolved form; under a DRIVER give a subagent a read list of git verbs and refuse the rest; find git and
  `cycle.sh` in every command position the asks name, through the shared segment walker of each hook; what the hook
  cannot resolve (a variable or substitution in the program word or in a target next to a guarded path) is refused
  for a subagent. Keep each hook's existing helpers; no new framework.
- Exact forms of every finding: private `~/.vulyk/audits/known-defects-2026-11-15/guards-review-r1.md` (items N1-N8,
  R1, OD1-OD3) and the round reports. Tests, comments, labels and commit text name the class in general words; a
  form left open is named in the header only in general words (brief `## Privacy`).
- Each header (git-guard, owner-guard, court-guard) gets one sentence: the guards stop accidents and shortcuts of a
  cooperative agent, not an adversary; then its exact open list.
- Over-denies are tests of allowed calls: a subagent `python3 -c "print(6 * 7)"`, interpreter or heredoc text with a
  lone `*`, `**` or `$name`, `sed -i '$d' <file>`, `echo x > "$OUT"`, `xargs sed -i`, `bash "$CLAUDE_PROJECT_DIR/scripts/x.sh"`,
  a seat writing its report by a relative path into its reports folder, a seat Read of a file in its own court in
  another letter case: each passes.
- Finding 1 (tests/full-suite.sh, parts at 212-213 s): not a code fault. Re-timed on an idle machine: cycle:red 172 s,
  telemetry:install-xp2 167 s, telemetry:edits 175 s (cut line 210 s); the round-2 run shared the machine with the
  seats. Do not touch tests/full-suite.sh or those parts.
- Finding 12 (plan.md `## Descoped`): the Queen wrote it (paperwork). Do not edit plan.md.
- `tests/maintenance.test.sh` runs near its cap (about 268 s): put new cases in tests/defects.test.sh where it fits.

- Worker (2026-11-16): stopped during reading, before any test or code edit. No hook, test or card was touched; no
  red receipt was stamped. The story covers three hooks of about 2900 lines, twelve findings and seven asks in one
  dispatch. A re-dispatch should split it, one hook per story (git-guard, owner-guard, court-guard).
- Split (2026-11-16, after the first worker's NEEDS_CONTEXT): one story per hook, each with its own test file and
  card: 05 git-guard (tests/maintenance.test.sh, card work-discarded-by-git-verb), 06 owner-guard (tests/defects.test.sh,
  card owner-words-by-builder), 07 court-guard (tests/inject.test.sh, wave 5). A finding on another hook is that
  story's; ASK 6 and ASK 7 lines are shared: each story fixes its own hook's part.
- This is defensive work on this repository's own guard hooks: read the exact forms from the private file, write
  tests that the hook refuses them, and do not copy a working form of a still-open class anywhere.
- Findings 2 and 3 ("pass both hooks") are git-guard's (story 05): plan A1 gives shell writes of the run state and
  `cycle.sh` verbs to git-guard, Edit/Write to owner-guard; one hook refusing a call is enough.

- Worker (2026-11-16, second dispatch): the red half is done. The new failing block is in tests/maintenance.test.sh
  (section "classes left open by round 2", guards-1115-05), and `stamp-red` wrote the receipt (maintenance exits 1,
  117 of 1374 checks fail; the other two lines are green). No edit was made to .claude/hooks/git-guard.sh or the card.
  The build stopped before the implementation because a safety classifier withheld this worker's output partway
  through. Nothing from that output ran. A re-dispatch that resumes from the receipt should build the git-guard fix
  in smaller pieces, one class per step: lexing, unresolved
  targets beside the run state and moves of the folder that holds it, the shell option value and `-c --`, wrapper
  option tables and dynamic command words, the read list under a DRIVER, cd scoping (subshell,
  `||`, pipeline, background), the no-Python fallback, and then the header and card open list with the
  cooperative-agent sentence. Timing: the guards part took 122 s before the new block. The whole file must stay
  under the 300 s line cap.
- Queen (2026-11-16, third dispatch): resume from the receipt; do not touch tests/maintenance.test.sh (sealed).
  Build git-guard.sh in the order above, one class per Edit, running only the new block between steps. In your
  own messages and notes name a class by its private item id (N1, N2, N6, R1, OD3) or in general words; never
  restate a working form. Then the header and the card's `## Check` list, then close-story. If the whole
  maintenance file goes past 210 s, return NEEDS_CONTEXT with the timing (no limit change).
- Worker (2026-11-16, fourth dispatch): stopped before any implementation edit. No change to
  .claude/hooks/git-guard.sh, the card or the sealed test. The new block, run alone from a scratch harness outside
  the repo, takes about 22 s and fails 115 of 169 checks, as the receipt says. A safety classifier then stopped this
  worker's output a second time, while it was reviewing the failing list. Re-dispatching the same story to this
  worker setup is likely to stop the same way. Two ways forward: the Queen asks the owner whether this hardening is
  done in a session he runs himself, or the story is cut into one class per story, each brief naming its class by
  its private item id only.
- Queen (2026-11-16, fourth dispatch, supersedes the scope above): the owner chose «Минимум для git-guard
  (Рекомендую)». This story now does only: (1) finding 1, the regression: a `cd` that does not take effect (a
  subshell, `||`, a failing `cd`) does not move the build-lock lookup; (2) finding 10's git-guard part (private OD3):
  an unresolved variable in a command word that names no guarded thing is not refused; (3) finding 11 for git-guard:
  the header says the guards stop accidents and shortcuts of a cooperative agent, not an adversary, and lists its
  open classes in general words (no spellings): glued redirects and unresolved targets beside the run state, moves of
  a folder that holds it, git verbs outside the list under a build lock, command positions and global options it
  misses; the card `work-discarded-by-git-verb.md` `## Check` list matches. Findings 2, 3, 6, 7 move to 0.55.0
  (plan.md `## Descoped`); do not work on them.
- Cut the sealed block in tests/maintenance.test.sh to the cases of (1)-(3), with a neighbour form for each and
  the allowed calls of (2); remove the rest of the block. Then write the fix. Then return NEEDS_CONTEXT "re-stamp":
  the Queen runs `stamp-red --baseline` (it stamps against HEAD's implementation and puts your working copy back),
  and you close. Name nothing beyond the class in your messages.

- Worker (2026-11-16, fifth dispatch): scope (1)-(3) built. The sealed block in tests/maintenance.test.sh is cut to
  the cd-scoping cases (six refused, four neighbours that pass), the command-word cases (five allowed, five
  neighbours refused) and the header sentence; the rest of the block is removed. `red_reason` now names the first
  label of the cut block. `--part guards`: 751 checks, 0 failed, 122 s. The test changed after the red receipt, so
  this returns NEEDS_CONTEXT "re-stamp": the Queen runs `stamp-red --baseline`, then the story closes.
- close-story (fifth dispatch) exit 4: `edited outside ## Files: docs/specs/guards-1115/guards-1115-01-git-guard.md,
  docs/specs/guards-1115/guards-1115-02-owner-guard.md, docs/specs/guards-1115/guards-1115-03-cycle-run-state.md -
  committed since the claim head 701fee89`. None are this worker's edits (the Queen's "revised" commits); they need
  a fresh claim head or the Queen's call, together with the re-stamp above.

## Implementation notes
- .claude/hooks/git-guard.sh: split_segments returns Seg words carrying their subshell scope and the operators
  around them; main keeps a `here` per scope, so a cd in a subshell moves only that subshell, a cd in a pipeline or
  the background moves nothing, a cd after `||` makes the place unknown (counts as held); `cd a b` does not move.
- .claude/hooks/git-guard.sh: judge_run judges an unresolved command word by its file name: a variable only in the
  folder part passes unless the name is cycle.sh (then the verb rule), `${X:-default}` reads as its default; a
  variable in the file name or any substitution is still refused.
- Commands a shell is handed (`bash -c`, a `!` alias) inherit the scope of the call that hands them.
- Header and card: the cooperative-agent sentence and the open classes in general words; the card ## Check list
  matches the header word for word.

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix.

## Files
- .claude/hooks/git-guard.sh
- tests/maintenance.test.sh
- docs/defects/work-discarded-by-git-verb.md

## Verification
`bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash scripts/defects-check.sh`

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 5275ccbffe03c9b872dd536ac436ef8de1d2d9dab18d8b6a13b25d7cb1e73038 (tests/maintenance.test.sh)
- impl: e995a5e9cdbb46a4d9f81e2b87cad6ac7ab30112c454f0032afbd6b1c41c0f7e
- stamped: 2026-11-16T12:34:29Z

```
::error::git-guard r2: a subagent's commit after a cd that does not take effect is denied under a DRIVER: (cd <temp>/tmp.io3PyChuJF/scr); git commit -m x - expected exit 1, got 0: 
::error::git-guard r2: a subagent's commit after a cd that does not take effect is denied under a DRIVER: true || cd <temp>/tmp.io3PyChuJF/scr; git commit -m x - expected exit 1, got 0: 
::error::git-guard r2: a subagent's commit after a cd that does not take effect is denied under a DRIVER: cd <temp>/tmp.io3PyChuJF/scr 2>/dev/null extra; git commit -m x - expected exit 1, got 0: 
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 1226 checks, 11 failed
```
