# Architecture

## One constraint shapes everything
In Claude Code, **subagents cannot spawn subagents** (no `Task` tool inside a subagent). VULYK does not fight this - it builds on it:

- All fan-out happens from the **main session (Queen)**. Commands (`/vulyk-plan`, `/vulyk-build`, `/vulyk-review`) encode the orchestration logic the Queen executes.
- Every subagent is **single-purpose**: it receives a complete brief, works in its own clean context window, returns a structured result. No nested delegation, no context bleed.
- With the experimental **Agent Teams** flag, teammates additionally coordinate peer-to-peer - VULYK treats this as an upgrade path for collaborative Tier 3-4 work, not a requirement.

## The castes
| Caste | Members | Model | Contract |
|---|---|---|---|
| Queen | main session, `queen-planner` | `TOP_MODEL`: fable on Max, opus on Pro — resolved per plan by `scripts/top-model.sh` | owns plan & integration; consumes reports, never source |
| Leads | `lead-architect`, `lead-review` | `TOP_MODEL` (frontmatter floor `opus`, dispatch parameter carries the upgrade) | judgment at the two highest-leverage points: design and gate |
| Workers | `worker-code`, `worker-test` | sonnet | one story, scoped files, structured handback |
| Drones | `drone-scout`, `drone-docs`, `librarian` | sonnet | recon, memory truth, hygiene - high volume; the Haiku question is weighed in [model-cascade.md](model-cascade.md) |
| Gates | `drone-coverage`, `drone-acceptance` | sonnet | independence: one sees the plan without the stories, the other sees the software without the plan |

## Data flow of one Tier 3 feature
The shape is the six-stage cycle in [cycle.md](cycle.md) - spec, plan, code, tests, human,
ship - each closed by a file on disk. This is the machinery inside it:
```text
goal -> Queen classifies tier
     -> brief.md: the request verbatim, through redact.sh (Tier 2+)
     -> briefing questions: only irreversible/costly/vendor/business-rule, one at a time
     -> the owner confirms the spec text (stage 01; a stop at Tier 3-4, shown-and-continue at Tier 2)
     -> drone-scouts (parallel, sonnet) ----- reports ------+
     -> memory/map + wiki pointers --------------------------+-> queen-planner (TOP_MODEL)
                                                             -> plan.md (+ Contracts) + stories
                                                                (## Requirements quote the brief)
     -> wave-check.sh: waves dispatchable? (file collisions, blocker order - deterministic)
     -> trace-check.sh: every story quotes the brief? every brief line carried? (deterministic)
     -> drone-coverage (sonnet): brief + plan only, never the stories - what is not carried?
human approves -> **Approved:** line in plan.md (stage 02)
     -> /vulyk-build puts the spec on its own branch, vulyk/<slug>, and records it (stage 03)
     -> Queen dispatches wave by wave (sonnet workers, one message per wave, disjoint files)
     -> each story closes alone: <=25-line return -> scope-check -> quiet verify -> own commit
     -> workers append Implementation notes / Findings to their story files
     -> lead-review (TOP_MODEL) gate: PASS | BLOCK(-> fix stories -> /vulyk-build)
        + drone-acceptance (sonnet), same message: brief + repo + run command + client path,
          never the specs - walks the path as a client would (stage 04)
          ACCEPTED | REJECTED | CANNOT_RUN -> acceptance-log.sh records the drift
                                              + the pack judged; --check before merge
the owner looks (stage 05 - mandatory, and never an agent's)
     -> check card: branch + client path + one line per ask -> the owner answers
     -> human-check.sh writes their words into plan.md + human.jsonl, pinned to the commit
     -> REJECTED: fix stories -> /vulyk-build; both gates and the look are re-earned
/vulyk-ship (stage 06)
     -> ship-check.sh: all six confirmations present, and about THIS pack at THIS commit
     -> version + CHANGELOG commit on the spec branch -> merge -> the human publishes
     -> ship-check.sh --record: **Shipped:** line + ship.jsonl
     -> drone-docs refreshes map + wiki; librarian harvests ADRs; post-merge hook flags staleness
     -> leftovers (UNASKED, ## Descoped, unfixed CONCERNS) handed over as the next brief's draft
session end
     -> hook captures learnings -> /vulyk-gc consolidates -> /vulyk-evolve turns them into config diffs
```

For what each gate structurally cannot see, and when a gate stops being true, see
[The gates](pipeline.md).

## Why state lives in git, not in context
Context windows are ephemeral and expensive; git is durable and free. Plans, stories, maps, wiki notes, learnings, ADRs, and even the framework's own evolution (changesets on `vulyk/evolve-*` branches) are files. Any session can die at any moment and the hive loses nothing but the last few turns. This is the same conclusion the strongest 2026 orchestration systems converged on independently.
