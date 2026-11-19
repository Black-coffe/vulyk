# ADR-037: A `.scrub-revs` commit keeps an owner quote's date only for a masked-only change

- Status: accepted (2026-11-15, owner: Andrei, «Принять все 15 (Рекомендую)»)
- Date: 2026-11-14
- Spec: docs/specs/audit-fixes-1113 (asks 14, story 06 and story 12)

## Context
Plan deltas:

> 2026-11-14, story 06 NEEDS_CONTEXT: story 04's path scrub rewrote an owner-quote line of a block card, so
> `defects-check.sh` (git-blame dating) saw a new quote and reported an ESCAPE. Root fix in story 06: blame with
> `--ignore-revs-file docs/defects/.scrub-revs`, listing scrub-only commits; `scripts/defects-check.sh`,
> `docs/defects/.scrub-revs` and `tests/defects.test.sh` join story 06 (none is named in wave 2; story 09 edits
> `defects-check.sh` later, in wave 3).

> 2026-11-14, side-agent note the owner forwarded: `.scrub-revs` is a plain list any agent can extend. New story 12
> (wave 4, beside 11, disjoint files): a listed commit keeps a quote's older date only for a masked-only change.

## Options
none recorded - the delta states the chosen shape only

## Decision
`defects-check.sh` dates owner quotes with git blame past the commits listed in `docs/defects/.scrub-revs`, and
a listed commit is honoured only where its change to the line did nothing but replace a span with a placeholder.
Any other change in a listed commit dates the quote at that commit, as if the commit were not listed.

## Consequences
Not recorded.

## Invariants created
- Being listed in `.scrub-revs` is not enough to keep a quote's older date; the gate checks the change itself.
- A scrub that must keep quote dates changes owner-quote lines only by masking spans with placeholders.

## Revisit when
Not recorded.
