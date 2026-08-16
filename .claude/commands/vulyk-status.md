---
description: Hive dashboard - open stories, memory freshness, skill stats, budget posture
argument-hint: []
---

Produce the hive status report. Read only metadata - this command must stay cheap:

1. **Stories:** scan `docs/specs/*/` status lines -> table: spec, story, status, assigned tier.
2. **Memory freshness:** `memory/map/*` last-verified dates vs. recent git churn in their modules (`git log --since` per path); flag stale. Note if `scripts/git-hooks/post-merge` left a `.stale` flag.
3. **Learnings buffer:** count raw files in `memory/learnings/` awaiting consolidation; remind about /vulyk-gc past 10.
4. **Skill usage:** top/bottom entries from `memory/stats/skills.json`; note candidates the next /vulyk-evolve will examine.
5. **Budget posture:** restate TOP_MODEL and the routing matrix one-liner; if the session has been long, recommend `/vulyk-handoff` then `/clear` after this report.
6. **Context hygiene** (only when the session is fresh — otherwise the advice arrives too late to act on): suggest `/context` to see what the session starts with, and `/mcp` to switch off servers this project never calls. Skip this step entirely on a long session.

Format: compact tables, no prose padding. End with the single most useful next action.
