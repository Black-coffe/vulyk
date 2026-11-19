---
story: guards-1115-12
status: done
returned: DONE
worker: worker-code
model: opus
wave: 10
blocked_by: []
narrow: true
red: required
red_reason: git-guard r5: a subagent's unset program variable passes (no DRIVER)
red_verified_at: 2026-11-17T03:09:52Z 5fc7eccf359639f828d23ab3d3b14a972c9003cb74e48df4dd8f66780b24eb0d
---

# Repair round 5

## Goal
Make the asks and findings council round 5 left RED pass, and change nothing else.

## Requirements
> 2. The owner-record guards cannot be walked around by spelling the guarded script or record differently (quoting, globbing, a variable, a directory pathspec, a changed directory) (private S2, S11, S12).
> 4. git-guard sees the git verb past the global options and command positions its tests pin, and keeps its subagent rules when Python is missing; a `cd` that does not take effect does not move its build-lock lookup, and an unresolved variable in a command word that names no guarded thing is not refused; the positions it misses are named open in the header, by class (private S4, S5, T14).
> 7. Every closed gap has a failing test with the original form and a neighbour form (Law 6), and no legitimate flow of the Queen, a worker or a council seat is denied (existing suites stay green).

## Findings
ASK 4: RED - git-guard verb past options/positions, no-Python rules, cd, unresolved variable - run: 134 hook inputs to git-guard.sh (17 global-option forms, 40 command positions, 16 with a PATH holding no Python, 18 cd / -C / GIT_DIR forms across a held and a free repo, 27 variable command words) saw: options, pinned positions, no-Python subagent rules and the cd lookup as asked; but a subagent call whose program word is a variable the hook cannot resolve, with words naming no guarded thing, is refused: "$PYBIN" tests/x.py --quick; $VULYK_PY -m py_compile src/x.py; $EDITOR src/a.txt; PY set from a command substitution then "$PY" tests/x.py -> deny "Spell the script path", with or without a DRIVER, while the same call behind timeout 60 or env, and in the no-Python fallback, passes
ASK 7: RED - every closed gap tested (original + neighbour), no legitimate flow denied - run: bash tests/maintenance.test.sh --part guards; grep of original/neighbour labels in the three guard test files; 53 legit worker, seat and Queen flows piped to the three hooks saw: 871 checks, 0 failed, exit 0, labels present; but owner-guard.sh denies a council seat (Bash is its only write tool) the heredoc that writes its report under the reports folder when a report line quotes the acceptance script beside a verdict word, or a redirect into a plan file ("a subagent cannot record an acceptance"), and denies a worker the same text sent by echo or heredoc to a notes file in /tmp; git-guard.sh and court-guard.sh read that heredoc as text and allow it. The live hook refused this seat two such calls this round
1. .claude/hooks/court-guard.sh:291 [regression] round-4 major 1 is fixed for bare parentheses only: the scan that decides whether an expansion opening with a dollar sign and two parentheses is arithmetic must pass over a closing parenthesis that is escaped or stands inside quotes, as bash does, or refuse the expansion; the head counts it as the closing one, takes the text for arithmetic and leaves the commands of the body unjudged, so a blind seat's read outside the court, a git read off the allowlist and a cd out of the court pass (5 unquoted forms) - base: hook input for a seat through `--check` on the `git show c5724761:.claude/hooks/court-guard.sh` (merge-base) and af4665d6 copies exits 1 for all 5, on 941d06c4 and the head 0; bash 5.3 ran the read on a harmless file for both shapes.
2. .claude/hooks/court-guard.sh:851 [regression] round-4 major 2 is half fixed: pattern mode must open only where bash reads the word as the `case` keyword, so not when a redirect or a quoted or escaped keyword word (one the hook skips in front of a command, :842) stands before it in the same simple command, and never in a PowerShell call, which has no such keyword; the head still opens it there and every command up to the next closing parenthesis goes unjudged (20 forms: 4 behind a redirect, 9 behind a quoted keyword, 2 inside a substitution or a child shell's string, 5 in the PowerShell tool; outside reads, a cd out of the court, a git read off the allowlist) - base: the merge-base and af4665d6 copies deny all 20, 941d06c4 and the head allow all 20; bash 5.3 and PowerShell ran what follows on a harmless file.
3. .claude/hooks/court-guard.sh:796 [regression] the closing word of a case must be recognised as bash reads it when a line continuation stands inside it or right after it: `mark_case` runs before `items` (:363) drops the continuation, so the word gets no mark, pattern mode stays on, and the commands up to the next closing parenthesis and the redirects on that word go unjudged (8 forms) - base: the merge-base and af4665d6 copies deny all 8; 941d06c4 denies 4 of them (commands after the closing word), which this diff newly allows, and the other 4 (its redirects, a case with no arm) pass on 941d06c4 and the head alike; bash 5.3 ran 3 of the shapes on a harmless file.
4. .claude/hooks/git-guard.sh [ask 2] behind a wrapper a program held in a variable the command sets must be judged as that program: in some line shapes it is not, for cycle.sh and for git alike (named open in the hook header; forms private).
- close-story (attempt 2): `defect card shell-needs-gnu-or-bash4 fails on tests/maintenance.test.sh` (portability-check `array`: bare "${R5OK[@]}" / "${R5NO[@]}" at :1795-1799 in a set -u file). Worker changed the four calls to ${R5OK[@]+"${R5OK[@]}"} / ${R5NO[@]+...} (portability-check ok, assertions unchanged); close-story then refuses `test changed after red receipt: re-run stamp-red` with the implementation already in the tree. Needs the Queen: re-stamp from base (revert impl, stamp-red, re-apply) or accept the sealed-test edit.

## Implementation notes
- court-guard.sh `lift`: the `$((` arithmetic scan skips escaped and quoted characters, so `\)` / `")"` close nothing (finding 1).
- court-guard.sh `mark_case`: marks unquoted keywords too (MARKED_KW); `walk` takes the lead word only before the segment's first redirect, past marked keywords; PowerShell is never marked (finding 2).
- court-guard.sh `walk`: line continuations joined before `mark_case` (finding 3).
- git-guard.sh `command_word(seg, env=None)`: no jump to a later git/shell/wrapper word when the variable run word is followed by a plain word, or (given env) the command sets it to such a program; `variants` and main's alt splice pass env (finding 4).
- git-guard.sh `judge_run`: a whole-variable program word left unresolved (unset, or set from a substitution) is judged by its words behind a wrapper or not (ask 4).
- owner-guard.sh: for a subagent's shell call `command_actions` keeps only the strict human.jsonl rule (`record_acts`); subagent_judge reads the words (ask 7).
- Headers + cards: court-guard header, git-guard header parser paragraph and open list (card `## Check` same words), owner-guard header and owner-words-by-builder card.
- Tests: inject.test.sh (r5 court forms incl. PowerShell), maintenance.test.sh (r5 git-guard), defects.test.sh (r5 owner-guard text/neighbour forms).
- Attempt 3: the Queen re-stamped from base with the portability-fixed test (03:09:52Z); the implementation is re-applied unchanged.
- Prototyped in a scratch copy before the red receipt; finding 4 for the main session not covered (it notes no variables; the round named subagents).

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix.

## Files
- .claude/hooks/court-guard.sh
- tests/inject.test.sh
- .claude/hooks/git-guard.sh
- tests/maintenance.test.sh
- docs/defects/work-discarded-by-git-verb.md
- .claude/hooks/owner-guard.sh
- tests/defects.test.sh
- tests/full-suite.sh
- tests/telemetry.test.sh
- docs/defects/owner-words-by-builder.md
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
- tests: 5fc7eccf359639f828d23ab3d3b14a972c9003cb74e48df4dd8f66780b24eb0d (tests/council.test.sh, tests/cycle.test.sh, tests/defects.test.sh, tests/e2e.test.sh, tests/inject.test.sh, tests/maintenance.test.sh, tests/solo.test.sh)
- impl: 45f411dd17b001312890948256934f6896c513beb0cd63d8604713e10e11173a
- stamped: 2026-11-17T03:09:52Z

```
::error::git-guard r5: a subagent's unset program variable passes (no DRIVER): "$PYBIN" tests/x.py --quick - expected exit 0, got 1: {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "VULYK git guard: a subagent may not run `$PYBIN` - the script or program name holds a variable or a substitution the hook cannot resolve. Spell the script path."}}
::error::git-guard r5: a subagent's unset program variable passes (no DRIVER): $VULYK_PY -m py_compile src/x.py - expected exit 0, got 1: {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "VULYK git guard: a subagent may not run `$VULYK_PY` - the script or program name holds a variable or a substitution the hook cannot resolve. Spell the script path."}}
::error::git-guard r5: a subagent's unset program variable passes (no DRIVER): $EDITOR src/a.txt - expected exit 0, got 1: {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "VULYK git guard: a subagent may not run `$EDITOR` - the script or program name holds a variable or a substitution the hook cannot resolve. Spell the script path."}}
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 1376 checks, 17 failed
```
