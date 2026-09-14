---
description: Launch the build -> council -> repair loop - the Workflow driver when it is available, an in-session fallback otherwise - one commit per state change
argument-hint: [spec slug; defaults to the newest spec carrying **Briefed:** or **Approved:** with no branch yet] [--fallback]
---

Launch the loop for: "$ARGUMENTS" (strip `--fallback` first; what remains is the slug - default:
the newest spec under `docs/specs/` that is briefed or approved but has no `**Branch:**` line yet).

1. **Mode detection and launch.** This is the driver launch protocol every other command points at
   rather than repeating - `/vulyk-plan` step 10 says "launch as here"; `/vulyk-resume` says "the
   same launch as here". Resolve `top_model="$(bash scripts/top-model.sh)"` (the alias the session
   brief announced; re-run only if it scrolled away); `second_model` - `opus` beside a Fable
   `top_model`, `sonnet` beside an Opus one, unless the spec's own Tier 4 sentence in `plan.md`
   names another (the same pairing `/vulyk-review` step 3 uses for its second reviewer); and
   `stamp="$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')"` (16 hex characters, never `date`), taken
   once, here, before either branch below - both drivers use this one random value for the whole
   run, and it never appears in a seat prompt: it is a per-run value the seat is never told, not a
   secret a report is expected to guess (R31). Detect the driver the same way
   `/vulyk-status` does: `Workflow` present in this session's own tool list -> Workflow driver;
   otherwise the fallback loop. **The fallback loop runs every step inside this pinned top-model
   session - the most expensive path in `docs/token-economy.md` - so it needs `--fallback` in
   "$ARGUMENTS": without it, stop here and say so in one sentence (enable the Workflow tool, or
   relaunch with `--fallback`).** Print which one - `driver: workflow` or `driver: fallback` - then,
   before touching anything else, print and journal the one line that tells the human the tree is
   not theirs right now:
   ```
   bash scripts/journal.sh docs/specs/<slug> 03-building "launching the <workflow|fallback> driver" \
     "the loop holds the working tree of vulyk/<slug>; to edit, run /vulyk-pause <slug>"
   ```
   Echo exactly what it prints - that one line - and nothing else. Then claim the DRIVER
   semaphore before either branch touches anything else (ADR-004/K3):
   `bash scripts/cycle.sh claim docs/specs/<slug> $stamp`. Its last line is JSON like every
   other verb; `"ok":false` (`held by <stamp>`) means another driver holds this spec - print
   its `error` verbatim and stop here, before dispatching the Workflow tool or entering the
   fallback loop. Never retry the claim.
   - **Workflow driver:** call the `Workflow` tool named `vulyk-cycle` with
     `args: {spec: "docs/specs/<slug>", top_model, second_model, stamp}` (C11). It drives
     build -> round -> judge -> repair through `cycle-clerk` and the worker/council/`lead-review`/
     `queen-planner` agents on its own to one of the terminal `next` values (`green`, `escalated`,
     `paused`, `shipped`). Do nothing else in this session while it runs. When it returns - in this
     session or a fresh one that resumes here - do the **wake-up** step (4) instead of reading
     anything it printed along the way; the transcript is not the record, the disk is.
   - **Fallback driver** (`Workflow` absent from the tool list): continue with step 2, in this same
     session, using your own Bash for every `cycle.sh` verb and the Agent tool for every worker,
     seat, `lead-review` and `queen-planner` dispatch the Workflow would otherwise make.

