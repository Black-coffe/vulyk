# Command reference

All commands are project slash commands in `.claude/commands/` - plain markdown, easy to read and adapt.

## /vulyk-bootstrap `[--quick]`
Interview (3 batches; `--quick` infers from the repo and asks for one confirmation) -> `## Project profile` in CLAUDE.md + the `## Commands` table filled with this project's *quiet* verification commands + path rules -> roster pruning -> initial map via parallel Sonnet scouts -> memory index -> wiki seed -> single init commit. Ends with a usage summary; never starts feature work.

## /vulyk-plan `<goal>`
Tier classification (announced) -> verbatim `brief.md` written through `redact.sh` (Tier 2+) -> briefing questions (facts looked up first; only irreversible/costly/vendor/business-rule questions reach the human, one at a time, each with a recommended default; answers appended verbatim) -> map-first recon, scouts only for gaps -> plan synthesis (inline for Tier 2, `queen-planner` for 3-4, `lead-architect` consult for 4; `templates/plan.md` with `## Contracts` between concurrent stories) -> `docs/specs/<slug>/` plan + stories with verbatim `## Requirements` quotes and `wave:`/`blocked_by:` concurrency lines -> `scripts/wave-check.sh` (deterministic: file collisions within a wave, blocker order, dangling ids) + `scripts/trace-check.sh` (deterministic: backward - every story quote found verbatim in brief.md or plan deltas, catches invented stories; forward - brief lines no story covers, advisory) + `drone-coverage` (sonnet, `maxTurns: 5`, receives brief + plan.md and *not* the stories: the planner cannot audit what the planner did not write) -> stops for human approval with token-posture estimate and all three verdicts. Tier 0 short-circuits to direct execution.

## /vulyk-build `[slug|story]`
Requires an approved plan. Re-runs `wave-check.sh` (now also: declared paths that do not resolve against the tree, stories whose verification cannot fail for their own files), then dispatches wave by wave: every story of a wave launched as parallel worker calls **in a single message** (cap 4), each with exactly story + map slice + relevant rules. Workers return a bounded ≤25-line report (`STATUS`/`FILES`/`TESTS`/`INTERFACES`/`CONCERNS`/`BLOCKERS`) — never diffs or raw logs. Each returning story is closed individually: scope-check (now measuring exactly that story's diff) -> quiet verification -> **one commit per story** -> status update. Repair is capped at two rounds (`NEEDS_CONTEXT` = fix the story; `WALL`/red = one fresh worker with findings as conditions; then `blocked` + re-plan). A repair dispatch obeys the same file-intersection rule as a wave, and no `git checkout`/`restore`/`stash` touches a tree full of uncommitted worker output. Mid-build narrowing goes to `## Descoped` in plan.md — never silent. Full verification at the end runs outside the main context (subagent or `tail -30`).

## /vulyk-review `[scope]`
Assembles diff + stories + wiki/ADR pointers -> `lead-review` gate **and `drone-acceptance` in the same message** (second adversarial reviewer for Tier 4). Acceptance receives brief + repo + run command + the milestone ledger, never plan.md or a story, and returns `ACCEPTED | REJECTED | CANNOT_RUN`; `scripts/acceptance-log.sh` records the verdict beside the story statuses in `memory/stats/acceptance.jsonl` and computes the drift — every story `done` while the blind gate did not accept — stamping the commit and a fingerprint of the pack judged. Cutting a repair story invalidates that verdict: the gate is re-dispatched when the repair round closes, and no merge is proposed until `acceptance-log.sh --check docs/specs/<slug>` reports `CURRENT`. On `BLOCK`, every finding worth acting on — not only criticals — becomes a fix story routed back through `/vulyk-build` (Law 5: no hand-patching); `PASS` triggers the docs-refresh recommendation. Overriding a BLOCK is the human's explicit call.

## /vulyk-map `[path|.]`
Scout batches (delta-verify against existing map files to preserve gotchas), `last-verified` stamps, index update, report of unmapped territory and surprises.

## /vulyk-evolve `[--dry-run]`
The weekly cycle - see [self-evolution.md](self-evolution.md). `--dry-run` stops after diagnosis.

## /vulyk-gc
Librarian pass: consolidate learnings (cap 40), flag stale maps, prune snapshots >14 days, verify pointer index. Main session then offers concrete follow-ups.

## /vulyk-handoff
Two-phase session checkpoint before `/clear` or a restart. Phase 1 (deterministic): `handoff.py dump` writes a mechanical skeleton to `.claude/handoff/` — git state, last TodoWrite, touched files, recent prompts, measured context size. Phase 2 (model): rewrites the skeleton's `## Summary` from what actually happened — goal, current state, next step, decisions *with reasons*, dead ends, needed resources — and flips `enriched: true`. The next session in the project restores the handoff automatically via the SessionStart hook. Unenriched dumps also happen automatically on `/clear`/exit/compaction; see [hooks-reference.md](hooks-reference.md).

## /vulyk-update
Upgrade the installed framework, with the owner holding the decision throughout. Reports the installed version against the newest published tag, runs `scripts/vulyk-update.sh . --check` so the change has a visible shape before anyone approves it, summarises the CHANGELOG between the two versions, and only then asks. On yes it delegates to that release's own `install.sh --upgrade` — so an upgrade can never mean more than the release documented: framework-owned trees (agents, commands, hooks, `_meta` skills, bootstrap, templates, scripts) are replaced where they changed, and `CLAUDE.md`, `memory/`, `docs/specs|adr|wiki` and `.claude/rules` are never touched. Constitution changes therefore remain a manual merge, and the command names them explicitly rather than performing them. Pin a version with `/vulyk-update 0.7.0`. The counterpart hook that notices a release in the first place is `vulyk-update-check.sh`.

## /vulyk-status
Cheap metadata-only dashboard: story table, map freshness vs git churn, learnings buffer depth, skill counters, budget posture. On a fresh session it also nudges the context-hygiene pass — `/context` to see what the session starts with, `/mcp` to drop servers this project never calls. Ends with the single most useful next action.
