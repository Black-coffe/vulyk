---
story: guards-1115-08
status: done
returned: DONE
worker: worker-code
model: opus
wave: 6
blocked_by: [guards-1115-07]
red: required
red_reason: a defaulted variable that names git is judged as git
red_verified_at: 2026-11-16T13:27:09Z efb84648e762c183659b259d22cdbbb211116bbeacde3a7a450295a153c7802f
---

# git-guard and owner-guard: a defaulted program word and a long alias chain

## Goal
Two small gaps found by an automated review of the commits of stories 05 and 06, both confirmed by probe on the
committed hooks (2026-11-16). This is defensive work on this repository's own guard hooks.
1. git-guard (a regression of story 05): story 05 lets a command word holding an unresolved variable pass when it
   names no guarded thing, and reads `${X:-default}` as its default. A command word whose default (or whose
   rewritten base) names git or `cycle.sh` is now let through, while it was refused before story 05. Judge it as
   the program it names: the same rules as a plain `git` / `cycle.sh` word. A variable whose base names no guarded
   program keeps passing (story 05's over-deny fix stays).
2. owner-guard: the alias walk stops after a fixed number of steps and then judges the unexpanded word. When an alias
   is still unexpanded after the walk (a longer chain, or a cycle), refuse the call for a subagent, with a reason
   that names the alias chain; a chain the walk resolves is judged as today.
Marked red: a parser that decides whether a call reaches git.

## Requirements
> 4. git-guard sees the git verb past the global options and command positions its tests pin, and keeps its subagent rules when Python is missing; a `cd` that does not take effect does not move its build-lock lookup, and an unresolved variable in a command word that names no guarded thing is not refused; the positions it misses are named open in the header, by class (private S4, S5, T14).
> 2. The owner-record guards cannot be walked around by spelling the guarded script or record differently (quoting, globbing, a variable, a directory pathspec, a changed directory) (private S2, S11, S12).
> 7. Every closed gap has a failing test with the original form and a neighbour form (Law 6), and no legitimate flow of the Queen, a worker or a council seat is denied (existing suites stay green).

## Files
- .claude/hooks/git-guard.sh
- tests/maintenance.test.sh
- .claude/hooks/owner-guard.sh
- tests/defects.test.sh

## Non-goals
- No other class of either hook. No header change: both forms are closed by this story.
- Do not touch court-guard (story 07) or any test of it.
- Keep every over-deny case of stories 05 and 06 passing.

## Acceptance criteria
- [ ] git-guard, subagent: `${X:-git} reset --hard` and the same with an absolute git path in the default are refused
  as `git reset --hard` is; neighbour: a defaulted variable naming a harmless program, and story 05's allowed
  variable forms, pass. The label contains `a defaulted variable that names git is judged as git`.
- [ ] owner-guard, subagent: a `git add` of the acceptance record reached through an alias chain longer than the walk
  is refused; neighbour: a two-step chain is refused as today, and an alias chain ending in a harmless verb passes.
- [ ] Every new case fails on HEAD; the notes list them.

## Verification
`bash tests/maintenance.test.sh`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one CHANGELOG: line. -->
- .claude/hooks/git-guard.sh: new `as_git(seg, env)` before `git_call`: a command word holding `$` whose default (`${X:-git}`, `${X-git.exe}`, an absolute path) or value set in the command (`G=git; $G`) names git is spelled as that git word, so every git rule applies; runs for the main session too (same rules as a plain git word).
- .claude/hooks/owner-guard.sh: `judge_git` records the alias chain; a verb still an alias after the 8-step walk, or a cycle back to an earlier name (not an alias naming itself, which git runs as the builtin), is refused with ALIAS_CHAIN naming the chain.
- tests/maintenance.test.sh: 6 denied forms (all fail on HEAD: `${X:-git} reset --hard`, `${X:-/usr/bin/git} reset --hard`, `"${GIT:-git}" checkout -- .`, `${X-git.exe} clean -fd`, `${X:-C:/Git/cmd/git.exe} reset --hard`, `G=git; $G reset --hard`) and 5 passing neighbours.
- tests/defects.test.sh: an 11-step chain and a 2-alias cycle to a `git add` of the record are denied naming the chain (both fail on HEAD); a two-step chain stays denied; two short chains ending in status / log pass.
- Surprise: `G=git; $G reset --hard` also passed on HEAD (judge_run resolved it, git_call never saw git); closed by the same rewrite.
- CHANGELOG: git-guard judges a command word whose variable default or value names git as git; owner-guard refuses a subagent's git call through an alias chain it cannot follow to the end.

## Findings
<!-- a repair story arrives with the round's findings here, verbatim - each is a condition to satisfy. -->

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: efb84648e762c183659b259d22cdbbb211116bbeacde3a7a450295a153c7802f (tests/defects.test.sh, tests/maintenance.test.sh)
- impl: d2e7c03fd97af36169f0558ff4673449232ab0e604ce24b33f0d3220a0e3f2ee
- stamped: 2026-11-16T13:27:09Z

```
::error::git-guard: a defaulted variable that names git is judged as git - a subagent's discarding verb is denied: ${X:-git} reset --hard - expected exit 1, got 0: 
::error::git-guard: a defaulted variable that names git is judged as git - a subagent's discarding verb is denied: ${X:-/usr/bin/git} reset --hard - expected exit 1, got 0: 
::error::git-guard: a defaulted variable that names git is judged as git - a subagent's discarding verb is denied: "${GIT:-git}" checkout -- . - expected exit 1, got 0: 
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 1237 checks, 6 failed
```
