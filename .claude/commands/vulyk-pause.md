---
description: Pause the loop - creates the PAUSE semaphore so it stops at its next safe point and hands the tree back
argument-hint: <slug> ["why"]
---

Pause: "$ARGUMENTS" (the first token is the spec slug; anything after it is the reason).

1. `bash scripts/cycle.sh pause docs/specs/<slug> "<why>"` (without a reason it records "no reason
   given"). Print exactly what it prints: the `cycle: <slug> - paused: <why>` line and its JSON.
2. Tell the owner what this does to a loop already running. Every mutating `cycle.sh` verb checks
   `PAUSE` first and exits 3 without acting, so:
   - the Workflow driver stops at its next `advance`; the agent in flight finishes first;
   - a solo or agent loop in a session stops at its next `cycle.sh` call;
   - a worker's edits are already on disk; only its `close-story` waits for `/vulyk-resume`;
   - a seat or reviewer report in flight is not recorded while paused; after `/vulyk-resume` the loop
     dispatches that seat again.
3. Say plainly: the working tree of `vulyk/<slug>` is now the owner's to edit, inspect and commit on;
   nothing in the hive touches it again until `/vulyk-resume <slug>` clears the semaphore.
