# solo-gate-1118 - Tier 1-2 round gate runs no full suite (plan)

**Tier:** 2 · **Spec slug:** `solo-gate-1118` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** the owner's 2026-11-17 rule for this repo (two rounds at most, checks sized to the change, Fable
and Opus only).
**Depends on:** `main` at 0.54.0-dev.6 (docs-1115 merged).

## Goal
At Tier 1-2 the round's gate stops running the full suite; the merge run stays the one full run. The Queen builds
it (Tier 2, one story); one Fable reviewer judges it; the full suite once before merge.

## Assumptions
- Owner 2026-11-18 «Только там, где включено (Рекомендую)»: opt-in by `.vulyk-solo-gate` = `merge-only` on the default
  branch; Fable: fail closed on any other content, not flippable from the spec branch.
- Owner 2026-11-18 «Одобряю, собирай здесь (Рекомендую)»: built in the same session, a named deviation from the
  Tier 2 fresh-session rule.
- `ship-check.sh` needs no change: it counts a round log only when it ends `SUITE: ok <N>s`, so a Tier 1-2 spec
  always gets its merge run (`cycle.sh suite --merge`).
- The no-step log uses the existing `SUITE: none` shape (the narrow-round and no-row paths), which record-seat and
  judge already take.
- Fable (design check, 2026-11-18): agrees; traps folded in: round_rerun, frozen tier, --full, reviewer line.
- A broken test now shows at the merge run, after the review, not before it: fix, then the whole suite once more.

## Stories
**Wave 1**
- `solo-gate-1118-01-solo-round-gate` - cmd_suite and round_rerun at Tier 1-2 (frozen ROUND tier, `--full` exempt); council.test.sh suite fixtures get an explicit tier; new cases: Tier 1 none, Tier 2 none, Tier 3 runs, `--full` at Tier 1 runs, Tier 1 repair round 2 runs no step; lead-review.md and doc lines.

## Contracts
none

## Integration gate
`bash tests/full-suite.sh` (the merge run)

## Descoped

## Plan deltas
- 2026-11-18, from a side-agent note the owner forwarded (Queen's wording): split every gate part that ran over 185 s in the docs-1115 green merge run (council `roster` 207 s, `round-scope2` 191 s; telemetry `upgrade` 189 s, `wiring` and `wiring2` 186 s), so this spec's own merge run does not go red by growth; `tests/telemetry.test.sh` joins the story's Files.

**Approved:** Andrei, 2026-11-18 «Одобряю (Рекомендую)»
**Briefed:** <written by cycle.sh briefed>
**Branch:** vulyk/solo-gate-1118
**Council:** GREEN round 1, 2026-11-18, at dd3a032a, pack 1e79cc18c716
**Council:** GREEN round 2, 2026-11-18, at 05657653, pack 1e79cc18c716
**Checked:** <written by human-check>
**Shipped:** 0.54.0-dev.7, 2026-11-18, at bb584d47 - merged to main (local) after GREEN round 2 and the owner's «Выпускаем локально, на гит не заливаем» (branch CI skipped, origin public); 6 hives on dev.7 (no switch file reaches a hive), 9 held; descoped: telemetry wiring2 split (its time is the shared fixture); next circle: a --full round's red step is not re-run after its repair, a slash in the default branch name reads the switch as off under Git Bash
