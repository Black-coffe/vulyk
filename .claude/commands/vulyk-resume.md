---
description: Clear the PAUSE semaphore and relaunch the build fresh - never resumeFromRunId
argument-hint: <slug>
---

Resume: "$ARGUMENTS" (the spec slug).

1. `bash scripts/cycle.sh resume docs/specs/<slug>`. Print exactly what it prints: the
   `cycle: <slug> - resumed` line and its JSON, which carries `stale` and `held` fields.
   `held` non-empty means a driver claim is still on disk; resume never removes it. Look at your task list
   (`/tasks`, the Workflow run): a run still going is finishing its agent in flight, so wait for its
   notification before step 3. Only a run that is gone (session restarted, run ended without releasing) is
   dead: then run the `release` command resume printed. A second driver over a live one's worker
   overwrites its files. A run that had not reached its next step when you resumed never saw the pause:
   it simply goes on building, so skip step 3 and wait for its notification.
2. If `stale: true`, the tree moved (a manual commit) while the loop was paused: the open round, if any,
   is stale, and the next round `advance` opens re-reviews the new diff. The tier's ceiling still counts
   it.
3. Relaunch with `/vulyk-build <slug>`, always a fresh run: the solo path at Tier 1-2, the hive path at
   Tier 3-4. On the hive path, once the stamp is resolved, run `bash scripts/telemetry.sh record
   driver_relaunched 1 0 --spec <slug> --ref relaunch:<slug>:$stamp` before the launch. Never pass
   `resumeFromRunId` or any equivalent: a cached status replayed after the owner touched the tree is
   exactly the wrong answer. `advance` re-derives everything from disk, so a story already done or a
   seat already recorded is never dispatched again.