2. **The fallback loop.** Repeat until a terminal `next`:
   1. Read `bash scripts/cycle.sh status docs/specs/<slug> --json` and take its `next` field (C3).
      This single field is the entire interface - never read a seat report, a story's
      `## Implementation notes` or a round count to decide what happens next; `cycle.sh` has
      already read everything relevant and named the one thing left to do.
   2. Act on exactly that value, one action, nothing more, from the table below. **Any verb's last
      line whose JSON object says `"ok":false` stops the loop**: print its `error` field, run
      `bash scripts/cycle.sh release docs/specs/<slug> $stamp` (every exit of this loop releases
      the semaphore claimed in step 1 - a held-by refusal on a gated verb is one such exit, same as
      a terminal `next`), and - since no `cycle.sh` failure path writes to `journal.md` on its own
      (`open-round`'s ceiling exit 6 is the one exception: it now records its own ESCALATE row,
      `**Council:**` line, `## Needs a human` and journal line before exiting, per R5) - journal the
      stop yourself first: `bash scripts/journal.sh docs/specs/<slug> 03-building "<verb> exit <n>"
      "<error>, stopped for a human"`. Exactly two cases read `error` and continue instead of
      stopping, both spelled out in the rows below: `record-seat` exit 4, and `close-story` exit 4
      on a story's first miss.

   | `next` | Action |
   |---|---|
   | `briefed` | Refuse: the spec is neither `**Briefed:**` nor `**Approved:**`. Point at `/vulyk-plan`. Release the semaphore, stop. |
   | `branch` | `bash scripts/cycle.sh branch docs/specs/<slug> --commit`. |
   | `build:<wave>` | `bash scripts/wave-check.sh docs/specs/<slug>` first - a collision here is a plan defect, fix the story files before dispatching anything. Then dispatch every entry of the status object's `wave_stories` - each already `{"file","story","worker","model","repeat"}` (C3 - the driver never opens a story file to learn its worker or model) - to the named `worker` (`worker-code`/`worker-test`) with `model: <model>` on the first dispatch and `model: opus` on a story's second dispatch (ADR-007: the senior takes the retry), one message, cap 4 concurrent, each worker getting exactly its story file, its map slice pointer and the relevant `.claude/rules/` paths. A worker that returns nothing at all - an empty final message, an abort, a timeout - is a miss under the same two-attempt bound as a red verification, and `close-story` is not run on it (R29). Run `close-story` on every *non-empty* return - `bash scripts/cycle.sh close-story <story-file> --commit --stamp $stamp` (it repeats `## Verification` the entry's own `repeat` times, C2); exit 4 is a miss whatever its `error` says (a red verification, `returned` not `DONE`, or `returned: missing`) - reading `STATUS:` by eye is allowed only for the one-line log, never for this decision. **First** miss on a story - a `close-story` exit 4, or an empty report, in any order - dispatch one fresh worker with the failure stated as a condition to satisfy (an empty report: state plainly that the previous attempt returned nothing), then `close-story` again once it answers exit 0; the story stays `todo`/`in-progress` for the next `status` either way, and the rest of the wave is untouched. **Second** miss on the *same* story, any mix of the two kinds - edit its `status:` to `blocked`, append a `## Findings` line naming the miss (the `error`, the worker's own `## Findings`, or "worker returned no report"), dispatch `lead-architect` with the story file and both failures, journal the stop (`03-building`, "story blocked" / the error), release the semaphore, and **end the loop entirely** - never `open-round` on a wave carrying a blocked story. |
   | `close-story:<file>` | `bash scripts/cycle.sh close-story <file> --commit --stamp $stamp` - a story whose worker already returned but was never closed (typically after a resume). |
   | `open-round` | `bash scripts/cycle.sh open-round docs/specs/<slug> --commit --stamp $stamp`. |
   | `dispatch:<seats>` | Read `court` and `round` off this same `status --json` - a blind seat's *entire* input (C11): `slug`, `round` and `court`, **never `round_dir`** - a seat that echoes its own input back is tainted on the spot (R9). `round_dir` goes to `lead-review` alone, alongside its packet. One message, every named seat: `haiku`/`sonnet`/`opus` -> `council-<seat>` working in `court`; `review` -> `lead-review` at `top_model`, in the main tree, never the court (Tier 4: plus a second reviewer at `second_model`, its `BLOCK`/`PASS` folded into `lead-review`'s per `/vulyk-review`'s rule - the stricter of the two). The report travels as free text inside the clerk's prompt; record it through the heredoc delimiter `VULYK_<stamp>_<seat>_<attempt>` - a per-run random value the seat is never told, which is what keeps the body from ending the heredoc early (R31): `bash scripts/cycle.sh record-seat docs/specs/<slug> <N> <seat> --stamp $stamp [--model <id>] <<'VULYK_<stamp>_<seat>_<attempt>'` ... `VULYK_<stamp>_<seat>_<attempt>` (never `EOF`; an empty report is still piped through unchanged, so the attempt exists on disk). Exit 4 -> re-ask that one seat once, naming the `error` field verbatim in the re-ask, with `<attempt>` now `2` in the next delimiter; record again either way and move on - a seat MALFORMED on both attempts is `ABSENT` on disk and `judge` accounts for it (R3). |
   | `judge` | `bash scripts/cycle.sh judge docs/specs/<slug> --commit --stamp $stamp`. |
   | `repair` | Once per round number: dispatch `queen-planner` at `top_model` with `red` and `review` read off this same `status --json` (C3); when `red` is empty, the prompt says plainly that the RED is the review seat's `BLOCK` (or an owner `REJECTED`), points at `<round_dir>/review.md`, and asks for one story per critical and per major finding whose fix is local - never phrased as addressing asks that are not there. It cuts fix stories into the plan - never write them yourself. Then `bash scripts/wave-check.sh docs/specs/<slug>` again: a repair round changes the pack, and a check that judged a different set of stories is not a check. If the next `status` still says `repair` for this same round (the planner cut no story, nothing landed), stop: print `repair landed nothing for round <N>` and the journal tail; do not dispatch `queen-planner` a second time for the same round (R30). |
   | `green` / `escalated` / `paused` | Stop - go to step 3. |
   | `shipped` | Release the semaphore, stop: this spec already shipped, nothing to build. |

   3. After the action, print exactly one line and nothing else - not the raw `cycle.sh` stdout,
      not its JSON object, not tool chatter: if the verb just run appended a new line to
      `<spec-dir>/journal.md` (every verb here does except `record-seat`, which does not journal
      per seat), print that new last line; for `record-seat`, print its own one-line `cycle: ...`
      confirmation instead. Either way, one line. This is the entire visible log - a human watching
      only the terminal must be able to follow the loop by it alone.
   4. Repeat from 2.1.

