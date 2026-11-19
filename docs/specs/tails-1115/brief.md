# Fix the known code defects and tails (brief) - part 2 of 3 for 0.54.0

**Date:** 2026-11-15 · **Owner:** Andrei · **Tier:** 3 · **Sibling specs:** `guards-1115` (guard hooks), `docs-1115`
(docs only, Tier 2), one minor release 0.54.0 after all three.
**Source:** the owner's request below. The verified inventory is private (`~/.vulyk/audits/known-defects-2026-11-15/`:
`tails.md` items marked OPEN, `security.md` items S15-S18, and `decisions.md` section FINAL), never in the repo.

## Request (verbatim)

> бери все известные косяки и недочеты и устраняй и выкати минорную версию после фикса

## Privacy
Secret-masking and leak-check gaps (S15-S18) are named here only in generic words; workers read the exact shapes from
the private file. Host project names never enter the repo (card `host-internals-in-public-repo`).

## Answers (owner, 2026-11-15, picked options verbatim)
- Shape: «Три спеки, один 0.54.0 (Рекомендую)» - this spec is the code-tails part.
- ADR statuses: «Принять все 15 (Рекомендую)» - done (479ba709); ADR-028 deferred with the parked weekly-budget spec.
- Earlier the same day, on the one finding from a talk review: «В очередь (Рекомендую)» - block checks print the fix.
- 2026-11-16, narrow-repair-1115 escalated (asks 5 and 8 red twice): «Принять, доделать в tails (Рекомендую)» - its two
  remaining gaps and the owner's 2026-11-15 «тесты exact» (pick tests by direct calls only, not by any mention) come
  here as asks 11 and 12.
- 2026-11-16, the reopen rule: «Узко, полный по вашему слову (Рекомендую)» - ask 13.
- 2026-11-16, `--fill-tests` over the stories approved before it: «Не применять, только отчёт (Рекомендую)» -
  not applied to this spec's stories; it runs once after story 12 as a report only.
- 2026-11-17, story 12's acceptance (asked mid-build): «Сузить до трёх (Рекомендую)» - ask 11's quoted-substitution
  rule is checked on the three scripts it really covers; three scripts that miss for other causes go to the next circle.

## Scope rule
Every `tails.md` item marked OPEN that touches code, a test, the installer, CI, the driver, a hook, an agent prompt, a
command or a skill belongs here, with the doc lines that describe that same change. Items that touch only docs or map
slices go to `docs-1115`. Items guarded by `guards-1115` (git-guard, owner-guard, court-guard, run-state) stay there.
FEATURE items and the narrow-repair policy are out, except asks 11-13 (the owner's 2026-11-16 choices above).

## Asks
1. The six canary-found defects are fixed: wave-check on test paths that do not exist yet; scope-check and close-story
   with an absolute story path; the commit subject taken from story frontmatter; the busy check reading a neighbour
   hive's driver journal; a block check that prints only the hit now prints the fix; the routing docs/code mismatch on
   the black-box seat follows the owner's 2026-11-13 choice ("instead of") (T1-T6).
2. The installer defects are fixed: release copies not counted as hive edits, untracked source files not copied,
   area-only cards named on upgrade, glob loops safe, side effects (user-scope mod, model pin) offered or flagged,
   never done silently (T7, T15, T22, T51-T55 and the rest of tails.md that touch install.sh).
3. The cycle, driver and clerk tails are fixed (cycle.sh, vulyk-cycle.js, lib.sh items in tails.md, including the
   long clerk line, the executable bit lost on close-story, the commit subject, the red-receipt staleness).
4. Secret masking and leak checking cover the shapes listed privately, and a masking failure stops the write instead
   of passing it through (S15-S17); CI actions are pinned to immutable versions (S18).
5. The hook, telemetry, token-report, prompt-check and model-floor tails in tails.md are fixed; a fallback never runs
   a model below the floor (pause instead).
6. Dead mechanisms are retired: the unwritten learnings chain and the never-read pre-compact snapshots, without
   deleting any data already in a hive.
7. Side-effect commands: `/vulyk-update` is not invoked by the model on its own; the others stay as they are.
8. A timing test that depends on host load is replaced by a bound that uses no clock; known flaky tests are fixed.
9. A claim about Claude Code behaviour that a fix rests on is checked against the official docs first; an item whose
   premise does not hold is closed as not-a-defect with the source named.
10. Every fix that code can check gets a failing test with the original case and a neighbour form; all suites green.
11. Test pick-up stays exact (direct calls only, owner 2026-11-15 «тесты exact»), and a direct call written inside a quoted command substitution (`"$(bash scripts/x.sh ...)"`) counts as one; a test that only sources `scripts/lib.sh` is not an exact test of every script `lib.sh` runs. The substitution rule is checked on the three scripts a test runs that way (trace-check.sh, defects-check.sh, suite-parts-check.sh); three scripts that miss an exact test for other causes are out of this spec (owner, 2026-11-17).
12. The defect-card hook reads a story's `## Files` outside fenced code blocks only, with the same fence rule as the other story-section readers.
13. A reopened `no-progress` escalation gets a narrow round (the reviewer on the repair's diff, the blind seat over every red ask and every touched one); a full round follows only when the owner says at reopen that it is a design fault (`cycle.sh reopen ... --full`); a reopened `half` stays a full round.
