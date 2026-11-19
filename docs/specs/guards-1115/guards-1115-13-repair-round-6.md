---
story: guards-1115-13
status: done
returned: DONE
worker: worker-code
model: opus
wave: 11
blocked_by: []
narrow: true
red: required
red_reason: round-6 regression forms are denied again
red_verified_at: 2026-11-17T07:29:57Z e4e956e95d68da2b4b89ff3591a9eae8dfaf69665a2ad6196b6b2e458759faf1
---

# Repair round 6

## Goal
Make the asks and findings council round 6 left RED pass, and change nothing else.

## Requirements
> 2. The owner-record guards cannot be walked around by spelling the guarded script or record differently (quoting, globbing, a variable, a directory pathspec, a changed directory) (private S2, S11, S12).

## Findings
ASK 2: RED - owner-record guards walked by respelling - run: owner-guard.sh, main-session Bash input (no agent_id), the two guarded script calls with the script, verb or verdict word split by a quote pair, a backslash or a same-call variable so that none of the text prefilter's words survives whole, 8 forms saw: no deny, exit silent (the same 8 from a subagent: DENY; a main-session form that splits elsewhere, as the project's own tests do: DENY). The header's body says such main-session spellings are denied; its open list concedes them. Ask 2 keeps its wording, so a quoting or variable spelling that passes is RED. Subagent side is solid: 27 script respellings and 40 record forms (pathspec by folder, dot, -A/-u/-a, glob, cd, -C, variable, case, redirects, copies) all DENY.
1. .claude/hooks/court-guard.sh:874 [regression] round-5 major 2 is fixed only for the forms it named (a redirect, a quoted or escaped keyword, PowerShell: 6 probes deny): pattern mode must open only where bash reads the word as the `case` keyword, so also not when the word before it in the same simple command is one the tokenizer (:387-398) turns into a separator or a parenthesis - a quoted or escaped separator or parenthesis, a lone brace given as an argument, a process substitution, an array assignment, a parenthesis inside a parameter expansion; the head starts a new segment there, opens pattern mode and leaves every command up to the next closing parenthesis unjudged, so a blind seat's read outside the court, a git read off the allowlist and a cd out of the court pass (19 forms, one of them inside a substitution), and the header (:15-18) states the rule as closed - base: a seat's hook input through `--check` on the `git show c5724761:.claude/hooks/court-guard.sh` (merge-base) and af4665d6 copies exits 1 for all 19, on 941d06c4, b32347d7 and the head 0; bash 5.3 ran the read on a harmless file for 15 of the shapes.
2. .claude/hooks/git-guard.sh:520 [regression] behind a wrapper a later git, shell or cycle.sh word must stay the command word when the variable word before it may expand to nothing or to an option: the head reads a variable word followed by any plain word (an assignment given to env, an option's value) as a program with its arguments and judges nothing after it, so for a subagent an owner-only cycle.sh verb, a discarding git verb and a history verb under a build lock pass (10 forms; an unset variable expands to nothing, so the shell runs the guarded command as written) - base: `--check` on the merge-base, 941d06c4 and b32347d7 copies of git-guard.sh exits 1 for all 10, on the head 0.
3. .claude/hooks/git-guard.sh [ask 2] a program word held in a variable the command does not set, or sets from a substitution, must pass only when its words name no guarded thing: the head does not read every following word, so some carriers pass (private); the bare form is denied and pinned.
4. .claude/hooks/owner-guard.sh:453 [regression] a subagent's shell command must still be judged wherever a shell or an interpreter runs its text, not only where a guarded call stands as a program word: with `command_actions` cut to the record rule for a subagent, a guarded call (the acceptance script with a verdict, the brief verb with its owner flag) or a rewrite of a spec's plan file named by its path passes when the text is piped into a shell, fed to one by a process substitution, sourced from a here-string, stands in a substitution inside a heredoc body whose end word is unquoted (bash runs it while cat only prints), or in an interpreter's inline code (22 forms); the header still states the plan-file forms (:19-23) and a command substitution (:37-38) as denied - base: a subagent's hook input through `--check` on the merge-base and b32347d7 copies of owner-guard.sh exits 1 for all 22, on the head 0; the quoted-text forms of the round-5 ask 7 line pass on the head as asked, and a heredoc with a quoted end word is rightly text.
- Queen (2026-11-17, before the build; owner after round 6: «Откат к версиям без регрессий (Рекомендую)»). This
  story is a revert, not a new fix; no council round follows it. Defensive work on this repository's own guard hooks.
  (1) Write `.claude/hooks/court-guard.sh` with its content at af4665d6, and `.claude/hooks/git-guard.sh` and
  `.claude/hooks/owner-guard.sh` with their content at b32347d7 (`git show <sha>:<path>`, written as the file; never a
  git verb that discards work). The Queen checked by running HEAD's own tests on those copies: none lets through a
  test-pinned form that 0.53 refuses; the round-6 reviewer's base runs say the same for its findings 1, 2, 4 and 5.
  (2) Tests: cases that pin behaviour the revert drops change with it. By the Queen's run of HEAD's tests on the
  copies: tests/inject.test.sh 11 (a seat's `cd` into the court, then a substitution reading a court file: back to
  denied, a known over-deny); tests/defects.test.sh 7 (a subagent's report text quoting a guarded call: back to
  denied) and 1 leak-check line to re-read; tests/maintenance.test.sh 10 (an unresolved program variable naming no
  guarded thing: back to denied), 7 (a held program behind a wrapper with a later guarded word: passes on 0.53 too:
  drop the case, name the class open) and 1 (the card's open list must equal the header's). Flip a dropped
  over-deny fix to the reverted result with a label that says `known over-deny, 0.55.0`; keep every other case.
  (3) Red test: one original and one neighbour form per round-6 finding 1, 2, 4 and 5 (finding 5 is the quoted
  arm-separator class), expected denied; they fail on HEAD and pass on the reverted copies. red_reason:
  `round-6 regression forms are denied again`.
  (4) Not fixed, named open by class in the header's open list (and the card's `## Check` list in the same words):
  ask 2's main-session respelling of a guarded script name by splitting its words (owner-guard); finding 3's program
  held in a variable the command does not set or sets from a substitution (git-guard); the over-denies the revert
  brings back. Keep the cooperative-agent sentence in all three headers.
  (5) Name forms by class in messages and notes; concrete spellings live only in the test files.

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix.

