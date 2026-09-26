---
description: Clear the PAUSE semaphore and relaunch the build fresh - never resumeFromRunId
argument-hint: <slug>
---

Resume: "$ARGUMENTS" (the spec slug).

1. `bash scripts/cycle.sh resume docs/specs/<slug>`. Print exactly what it prints: the
   `cycle: <slug> - resumed` line and its JSON, which carries a `stale` field.
2. If `stale: true`, the tree moved (a manual commit) while the loop was paused: the open round, if any,
   is stale, and the next round `advance` opens re-reviews the new diff. The tier's ceiling still counts
   it.
3. Relaunch with `/vulyk-build <slug>`, always a fresh run: the solo path at Tier 1-2, the hive path at
   Tier 3-4. On the hive path, once the stamp is resolved, run `bash scripts/telemetry.sh record
   driver_relaunched 1 0 --spec <slug> --ref relaunch:<slug>:$stamp` before the launch. Never pass
   `resumeFromRunId` or any equivalent: a cached status replayed after the owner touched the tree is
   exactly the wrong answer. `advance` re-derives everything from disk, so a story already done or a
   seat already recorded is never dispatched again.
