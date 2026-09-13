---
story: autonomous-cycle-12
spec: autonomous-cycle
status: done
tier: 4
worker: worker-code
tracer: false
wave: 4
blocked_by: [autonomous-cycle-08, autonomous-cycle-09, autonomous-cycle-10]
---

# Guides: `architecture.md`, `command-reference.md`, `getting-started.md`, `model-cascade.md`, `token-economy.md`, `README.md`

## Goal
Every guide that walks a reader through the cycle walks the v0.12.0 cycle: the grill as the one stop, the driver loop, the council and its court, the ceiling, pause/resume, local merge with publish printed; the caste table lists the three seats and the clerk; the token-economy page carries the honest cost of a round and of the fallback path.

## Requirements
> Совет остаётся, переформулирован + все технические фиксы. Совет = усиленная слепая приёмка (3 места, 3 угла) вместо одного drone-acceptance; человеческий гейт убран как не ловивший ничего.

> Workflow-скрипт + fallback в сессию. /vulyk-plan: Fable грилит, планирует, пишет стори — и запускает один Workflow: волны воркеров → story-close (скрипт) → lead-review ∥ совет → фикс-стори → повтор, потолок 3. Королева просыпается дважды: итоговый отчёт (мерж) или эскалация. Где Workflow недоступен — сегодняшняя петля в сессии, но через те же скрипты.

> Мерж сам, публикация — нет.

> оркестратором у волыка, королем, королевой всегда должен быть фейбл последней модели. И он должен делать минимум.

## Files
- docs/architecture.md
- docs/command-reference.md
- docs/getting-started.md
- docs/model-cascade.md
- docs/token-economy.md
- README.md

