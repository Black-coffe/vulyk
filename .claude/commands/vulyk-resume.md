---
description: Clear the PAUSE semaphore and relaunch the driver fresh - never resumeFromRunId
argument-hint: <slug>
---

Resume: "$ARGUMENTS" (the spec slug).

1. `bash scripts/cycle.sh resume docs/specs/<slug>`. Print exactly what it prints: the
   `cycle: <slug> - resumed` line and its JSON, nothing added. That JSON carries a `stale` field.
2. If `stale: true` - the tree moved (a manual commit) while the loop was paused - say so plainly:
   the open round (if any) is now stale by the same rule a hand-edit stales the owner's check, and
   the next `open-round` the relaunched driver runs will open a fresh one; the ceiling still counts
   it.
3. **Relaunch.** This is always a fresh run: perform the exact same launch `/vulyk-build` step 1
   describes - mode detection, `top_model`/`stamp` resolution, the "loop holds the working tree"
   line, then either the `Workflow` call or the fallback loop. Once `$stamp` is resolved, record
   `bash scripts/telemetry.sh record driver_relaunched 1 0 --spec <slug> --ref
   relaunch:<slug>:$stamp` (quiet one-liner, no output) before continuing the launch. Never pass
   `resumeFromRunId` or any
   equivalent - a cached `status` replayed after a human touched the tree is exactly the wrong
   answer (ADR-001 D2, "Resume is the disk, not the run"). A fresh launch costs one `cycle-clerk`
   call per already-closed step; it never re-dispatches a seat or a worker whose file already
   exists.