3. **Stop conditions** (both drivers land here - the Workflow driver via step 4 below). In the
   fallback loop, every one of these three also runs `bash scripts/cycle.sh release
   docs/specs/<slug> $stamp` (harmless, exit 0, if `pause` already removed the file - not the
   mechanism there, just a no-op) before printing its report:
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

4. **Wake-up after a Workflow run.** Never read the transcript - the returned object and the disk
   are the record.
   - **The returned object carries `stop`** (`{verb, file, error}`, C11): the driver ended the run
     early, exactly as the fallback loop's own stop rule does. Print `stop.error`. A `stop` that
     carries `file` - `stop.verb` is `close-story` (a second red verification) or `build` (a second
     miss, red or an empty worker report, R29) - applies the fallback's `build:<wave>` rule above
     regardless of which: edit that story's `status:` to `blocked`, append the error to its
     `## Findings`, dispatch `lead-architect` with the story file and both failures, then stop.
     `stop.verb` `repair` (R30: `repair` landed nothing twice for the same round) or `launch` (step 1
     passed no `stamp` - fix the launch, never relaunch blindly to retry it) carries no `file`: print
     `journal.md`'s tail (the lines since this launch) and stop. `stop.verb` `claim` (K3): another
     driver holds this spec; if it is dead, run the release command the error names - never claim or
     relaunch on your own guess that it is stale. Any other `stop` also prints `journal.md`'s tail and
     stops, as story 23 left it.
   - **No `stop` field** (the run reached one of the four terminal `next` values): read
     `journal.md`'s tail and the newest round's seat files under
     `docs/specs/<slug>/council/round-N/*.md`, then print exactly the stop-condition report of
     step 3 for whichever terminal state the run reached; `escalated` still prints `## Needs a
     human` from `plan.md` verbatim - `open-round` at the ceiling now writes it directly, the same
     as `judge`'s own ESCALATE (R5), so this reads the same either way.
