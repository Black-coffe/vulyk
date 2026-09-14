# ADR-007: The model ladder - four rungs, no Haiku until Haiku 5

- Status: accepted (2026-09-14, owner: Andrei)
- Date: 2026-09-14
- Spec: docs/specs/lean-cascade (v0.13.0)
- Amends: ADR-002 (Tier 2 court)

## Context

The owner, 2026-09-14, after running v0.12.0 on two other hives (quoted from
`docs/specs/lean-cascade/brief.md`):

> Тимлид — это Fable последней версии. Сеньоры — это «Опус» последней версии. Мидлы — это
> «Сонет» последней версии. И джуны … — это «Хайку». И только в том случае, если там есть 5 и
> выше модель «Хайку». Если пятёрки нету, а 4.5 последняя модель «Хайку», то тогда джунами
> остаются «Сонеты».

This is the owner's rule and the decision rests on it. What the record adds, honestly stated:

- `memory/stats/council.jsonl` holds three rounds for `autonomous-cycle`; the `haiku` seat
  (Haiku 4.5) returned `N/A` in all three - because the Profile's *Client path* row was
  unfilled and the seat had nothing to walk (`council/round-{1,2,3}/haiku.md`: `PATH: none
  named`). That says nothing about the model and is not evidence for this ADR.
- The `v0-12-0-remainders` journal records eight or nine dead worker returns on Sonnet: stories
  01 and 05 twice each (dead subagent, mid-edit), story 15 four times (turn cap, twice before
  and twice after the cap was raised in a session that had not reloaded it) plus once to a lost
  login, and story 08 twice on a wave-order plan defect an Opus retry would have failed on
  identically. None is attributed to the model. What the record does show is that every retry
  went to the same model that had just missed, and the second miss always cost a block, a
  `lead-architect` consult and a relaunch.

## Decision

Four rungs. Frontmatter carries the rung, the dispatch parameter carries the plan-aware
upgrade (unchanged from ADR-001 / v0.10):

| Rung | Alias | Agents | Work |
|---|---|---|---|
| Lead | `TOP_MODEL` (`fable` where the plan carries it, `opus` elsewhere) | Queen, `queen-planner`, `lead-architect`, `lead-review` | planning, design, the gate |
| Senior | `opus` | `council-opus`; the second attempt of any story a mid missed; stories the planner marks `model: opus`; the Tier 4 second reviewer beside a Fable gate | judgment, hard stories, retries |
| Mid | `sonnet` | `worker-code`, `worker-test`, `council-sonnet`, `drone-scout`, `drone-docs`, `drone-coverage`, `librarian` | implementation, recon, memory |
| Junior | `haiku` only once a fifth-generation Haiku exists; `sonnet` until then | `council-haiku`, `cycle-clerk`, the `VULYK_AUTOLEARN` distiller | mechanical, one-verb, no judgment |

Three mechanisms, all in files:

1. **Frontmatter.** `council-haiku.md` and `cycle-clerk.md` say `model: sonnet` (a bare
   alias - the rationale sits in the body, never as an inline comment on the line a parser
   reads); `session-end-learnings.sh` calls `claude -p --model sonnet`. The seat keeps its
   name `haiku` - it is an angle (the black box) and a key in `council.jsonl`, `record-seat`
   and 2 400 lines of contract tests; renaming it buys nothing the rule needs. When a Haiku 5
   ships, the junior rung flips back with three one-word edits and a CHANGELOG line - and
   only then. Frontmatter cannot be conditional, and a resolver that guesses the Haiku
   generation from a local file would be inventing a fact.
2. **Per-story model.** `status --json`'s `wave_stories` objects carry `"model"`, read from
   the story's `model:` frontmatter line (`sonnet` when absent). The planner writes `opus` on
   a story that is cross-cutting, touches a `## Contracts` entry, or is the tracer. The driver
   passes it as the dispatch parameter and never opens the story file.
3. **The retry climbs one rung.** A story's second dispatch - after a red `close-story`, an
   empty report, or a `WALL`/`NEEDS_CONTEXT` return - goes to `opus` regardless of the
   story's own `model`. This is a judgment, not a measured fix: the record shows no
   model-caused miss, only that the same model always got the retry. The rung costs one Opus
   worker per missed story and is bounded by the same two-attempt rule; it buys a second
   attempt that is never the same model reading the same wall.

And one seat change that follows from the rungs: **Tier 2 requires `sonnet` + `review`**, no
longer `opus` too (C15 amended; ADR-002's "never to zero" holds; Tier 1 and Tier 3-4 unchanged -
the full court, black-box seat included, from Tier 3). A Tier 2 spec is a feature inside one
module; the line-by-line seat plus the lead's review is the gate, and the intent seat - a
senior - joins at Tier 3 where more than one module is in play. This quotes no ask of its own;
it is recorded as a plan delta under the owner's ask 2 (token economy) and reverts with one line
in `required_seats_for_tier`.

## Rejected

- **Haiku 4.5 as the junior.** The owner's rule. The framework adds no evidence of its own
  for or against; it removes the model from the roster and records how to put it back.
- **Opus for every Tier 3-4 story.** Every story in a Tier 4 spec inherits `tier: 4`, so this
  would have put all seventeen `v0-12-0-remainders` stories on Opus. The per-story `model:`
  and the retry rung reach the stories that need it at a fraction of the cost.
- **A resolver that detects the current Haiku generation.** No local file records it; the
  resolver would be a guess wearing a script.

## Consequences

- A hive pays Sonnet where it paid Haiku for the clerk and the black-box seat - a few short
  calls per round. The retry rung costs one Opus worker per missed story.
- `wave_stories` gains a key; every consumer that asserts its exact shape (the council suite
  fixtures, the driver test) was updated in the same spec.
- A blank *Client path* row still buys a black-box seat that can only answer `N/A` at Tier
  3-4 - the Profile's defect, not the seat's; `/vulyk-bootstrap` step 3 already says so.

## Revisit when

A Haiku 5 ships (flip the junior rung); or `council.jsonl` and the journals show the Opus retry
missing as often as the Sonnet first attempt (then the story shape, not the model, is the
defect - ADR-006).
