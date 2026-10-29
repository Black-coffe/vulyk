# ADR-027: The red receipt seals tests only, never a product file

- Status: proposed
- Date: 2026-10-29
- Spec: docs/specs/cross-platform (plan delta, story 09)
- Amends: ADR-025 (D2/D3 sealed set)

## Context
ADR-025 seals every path that `## Verification` names under `## Files`. In cross-platform story 09 that set included a
product script, so the fix to it tripped the receipt's own gate:

> 2026-10-29, story 09: close-story refused «test changed after red receipt» - `scripts/defects-check.sh` (named in Files
> and in Verification by the Queen's ruling) was sealed as a test and then fixed. Owner's choice «Снять отметку red с 09
> (Рекомендую)»: the mark is removed, both earlier receipts stay in the story as the record. Next circle: seal tests only.

## Options
none recorded - the delta states the chosen shape only (the one-off remedy, removing the `red` mark from 09, is
recorded but is not an alternative rule).

## Decision
The sealed set of a `red: required` story holds tests only. A product script that the story must change is never
sealed, even when `## Verification` invokes it. Deciding factor, as recorded: sealing a file the story must fix makes
close-story refuse the fix as «test changed after red receipt».

## Consequences
not recorded. (Implementation is "next circle": until then, planners avoid naming a product file in a marked story's
`## Verification` in a way that seals it.)

## Invariants created
- A file the story's implementation changes is never part of its red receipt's sealed-tests hash.

## Revisit when
not recorded.
