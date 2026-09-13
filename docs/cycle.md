# The cycle

Six stages, six confirmations, one loop. This page names the shape the whole framework is
in service of; [architecture.md](architecture.md) draws the machinery inside it and
[pipeline.md](pipeline.md) says what each gate cannot see.

```text
   01 Spec ───► 02 Plan ───► 03 Code
    ▲                           │
    │ next circle               ▼
   06 Ship ◄─── 05 Council ◄─── 04 Tests
                    ▲
        Human ------┘   (override, any stage: /vulyk-pause, human-check.sh)
```

A stage is not finished when the work is done. It is finished when its **confirmation
artifact exists on disk**, because a confirmation that lives in a chat turn is gone at the
next `/clear`, and the stage after it then rests on memory. Every artifact below is a file
or a line in one, every one is checked by a script that costs no tokens, and the command
that opens the next stage refuses when the previous stage's artifact is missing.

| # | Stage | Who | Confirmation artifact | Where it lives | Opened by |
|---|---|---|---|---|---|
| 01 | **Spec** — what and why: the message, the error report, the user's ask | human writes, Queen records | the spec text, verbatim | `docs/specs/<slug>/brief.md` (+ `## Answers`) | `/vulyk-plan` |
| 02 | **Plan** — who does what in which files; the plan can be handed to an agent whole | Queen / `queen-planner` | the list of steps, approved | `plan.md` + story files; `**Approved:**` line | `/vulyk-plan`, stop for approval |
| 03 | **Code** — an agent or a person works; changes live in their own branch | workers | the branch, one commit per story | `**Branch:**` line in plan.md; git | `/vulyk-build` |
| 04 | **Tests** — automatic: each story's own `## Verification` command, run and repeated as the story asks | `worker-code` / `worker-test`, via `cycle.sh close-story` | every story's verification green | story `## Verification` greens | `/vulyk-build` |
| 05 | **Council** — three blind seats judge the brief's own `## Asks` from a court that cannot see the hive's stories; `lead-review` judges the code in parallel | `council-haiku`, `council-sonnet`, `council-opus`, `lead-review` | unanimous green, or an evidenced verdict on every ask | `**Council:**` line in plan.md; `memory/stats/council.jsonl` | `/vulyk-build` (driver) or `/vulyk-review` (one round) |
| 06 | **Ship** — history fixed, branch merged locally, publish command printed and never pressed, next circle opened | Queen merges and prints; human presses when ready | the local merge, recorded | `**Shipped:**` line in plan.md; git (local merge) | `/vulyk-ship` |

## Why 05 is red

Every gate before it is answerable to the brief, and the brief can ask for the wrong
thing — that is still true, and it is still what makes 05 the one stage that cannot be
skipped. What changed is who does the asking. `memory/stats/human.jsonl` across three hives
over one week (10 rows) recorded zero `REJECTED` verdicts, two of them stamped the same
second as the commit they were meant to be reading — evidence a mandatory human look had
drifted into ceremony, not substance. Over the same period `memory/stats/acceptance.jsonl`
across five hives (42 rows) recorded five `REJECTED` verdicts, every one substantive: an
interactive session dying after the first search, a brief requirement delivered nowhere, a
central ask left empty twice including after a repair round. The gate actually catching
things was the blind agent, not the human standing beside it.

Stage 05 is now the **council**: three blind seats (`council-haiku`, `council-sonnet`,
`council-opus`), one model and one angle each, working in a worktree with
`docs/specs/<slug>/` reduced to `brief.md` so none of them can see the hive's own account of
what it built — the same blindness stage 05 used to buy from a human who had not read the
stories either. Green requires unanimity: every seat `GREEN` or `N/A`, and `lead-review`
(which does see the code, in parallel, unchanged) `PASS`. A round with an evidenced RED on
half the asks or more escalates immediately rather than burning further rounds on a plan
that is wrong; three RED rounds without unanimity escalate on the ceiling. Either way
`cycle.sh escalate` writes `## Needs a human` into `plan.md` and stops — this is the
emergency exit, not the routine path.

