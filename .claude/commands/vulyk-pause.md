---
description: Pause the loop - creates the PAUSE semaphore so it stops at its next safe point and hands the tree back
argument-hint: <slug> ["why"]
---

Pause: "$ARGUMENTS" (first token is the spec slug; anything after it is the reason, quoted or not).

1. `bash scripts/cycle.sh pause docs/specs/<slug> "<why>"` (omit the third argument and it records
   "no reason given" - still a pause, just an unexplained one). Print exactly what it prints: the
   `cycle: <slug> - paused: <why>` line and its JSON, nothing added.
2. Tell the human what this does to a driver already running:
   - **Workflow driver:** the running loop stops at its next `cycle-clerk` call. An agent already
     in flight when you pause - a worker, a council seat, `lead-review` - finishes and its result is
     recorded once you resume; nothing after that call runs until `/vulyk-resume`.
   - **Fallback driver** (this session): the loop's next `status --json` read will see `PAUSE` and
     stop before its next action - every mutating `cycle.sh` verb checks `PAUSE` first and exits 3
     rather than acting.
3. Say plainly: **the working tree of `vulyk/<slug>` is now the human's** - edit it, inspect it,
   commit on it if needed; nothing in the hive touches it again until `/vulyk-resume <slug>` clears
   the semaphore.
