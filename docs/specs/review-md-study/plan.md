# Reviewer reads the project's rules (plan)

**Tier:** 1 · **Spec slug:** `review-md-study` · **Brief:** [brief.md](brief.md)
**Governed by:** convergent-judge anchor rule (`[ask N]` / `[regression]`), ADR-014 / ADR-021 (rules tree), Law 2, Law 6
**Depends on:** 0.32.1 on main (f8e4fdc)

## Goal
Teach `lead-review` three things, by text only: read the diff with its paths named so the existing card hook puts the project's rules in front of it, and report a broken Never/How-to line as an `[unanchored]` major naming the card; in round 1 name every place in the diff where a finding's condition fails; anchor a security hole or data-loss path the diff adds to the ask whose code carries it. No script, no new anchor, cycle.sh untouched.

## Assumptions
- One Bash line `git diff <range> -- <every changed path>` wakes the hook for all paths (probed 2026-10-21: three paths, six cards, the overflow folded into a `+N cards` line); folded cards are opened by the reviewer from `docs/defects/<ref>.md`.
- A card finding never blocks: it reaches the owner at `/vulyk-ship` (`vulyk-ship.md:45-46`); a card broken again gets a `check:` under Law 6, the existing road to a block.
- Ask 3 is in only if the owner says so at this stop; without it story 01 drops the security line.
- The change is prose in an agent prompt: no suite can fail on it (wave-check `verify-gap` accepted). The gate is the hook suites the route leans on, the path-token probe, and the one council round.
- Release 0.33.0 and the roll to live hives follow the build (owner rules: a fix must reach live hives; push/tag/upgrade are the Queen's to run).

## Stories

**Wave 1**
- `review-md-study-01` — `lead-review.md`: rules by path (ask 1), the class in round 1 (ask 2), the security anchor (ask 3); CHANGELOG line.

## Contracts
- none (Tier 1, built by the Queen).

## Integration gate
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`

## Descoped

*(empty)*

## Plan deltas

**Approved:** Andrei, 2026-10-21 («Да, все три (Рекомендую)»)
**Branch:** vulyk/review-md-study
**Council:** GREEN round 1, 2026-10-21, at 4963cc4, pack 4352ed0c5f64
