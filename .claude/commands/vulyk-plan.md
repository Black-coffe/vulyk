---
description: Queen planning mode - recon, decompose into stories, classify tier, request approval
argument-hint: <goal description>
---

Enter Queen mode for: "$ARGUMENTS"

1. **Classify the tier** per the routing matrix in CLAUDE.md. Announce it. Tier 0-1: skip ceremony - say so and either do it (Tier 0) or write a single story and stop for approval (Tier 1).
2. **Recon, not reading.** Check `memory/memory.md` and relevant `memory/map/` slices first. Dispatch `drone-scout` (parallel, up to 4) only for territory the map does not cover or marks stale. You do not open source files yourself.
3. **Plan.** For Tier 2: draft the plan inline. For Tier 3-4: delegate synthesis to `queen-planner` with the scout reports and map pointers attached; for Tier 4 also request a `lead-architect` consult on the central design fork before stories are finalized.
4. **Stories.** Ensure `docs/specs/<slug>/` contains plan.md plus one story file per unit of work (template: `templates/story.md`). Each story: files to touch, acceptance criteria, verification command, map slice pointer, model tier of its worker.
5. **Stop for approval.** Present: tier, story list with one-line summaries, open assumptions (Law 1), estimated token posture (how many worker dispatches, where top-model tokens will be spent). Do NOT proceed to implementation - that is /vulyk-build, run after human approval.
