---
description: Launch the build -> council -> repair loop - the Workflow driver when it is available, an in-session fallback otherwise - one commit per state change
argument-hint: [spec slug; defaults to the newest spec carrying **Briefed:** or **Approved:** with no branch yet]
---

Launch the loop for: "$ARGUMENTS" (default: the newest spec under `docs/specs/` that is briefed or
approved but has no `**Branch:**` line yet).

1. **Mode detection and launch.** This is the driver launch protocol every other command points at
   rather than repeating - `/vulyk-plan` step 10 says "launch as here"; `/vulyk-resume` says "the
   same launch as here". Resolve `top_model="$(bash scripts/top-model.sh)"` (the alias the session
   brief announced; re-run only if it scrolled away) and `stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"`.
   Detect the driver the same way `/vulyk-status` does: `Workflow` present in this session's own
   tool list -> Workflow driver; otherwise the fallback loop. Print which one - `driver: workflow`
   or `driver: fallback` - then, before touching anything else, print and journal the one line that
   tells the human the tree is not theirs right now:
   ```
   bash scripts/journal.sh docs/specs/<slug> 03-building "launching the <workflow|fallback> driver" \
     "the loop holds the working tree of vulyk/<slug>; to edit, run /vulyk-pause <slug>"
   ```
   Echo exactly what it prints - that one line - and nothing else.
   - **Workflow driver:** call the `Workflow` tool named `vulyk-cycle` with
     `args: {spec: "docs/specs/<slug>", top_model, stamp}` (C11). It drives build -> round -> judge
     -> repair through `cycle-clerk` and the worker/council/`lead-review`/`queen-planner` agents on
     its own to one of the terminal `next` values (`green`, `escalated`, `paused`, `shipped`). Do
     nothing else in this session while it runs. When it returns - in this session or a fresh one
     that resumes here - do the **wake-up** step (4) instead of reading anything it printed along
     the way; the transcript is not the record, the disk is.
   - **Fallback driver** (`Workflow` absent from the tool list): continue with step 2, in this same
     session, using your own Bash for every `cycle.sh` verb and the Agent tool for every worker,
     seat, `lead-review` and `queen-planner` dispatch the Workflow would otherwise make.

2. **The fallback loop.** Repeat until a terminal `next`:
   1. Read `bash scripts/cycle.sh status docs/specs/<slug> --json` and take its `next` field (C3).
      This single field is the entire interface - never read a seat report, a story's
      `## Implementation notes` or a round count to decide what happens next; `cycle.sh` has
      already read everything relevant and named the one thing left to do.
   2. Act on exactly that value, one action, nothing more:

   | `next` | Action |
   |---|---|
   | `briefed` | Refuse: the spec is neither `**Briefed:**` nor `**Approved:**`. Point at `/vulyk-plan`. Stop. |
   | `branch` | `bash scripts/cycle.sh branch docs/specs/<slug> --commit`. |
   | `build:<wave>` | `bash scripts/wave-check.sh docs/specs/<slug>` first - a collision here is a plan defect, fix the story files before dispatching anything. Then dispatch every entry of the status object's `wave_stories` - each already `{"file","story","worker","repeat"}` (C3, plan delta 2 - the driver never opens a story file to learn its worker) - to the named `worker` (`worker-code`/`worker-test`), one message, cap 4 concurrent, each worker getting exactly its story file, its map slice pointer and the relevant `.claude/rules/` paths. As each returns: `STATUS: DONE` -> `bash scripts/cycle.sh close-story <story-file> --commit` (it repeats `## Verification` the entry's own `repeat` times and reports red/green, C2). A red verification (`close-story` exit 4) or `NEEDS_CONTEXT`/`WALL` -> one fresh worker, the failure stated as a condition to satisfy, then `close-story` again. Second failure on the same story -> mark it `blocked`, escalate the design question to `lead-architect`, move on to the rest of the wave; a third identical attempt is a token bonfire. |
   | `close-story:<file>` | `bash scripts/cycle.sh close-story <file> --commit` - a story whose worker already returned but was never closed (typically after a resume). |
   | `open-round` | `bash scripts/cycle.sh open-round docs/specs/<slug> --commit`. |
   | `dispatch:<seats>` | Read `court`, `round` and `round_dir` off this same `status --json` - a seat's entire input (C11); it reads `brief.md` and the Profile from the court itself, nothing is attached. One message, every named seat: `haiku`/`sonnet`/`opus` -> `council-<seat>` working in `court`; `review` -> `lead-review` at `top_model`, in the main tree, never the court (Tier 4: plus a second reviewer on the paired model, its `BLOCK`/`PASS` folded into `lead-review`'s per `/vulyk-review`'s rule - the stricter of the two). Record each report: `bash scripts/cycle.sh record-seat docs/specs/<slug> <N> <seat> [--model <id>] <<'EOF' ... EOF`. Exit 4 -> re-ask that one seat once, naming the `error` field verbatim in the re-ask; record again either way and move on. |
   | `judge` | `bash scripts/cycle.sh judge docs/specs/<slug> --commit`. |
   | `repair` | Dispatch `queen-planner` at `top_model` with the newest round's RED asks and any `review` `BLOCK` findings; it cuts fix stories into the plan - never write them yourself. Then `bash scripts/wave-check.sh docs/specs/<slug>` again: a repair round changes the pack, and a check that judged a different set of stories is not a check. |
   | `green` / `escalated` / `paused` | Stop - go to step 3. |
   | `shipped` | Stop: this spec already shipped, nothing to build. |

   3. After the action, print exactly one line and nothing else - not the raw `cycle.sh` stdout,
      not its JSON object, not tool chatter: if the verb just run appended a new line to
      `<spec-dir>/journal.md` (every verb here does except `record-seat`, which does not journal
      per seat), print that new last line; for `record-seat`, print its own one-line `cycle: ...`
      confirmation instead. Either way, one line. This is the entire visible log - a human watching
      only the terminal must be able to follow the loop by it alone.
   4. Repeat from 2.1.

3. **Stop conditions** (both drivers land here - the Workflow driver via step 4 below):
   - **`green`** - print how many rounds it took (the `round` field of the `status --json` that
     produced `green`), the newest `**Council:**` line (`grep '^\*\*Council:\*\*' docs/specs/<slug>/plan.md | tail -1`),
     and the next-circle material already on disk: each seat file's `UNASKED:` line from that round
     (skip "none"). Recommend `/vulyk-ship`; note that `/vulyk-review` still runs another round on
     demand first if the owner wants one.
   - **`escalated`** - print `## Needs a human` from `plan.md` verbatim. The owner has three exits:
     `human-check.sh ACCEPTED` (ship over the council), `cycle.sh reopen "<decision>"` (three more
     rounds), or leaving the spec open. Do not choose for them.
   - **`paused`** - print that the loop is paused and holds nothing further; `/vulyk-resume <slug>`
     restarts it, running `/vulyk-pause` again is a no-op.

4. **Wake-up after a Workflow run.** Never read the transcript. Read `journal.md`'s tail (the lines
   since this launch) and the newest round's seat files under
   `docs/specs/<slug>/council/round-N/*.md`, then print exactly the stop-condition report of step 3
   for whichever terminal state the run reached.
