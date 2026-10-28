# Memory triage is offered, not run (brief)

**Date:** 2026-10-28 · **Tier:** 1

## Request
<!-- The Queen's wording, passed to /vulyk-plan; it is not an owner quote. The owner's own words are the decision line below. -->
> Hotfix 0.41.1 for 0.41.0 (spec auto-memory-subagent-start). The SessionStart brief adds `memory triage (...)` to the `maintenance due` line, which tells the Queen to run every item through the Skill tool without asking after the owner's task. `/vulyk-gc memory` step 2 reads every private memory file (75-270 in large hives on this machine), so a hive's first session after `/vulyk-update` would spend a large context on it unasked. Fix: the memory triage leaves `maintenance due` and gets its own line telling the Queen to ask the owner once after the current task; on a no, `memory-triage.sh --mark` so the signal stays quiet until the index grows. No hive runs 0.41.0 yet.

Owner decision, 2026-10-28: «Хотфикс 0.41.1: только предлагать (Рекомендую)».

## Asks
1. A `MEMORY.md` over the threshold no longer puts `memory triage` into the `maintenance due` line; the brief prints its own line that tells the Queen to ask the owner once, after the current task, whether to run `/vulyk-gc memory`, and to run `memory-triage.sh --mark` on a no.
