# Architecture

## One constraint shapes everything
In Claude Code, **subagents cannot spawn subagents** (no `Task` tool inside a subagent). VULYK does not fight this - it builds on it:

- All fan-out happens from the **main session (Queen)** or, once a spec is briefed, from the **Workflow driver** running the same loop unattended. Commands (`/vulyk-plan`, `/vulyk-build`, `/vulyk-review`, `/vulyk-ship`) encode the orchestration logic either one executes.
- Every subagent is **single-purpose**: it receives a complete brief, works in its own clean context window, returns a structured result. No nested delegation, no context bleed.
- With the experimental **Agent Teams** flag, teammates additionally coordinate peer-to-peer - VULYK treats this as an upgrade path for collaborative Tier 3-4 work, not a requirement.

## The castes
| Caste | Members | Model | Contract |
|---|---|---|---|
| Queen | main session, `queen-planner` | `TOP_MODEL`: fable on Max, opus on Pro — resolved per plan by `scripts/top-model.sh` | owns plan & integration; consumes reports, never source |
| Leads | `lead-architect`, `lead-review` | `TOP_MODEL` (frontmatter floor `opus`, dispatch parameter carries the upgrade) | judgment at the two highest-leverage points: design and the council round |
| Workers | `worker-code`, `worker-test` | sonnet | one story, scoped files, structured handback |
| Drones | `drone-scout`, `drone-docs`, `librarian` | sonnet | recon, memory truth, hygiene - high volume; the Haiku question is weighed in [model-cascade.md](model-cascade.md) |
| Gate | `drone-coverage` | sonnet | plan-time independence: sees the brief and the plan, never the stories |
| Council | `council-haiku`, `council-sonnet`, `council-opus` | Haiku, Sonnet, Opus aliases - one seat per model | blind verdict on `brief.md`'s `## Asks` only, from a reduced git worktree that cannot see the stories - three angles: black-box client path, line-by-line suite + each ask, intent and edge cases |
| Clerk | `cycle-clerk` | Haiku | the Workflow driver's only way to reach a shell; runs exactly one `cycle.sh`/`journal.sh` verb per dispatch and holds no verdict or ceiling logic of its own |

## Data flow of one Tier 3 feature
The shape is the six-stage cycle in [cycle.md](cycle.md) - spec, plan, code, tests+human, ship -
each closed by a file on disk. This is the machinery inside it:
```text
goal -> Queen classifies tier
     -> brief.md: the request verbatim, through redact.sh (Tier 2+)
     -> drone-scouts (parallel, sonnet) ----- reports ------+
     -> memory/map + wiki pointers --------------------------+-> queen-planner (TOP_MODEL, Tier 3-4)
     -> the grill (templates/grill.md): one round, one question at a time, recommended option
        first with a recon-grounded reason, closing into brief.md's ## Asks - the one human
        stop autonomous mode keeps (stage 01+02, **Briefed:**)
     -> plan.md (+ Contracts) + stories (## Requirements quote the brief)
     -> wave-check.sh: waves dispatchable? (file collisions, blocker order - deterministic)
     -> trace-check.sh: every story quotes the brief? every brief line carried? (deterministic)
     -> drone-coverage (sonnet): brief + plan only, never the stories - what is not carried?
     -> cycle.sh briefed --commit closes the intake (the two-stop opt-out still stops here for
        a plan approval, as v0.11 did, when the owner asked for it in the grill's last question)
/vulyk-build launches the driver - a Workflow run where available, this session's own loop otherwise
     -> puts the spec on its own branch, vulyk/<slug>, and records it (stage 03)
     -> dispatches wave by wave (sonnet workers, one message per wave, disjoint files)
     -> each story closes alone: <=25-line return -> scope-check -> quiet verify -> own commit
        -> cycle.sh close-story
     -> workers append Implementation notes / Findings to their story files
     -> cycle.sh open-round (every story done/blocked, clean tree, ## Asks present) opens a
        reduced git worktree - the court - at the pack commit, docs/specs/<slug>/ reduced to brief.md
     -> lead-review (TOP_MODEL, main tree) ∥ council-haiku / council-sonnet / council-opus (in the
        court), one message, one round (stage 04+05): haiku walks the Client path blind, sonnet
        runs the suite once then proves each ask by running it, opus judges intent and edge cases
     -> cycle.sh judge: a model-free script reads the labelled, evidenced seat reports plus
        lead-review's PASS/BLOCK and computes the verdict - no model writes it
        GREEN -> stage 04+05 close together, /vulyk-ship unblocks
        RED -> repair: queen-planner (TOP_MODEL) cuts fix stories from the RED asks, back through /vulyk-build
        ESCALATE (ceiling 3 rounds, or half the asks RED already) -> the Queen wakes once,
        ## Needs a human in plan.md names the exits
/vulyk-ship (stage 06)
     -> ship-check.sh: all six confirmations present, and about THIS pack at THIS commit
     -> version + CHANGELOG commit on the spec branch -> local merge -> the human presses publish
     -> ship-check.sh --record: **Shipped:** line + ship.jsonl
     -> drone-docs refreshes map + wiki; librarian harvests ADRs (stage 06 only, proposed-only);
        post-merge hook flags staleness
     -> leftovers (UNASKED, ## Descoped, unfixed CONCERNS) handed over as the next brief's draft
session end
     -> hook captures learnings -> /vulyk-gc consolidates -> /vulyk-evolve turns them into config diffs
```

## Two drivers, one state
The loop *build -> gates -> council -> repair* runs under either of two drivers with identical
behaviour: `.claude/workflows/vulyk-cycle.js`, a Workflow script - deterministic, background,
resumable, unable to ask a human - where Claude Code supports it, and the Queen's own session
stepping through the same loop with its own `Bash` and `Agent` calls where it does not. Neither
driver holds a round counter, a verdict rule or a ceiling of its own; both are nothing more than a
loop over `bash scripts/cycle.sh status --json`, reading its `next` field and performing the one
action it names. State - round directories, seat reports, `council.jsonl`, the journal - lives in
committed files, never inside a run, so a crash, a `/clear` or a `/vulyk-pause` costs at most the
step in flight, and `/vulyk-resume` always relaunches the driver fresh rather than replaying it.
`/vulyk-status` and the SessionStart brief say which driver is active in this session.

## Why state lives in git, not in context
Context windows are ephemeral and expensive; git is durable and free. Plans, stories, maps, wiki notes, learnings, ADRs, and even the framework's own evolution (changesets on `vulyk/evolve-*` branches) are files. Any session can die at any moment and the hive loses nothing but the last few turns. This is the same conclusion the strongest 2026 orchestration systems converged on independently.
