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
| 02 | **Plan** — who does what in which files; the plan can be handed to an agent whole | Queen / `queen-planner` | the list of steps, approved by the owner (default) or briefed straight through (`--go`, Tier 1) | `plan.md` + story files; `**Approved:**` or `**Briefed:**` line | `/vulyk-plan`, stop for approval |
| 03 | **Code** — changes live in their own branch | the Queen at Tier 1-2; workers in waves at Tier 3-4 | the branch, one commit per story | `**Branch:**` line in plan.md; git | `/vulyk-build` |
| 04 | **Tests** — automatic: each story's own `## Verification` command, run once inside `cycle.sh close-story` (under a 540 s timeout) and repeated as the story asks | whoever built the story closes it: the Queen, or the worker itself | every story's verification green | story `## Verification` greens | `/vulyk-build` |
| 05 | **Council** — `lead-review` judges the diff against the brief's `## Asks`; at Tier 3-4 blind seats judge the same asks from a court that cannot see the hive's stories | `lead-review` (+ `council-opus`, and `council-haiku` when the Client path is filled, at Tier 3-4) | every required seat GREEN or N/A and the review PASS | `**Council:**` line in plan.md; `memory/stats/council.jsonl` | `/vulyk-build` or `/vulyk-review` (one round) |
| 06 | **Ship** — history fixed, branch merged locally, publish command printed and never pressed, next circle opened | a green build or review asks «Выпускаем?» once and a yes runs `/vulyk-ship`; Queen merges and prints; human presses when ready | the local merge, recorded | `**Shipped:**` line in plan.md; git (local merge) | `/vulyk-ship` |

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

Stage 05 is now the **council**, sized by the tier (changed in 0.18.0, ADR-013). At Tier 1-2 it
is one fresh-context reviewer, `lead-review`, judging the diff against the asks and for
correctness. At Tier 3-4 blind seats join it: `council-opus` (intent and edge cases) and, when
the Profile's *Client path* is filled, `council-haiku` (the black-box walk). They work in a
worktree with `docs/specs/<slug>/` reduced to `brief.md`, so neither can see the hive's own
account of what it built — the same blindness stage 05 used to buy from a human who had not
read the stories either. Green requires unanimity: every required seat `GREEN` or `N/A`, and
`lead-review` `PASS`.

