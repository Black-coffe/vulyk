# Ship safety (plan)

**Tier:** 2 · **Spec slug:** `ship-safety` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-001 (cycle state contract), ADR-004 (driver mutual exclusion), ADR-013 D5 (clean-tree predicate)
**Depends on:** 0.30.0 on main (2e4baa2, evolve 2026-10-19 merged)

## Goal
Make the two git moments of the cycle safe. At ship: `ship-check.sh` proves the spec branch merges into the default branch without conflict (`git merge-tree --write-tree`, git >= 2.38) and that the session stands on the recorded branch; `/vulyk-ship` merges only from a clean default branch, aborts a failed merge, proposes the repair on a conflict, and deletes the spec branch with `git branch -d`. During the build: `cycle.sh` refuses `claim`, `close-story` and `open-round` on any branch other than the plan's `**Branch:**` (exit 2, both branches named), and `branch` refuses to reuse an old spec branch that is already merged.

## Assumptions
- The merge precheck reads exit codes strictly: 0 = clean, 1 = conflict (files listed), anything else (old git, bad ref) = NOT READY "cannot check", never clean.
- The precheck compares the recorded `**Branch:**` with the default branch ship-check already resolves (`ship-check.sh:96-100`); it runs from the spec branch, so it needs no checkout.
- The branch guard applies only when the plan has a `**Branch:**` line; before `cycle.sh branch` runs (a fresh `claim`), there is nothing to compare.
- "Already merged" for `branch` means: the branch exists, its tip is an ancestor of the default branch, and its tip is not the default branch's tip (a branch just cut from the current default is fresh, not stale).
- The conflict repair is a proposal the Queen makes in `/vulyk-ship`; nothing merges the default branch into the spec branch automatically.
- `ship-check.sh` stays exit 0 (it reports; `/vulyk-ship` refuses on NOT READY).

## Stories

**Wave 1**
- `ship-safety-01` — ship-check merge precheck + branch comparison; `/vulyk-ship` step 2 clean-main merge, abort, repair offer, `git branch -d`.

**Wave 2**
- `ship-safety-02` — `cycle.sh` branch guard for claim/close-story/open-round; `branch` refuses a merged spec branch; ADR-001 rows.

## Contracts
- none (Tier 2, built in order by the Queen).

## Integration gate
`bash tests/cycle.test.sh && bash tests/solo.test.sh && bash tests/e2e.test.sh`

## Descoped

*(empty)*

## Plan deltas

**Approved:** Andrei, 2026-10-19
**Branch:** vulyk/ship-safety
