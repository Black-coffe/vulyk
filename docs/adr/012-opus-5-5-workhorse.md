# ADR-012: Opus 5.5 is the workhorse, Fable holds the gate, effort goes back into frontmatter

- Status: accepted (2026-09-22, owner: Andrei). Partially superseded by ADR-013 (2026-09-27): the gate's scope - `lead-review` runs on `opus` at Tier 1-3, and `TOP_MODEL` is passed only to the Tier 4 review (with the second reviewer), `lead-architect`, the Tier 4 `queen-planner` and a missed story's retry; `council-sonnet` leaves the junior rung
- Date: 2026-09-22
- Spec: docs/specs/opus-5-5-ladder (study report + owner approval; the change was made by the
  Queen's session directly, the owner having lifted the 2026-09-14 "framework surgery is
  Fable-only" rule the same day)
- Supersedes: the rungs of ADR-007 (its Haiku rule stands); amends ADR-001's `status --json`
  default `model`

## Context

Opus 5.5 shipped on 2026-09-22. The full evidence and the source table are in
`docs/specs/opus-5-5-ladder/report.md`. What decided the change:

- Artificial Analysis, Intelligence Index v4.3.2 (index / output tokens / $ per task):
  - Opus 5.5 `medium`: 51 / 38M / $1.34.
  - Opus 5.5 `high`: 54 / 53M / $2.00.
  - Fable 5.1 `high`: 51 / 62M / $3.91.
  - Fable 5.1 `max`: 53 / 190M / $7.63.
  - Sonnet 5 `max`, the only level reported: 38 / 370M / about $4.8.
- Anthropic: "start with Claude Opus 5.5 for most workloads", with Fable 5.1 for "demanding
  reasoning and long-horizon agentic work". Opus 5.5 system card §8.12: Opus 5.5 is ahead of Opus 5
  and Fable 5.1 at every agent-team size from 1 to 100. That is a vendor claim, with no
  independent replication yet.
- Price per MTok: Opus 5.5 $4/$20, Fable 5.1 $10/$50, Sonnet 5 $2/$10. Cache read: $0.20, $0.25
  and $0.20. On Max, Fable is capped at half the weekly limit; Opus 5.5 draws from the general
  pool.
- The `opus` alias already resolves to Opus 5.5 in Claude Code 2.1.280, which also made it the
  default model on every paid plan.
- A probe on 2.1.280 on 2026-09-22 found that `effort:` in agent frontmatter now overrides the
  session level. The subagent ran on Opus 5.5: `low` gave 613 / 715 output tokens, `max` gave
  3 136 / 3 296. The July 2026 finding ("silently ignored", 2.1.220) no longer holds.

## Decision

1. **Three rungs.**

   | Rung | Model | Roles |
   |---|---|---|
   | Gate | `TOP_MODEL`: Fable 5.1 where the plan carries it, else Opus 5.5 | `lead-review`, `lead-architect`, the Tier 4 `queen-planner`, a missed story's retry |
   | Workhorse | `opus` → Opus 5.5 | the Queen, `queen-planner` at Tier 1–3, `worker-code`, `worker-test`, `drone-scout`, `drone-docs`, `drone-coverage`, `librarian`, `council-opus`, the Tier 4 second reviewer beside Fable |
   | Junior | `sonnet` | `council-sonnet` (permanently), `council-haiku`, `cycle-clerk`, the learnings distiller |

   `council-haiku`, `cycle-clerk` and the distiller move to Haiku 5.5 when it ships.
2. **`TOP_MODEL` names the gate, not the Queen.** `scripts/top-model.sh` resolves the same alias
   as before; `--apply` and `--check` now pin and compare the Queen's session against `opus`.
3. **The retry climbs to the gate.** `.claude/workflows/vulyk-cycle.js` dispatches a story's
   second attempt with `model: TOP` (was `'opus'`). `cycle.sh status --json` defaults a story's
   `model` to `opus` (was `sonnet`).
4. **Effort per agent.**
   - `low`: `drone-scout`, `drone-docs`, `librarian`, `cycle-clerk`.
   - `medium`: `worker-code`, `worker-test`, `drone-coverage`.
   - `high`: `queen-planner`, `lead-architect`, `lead-review`.
   - Council seats carry no level and inherit the session's.

## Why the gate stays on Fable

The workers now write on Opus 5.5. A gate on Opus 5.5 would review code with the model that wrote
it, which `docs/model-cascade.md` names as an anti-pattern. The gate is also a short call where a
miss costs most, so it never approaches Fable's half-the-limit cap. On Pro and API there is no
Fable. There the gate is Opus 5.5 and the court's model diversity comes from `council-sonnet` (and
the Tier 4 second reviewer on `sonnet`).

## Rejected

- **Everything on Opus 5.5, no Sonnet.** This is the simplest option. It loses the one different
  model in the court, and it makes the clerk pay for thinking that Opus 5.5 cannot switch off. The
  saving from dropping Sonnet's three light roles is marginal.
- **Fable stays the Queen.** It measures the same as Opus 5.5 `medium` at about three times the
  cost, under a cap, and against Anthropic's own default.
- **Wait for Sonnet 5.5 / Haiku 5.5.** They are announced, not shipped. The ladder is written in
  aliases, so revisiting it costs a line.

## Consequences

- On Pro and API the retry runs on the same model as the first attempt. That rung is missing
  there, and the gap is recorded rather than hidden.
- Frontmatter effort outranks the session, so `/effort max` no longer lifts a worker. A story is
  escalated by the retry rule, not by a bigger budget.
- An upgrade re-pins an existing hive's Queen from `fable` to `opus` through the installer's
  `--apply`.
- The `memory/map/` slices that describe the old ladder are stale until `drone-docs` refreshes
  them. That is its job, not the Queen's.

## Revisit when

- Sonnet 5.5 or Haiku 5.5 ships.
- Independent replication of Opus 5.5 orchestration arrives. It is a single vendor source today.
- `memory/stats/council.jsonl` shows lead-review on Fable missing what the seats catch.
- Claude Code changes the frontmatter `effort:` behaviour again. Re-run the probe after upgrades.
