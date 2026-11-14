---
story: audit-fixes-1113-17
status: todo
returned:
worker: worker-code
model: opus
wave: 9
blocked_by: []
red: required
red_reason:
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