## Files
- .claude/hooks/court-guard.sh
- tests/inject.test.sh
- .claude/hooks/git-guard.sh
- tests/maintenance.test.sh
- .claude/hooks/owner-guard.sh
- tests/defects.test.sh
- docs/defects/*

## Verification
`bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash scripts/defects-check.sh`
`bash tests/cycle.test.sh --part runstate`
`bash tests/cycle.test.sh --part red`
`bash tests/cycle.test.sh --part red2`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part close2`
`bash tests/cycle.test.sh --part approved`
`bash tests/council.test.sh --part close`
`bash tests/solo.test.sh`
`bash tests/e2e.test.sh`

## Implementation notes
- .claude/hooks/court-guard.sh: content at af4665d6; open list gains one over-deny line (case statements, arithmetic with a group or a substitution, a substitution after a cd into the court).
- .claude/hooks/git-guard.sh: content at b32347d7; open list gains the subagent's unresolved program variable (finding 3's class) as a known over-deny, 0.55.0.
- .claude/hooks/owner-guard.sh: content at b32347d7; open list names ask 2's main-session word-splitting respelling explicitly and the subagent's quoted-text over-deny; the body's main-session sentence now says it holds while a prefilter word stays whole.
- docs/defects/work-discarded-by-git-verb.md, owner-words-by-builder.md: content at b32347d7 plus the same open lines as the headers, word for word.
- tests/inject.test.sh: 11 allow cases flipped to `known over-deny, 0.55.0` deny (helper `cgo`); 8 red forms for findings 1 and 5 (helper `cg6`).
- tests/defects.test.sh: the 7 quoted-text cases flipped to over-deny deny; 7 red forms for finding 4 (helper `sa6`, JSON-encoded).
- tests/maintenance.test.sh: round-5 finding-4 deny block dropped (passes on 0.53 too, named open); R5OK flipped to over-deny deny twice; 5 red forms for finding 2 under a DRIVER.
- Checked before the receipt: the edited tests ran on a copy of the tree holding the reverted hooks; the only failures left were the copy's own (no .git) and the card/header list mismatch the card revert fixes.
- Surprise: the defects leak-check line failed only in the scratch copy (its path holds the Claude temp folder), not a hook effect.

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: e4e956e95d68da2b4b89ff3591a9eae8dfaf69665a2ad6196b6b2e458759faf1 (tests/defects.test.sh, tests/inject.test.sh, tests/maintenance.test.sh)
- impl: 78f1662c7a941b48b05288b2988a35747f0482405aaff9bd1fc6d6044b5c884c
- stamped: 2026-11-17T07:29:57Z

```
::error::git-guard r6: round-6 regression forms are denied again: env $X A=1 bash scripts/cycle.sh judge dv - expected exit 1, got 0: 
::error::git-guard r6: round-6 regression forms are denied again: env $X A=1 git reset --hard - expected exit 1, got 0: 
::error::git-guard r6: round-6 regression forms are denied again: nice $N 5 git reset --hard - expected exit 1, got 0: 
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 1374 checks, 15 failed
```
