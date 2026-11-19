---
story: guards-1115-11
status: done
returned: DONE
worker: worker-code
model: opus
wave: 9
blocked_by: []
red: required
red_reason: git-guard r4: a subagent's guarded word behind a wrapper option held in a variable is denied
red_verified_at: 2026-11-16T21:05:01Z 2b46e17f35e87560673fe2d7bee9040a8fc3cbb0ee5beebbf0dfcbe7a6223191
---

# Repair round 4

## Goal
Make the asks and findings council round 4 left RED pass, and change nothing else.

## Requirements
> 2. The owner-record guards cannot be walked around by spelling the guarded script or record differently (quoting, globbing, a variable, a directory pathspec, a changed directory) (private S2, S11, S12).

## Findings
ASK 2: RED - owner-record guards not walked around by another spelling - run: 70 cycle.sh spellings to git-guard as a subagent saw: quotes, globs, bracket patterns, letter case, dot-dot, assigned variable, for-list variable, changed directory, subshell, pushd, bash -c, env, source, xargs, PowerShell all denied for the owner-only verbs and the six worker verbs allowed; BUT a shell's script word written as a variable with a default value (4 operator and quoting variants, also behind a wrapper) is allowed with the owner-only verbs judge, approve, revise, reopen (the same variable as the command word, or with no default, is denied). The header says this form is read as its default; the variable class of this ask is open. owner-guard's own script and record spellings could not be probed directly (the live guard refuses a seat command carrying those words): suite section ok only
1. .claude/hooks/court-guard.sh:286 [regression] an expansion that opens with a dollar sign and two parentheses must be taken for arithmetic only when the parentheses inside it balance as one expression, and otherwise be read as the command substitution bash falls back to (or be refused): `lift` takes every such text that closes with two parentheses for arithmetic and keeps only the substitutions inside it, so the commands of a body that opens and closes with a parenthesised group go unjudged, and a blind seat's read outside the court and a git read off the allowlist pass - base: hook input on stdin to the `git show af4665d6:.claude/hooks/court-guard.sh` copy answers deny for my 4 unquoted forms (and allow for the same shape reading a court file, so the base judged the path), the head copy allows all 4; bash's fallback is from its source and POSIX, not run here (the session's built-in safety check refused that probe).
2. .claude/hooks/court-guard.sh:808 [regression] the redirects of the simple command that holds `esac` must be judged, and pattern mode (:813) must start only at a real `case` keyword and end at its `esac` also when that word stands in the same simple command: the head skips the closing word's segment whole, so a redirect on it reads or writes outside the court (6 forms), and after a `case` with no arm, or a quoted or escaped word spelled like the keyword, every command up to the next closing parenthesis goes unjudged (9 forms: outside reads, a cd out of the court, a git read off the allowlist) - base: the af4665d6 copy denies all 15, the head copy allows all 15; in bash the three shapes ran what follows on harmless files.
3. .claude/hooks/git-guard.sh:505 [regression] behind a wrapper a word made by a variable that is not the program (an option or its value held in a variable) must not end the search for the git, shell or cycle.sh word after it: `command_word` now stops at that word, so for a subagent a discarding verb, a history verb under a DRIVER, a command string handed to a shell and a `cycle.sh` verb outside the six exit 0 when the command sets the variable (7 forms, the last one inside ask 2's variable class), and for the main session a discarding verb over a dirty tree exits 0 whether the command sets the variable or not (5 forms with a `porcelain` field) - base: `--check` on the `git show af4665d6:.claude/hooks/git-guard.sh` copy exits 1 for each, on the head 0; the header (:22-26) says such a word is judged as itself and the open list does not name what that lets through.
- Queen (2026-11-16, before the build; owner after round 4: «Ремонт: регрессии + вопрос 2 (Рекомендую)»):
  fix the three regressions and the last ask-2 spelling, each with a test of the original form and a neighbour form,
  plus the over-deny the round named (a wrapper in front of an unset variable: an ordinary worker call). Read the
  exact forms from council/round-4 (review.md, opus.md); name them by class in messages. This is defensive work on
  this repository's own guard hooks.
- Owner, 2026-11-16: «Push/tag нельзя, iex можно (Рекомендую)». In git-guard the main session stays denied forced
  push and forced tag, and is allowed `iex` / Invoke-Expression again; subagents stay denied all three. Change the
  test that pins the main-session `iex` refusal to an allowed case, and the header's line to match.
- git-guard's header and the card's `## Check` list name open classes only, no spellings (round 4 minor 1).
- Out of scope: review major 4 (unanchored, the same on the base) and the other minors stay for the next circle.

## Implementation notes
- court-guard.sh `lift`: `$((` is arithmetic only when the first `)` it does not open is followed by another; else it falls to the substitution parser (finding 1).
- court-guard.sh `walk`: `mark_case` marks only unquoted, unescaped `case`/`esac` words (a `\x01` in the text is unreadable); a case segment holding its `esac` opens no pattern mode; the redirects on the `case` and `esac` segments are judged (finding 2).
- git-guard.sh `command_word`: behind a wrapper the first git/cycle.sh/eval/shell/wrapper word wins over a variable word before it (finding 3).
- git-guard.sh `judge_run`: iterates `word_values`, so a shell's script word with a default value is read as its default (ask 2).
- git-guard.sh `judge_run`: a program behind a wrapper held in a variable the command does not set passes unless its next words are a cycle.sh verb outside the six (new Python `CYCLE_OTHER`, mirrors the bash list), stamp-red --baseline, or a listed git verb (over-deny); keeps the round-3 `timeout 60 "$C" revise dv` refusal.
- git-guard.sh iex: denied to subagents only; the main session's evaluated string is read as PowerShell commands (fed_string), so a discarding verb inside it still meets the dirty-tree check.
- Header + card `## Check`: iex line, wrapper rule, open list in classes (dropped the two spellings, the inexact variable-git-word clause, named the two wrapper-variable classes left open).
- Tests: inject.test.sh (4+12 deny, 3+5 allow), maintenance.test.sh (r4 section; main-session iex test turned to allow plus a dirty-tree deny).

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix.

## Files
- .claude/hooks/court-guard.sh
- tests/inject.test.sh
- .claude/hooks/git-guard.sh
- tests/maintenance.test.sh
- docs/defects/work-discarded-by-git-verb.md
- .claude/hooks/owner-guard.sh
- docs/defects/owner-words-by-builder.md
- tests/defects.test.sh
- tests/full-suite.sh
- tests/telemetry.test.sh
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
- tests: 2b46e17f35e87560673fe2d7bee9040a8fc3cbb0ee5beebbf0dfcbe7a6223191 (tests/council.test.sh, tests/cycle.test.sh, tests/defects.test.sh, tests/e2e.test.sh, tests/inject.test.sh, tests/maintenance.test.sh, tests/solo.test.sh)
- impl: d8200c60c910b3782a28571da059587f81667a1562e11a5005c006077fcf02aa
- stamped: 2026-11-16T21:05:01Z

```
::error::git-guard r4: a subagent's guarded word behind a wrapper option held in a variable is denied: O=-i; env $O git reset --hard - expected exit 1, got 0: 
  ok    git-guard r4: a subagent's guarded word behind a wrapper option held in a variable is denied: env $O git stash
::error::git-guard r4: a subagent's guarded word behind a wrapper option held in a variable is denied: O=-n; timeout 5 $O git checkout -- . - expected exit 1, got 0: 
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 1346 checks, 26 failed
```
