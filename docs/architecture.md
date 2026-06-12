# Architecture

## One constraint shapes everything
In Claude Code, **subagents cannot spawn subagents** (no `Task` tool inside a subagent). VULYK does not fight this - it builds on it:

- All fan-out happens from the **main session (Queen)**. Commands (`/vulyk-plan`, `/vulyk-build`, `/vulyk-review`) encode the orchestration logic the Queen executes.
- Every subagent is **single-purpose**: it receives a complete brief, works in its own clean context window, returns a structured result. No nested delegation, no context bleed.
- With the experimental **Agent Teams** flag, teammates additionally coordinate peer-to-peer - VULYK treats this as an upgrade path for collaborative Tier 3-4 work, not a requirement.

## The castes
| Caste | Members | Model | Contract |
|---|---|---|---|
| Queen | main session, `queen-planner` | top / opus | owns plan & integration; consumes reports, never source |
| Leads | `lead-architect`, `lead-review` | opus | judgment at the two highest-leverage points: design and gate |
| Workers | `worker-code`, `worker-test` | sonnet | one story, scoped files, structured handback |
| Drones | `drone-scout`, `drone-docs`, `librarian` | haiku | recon, memory truth, hygiene - high volume, low cost |

## Data flow of one Tier 3 feature
```text
goal -> Queen classifies tier
     -> drone-scouts (parallel, haiku) ------ reports ------+
     -> memory/map + wiki pointers --------------------------+-> queen-planner (opus)
                                                             -> docs/specs/<slug>/plan.md + stories
human approves
     -> Queen fans out worker-code / worker-test (sonnet, parallel per story DAG)
     -> workers append Implementation notes / Findings to their story files
     -> lead-review (opus) gate: PASS | BLOCK(-> fix stories -> /vulyk-build)
merge
     -> drone-docs refreshes map + wiki; post-merge git hook flags staleness as backup
session end
     -> hook captures learnings -> /vulyk-gc consolidates -> /vulyk-evolve turns them into config diffs
```

## Why state lives in git, not in context
Context windows are ephemeral and expensive; git is durable and free. Plans, stories, maps, wiki notes, learnings, ADRs, and even the framework's own evolution (changesets on `vulyk/evolve-*` branches) are files. Any session can die at any moment and the hive loses nothing but the last few turns. This is the same conclusion the strongest 2026 orchestration systems converged on independently.
