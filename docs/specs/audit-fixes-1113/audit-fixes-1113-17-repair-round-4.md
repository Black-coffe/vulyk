---
story: audit-fixes-1113-17
status: done
returned: DONE
worker: worker-code
model: opus
wave: 9
blocked_by: []
red: required
red_reason: git-guard: a subagent's git merge --abort is denied
red_verified_at: 2026-11-14T09:34:38Z 9a63ae6aa1f153fb2ffc520e5d1196467eb5ae35bcf2b231ee843ff0df06a5f6
---

# Repair round 4 (narrow)

## Goal
Owner, 2026-11-14: «Узкий ремонт + раунд (Рекомендую)», then «Чинить в этом ремонте (Рекомендую)» for the clerk line
(option labels; the wording is the agent's). Then the owner's own words on full re-runs: «Мы ремонтировали маленький
кусочек и проверяем.» So this repair is narrow: its own files and their own tests, nothing else. No full suite, no
seat round follows it; a review of this diff alone and the owner's acceptance close the spec.

## Requirements
> 5. git-guard covers every git form that discards uncommitted work or commits, including git run through a shell, an alias or a heredoc fed to a shell. Every form it leaves open on purpose is named in its header.
> 3. `/vulyk-ship` pushes a spec branch only to a private origin; with a public origin it asks the owner (landed as Tier 0 in 86e15292); a test pins it.

## Findings
1. ASK 5 (round 4 seat): `.claude/hooks/git-guard.sh` denies `git reset --merge` and `git merge --abort` like the
   other listed verbs (subagent and main session, Python half and bash fallback, both verb lists equal). The other
   forms the seat found are named in the header's "Not covered, on purpose" list; details (moved to a private file before publishing).
2. Review Major carried since round 2: the header of `.claude/hooks/owner-guard.sh` names every shell form its
   plan.md rewrite check leaves open (see `docs/specs/audit-fixes-1113/council/round-2/review.md` Major 1).
3. Seat UNASKED (a): on a stock Git for Windows checkout (`core.autocrlf=true`) `tests/cycle.test.sh --part ship`
   false-fails four pins because the helper that flattens `vulyk-ship.md` keeps carriage returns: strip CR there.
4. Clerk line (owner's choice): two driver launches stopped because `cycle-clerk` echoed `advance`'s ~900-char last
   line with trailing fields dropped. Every line the Workflow driver receives through the clerk (`advance`,
   `status`, `suite`, `claim`, `release`, `close-story`) becomes short and flat: only the fields
   `.claude/workflows/vulyk-cycle.js` reads, story ids instead of file paths, no court path. A test with a long
   spec path and eight wave stories asserts each such line is at most 400 characters and that the driver still
   reads everything it needs. Humans keep the full JSON through `status --json` (or a flag), unchanged.

5. NEEDS_CONTEXT (worker, after the red receipt; implementation green otherwise): two lines of the sealed tests I wrote
   are wrong, and fixing them is a test edit after the implementation, which the protocol leaves to the Queen:
   - tests/defects.test.sh:744 and :747 put `case` inside `$(...)`, so portability-check flags them
     (`case-in-subst`) and `bash tests/maintenance.test.sh` fails 2 checks ("portability-check: the tree exits 0").
     Fix: compute the 0/1 first with `case ... esac` into a variable, outside the substitution, then call `ok`.
   - tests/driver.test.sh, "ask 17 (repeated fragment)": with the short line, the fixture `whole.slice(0, k + 100) +
     whole.slice(k + 30, k + 100) + ...` is still valid JSON (it yields a `["-04opus"]` entry), so the
     `!parses` precondition fails. The driver already treats that line as unreadable (a wave entry must be
     [id, worker(, model)]) and walks re-claim, status, wave, green. Fix: offsets that cut inside a string, e.g.
     `whole.slice(0, k + 100) + whole.slice(k + 33, k + 100) + whole.slice(k + 100)`, or assert only the walk.
   Either fix needs `stamp-red` again (revert impl, re-stamp, re-apply) or a Queen decision on the sealed edit.
   Status otherwise: driver.test.sh 142/143, defects.test.sh all pass, cycle.test.sh --part ship passes,
   maintenance guards part fails only the two portability lines above.

## Files
- .claude/hooks/git-guard.sh
- .claude/hooks/owner-guard.sh
- scripts/cycle.sh
- .claude/workflows/vulyk-cycle.js
- tests/maintenance.test.sh
- tests/defects.test.sh
- tests/cycle.test.sh
- tests/driver.test.sh

## Non-goals
- No other file, no other finding. Run only the rows below while working and once at the end.

## Verification
`bash tests/maintenance.test.sh`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/cycle.test.sh --part ship`
`bash tests/driver.test.sh`

## Implementation notes
- .claude/hooks/git-guard.sh: `merge` in both verb lists; reset --merge and merge --abort deny like reset --hard;
  the header names the forms left open.
- .claude/hooks/owner-guard.sh: header narrows the rewrite rule to a spelled path and lists every open form
  (probed each with --check before naming it).
- scripts/cycle.sh: `--short` on any verb reruns it and prints short_line of its last line (flat keys, ids as `-NN`,
  court as its absolute path per the Queen's ruling, since/steps/rejected left out when empty so the dispatch line
  with a long temp court path stays under 400, errors cut at 160 chars); without the flag every line is unchanged.
- Queen's ruling applied: the two sealed-test fixes of Findings item 5 (defects.test.sh `case` moved out of `$(...)`,
  driver.test.sh fragment offset k + 36, checked unparsable); the driver passes COURT as the absolute path again.
- .claude/workflows/vulyk-cycle.js: asks every verb with `--short`, reads the flat line, names a story by id
  (worker finds the file by frontmatter), passes the line's absolute court as COURT, `stop.file` holds the id;
  a wave entry that is not [id, worker(, model)] makes the line unreadable.
- tests/cycle.test.sh: `flat` strips CR (finding 3); the seal was re-stamped for it (impl reverted, re-stamped, re-applied).

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 9a63ae6aa1f153fb2ffc520e5d1196467eb5ae35bcf2b231ee843ff0df06a5f6 (tests/cycle.test.sh, tests/defects.test.sh, tests/driver.test.sh, tests/maintenance.test.sh)
- impl: ab4bde3f96d3ce38de7df224b36d150844a9f750b0b445a68bc3bd7036c73e3d
- stamped: 2026-11-14T09:34:38Z

```
::error::git-guard: a subagent's git merge --abort is denied - expected 'exit=1' in:
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 997 checks, 11 failed
```
