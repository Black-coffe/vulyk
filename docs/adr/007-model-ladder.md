# ADR-007: The model ladder - four rungs, no Haiku until Haiku 5

- Status: accepted (2026-09-14, owner: Andrei)
- Date: 2026-09-14
- Spec: docs/specs/lean-cascade (v0.13.0)

## Context

The owner, 2026-09-14, after running v0.12.0 on two other hives (quoted from
`docs/specs/lean-cascade/brief.md`):

> Тимлид — это Fable последней версии. Сеньоры — это «Опус» последней версии. Мидлы — это
> «Сонет» последней версии. И джуны … — это «Хайку». И только в том случае, если там есть 5 и
> выше модель «Хайку». Если пятёрки нету, а 4.5 последняя модель «Хайку», то тогда джунами
> остаются «Сонеты».

Two facts from the record support the rule. `memory/stats/council.jsonl` holds three rounds
for `autonomous-cycle`; the `haiku` seat (Haiku 4.5) returned `N/A` in all three - it produced
no evidence any round. `memory/learnings` and the `v0-12-0-remainders` journal record seven
worker dispatches that died at their turn cap on Sonnet, each retried on the same model with
the same result until the cap was raised; the second miss on story 08 was the same model
reading the same wall twice. The v0.12 cascade had no rung between "Sonnet again" and
"block the story".

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

1. **Frontmatter.** `council-haiku.md` and `cycle-clerk.md` say `model: sonnet`;
   `session-end-learnings.sh` calls `claude -p --model sonnet`. The seat keeps its name
   `haiku` - it is an angle (the black box) and a key in `council.jsonl`, `record-seat` and
   2 400 lines of contract tests; renaming it buys nothing the rule needs. When a Haiku 5
   ships, the junior rung flips back with three one-word edits and a CHANGELOG line - and
   only then. Frontmatter cannot be conditional, and a resolver that guesses the Haiku
   generation from a local file would be inventing a fact.
2. **Per-story model.** `status --json`'s `wave_stories` objects carry `"model"`, read from
   the story's `model:` frontmatter line (`sonnet` when absent). The planner writes `opus` on
   a story that is cross-cutting, touches a `## Contracts` entry, or is the tracer. The driver
   passes it as the dispatch parameter and never opens the story file.
3. **The retry climbs one rung.** A story's second dispatch - after a red `close-story`, an
   empty report, or a `WALL`/`NEEDS_CONTEXT` return - goes to `opus` regardless of the
   story's own `model`. A miss is information; the same model rereading the same wall is the
   cheapest way to buy a second miss, and the second miss blocks the story and wakes the
   Queen, which is the expensive outcome the retry exists to avoid.

And one seat change that follows from the rungs: **Tier 2 requires `sonnet` + `review`**, no
longer `opus` too (C15 amended; ADR-002's "never to zero" holds). A Tier 2 spec is a feature
inside one module; the line-by-line seat plus the lead's review is the gate, and the intent
seat joins at Tier 3 where more than one module is in play.

## Rejected

- **Haiku 4.5 as the junior.** The seat that ran on it produced nothing in three rounds, and
  a clerk that returns a mangled line ends a whole driver run. The saving per call is real
  and small; the cost of one bad call is a run.
- **Opus for every Tier 3-4 story.** Every story in a Tier 4 spec inherits `tier: 4`, so this
  would have put all seventeen `v0-12-0-remainders` stories on Opus for a defect that only
  two of them hit. The per-story `model:` and the retry rung reach the same stories at a
  fraction of the cost.
- **A resolver that detects the current Haiku generation.** No local file records it; the
  resolver would be a guess wearing a script.

## Consequences

- A hive on Pro pays Sonnet where it paid Haiku for the clerk and the black-box seat -
  a few short calls per round. The retry rung costs one Opus worker per missed story and
  saves the block + `lead-architect` + relaunch that a second Sonnet miss cost every time
  it happened in September 2026.
- `wave_stories` gains a key; every consumer that asserts its exact shape (the council suite
  fixtures) was updated in the same spec.

## Revisit when

A Haiku 5 ships (flip the junior rung); or `council.jsonl` shows the retry rung missing as
often as the mid did (then the story shape, not the model, is the defect - see ADR-006).
