---
description: Execute approved stories with cascade-routed workers, parallel where independent
argument-hint: [spec slug or story id; defaults to newest approved plan]
---

Execute the approved plan: "$ARGUMENTS" (default: most recent plan in `docs/specs/` marked approved).

1. **Load the plan.** Refuse politely if no approval marker - planning and building are separate decisions by design.
2. **Order the work.** Build the dependency order from story files. Dispatch independent stories in parallel (cap: 4 concurrent workers; respect any budget posture in CLAUDE.md).
3. **Dispatch.** Each story goes to `worker-code` (then `worker-test` where the story requires tests) with EXACTLY: the story file, its map slice pointer, the relevant `.claude/rules/` paths. Nothing more - scoped context is the law.
4. **Supervise without micromanaging.** When a worker returns a wall (`## Findings`), decide: re-scope the story, send a fresh worker with the findings attached, or escalate the design question to `lead-architect`. Never re-dispatch the identical prompt hoping for luck.
5. **Track.** Update each story's status line (todo -> in-progress -> done/blocked) as you go. Keep your own context lean: you hold the plan and statuses, not the diffs.
6. **Close.** When all stories are done or blocked: summarize changes, run the project's full verification command once, then recommend `/vulyk-review` (mandatory for Tier 3-4). Suggest `drone-docs` dispatch for map/wiki updates after the review passes.
