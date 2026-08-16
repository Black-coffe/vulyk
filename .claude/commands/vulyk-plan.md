---
description: Queen planning mode - recon, decompose into stories, classify tier, request approval
argument-hint: <goal description>
---

Enter Queen mode for: "$ARGUMENTS"

1. **Classify the tier** per the routing matrix in CLAUDE.md. Announce it. Tier 0-1: skip ceremony - say so and either do it (Tier 0) or write a single story and stop for approval (Tier 1).
2. **Recon, not reading.** Check `memory/memory.md` and relevant `memory/map/` slices first. Dispatch `drone-scout` (parallel, up to 4) only for territory the map does not cover or marks stale. You do not open source files yourself.
3. **Plan.** For Tier 2: draft the plan inline. For Tier 3-4: delegate synthesis to `queen-planner` with the scout reports and map pointers attached; for Tier 4 also request a `lead-architect` consult on the central design fork before stories are finalized.
4. **Stories.** Ensure `docs/specs/<slug>/` contains plan.md plus one story file per unit of work (template: `templates/story.md`). Each story: files to touch, acceptance criteria, verification command, map slice pointer, model tier of its worker, and its `wave:`/`blocked_by:` lines. Wave rule: stories in one wave run concurrently, so their `## Files` must be disjoint - when two stories need the same file, either merge them, move the shared file into its own earlier story, or push one to a later wave via `blocked_by`.
5. **Check the waves.** Run `bash scripts/wave-check.sh docs/specs/<slug>` - deterministic, free, and it catches the collision that would silently eat a worker's diff mid-build. Fix any finding in the story files now; a plan approved with a colliding wave ships the defect.
6. **Stop for approval.** Present: tier, story list with one-line summaries grouped by wave, open assumptions (Law 1), estimated token posture (how many worker dispatches, where top-model tokens will be spent), and the wave-check verdict. Do NOT proceed to implementation - that is /vulyk-build, run after human approval.
