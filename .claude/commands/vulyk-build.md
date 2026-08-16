---
description: Execute approved stories in waves of cascade-routed workers, one commit per story
argument-hint: [spec slug or story id; defaults to newest approved plan]
---

Execute the approved plan: "$ARGUMENTS" (default: most recent plan in `docs/specs/` marked approved).

1. **Load the plan.** Refuse politely if no approval marker - planning and building are separate decisions by design.

2. **Check the waves.** Run `bash scripts/wave-check.sh docs/specs/<slug>` and show its output. A collision, order violation or dangling blocker is a plan defect: fix the story files (merge, split, or re-wave) before dispatching anything. Disjoint `## Files` within a wave is the precondition for parallel dispatch - two concurrent workers on one file silently overwrite each other.

3. **Dispatch by wave, one message per wave.** Launch every story of the current wave as parallel worker calls **in a single message** - that, and nothing else, is what makes them actually run concurrently; one call per message is a serial build wearing parallel clothes. Each story goes to its worker (`worker-code`, then `worker-test` where the story requires tests) with EXACTLY: the story file, its map slice pointer, the relevant `.claude/rules/` paths. Nothing more - scoped context is the law. Cap: 4 concurrent workers; a bigger wave dispatches in slices.

4. **Close each story as its worker returns** - do not wait for the whole wave:
   1. Read the return report (`STATUS`/`FILES`/`TESTS`/...). If a worker returned prose instead of the contract, take what it did as unverified: run the story's verification yourself via a quiet command before trusting it.
   2. `bash scripts/scope-check.sh <story-file>` - with per-story commits the default working-tree range is exactly this story's diff, so the numbers are finally per-story, not per-pileup.
   3. Run the story's `## Verification` command (quiet variant). Red -> back to the worker path, never patched by your hands.
   4. Commit: `git add` the story's declared files (plus the story file itself) and commit as `story(<slug>-NN): <title>`. **One story, one commit** - it is the rollback point and the review unit. Out-of-scope files flagged by scope-check are a decision, not a default: leave them uncommitted and resolve (amend the story, or descope the change) before they ride along.
   5. Update the story's `status:` line.

5. **Repair has a ceiling: two rounds per story.**
   - `NEEDS_CONTEXT` -> the story was defective. Fix the story file (or answer the question), then send a **fresh** worker. This round counts against the plan, not the worker.
   - `WALL` or red verification -> send ONE fresh worker with `## Findings` attached and the repair stated as a condition to satisfy ("make X pass with Y preserved"), not as instructions to follow. Never re-dispatch the identical prompt hoping for luck.
   - Second failure -> stop the story: mark it `blocked`, and either re-plan it or escalate the design question to `lead-architect`. A third identical attempt is a token bonfire.

6. **Descoping is recorded, never silent.** If you narrow, split or drop a story mid-build, append one line to `## Descoped` in `plan.md`: what was cut, why, and what evidence the build produced. The human sees the plan they approved; a story that quietly shrank is a requirement that quietly vanished.

7. **Track lean.** You hold the plan, the wave number and the status lines - not the diffs, not the test output. Anything longer than a return report gets re-read from disk when needed.

8. **Close the build.** When all stories are done or blocked: summarize per-story commits and statuses, then run the project's full verification once **without flooding your context** - dispatch it to a worker or pipe through `tail -30`; you need the verdict and the names of what failed, not the log. Recommend `/vulyk-review` (mandatory for Tier 3-4). Suggest `drone-docs` dispatch for map/wiki updates after the review passes.
