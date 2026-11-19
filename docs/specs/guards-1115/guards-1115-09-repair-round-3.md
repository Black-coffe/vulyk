---
story: guards-1115-09
status: done
returned: DONE
worker: worker-code
model: opus
wave: 7
blocked_by: []
narrow: true
red: required
red_reason: git-guard r3: a main-session forced tag or push is denied
red_verified_at: 2026-11-16T15:02:09Z c7d784d7bf969d9cb0ae9bb12c41763192345b76defdfb19c741a30d5637599c
---

# Repair round 3

## Goal
Make the asks and findings council round 3 left RED pass, and change nothing else.

## Requirements
> 2. The owner-record guards cannot be walked around by spelling the guarded script or record differently (quoting, globbing, a variable, a directory pathspec, a changed directory) (private S2, S11, S12).
> 4. git-guard sees the git verb past the global options and command positions its tests pin, and keeps its subagent rules when Python is missing; a `cd` that does not take effect does not move its build-lock lookup, and an unresolved variable in a command word that names no guarded thing is not refused; the positions it misses are named open in the header, by class (private S4, S5, T14).
> 6. The header-named open forms are closed as answered above (private S6, S10), and each hook header lists exactly what it still leaves open, in general words, and says the guards stop accidents and shortcuts of a cooperative agent, not an adversary.
> 7. Every closed gap has a failing test with the original form and a neighbour form (Law 6), and no legitimate flow of the Queen, a worker or a council seat is denied (existing suites stay green).