The council converges rather than starting over each round. A blind seat that was `GREEN` or
`N/A` in round n-1 is carried into round n, and from round 2 `lead-review` reads only
`since..head` against the previous round's findings. A `BLOCK` needs a finding anchored to an
ask (`[ask N]`) or a `[regression]`. A RED round becomes a repair story written by
`cycle.sh repair`: the RED asks quoted, the anchored findings verbatim, no planner in between.
A round with an evidenced RED on
half the asks or more escalates immediately rather than burning further rounds on a plan
that is wrong; a round that finds the same ask RED as the round before escalates at once
(`no-progress`) instead of opening another repair; RED rounds without unanimity escalate on the tier's ceiling (1 RED round at Tier 1,
2 at Tier 2, 3 at Tier 3–4; a GREEN or `STALE` round never counts). Either way
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
| The brief gains an `## Answers` line that changes an ask after the grill closed | 02 onward | `**Approved:**` (or `**Briefed:**` on the `--go` / Tier 1 path) — re-present the plan |
| A code commit lands on the branch while a council round is open | 05 | the open round: `cycle.sh open-round` re-stamps it in place if no seat has reported yet, or writes a `STALE` row and opens round N+1 if one already has — neither counts against the ceiling, which counts only rounds that ended RED |
| A code commit lands after a round already judged GREEN | that `**Council:**` row | `ship-check.sh` reads it as `STALE (commit)` unless only paperwork landed since (`paperwork_only`; `VERSION` and `CHANGELOG.md` count as paperwork); a fresh round opens, carries the green blind seats and re-reviews only the new diff; a GREEN round never counts against the ceiling |
| A round is RED for half the asks or more, holds an ask RED that round N-1 also held RED (`no-progress`), or the tier's ceiling (1 / 2 / 3 rounds that ended RED for Tier 1 / 2 / 3–4, `+` the same per `reopen`; a GREEN or `STALE` round never counts) is reached | 05 | `ESCALATE` — `cycle.sh escalate` writes `## Needs a human` into `plan.md`; the loop stops instead of opening a round nobody asked for |
| The owner pauses, at any stage | any | `PAUSE` semaphore — the loop stops at its next safe point; `/vulyk-resume` clears it and relaunches fresh, never resuming a cached run |
| An `ESCALATE` is on the record | 05 | three exits, all on the record: `human-check.sh ACCEPTED` (ship over the council), `cycle.sh reopen "<decision>"` (another tier's worth of rounds, starting with a repair story; with a fresh round instead when the escalation was `env` or the round is stale), or leaving the spec open |
| The owner records `**Checked:** REJECTED` after a GREEN council row | 05, then 03–04 via repair | the council verdict — treated as RED regardless of what the seats said; the repair story goes through `/vulyk-build`, then a fresh round |

`scripts/ship-check.sh docs/specs/<slug>` reads all of it at once and says which stage is
open. It is what `/vulyk-ship` runs first, and it is free.

## Tiers and the cycle

The cycle is the shape of every Tier 1+ spec. Tier 0 work skips it entirely by design —
there is no brief, so there is nothing to judge. Past that, the tier the Queen already
assigned before any work started is the cycle's one scaling decision: `cycle.sh` reads it
from plan.md's `**Tier:**` line and freezes the seats that tier requires into the round's
`ROUND` file when the round opens (ADR-013 D1).

| Tier | Who builds | Required seats | Round ceiling | Agents per round |
|---|---|---|---|---|
| 1 | the Queen, solo | `review` | 1 | 1 `lead-review` |
| 2 | the Queen, solo, in a fresh session after approval | `review` | 2 | 1 `lead-review` |
| 3 | workers in waves (Workflow driver) | `opus`, `review`; `haiku` when *Client path* is filled | 3 | the seats + 1 clerk call to record them |
| 4 | workers in waves + `lead-architect` | as Tier 3; `review` is two reviewers on different models, folded into one | 3 | as Tier 3, one reviewer more |

Solo means no driver, no clerk and no court: the Queen runs `cycle.sh advance` from her own
Bash. It performs every mechanical step (branch, open-round, judge, repair) and stops at the
next thing only an agent can do.

A story can also wait on a hand step: `blocked_by: [manual:<id>]` (0.19). When the earliest wave with
todo stories has none ready and one waits on an unrecorded step, `next` is `manual:<id,...>` (the ids
also under `status.manual`); no later wave is built past it, and the driver stops without dispatching.
`bash scripts/cycle.sh manual-done docs/specs/<slug> <id> [note]` writes and commits
`docs/specs/<slug>/manual/<id>`, and the wave becomes ready.

Study work - a request whose deliverable is a document - never enters the loop at all: it ends
at `report.md` (ADR-008). And since v0.13 stage 02 closes on the owner's `**Approved:**` by
default; `**Briefed:**` is the straight-through opt-in (`--go`) and Tier 1's mini-brief.

What still shrinks below that floor is the size of the record — a one-line `## Asks` instead
of a grill's 3-7, one story instead of many — never whether the reviewer runs.

## The next circle

Stage 06 does not end at the tag. Three things carry over, and `/vulyk-ship` writes them
down before recommending `/clear`:

- `UNASKED` lines from the blind seats' reports (`docs/specs/<slug>/council/round-N/{haiku,opus}.md`)
  — behaviour nobody asked for that is now on the record, and either a bug or the seed of
  the next brief;
- `lead-review`'s minors and every `[unanchored]` critical or major finding: they never block
  a round, so they wait here;
- `## Descoped` lines from plan.md — requirements the human agreed to drop *for now*;
- `CONCERNS` from worker returns that review ranked minor and nobody fixed.

Together they are the draft of the next `brief.md`. The human decides which of them
becomes one; the framework only refuses to forget them.
