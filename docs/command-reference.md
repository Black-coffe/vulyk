# Command reference

All commands are project slash commands in `.claude/commands/` - plain markdown, easy to read and adapt.

## /vulyk-bootstrap `[--quick]`
Interview (3 batches; `--quick` infers from the repo and asks for one confirmation) -> `## Project profile` in CLAUDE.md + path rules -> roster pruning -> initial map via parallel Haiku scouts -> memory index -> wiki seed -> single init commit. Ends with a usage summary; never starts feature work.

## /vulyk-plan `<goal>`
Tier classification (announced) -> map-first recon, scouts only for gaps -> plan synthesis (inline for Tier 2, `queen-planner` for 3-4, `lead-architect` consult for 4) -> `docs/specs/<slug>/` plan + stories -> stops for human approval with token-posture estimate. Tier 0 short-circuits to direct execution.

## /vulyk-build `[slug|story]`
Requires an approved plan. Builds the story DAG, dispatches up to 4 parallel workers (posture-capped) with exactly story + map slice + relevant rules. Routes walls (re-scope / fresh worker with findings / architect escalation), tracks statuses, runs full verification once at the end, recommends the gate.

## /vulyk-review `[scope]`
Assembles diff + stories + wiki/ADR pointers -> `lead-review` gate (second adversarial reviewer for Tier 4). `BLOCK` findings become fix stories routed back through `/vulyk-build`; `PASS` triggers the docs-refresh recommendation. Overriding a BLOCK is the human's explicit call.

## /vulyk-map `[path|.]`
Scout batches (delta-verify against existing map files to preserve gotchas), `last-verified` stamps, index update, report of unmapped territory and surprises.

## /vulyk-evolve `[--dry-run]`
The weekly cycle - see [self-evolution.md](self-evolution.md). `--dry-run` stops after diagnosis.

## /vulyk-gc
Librarian pass: consolidate learnings (cap 40), flag stale maps, prune snapshots >14 days, verify pointer index. Main session then offers concrete follow-ups.

## /vulyk-status
Cheap metadata-only dashboard: story table, map freshness vs git churn, learnings buffer depth, skill counters, budget posture. Ends with the single most useful next action.
