---
description: Build a planned spec to a council verdict - solo at Tier 1-2 (the Queen builds, one reviewer per round), hive at Tier 3-4 (workers in waves through the Workflow driver)
argument-hint: [spec slug; defaults to the newest briefed or approved spec with no branch yet]
---

Build: "$ARGUMENTS" (default: the newest spec under `docs/specs/` whose plan.md carries `**Briefed:**`
or `**Approved:**` and no `**Branch:**`).

plan.md's `**Tier:**` picks the path: Tier 1-2 solo, Tier 3-4 hive. Every `cycle.sh` verb prints one
JSON object as its last stdout line; decide from its `ok`, `next` and `status`, never from prose. Bash
calls that run `advance` or `close-story` carry `timeout: 600000`. After each call print one line: the
verb, `advance`'s `steps`, and `next`.

## Solo (Tier 1-2)

No driver, no clerk, no court. Loop:

1. `bash scripts/cycle.sh advance docs/specs/<slug>`. It runs every mechanical step (branch,
   open-round, judge, the repair story) up to the next thing only an agent can do, and names it `next`.
2. `build:<W>`: take `status.wave_stories` in order. For each, implement it yourself (its `## Files`
   only; targeted checks while working), add `## Implementation notes`, set `returned: DONE`, and run
   `bash scripts/cycle.sh close-story <file> --commit`. On exit 4, read the error, fix, rerun; after
   three failed reruns write `## Findings` and stop for the owner. A repair story (`# Repair round <n>`)
   is built the same way; its `## Findings` are the conditions to meet. Back to 1.
3. `dispatch:review`: dispatch `lead-review` with the Agent tool, no model parameter:
   `Review <slug>, round <round>. Spec: <spec>. Branch <branch> at <head>. Report: .vulyk/reports/<slug>/round-<round>/review.attempt-<k>.md`
   with k = `status.seat_attempt.review`; from round 2 add `Since: <since>. Previous round:
   <spec>/council/round-<round-1>.` Then `bash scripts/cycle.sh advance docs/specs/<slug> --ingest`.
   If `next` is still `dispatch:review`, the report was rejected: dispatch once more with the
   `rejected` entry's `error` appended, and `--ingest` again. Then act on the new `next`.
4. Any other `next` is terminal (below).

## Hive (Tier 3-4)

1. Resolve `top_model="$(bash scripts/top-model.sh)"`; `second_model`, the pairing
   `bash scripts/top-model.sh --explain` prints (opus beside Fable, sonnet beside Opus) unless plan.md's
   Tier 4 line names another; `stamp="$(openssl rand -hex 8 2>/dev/null || python -c 'import secrets; print(secrets.token_hex(8))')"`.
2. Journal and print the line that hands the tree to the loop: `bash scripts/journal.sh
   docs/specs/<slug> 03-building "launching the hive" "the loop holds the working tree of vulyk/<slug>; to edit, run /vulyk-pause <slug>"`.
3. Call the Workflow tool with `scriptPath: ".claude/workflows/vulyk-cycle.js"` (never `name:`, which
   its permission handler rejects) and `args: {spec: "docs/specs/<slug>", stamp, top_model,
   second_model}`. The driver claims the spec itself; run no `claim` first, and nothing else while it
   runs. If the call itself throws, run `bash scripts/telemetry.sh record driver_refused 1 0 --spec
   <slug> --ref driver:<slug>:$(date -u +%Y-%m-%d)`, print the error and stop.
4. Wake-up: read the returned object, the `journal.md` lines since launch and the newest round's files
   under `docs/specs/<slug>/council/`; never the run transcript. The run's printed `totalTokens` sums
   final contexts and is not spend; `python scripts/token-report.py . --spec <slug>` measures spend.
   - `stop` with a `file` (a story missed twice): set that story's `status: blocked`, append the error
     under `## Findings`, dispatch `lead-architect` (`model: <top_model>`) with the story and both
     failures, and stop.
   - `stop.verb` `claim`: another driver holds the spec. Run the release command the error names only
     if that driver is known dead.
   - Any other `stop`: print `stop.error` and the journal tail, and stop. No `stop`: see Terminal.

Without the Workflow tool, run the solo loop from this session with the stamp, but agents do the work:
- Begin with `advance --stamp <S> --claim`; every later call carries `--stamp <S>`; every exit runs
  `bash scripts/cycle.sh release docs/specs/<slug> <S>`.
- `build:<W>`: one message dispatching each `wave_stories` entry to its `worker` with `model: <model>`
  (`<top_model>` on its second dispatch): `Your story: <file>. Stamp: <S>. Your last step is bash
  scripts/cycle.sh close-story <file> --commit --stamp <S>.` Then `advance --stamp <S>`. A story still
  listed is a miss; a second miss is handled as a `stop` with a `file`.
- `dispatch:<seats>`: one message, every seat, each told to write its report to
  `.vulyk/reports/<slug>/round-<round>/<seat>.attempt-<k>.md`, k from `status.seat_attempt`. `opus` or
  `haiku`: `council-<seat>` with `Council round <round> for <slug>, seat <seat>. COURT: <court>.
  Report: <path>.` and nothing more (never `round_dir`). `review`: `lead-review` as in solo; at Tier 4
  two dispatches, `model: <top_model>` writing `review-top.attempt-<k>.md` and `model: <second_model>`
  writing `review-second.attempt-<k>.md`, the second told to probe concurrency, security and migration
  safety. Then `advance --stamp <S> --ingest`. A seat still listed is re-dispatched once with its
  `rejected` error; one needing a third dispatch in a round stops the loop.

## Terminal

- `green`: print the round count and the newest `**Council:**` line; recommend `/vulyk-ship`.
- `escalated`: print plan.md's `## Needs a human` verbatim. The owner chooses: `bash
  scripts/human-check.sh docs/specs/<slug> ACCEPTED "<note>"`, `bash scripts/cycle.sh reopen
  docs/specs/<slug> "<decision>"`, or leaving it open.
- `paused`: stop; `/vulyk-resume <slug>` continues. `shipped`: nothing to build. `briefed`: point at
  `/vulyk-plan`.
- `close-story:<file>`: a story from before 0.18 still says `status: in-progress`. Set it to `todo`
  if its work is unfinished, or run `bash scripts/cycle.sh close-story <file> --commit` if it is done,
  then build again.
- `ok:false` from any verb: print `failed` and `error`, run `bash scripts/journal.sh docs/specs/<slug>
  03-building "<failed> exit <exit>" "<error>, stopped for a human"`, and stop.
