# Journal: ab-run-fixes

- 2026-11-08T21:14:02Z · 02-approved · approved by Andrei · next: branch
- 2026-11-08T21:16:34Z · 03-building · launching the hive · next: the loop holds the working tree of vulyk/ab-run-fixes; to edit, run /vulyk-pause ab-run-fixes
- 2026-11-08T21:16:45Z · 03-building · branch vulyk/ab-run-fixes created · next: build:1
- 2026-11-08T21:18:49Z · 03-building · hive stopped by owner: workers ran on sonnet; wave-1 partial edits reverted (patch kept in scratchpad), profile restored to opus-builds · next: relaunch the hive with worker opus
- 2026-11-08T21:18:50Z · 03-building · launching the hive · next: the loop holds the working tree of vulyk/ab-run-fixes; to edit, run /vulyk-pause ab-run-fixes
- 2026-11-08T22:40:23Z · 03-building · story 06 missed twice on the portability gate (3 hits in committed cycle.sh from 04/05); lead-architect ruled a repair (council/architect-06.md, ADR-031); repair story 07 added to wave 3, 06 back to todo blocked_by 07 · next: relaunch the hive: 07 then 06
- 2026-11-08T22:40:23Z · 03-building · launching the hive · next: the loop holds the working tree of vulyk/ab-run-fixes; to edit, run /vulyk-pause ab-run-fixes
- 2026-11-08T22:41:16Z · 03-building · driver refused at launch: Date.now() in vulyk-cycle.js (story 05 checkpoint), runtime forbids a clock read; repair story 08 added; hive continues without the Workflow driver · next: advance --claim, dispatch 07
- 2026-11-08T22:48:48Z · 03-building · 07, 06, 08 closed; 08 leaves the checkpoint off live (no now, no launched_at): story 09 added in wave 4 · next: build 09, then the round gate
- 2026-11-08T22:58:00Z · 03-building · 09 NEEDS_CONTEXT: now breaks whole-line asserts in council.test.sh; Queen added tests/council.test.sh to its Files (strip now before comparing) · next: 09's worker continues
- 2026-11-08T23:07:48Z · 04-council:open · round 1 opened, court at E:/Projects/vulyk/.vulyk/court/ab-run-fixes/round-1 · next: dispatch:opus,review
- 2026-11-08T23:39:57Z · 04-council:RED · round 1 verdict RED at c89d3bc pack d2df65182f50 · next: repair
- 2026-11-08T23:40:03Z · 03-building · repair round 1: ab-run-fixes-10-repair-round-1.md · next: build:5
- 2026-11-08T23:40:17Z · 03-building · round 1 RED (review BLOCK: stale red-part asserts, checkpoint now not top-level on advance/suite, defects INDEX stale; opus GREEN 22/22); repair 10 cut, Queen added tests/e2e.test.sh to its Files · next: build repair 10
