# /vulyk-evolve counts the owner's corrections (plan)

**Tier:** 1 · **Spec slug:** `evolve-corrections-count` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-014 (defect library), ADR-018, ADR-019; litopys ADR-011 (verbatim quotes)
**Depends on:** litopys v0.4.0 (`litopys corrections`), VULYK v0.23.0

## Goal
The weekly evolve run shows how many owner corrections happened and how many reached `docs/defects/`. This is the first
filed-rate number (the board's C3). The lexicon is the defect-intake hook's own, exported, so the two cannot drift.

## Assumptions
- The litopys CLI is found through `command -v litopys`, then the newest cached plugin copy. `${CLAUDE_PLUGIN_ROOT}` exists
  only inside litopys's own components.
- The ERE export uses `(^|[^[:alnum:]_])` / `([^[:alnum:]_]|$)` edges instead of Python's lookbehind, so BSD and GNU grep both
  read it. It needs a UTF-8 locale for Cyrillic `[:alnum:]`, which litopys 0.4.0 already picks.
- The counts are information for step 3. They are never a gate, and they never file anything.

## Stories

**Wave 1**
- `evolve-corrections-count-01` — `defect-intake.sh --lexicon` export + the counter block in `/vulyk-evolve` step 1

## Contracts
- none

## Integration gate
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh` · `git ls-files '*.sh' | xargs -n1 bash -n`

## Descoped

*(empty)*

## Plan deltas

**Approved:**
**Briefed:** via mini-brief, Andrei, 2026-09-29
**Branch:** vulyk/evolve-corrections-count
**Checked:**
**Council:**
**Shipped:**
