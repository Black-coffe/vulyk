# ADR-026: Cross-platform code meets macOS CI before a council round, and before ship

- Status: proposed
- Date: 2026-10-29
- Spec: docs/specs/cross-platform (plan deltas of 2026-10-29)

## Context
The cross-platform build passed council round 2 GREEN and was then REJECTED by the owner on CI evidence: the first
macOS runs found product and test failures no seat had seen. Round 4 hit the ceiling for the same reason. Two plan
deltas record the ruling:

> 2026-10-29, after ESCALATE round 4 (ceiling): reopened by the owner, «Переоткрыть: только 3 падения Mac (Рекомендую)».
> Repair story 11's round-4 latency finding is ruled machine-load noise (no change); its task is the three macOS-only
> failures of probe 40871539881 (`mac-probe-round4.txt`). Order from here: build 11, then macOS CI on the branch, and only
> on a green macOS run the next council round - a round on code CI has not yet seen on macOS spends a round for nothing.

> 2026-10-29, after GREEN round 2: the owner REJECTED («Переоткрыть, довести Mac») on CI evidence - the first macOS runs
> (40787799947, probe 40857869190) show three causes in product code (`awk -v` with a newline, bash 3.2 `case` inside
> `$( )`, BSD `paste` operand) and a test hang (`full-suite.test.sh` `nopy_path` drops `/usr/bin`). Wave 5: stories 07
> (product), 08 (tests), 09 (gate rules + CI timeouts), disjoint files. Round 3 follows; the Queen re-runs macOS CI on the
> branch before any ship.

## Options
none recorded - the delta states the chosen shape only.

## Decision
On a spec whose goal includes running on macOS (or that touches shell code the macOS CI leg exercises), the order is:
build, then macOS CI on the branch, then - only on a green macOS run - the next council round. The Queen re-runs macOS
CI on the branch before any ship. Deciding factor, as recorded: a council round on code CI has not yet seen on macOS
spends a round for nothing (the local runner is Windows Git Bash; seats cannot observe BSD/bash 3.2 behaviour).

## Consequences
not recorded.

## Invariants created
- No council round opens on cross-platform shell work whose current commit has no green `macos-latest` CI run.
- No ship of such work without a green macOS CI run on the branch.

## Revisit when
not recorded.
