# ADR-041: Guard hooks close named form classes and name every open class in their header

- Status: proposed
- Date: 2026-11-17
- Spec: docs/specs/guards-1115

## Context
The guard hooks (git-guard, owner-guard, court-guard) judge shell text. Asks that read "by any tool", "by any verb"
or "cannot be left" could not be met; after council round 1 ESCALATE the owner narrowed them to named classes.
From plan.md `## Descoped`:

> Ask 1 (2026-11-16): "by any tool" narrowed to the named form classes (...); every other form is named open in the
> header. Why: the hooks judge shell text, so a neighbour spelling always exists and "any tool" cannot be met. Owner,
> 2026-11-16, after round 1 ESCALATE: «Ремонт классами + сузить вопросы (Рекомендую)».

Asks 3, 4 and 5 were narrowed the same day for the same reason under the same owner line. Contract O2 in plan.md:

> Each hook header ends with one block listing every form the hook leaves open, in general words; a form closed in
> this spec is not on it. Cards `work-discarded-by-git-verb` and `owner-words-by-builder` carry the same list in
> `## Check`.

## Options
none recorded in `## Descoped` - it states the chosen shape only. (plan.md `## Contracts` "Rejected alternative"
records the rejected options for the run-state protection: records as git refs, and a signature over the records.)

## Decision
A guard requirement is stated and tested as a set of named form classes, not as "any form". Every form a hook leaves
open is named by class, in general words, in one block at the end of that hook's header, mirrored in the matching
cards' `## Check`. Exact forms live only in the private inventory; a form enters the repo only as a test input for a
gap the story closes. Deciding factor: a guard that reads shell text always has a neighbour spelling.

## Consequences
- Each repair of the hand-written shell parsers opened new neighbour spellings (rounds 4-6). After round 6 the owner
  chose «Откат к версиям без регрессий (Рекомендую)» (2026-11-17): each hook went back to its newest version that lets
  through no form the last release refused, so a release is never weaker than the one before; the ordinary calls those
  versions still refuse are named in the header as known over-denies.
- Recorded follow-up: a guard design not built on shell text is planned for 0.55.0, per `## Descoped`.

## Invariants created
- No ask, story or doc claims a text-judging guard stops a form "by any tool/verb/spelling".
- Each guard hook header ends with an open-forms block; a form closed is removed from it in the same change.
- The open-forms block and the card `## Check` lists agree.
- No concrete bypass spelling appears in repo text except as a test input for a closed gap.

## Revisit when
not recorded. (The 0.55.0 guard design not built on shell text is the evident trigger.)
