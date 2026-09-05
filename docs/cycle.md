# The cycle

Six stages, six confirmations, one loop. This page names the shape the whole framework is
in service of; [architecture.md](architecture.md) draws the machinery inside it and
[pipeline.md](pipeline.md) says what each gate cannot see.

```text
   01 Spec ───► 02 Plan ───► 03 Code
    ▲                           │
    │ next circle               ▼
   06 Ship ◄─── 05 Human ◄─── 04 Tests
                (mandatory)
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
| 04 | **Tests** — automatic: the agent runs the suite and walks the client's path | `worker-test`, `drone-acceptance` | a passed run | story `## Verification` greens; `memory/stats/acceptance.jsonl` | `/vulyk-build` step 4, `/vulyk-review` |
| 05 | **Human** — the owner looks with their own eyes, on a test or live version | **the human, nobody else** | your check, recorded | `**Checked:**` line in plan.md; `memory/stats/human.jsonl` | `/vulyk-review` PASS path |
| 06 | **Ship** — history fixed, version published, next circle opened | Queen prepares, human presses | the published version | `**Shipped:**` line in plan.md; tag / release | `/vulyk-ship` |

## Why 05 is red

Every gate before it is answerable to the brief, and the brief can ask for the wrong
thing. The blind acceptance drone can tell you the software does what the words said;
only the person who wrote the words can tell whether the words said what they meant.
That is not a check any agent can run, so it is not a check any agent is allowed to skip:
`/vulyk-ship` refuses without a `**Checked:**` line the same way `/vulyk-build` refuses
without `**Approved:**`. Overriding it is possible — the record then says the owner shipped
unchecked, in their own words — and it is never silent.

The check is cheap to do and cheap to record: `scripts/human-check.sh docs/specs/<slug>
ACCEPTED "<where you looked>"` writes one line in two places. What it buys is that the ship
stage, the release ledger and the next circle all rest on something a person actually saw.

## What invalidates a confirmation

Each artifact is about the pack **at a commit**. Move the pack and the artifact is about
something else — same rule as every gate in [pipeline.md](pipeline.md).

| Event | Stage(s) it reopens | Artifact that goes stale |
|---|---|---|
| The brief gains an `## Answers` line that changes an ask | 02 onward | `**Approved:**` — re-present the plan |
| A story is cut, merged or re-waved after approval | 04, 05 | acceptance verdict (`--check` says STALE); the human check (`human-check.sh --check`) |
| A code commit lands on the spec branch after the owner looked | 05 | `**Checked:**` — it names the commit it was given against. A commit touching only the cycle's own ledgers (plan.md marker lines, `memory/stats/*.jsonl`) is paperwork and does not count |
| The owner rejects at 05 | 02–04 | findings become fix stories, back through `/vulyk-build`; both verdicts are re-earned |

`scripts/ship-check.sh docs/specs/<slug>` reads all of it at once and says which stage is
open. It is what `/vulyk-ship` runs first, and it is free.

## Tiers and the cycle

The cycle is the shape of every Tier 2+ spec. Tier 0–1 work skips the paperwork by
design — there is no brief to confirm and no branch to record — but **stage 05 does not
scale with tier**: a one-file change that reaches a user still gets looked at by the owner
before it is published. What shrinks is the record, not the look.

## The next circle

Stage 06 does not end at the tag. Three things carry over, and `/vulyk-ship` writes them
down before recommending `/clear`:

- `UNASKED` lines from the acceptance report — behaviour nobody asked for that is now on
  the record, and either a bug or the seed of the next brief;
- `## Descoped` lines from plan.md — requirements the human agreed to drop *for now*;
- `CONCERNS` from worker returns that review ranked minor and nobody fixed.

Together they are the draft of the next `brief.md`. The human decides which of them
becomes one; the framework only refuses to forget them.
