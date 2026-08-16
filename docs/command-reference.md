# Command reference

All commands are project slash commands in `.claude/commands/` - plain markdown, easy to read and adapt.

## /vulyk-bootstrap `[--quick]`
Interview (3 batches; `--quick` infers from the repo and asks for one confirmation) -> `## Project profile` in CLAUDE.md + the `## Commands` table filled with this project's *quiet* verification commands + path rules -> roster pruning -> initial map via parallel Haiku scouts -> memory index -> wiki seed -> single init commit. Ends with a usage summary; never starts feature work.

## /vulyk-plan `<goal>`
Tier classification (announced) -> map-first recon, scouts only for gaps -> plan synthesis (inline for Tier 2, `queen-planner` for 3-4, `lead-architect` consult for 4) -> `docs/specs/<slug>/` plan + stories with `wave:`/`blocked_by:` concurrency lines -> `scripts/wave-check.sh` (deterministic: file collisions within a wave, blocker order, dangling ids) -> stops for human approval with token-posture estimate and the wave-check verdict. Tier 0 short-circuits to direct execution.

## /vulyk-build `[slug|story]`
Requires an approved plan. Re-runs `wave-check.sh`, then dispatches wave by wave: every story of a wave launched as parallel worker calls **in a single message** (cap 4), each with exactly story + map slice + relevant rules. Workers return a bounded ≤25-line report (`STATUS`/`FILES`/`TESTS`/`INTERFACES`/`CONCERNS`/`BLOCKERS`) — never diffs or raw logs. Each returning story is closed individually: scope-check (now measuring exactly that story's diff) -> quiet verification -> **one commit per story** -> status update. Repair is capped at two rounds (`NEEDS_CONTEXT` = fix the story; `WALL`/red = one fresh worker with findings as conditions; then `blocked` + re-plan). Mid-build narrowing goes to `## Descoped` in plan.md — never silent. Full verification at the end runs outside the main context (subagent or `tail -30`).

## /vulyk-review `[scope]`
Assembles diff + stories + wiki/ADR pointers -> `lead-review` gate (second adversarial reviewer for Tier 4). On `BLOCK`, every finding worth acting on — not only criticals — becomes a fix story routed back through `/vulyk-build` (Law 5: no hand-patching); `PASS` triggers the docs-refresh recommendation. Overriding a BLOCK is the human's explicit call.

## /vulyk-map `[path|.]`
Scout batches (delta-verify against existing map files to preserve gotchas), `last-verified` stamps, index update, report of unmapped territory and surprises.

## /vulyk-evolve `[--dry-run]`
The weekly cycle - see [self-evolution.md](self-evolution.md). `--dry-run` stops after diagnosis.

## /vulyk-gc
Librarian pass: consolidate learnings (cap 40), flag stale maps, prune snapshots >14 days, verify pointer index. Main session then offers concrete follow-ups.

## /vulyk-handoff
Two-phase session checkpoint before `/clear` or a restart. Phase 1 (deterministic): `handoff.py dump` writes a mechanical skeleton to `.claude/handoff/` — git state, last TodoWrite, touched files, recent prompts, measured context size. Phase 2 (model): rewrites the skeleton's `## Summary` from what actually happened — goal, current state, next step, decisions *with reasons*, dead ends, needed resources — and flips `enriched: true`. The next session in the project restores the handoff automatically via the SessionStart hook. Unenriched dumps also happen automatically on `/clear`/exit/compaction; see [hooks-reference.md](hooks-reference.md).

## /vulyk-status
Cheap metadata-only dashboard: story table, map freshness vs git churn, learnings buffer depth, skill counters, budget posture. On a fresh session it also nudges the context-hygiene pass — `/context` to see what the session starts with, `/mcp` to drop servers this project never calls. Ends with the single most useful next action.