## Findings
ASK 2: RED - owner-record guards walked around by spelling - run: owner-guard, 32 spellings of the acceptance script, the briefed straight-through flag, the record and its pathspecs, as a subagent and as the main session with an empty transcript saw: subagent denied on all 32 (split quotes, wildcard, variable, folder pathspec, dot, -A, -C, changed directory) and legit calls pass; main session with no owner words: plain spelling denied, but the same call with the script named through split quotes, a wildcard or a variable, the verdict held in a variable, or the flag held in a variable is NOT denied. The header and the card name this open on purpose; the ask names exactly these classes and was not narrowed
ASK 6: RED - header-named forms closed, headers exact - run: git-guard forced tag, forced push (5 forms), PowerShell evaluate-a-string as subagent and as main session; read the three headers saw: subagent denied on all; all three headers carry the cooperative-agent sentence and an open list; but the main session is not denied a forced tag, a forced push or the evaluate command, and git-guard's open list does not name that (it reads "history rewrites other than a forced tag or push ... by the main session"), so the owner's "forms no agent needs" are closed for subagents only and the list is not exact
ASK 7: RED - tests per gap, no legitimate flow denied - run: bash tests/maintenance.test.sh --part guards; court-guard as a seat whose call starts in the project folder (as the seat contract says it does) saw: 762 checks, 0 failed, with neighbour-form batches; but after "cd COURT &&" any command substitution reading a court file by relative path (cat, wc, a redirect, a test part) is denied as "outside the court" (the cd is not carried into the substitution); the same call passes when the input cwd is the court. This seat hit it live four times
1. tests/full-suite.sh:172 [regression] the full suite must end `SUITE: ok` with every part under 70% of its cap: the round 3 log (`docs/specs/guards-1115/council/round-3/suite.log`, steps 2, 4, 6 and 8 FAIL) cuts `council:advance` at 211 s, `cycle:red` at 216 s, `telemetry:install` at 213 s, `telemetry:install-xp2` at 214 s and `telemetry:edits` at 212 s of a 300 s cap, each with every check ok - base: the round 1 log shows `SUITE: ok 1336s`; round 2's critical line was answered by a re-timing on an idle machine and no split, and two more parts now cross the line; my rerun `bash -c '. scripts/lib.sh && run_capped 300 bash tests/council.test.sh --part advance'` ended rc 0 in 159 s with no error line, so the red is run time under the gate's own load on parts that sit within reach of 210 s (card `test-gate-one-long-limit`, How-to: a part that grows toward its cap is split).
1. .claude/hooks/git-guard.sh:938 [regression] a command word of a subagent that holds a variable must be judged as the program it runs whenever its default or its value names a program the hook reads through, not only git or cycle.sh: with a default that names a shell, a wrapper or eval (:442 `command_word`, :466 `fed_string` and :782 `run_word` read only a literal word), or a variable the same command sets to git while its default names another program (:935 takes the default), a discarding verb, a `cycle.sh` verb outside the six and a write of the run state exit 0 - base: `--check` on `git show b5b1466e:.claude/hooks/git-guard.sh` exits 1 for each of my 9 forms, on the head 0 (story 08 closed the default that names git only; header :36 says a default is read as its default).
2. .claude/hooks/court-guard.sh:664 [regression] ordinary shell syntax of a blind seat must pass: an unquoted arithmetic expansion that holds a command substitution (a seat timing its own run) and a `case` whose later arm is a wildcard pattern (the default arm) are refused as a program whose name is built from a variable or a glob (:659 skips only the segment that starts with the `case` word, and `items` at :249 cuts both forms into new command positions) - base: `--check` on the b5b1466e copy exits 0 for my 3 cases, on the head 1; the quoted arithmetic form and a `case` with literal arms pass on both.
3. .claude/hooks/git-guard.sh:796 [ask 2] a `cycle.sh` verb outside the six must be refused for a subagent under the spellings ask 2 names, or that part must be narrowed the way the owner chose for git-guard: a shell option that carries a value (:796-803), a verb handed in by xargs, the shell or the whole command held in a variable and a globbed or variable script word behind a wrapper still exit 0 (11 of my round 1 cases, unchanged; round 2 line 3), while the 2026-11-16 line of plan.md `## Descoped` names only asks 1, 3 and 4, ask 2 is not narrowed, and the open list (:84-103, the card's `## Check` with it) names none of these classes nor a command line after a heredoc whose end word the hook reads short, although :36-41 says such calls are denied (card `safeguard-bypassable-or-late`, Never line 1).
4. .claude/hooks/git-guard.sh:1028 [ask 4] under a DRIVER a `cd` that runs inside a child shell (the command string handed to a shell) must not move the build-lock lookup of the commands after it: `inherit` (:1028-1032) puts the handed string into the scope of the caller, so a commit that follows is judged in the folder the child went to and exits 0 in a held repository - base: `--check` on `git show c5724761:.claude/hooks/git-guard.sh` exits 1 for my case, on the head 0; the subshell, `||`, two-folder, pipeline and background forms of round 2 line 1 are refused now.
- [regression] PART council:advance ok 211s cap 300s
- [regression] PART cycle:red ok 216s cap 300s
- [regression] PART telemetry:install ok 213s cap 300s
- [regression] PART telemetry:install-xp2 ok 214s cap 300s
- [regression] PART telemetry:edits ok 212s cap 300s
- NEEDS_CONTEXT (worker, before any edit): finding 1 (tests/full-suite.sh:172) needs a file outside `## Files`.
  `council:advance` and `cycle:red` can be split in tests/council.test.sh and tests/cycle.test.sh (both named), but
  `telemetry:install`, `telemetry:install-xp2` and `telemetry:edits` (and `telemetry:install-xp`, 209 s, 1 s under
  the line) are parts of tests/telemetry.test.sh, which `## Files` does not name. The only lever inside `## Files`
  is a lower default `--jobs` in tests/full-suite.sh, but that is the load answer round 2 was judged for (the card
  `test-gate-one-long-limit` How-to says split), and tests/full-suite.test.sh:238 pins the cap of 12, also not named.
  Question: add `tests/telemetry.test.sh` to `## Files` so those parts are split (recommended), or say otherwise.
- Queen (2026-11-16): (1) Finding 1: yes, split the parts (card test-gate-one-long-limit), never a lower `--jobs` or
  a higher cap: `tests/telemetry.test.sh` is added to `## Files` for its four parts; split `council:advance` and
  `cycle:red` in their own files; register the new part names where tests/full-suite.sh lists them. Idle timings
  are about 170 s; the gate runs its parts in parallel, so aim each new part well under 150 s idle.
  (2) Finding 3 (`cycle.sh` verb spellings in git-guard): not this story; story 10 takes it (owner, 2026-11-16:
  «Чинить сейчас (Рекомендую)»; the Queen's earlier narrowing of ask 2 is undone).
  (3) Your planned call stands: deny forced tag, forced push and `iex` to the main session too; flip that one test.
  (4) Findings 1 (major), 2, 4 and the asks 2, 6, 7 lines: as you listed. Name forms by class in messages.
  (5) The leak minors are done by the Queen (receipt tails of 04 and 05 masked).

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix.

## Files
- tests/full-suite.sh
- tests/telemetry.test.sh
- .claude/hooks/git-guard.sh
- tests/maintenance.test.sh
- .claude/hooks/court-guard.sh
- tests/inject.test.sh
- docs/defects/work-discarded-by-git-verb.md
- .claude/hooks/owner-guard.sh
- docs/defects/owner-words-by-builder.md
- tests/defects.test.sh
- .claude/agents/council-opus.md
- .claude/agents/council-haiku.md
- scripts/cycle.sh
- scripts/lib.sh
- tests/cycle.test.sh
- tests/council.test.sh
- tests/solo.test.sh
- tests/e2e.test.sh
- docs/cycle.md
- docs/defects/*

## Verification
`bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/cycle.test.sh --part runstate`
`bash tests/cycle.test.sh --part red`
`bash tests/cycle.test.sh --part red2`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part close2`
`bash tests/cycle.test.sh --part approved`
`bash tests/council.test.sh --part close`
`bash tests/solo.test.sh`
`bash tests/e2e.test.sh`
`bash scripts/defects-check.sh`

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: c7d784d7bf969d9cb0ae9bb12c41763192345b76defdfb19c741a30d5637599c (tests/council.test.sh, tests/cycle.test.sh, tests/defects.test.sh, tests/e2e.test.sh, tests/inject.test.sh, tests/maintenance.test.sh, tests/solo.test.sh)
- impl: a8a466ed1ea1ced54137f1898a1bb054e0704125dd2f4d0118c7465c15608d6d
- stamped: 2026-11-16T15:02:09Z

```
::error::git-guard r3: a main-session forced tag or push is denied: git tag -f v1 - expected exit 1, got 0: 
::error::git-guard r3: a main-session forced tag or push is denied: git push --force - expected exit 1, got 0: 
::error::git-guard r3: a main-session forced tag or push is denied: git push origin +main - expected exit 1, got 0: 
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 1263 checks, 19 failed
```

## Implementation notes
- .claude/hooks/git-guard.sh: forced tag, forced push and `iex` denied to every caller (main-session prefilter reads `iex` too); a command word whose default or value from the command names git, cycle.sh, a shell, a wrapper or eval is judged as each such program (`variants`); a shell's command string and a `!` alias run in a child scope, eval in the caller's; header open list names the `cycle.sh` verb spelling classes (Queen: moved to 0.55.0).
- .claude/hooks/court-guard.sh: substitutions are lifted into marks and read where their command stands (after each cd), `$(( ))` keeps its inner substitutions, a case arm's pattern is no command.
- .claude/hooks/owner-guard.sh: the main session's shell call that runs human-check with a verdict or `briefed --go` spelled otherwise is denied through the subagent reader in a script-only mode while the text prefilter sees it; what the main session cannot see is named open in the hook header; the prefilter was widened.
- docs/defects/work-discarded-by-git-verb.md, docs/defects/owner-words-by-builder.md: `## Check` and open lists match the hook headers.
- tests/telemetry.test.sh: parts install, install-xp, install-xp2 and edits split into install2, install-xp3, install-xp4 and edits2 (checks moved, none dropped: 83/87/28/22 -> 83/89/30/24 incl. per-part syntax checks); measured 4 old parts at 159-164 s in parallel, the 8 new ones at 63-126 s in parallel. tests/full-suite.sh needs no change: it reads `--list-parts`.
- tests/council.test.sh (advance -> advance + advance2), tests/cycle.test.sh (red -> red + red3): split for time.
- Tests: maintenance (main-session forced forms, child-shell cd, defaulted program words, cycle.sh open-list line), inject (court substitution cwd, arithmetic, case arms), defects (main-session spellings and legit neighbours).
