# Tails after 0.52.0-dev.1 (plan)

**Tier:** 2 · **Spec slug:** `post-052-tails` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** ADR-033 (local hives are the beta channel), card `public-release-per-change`, `memory/map/README.md` (~80-line slice cap)
**Depends on:** local-beta-rollout, shipped as 0.52.0-dev.1 (4e91beef, local tag), ba53f294 (ADR-033 proposed, map slices)

## Goal
Close the round-2 review minors and the descoped line of local-beta-rollout, and stop held hives from sitting out
whole releases. `/vulyk-ship` says truthfully that its only tag is the local dev build's; the impossible-day test
fails without the real-day rule; `/vulyk-status` names lagging hives in the VULYK source; step 2a re-checks every hold
on every ship. The map gets back the ADR-032 bullet, `scripts.md` is split into slices within the cap, and ADR-033
becomes accepted on the owner's grill answer.

## Assumptions
- The status line runs only where `install.sh` and `VERSION` sit at the root and the registry exists (the same guard
  as ship step 2a); it prints the `hives-behind:` summary line plus every `RED` line.
- Hold re-check (ask 7) is a rule in the prose of step 2a, not new script logic: a held hive whose tree is clean and
  which is on the branch it ships from has its hold removed and is upgraded like the others; any other held hive
  keeps a hold with the reason seen now and a date at most 7 days ahead. A dirty tree is never touched. The first
  pass is this spec's own ship, before 2026-11-19.
- Map files are written by `drone-docs` (the constitution gives `memory/memory.md` and the map to it and the
  librarian); the Queen dispatches it in story 02 and checks the result. `agents-and-commands.md` (134 lines) and
  `cycle.md` (154) stay over the cap: not asked.
- One new check in `tests/maintenance.test.sh` keeps every `memory/map/scripts*.md` slice at <= 80 lines, so the split
  cannot drift back unseen.
- ADR-033's Status line follows ADR-032's form: `accepted (<approval date>, owner: Andrei, ...)`.
- plan.md "Nothing is tagged" (round-2 minor 3) is already fixed in ba53f294: no work.

## Stories

**Wave 1**
- `post-052-tails-01` — ship description, impossible-day test, `/vulyk-status` lagging-hives line, step 2a hold re-check, CHANGELOG

**Wave 2**
- `post-052-tails-02` — map: ADR-032 bullet back, `scripts.md` split into <= 80-line slices + cap check; ADR-033 accepted

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

**Approved:** <owner, date>