The owner is never locked out: `/vulyk-pause` hands the tree back at any stage, and
`scripts/human-check.sh` still writes `**Checked:** ACCEPTED` or `REJECTED`, which outranks
the council's verdict whichever way it points — `scripts/human-check.sh docs/specs/<slug>
ACCEPTED "<where you looked>"` writes one line in two places. `/vulyk-ship` refuses without
either a GREEN `**Council:**` row or a `**Checked:**` line, exactly as it refused without a
human look before.

## What invalidates a confirmation

Each artifact is about the pack **at a commit**. Move the pack and the artifact is about
something else — same rule as every gate in [pipeline.md](pipeline.md).

| Event | Stage(s) it reopens | Artifact that goes stale |
|---|---|---|
| The brief gains an `## Answers` line that changes an ask after the grill closed | 02 onward | `**Briefed:**` (or `**Approved:**` in two-stop mode) — re-present the plan |
| A code commit lands on the branch while a council round is open | 05 | the open round: `cycle.sh open-round` re-stamps it in place if no seat has reported yet, or writes a `STALE` row and opens round N+1 if one already has — either way the ceiling still counts it |
| A code commit lands after a round already judged GREEN | that `**Council:**` row | `ship-check.sh` reads it as `STALE (commit)` unless only paperwork landed since (`paperwork_only`); a fresh round is needed |
| A round is RED for half the asks or more, or the ceiling (3, `+3` per `reopen`) is reached | 05 | `ESCALATE` — `cycle.sh escalate` writes `## Needs a human` into `plan.md`; the loop stops instead of opening a round nobody asked for |
| The owner pauses, at any stage | any | `PAUSE` semaphore — the loop stops at its next safe point; `/vulyk-resume` clears it and relaunches fresh, never resuming a cached run |
| An `ESCALATE` is on the record | 05 | three exits, all on the record: `human-check.sh ACCEPTED` (ship over the council), `cycle.sh reopen "<decision>"` (three more rounds), or leaving the spec open |
| The owner records `**Checked:** REJECTED` after a GREEN council row | 05, then 03–04 via repair | the council verdict — treated as RED regardless of what the seats said; fix stories go through `/vulyk-build`, then a fresh round |

`scripts/ship-check.sh docs/specs/<slug>` reads all of it at once and says which stage is
open. It is what `/vulyk-ship` runs first, and it is free.

## Tiers and the cycle

The cycle is the shape of every Tier 1+ spec. Tier 0 work skips it entirely by design —
there is no brief, so there is nothing for a court to judge blind. Past that, the tier the
Queen already assigned before any work started is the cycle's one scaling decision:
`cycle.sh` reads it from plan.md's `**Tier:**` line and requires only the seats that tier
calls for (C15) — the council shrinks by seat count with the tier, but never to zero.

| Tier | Required seats | Agents |
|---|---|---|
| 1 | `sonnet` | 1 worker + 1 seat |
| 2 | `sonnet`, `opus`, `review` | 2-4 workers + 2 seats + `lead-review` |
| 3-4 | `haiku`, `sonnet`, `opus`, `review` | 4-8 workers (+ `lead-architect` and a second reviewer at Tier 4) |

What still shrinks below that floor is the size of the record — a one-line `## Asks` instead
of a grill's 3-7, one story instead of many — never whether a seat the tier requires runs.

## The next circle

Stage 06 does not end at the tag. Three things carry over, and `/vulyk-ship` writes them
down before recommending `/clear`:

- `UNASKED` lines from the council's seat reports (`docs/specs/<slug>/council/round-N/{haiku,sonnet,opus}.md`)
  — behaviour nobody asked for that is now on the record, and either a bug or the seed of
  the next brief;
- `## Descoped` lines from plan.md — requirements the human agreed to drop *for now*;
- `CONCERNS` from worker returns that review ranked minor and nobody fixed.

Together they are the draft of the next `brief.md`. The human decides which of them
becomes one; the framework only refuses to forget them.