## Non-goals
- Do not edit `CLAUDE.md`, `docs/cycle.md`, `docs/pipeline.md` or `bootstrap/interview.md` (story 11) or `CHANGELOG.md`/`README.md` roadmap version lines that story 13 owns (the `## [0.12.0]` roadmap entry is story 13's; you update the prose that describes v0.11.0 behaviour as current).
- Do not invent measured numbers: the cost line is the ADR's estimate ("roughly 2-3x the gate cost at <= 2 rounds", "fallback is the most expensive path") stated as an estimate with its date; the grill's targets (median 1 stop, >= 80 % green in <= 2 rounds, <= 10 % escalations) are targets, labelled so.
- Do not document the personal `grill` skill as a dependency; `templates/grill.md` is the protocol.
- Do not turn `docs/model-cascade.md` into a council design doc: update the per-caste table rows and the "dispatched together" sentence, nothing more.

## Map slice
`docs/specs/autonomous-cycle/plan.md` `## Goal`, `## Contracts` C10-C12, `## Tradeoffs` · `docs/adr/001-cycle-state-contract.md` Consequences (the token-cost paragraph is the source for `token-economy.md`), D2 (the two drivers, for `architecture.md`) · `docs/specs/autonomous-cycle/recon/scout-docs.md` §Answer 1 (`architecture.md:17,40-47,52`; `command-reference.md:15`; `getting-started.md:49`; `README.md:151,164,269`), §Answer 2 (`command-reference.md:9,17-18`; `architecture.md:34,48-51`), §Answer 3 (`architecture.md:6-8,13,23-55`; `token-economy.md:51-70`; `command-reference.md:11-15`), §Answer 7 (`model-cascade.md:97-106`) · the final command files from stories 08-10 (read them; describe what they do, not what this story file says).

## Acceptance criteria
- [ ] `docs/architecture.md`: caste table has `council-haiku`/`council-sonnet`/`council-opus` (Haiku/Sonnet/Opus aliases), `cycle-clerk` (Haiku), no `drone-acceptance`; the data-flow section shows grill -> `Briefed` -> driver (Workflow or session) -> waves -> `open-round` -> `lead-review` ∥ seats in the court -> `judge` -> repair/green -> `/vulyk-ship` local merge; one paragraph on the two drivers sharing `cycle.sh status --json`; the "owner looks (stage 05)" lines are gone; the librarian ADR-harvest sentence still points at stage 06.
- [ ] `docs/command-reference.md`: `/vulyk-plan`, `/vulyk-build`, `/vulyk-review`, `/vulyk-ship`, `/vulyk-status` paragraphs match the command files; new `/vulyk-pause`, `/vulyk-resume` paragraphs; no "stops for human approval", no check card, no "human presses" beyond the publish line.
- [ ] `docs/getting-started.md` working-loop block: grill questions -> the terminal shows journal lines -> wake on green or escalation -> `/vulyk-ship` prints the publish command; one sentence each on `/vulyk-pause` and the two-stop opt-out.
- [ ] `docs/model-cascade.md:97-106` table: `drone-acceptance` row replaced by the three seats and the clerk with their models; the "dispatched together" sentence names `lead-review` ∥ seats per round.
- [ ] `docs/token-economy.md`: a dated "Cost of the council" paragraph: per round 3 cold-cache seats (one Opus-class) + `lead-review` at the top model + ~5 Haiku clerk calls; on RED one planner dispatch at the top model plus workers; roughly 2-3x the v0.11 gate cost at <= 2 rounds; the fallback driver additionally carries ~120 lines of reports per round through the pinned top-model session - the most expensive path, which `/vulyk-status` reports.
- [ ] `README.md`: the build-discipline bullet at `:151` says the cycle closes with a council and one human stop at the start; the `/vulyk-ship` row at `:164` says merge local, publish printed; the command table lists `/vulyk-pause` and `/vulyk-resume`; the v0.11.0 roadmap entry at `:269` is left as history (story 13 adds v0.12.0).

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `docs/architecture.md`: full rewrite of the caste table (council-haiku/sonnet/opus + cycle-clerk replace drone-acceptance) and the data-flow block (grill -> Briefed -> driver -> waves -> open-round -> lead-review ∥ seats in the court -> judge -> repair/green -> local merge); added a "Two drivers, one state" paragraph on the shared `cycle.sh status --json` contract. Wrote with the Write tool, LF only (verified 0 CRLF bytes).
- `docs/command-reference.md`: rewrote `/vulyk-plan`, `/vulyk-build`, `/vulyk-review`, `/vulyk-ship`, `/vulyk-status` paragraphs from the actual `.claude/commands/*.md` files (not from the plan/ADR text) and added `/vulyk-pause`/`/vulyk-resume`; dropped every "stops for human approval" / check-card / stage-05 phrase.
- `docs/getting-started.md`: working-loop block now reads grill questions -> journal lines on the terminal -> wake on green/escalation -> `/vulyk-ship` prints the publish command; added one sentence each on `/vulyk-pause` and the two-stop opt-out.
- `docs/model-cascade.md:97-106`: split the old `drone-coverage, drone-acceptance` row into `drone-coverage` plus three council-seat rows and `cycle-clerk`, each with its real model; added the "dispatched together" sentence naming `lead-review` ∥ the three seats per round.
- `docs/token-economy.md`: added a dated "Cost of the council (v0.12.0)" section citing ADR-001 (2026-09-12) as an estimate, not a measured number - per-round seat/clerk/planner cost, the "~2-3x the v0.11 gate cost at <=2 rounds" line, and the fallback driver's ~120-lines-per-round cost that `/vulyk-status` reports. Caught and fixed my own relative-link bug (`../adr/...` -> `adr/...`) before finishing.
- `README.md`: build-discipline bullet (now the one at the same position, since earlier edits shifted line numbers) says the cycle closes with a council and one human stop at the grill; caste table swaps `drone-acceptance` for the three council seats + `cycle-clerk`; command-table rows for `/vulyk-plan`, `/vulyk-review`, `/vulyk-ship` rewritten and `/vulyk-pause`/`/vulyk-resume` added; the v0.11.0 roadmap entry left untouched (story 13 owns v0.12.0's entry). Also reframed the "What is measured" section's `acceptance-log.sh` paragraph as the explicit pre-council fallback for specs recorded before v0.12.0, without touching its historical numbers - judged necessary for internal consistency (Files list names the whole file; leaving a caste table and a command row naming a deleted agent would fail the story's own `grep -n 'drone-acceptance'` check) even though the acceptance criteria named only three items in this file.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
