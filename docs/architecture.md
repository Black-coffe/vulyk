# Architecture

## One constraint shapes everything
In Claude Code, **subagents cannot spawn subagents** (no `Task` tool inside a subagent). VULYK does not fight this - it builds on it:

- All fan-out happens from the **main session (Queen)** or, at Tier 3-4, from the **Workflow driver** running the same loop unattended. Below Tier 3 there is no fan-out to speak of: the Queen builds the stories herself and dispatches one reviewer per round (changed in 0.18.0, ADR-013). Commands (`/vulyk-plan`, `/vulyk-build`, `/vulyk-review`, `/vulyk-ship`) encode the orchestration logic.
- Every subagent is **single-purpose**: it receives a complete brief, works in its own clean context window, returns a structured result. No nested delegation, no context bleed.
- With the experimental **Agent Teams** flag, teammates additionally coordinate peer-to-peer - VULYK treats this as an upgrade path for collaborative Tier 3-4 work, not a requirement.

## The castes
| Caste | Members | Model | Contract |
|---|---|---|---|
| Queen | main session, `queen-planner` | opus on every plan; a Tier 4 `queen-planner` gets `TOP_MODEL` (ADR-012) | plans; builds Tier 1-2 stories herself; at Tier 3-4 dispatches and integrates; `queen-planner` plans Tier 3-4 |
| Leads | `lead-review`, `lead-architect` | `lead-review`: opus at Tier 1-3, `TOP_MODEL` at Tier 4 beside a second reviewer; `lead-architect`: `TOP_MODEL` (fable on Max, opus on Pro, resolved by `scripts/top-model.sh`) | the reviewer seat of every round (asks + correctness); design decisions and ADRs |
| Workers | `worker-code`, `worker-test` | sonnet (the story's `model:`), effort medium; a retry goes to `TOP_MODEL`, always a different family (ADR-015) | Tier 3-4 only: one story, scoped files, closes it with `cycle.sh close-story` |
| Drones | `drone-scout`, `drone-docs`, `librarian` | sonnet (scout, docs) / opus (librarian), effort low | recon (capped per tier: 0-1/1/2/4 scouts), memory truth, hygiene |
| Gate | `drone-coverage` | opus, effort medium | plan-time independence at Tier 3-4: sees the brief and the plan, never the stories |
| Council | `council-opus`, `council-haiku` | opus (effort medium); opus - it judges, the name is the angle | Tier 3-4 only; blind verdict on `brief.md`'s `## Asks` from a reduced git worktree that cannot see the stories: intent and edge cases; the black-box client path, required only when the Profile's *Client path* is filled |
| Clerk | `cycle-clerk` | sonnet, effort low; haiku once a Haiku at or above the floor ships | the Workflow driver's only way to reach a shell: one `cycle.sh` command per agent boundary, no logic of its own |

Every subagent above except `queen-planner`, the workers, `lead-review` and `lead-architect`
carries `omitClaudeMd: true`: it takes everything from its dispatch prompt and its own body, so
it does not load the constitution. Those four keep it because they need the host's conventions.

## Data flow of one Tier 3 feature
The shape is the six-stage cycle in [cycle.md](cycle.md) - spec, plan, code, tests+human, ship -
each closed by a file on disk. This is the machinery inside it:
```text
goal -> Queen names the deliverable: a document ends at report.md (study, ADR-008); code gets a tier
     -> brief.md: the request verbatim, through redact.sh (Tier 2+)
     -> drone-scouts (opus low, capped: 1 at Tier 1-2, 2 at Tier 3, 4 at Tier 4) -- reports --+
     -> memory/map + wiki pointers --------------------------+-> queen-planner (opus Tier 3, TOP_MODEL Tier 4)
     -> the grill (templates/grill.md): one round, one question at a time, recommended option
        first with a recon-grounded reason, closing into brief.md's ## Asks - the first of the
        two human stops (the second is the plan approval below, stage 01+02, **Approved:**)
     -> plan.md (+ Contracts) + stories (## Requirements quote the brief)
     -> wave-check.sh: waves dispatchable? (file collisions, blocker order - deterministic)
     -> trace-check.sh: every story quotes the brief? every brief line carried? (deterministic)
     -> drone-coverage (opus, Tier 3-4): brief + plan only, never the stories - what is not carried?
     -> the plan shown to the owner, one word of approval -> **Approved:** (the default since v0.13);
        --go or the grill's straight-through opt-in closes the intake with cycle.sh briefed instead
/vulyk-build launches the Workflow driver (Tier 3-4; Tier 1-2 run the same loop solo, below)
     -> advance --claim: claims the spec (refused on a tree dirty outside paperwork), puts it on
        its own branch, vulyk/<slug>, and records it (stage 03)
     -> build:<wave>: opus workers in parallel, one message per wave, disjoint files; each
        worker closes its own story with cycle.sh close-story --commit: scope-check, the
        story's verification run once under a 540 s timeout, its own commit (stage 04);
        a story still todo after its wave is retried once on the gate model (ADR-012)
     -> advance: every story done -> cycle.sh open-round freezes the tier's seats into ROUND
        and, when a blind seat is required, opens a reduced git worktree - the court - at the
        pack commit, docs/specs/<slug>/ reduced to brief.md
     -> dispatch:<seats>: lead-review (main tree; round 2+ reads only since..head) ∥ council-opus
        (intent and edge cases) ∥ council-haiku (the Client path, blind; only when the Profile
        fills it), each writing its report to .vulyk/reports/<slug>/round-<n>/
     -> advance --ingest: record-seat checks each report, then cycle.sh judge, a model-free
        script, computes the verdict from the labelled, evidenced reports (stage 05)
        GREEN -> /vulyk-ship unblocks
        RED -> cycle.sh repair writes the repair story (RED asks quoted, anchored findings
               verbatim) -> the next wave; green blind seats carry into the next round
        ESCALATE (tier ceiling: 1/2/3 rounds for Tier 1/2/3-4, + the same per reopen; half
        the asks RED; the same ask RED twice) -> ## Needs a human in plan.md names the exits
     -> release
     Tier 1-2 (solo): the Queen implements each story herself and runs close-story and
     `advance` from her own Bash; the council is one lead-review per round; no clerk, no court
/vulyk-ship (stage 06)
     -> ship-check.sh: all six confirmations present, and about THIS pack at THIS commit
     -> version + CHANGELOG commit on the spec branch -> local merge -> the human presses publish
     -> ship-check.sh --record: **Shipped:** line + ship.jsonl
     -> drone-docs refreshes map + wiki; librarian harvests ADRs (stage 06 only, proposed-only);
        post-merge hook flags staleness
     -> leftovers (UNASKED, ## Descoped, unfixed CONCERNS) handed over as the next brief's draft
weekly
     -> /vulyk-gc consolidates memory -> /vulyk-evolve reads learnings, stats and token-report.py,
        and proposes config diffs
```

## One verb, one state
The loop *build -> council -> repair* is stepped by one verb, `bash scripts/cycle.sh advance`. It
runs every mechanical step (`branch`, `open-round`, `judge`, `repair`) until `next` names
something only an agent can do (`build:<wave>` or `dispatch:<seats>`), then prints one JSON line
carrying the status. Three callers step it the same way:

- the Queen from her own `Bash` at Tier 1-2, building the stories herself;
- `.claude/workflows/vulyk-cycle.js` at Tier 3-4, a Workflow script that reaches the shell
  through `cycle-clerk`, one call per agent boundary (a happy Tier 3 run is 4 clerk calls);
- the Queen at Tier 3-4 when the Workflow tool is missing, dispatching with the `Agent` tool.

None of them holds a round counter, a verdict rule or a ceiling of its own. State - round
directories, seat reports, `council.jsonl`, the journal - lives in committed files, never inside a
run, so a crash, a `/clear` or a `/vulyk-pause` costs at most the step in flight, and
`/vulyk-resume` always relaunches fresh rather than replaying.

## Why state lives in git, not in context
Context windows are ephemeral and expensive; git is durable and free. Plans, stories, maps, wiki notes, learnings, ADRs, and even the framework's own evolution (changesets on `vulyk/evolve-*` branches) are files. Any session can die at any moment and the hive loses nothing but the last few turns. This is the same conclusion the strongest 2026 orchestration systems converged on independently.
