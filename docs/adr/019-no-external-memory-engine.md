# ADR-019: No external memory engine; owner lessons stay checks

- Status: accepted (owner, 2026-09-30)
- Date: 2026-09-29
- Spec: docs/specs/hindsight-memory (study), docs/specs/hindsight-harvest (v0.23.0)

## Context
A three-member editorial board studied vectorize-io/hindsight. `docs/specs/hindsight-memory/report.md`:

> The headline claim, "the agent changes behaviour after your corrections", has **no mechanism and no measurement**. The lesson carrier is prose injected into the prompt (≤1024 tokens per prompt). The benchmarks (LongMemEval, LoCoMo) test recall of a conversation, not whether a mistake repeats.

> Unanimous: **do not install Hindsight**. The board also unanimously rejected:
> - a daemon with Postgres/pgvector;
> - per-prompt recall;
> - a CLAUDE.md that rewrites itself;
> - vectors or graph retrieval;
> - an LLM correction classifier;
> - counters used as an escalation ladder;
> - one shared bank across projects.

Also recorded in the report: the recommended plugin `hindsight-memory` "is **deprecated by its own authors**".

`docs/specs/hindsight-harvest/plan.md`, `## Goal`: "Take what the editorial board accepted from Hindsight into VULYK as checks, not as prose."

ADR-014 already covers the underlying rule ("VULYK learns by adding checks to the host, not by growing
prompts"). It also already rejects an LLM classifier and counters as an escalation ladder. This ADR adds the
other shapes the board rejected, so that the next memory product that comes along does not reopen them.

## Options
1. Install Hindsight (plugin + daemon). Rejected: the plugin is deprecated, and nothing shows that it stops
   mistakes from repeating.
2. Harvest individual ideas as checks (C4, C5, C6, C9, C11). Chosen.

## Decision
VULYK does not install Hindsight or any equivalent memory engine. The board rejected it unanimously
because the claimed behaviour change has no mechanism and no measurement, and the lesson carrier is prose
in the prompt. The ideas worth keeping enter VULYK as failing checks.

## Consequences
not recorded

## Invariants created
- No daemon or database (Postgres/pgvector), vector or graph retrieval, or per-prompt recall in VULYK.
- No CLAUDE.md that rewrites itself.
- No memory bank shared across projects.
- A new lesson source is adopted as a check, not as injected prose (ADR-014).

## Revisit when
not recorded. The report does name the missing metric ("does a filed correction stop repeating"; C11 + C3
give the first number), but it does not make that metric a trigger.
