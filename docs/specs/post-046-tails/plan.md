# Tails after 0.46.0 (plan)

**Tier:** 2 · **Spec slug:** `post-046-tails` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-029 (gate split, 300 s part cap, the 70% rule), ADR-023 (one full suite per round), ADR-026 (CI before ship)
**Depends on:** post-045-tails, shipped as v0.46.0 (tag on 3ed325c)

## Goal
Close the reviewer's notes and the descoped repair of post-045-tails. ship-check's `ci` line judges the newest
run of each workflow on a commit, so a green re-dispatch clears an old red run, and /vulyk-ship says what to do
with a red one; vulyk-build.md stops claiming ship never pushes. A red receipt shows the line that carries
`red_reason`, not just the last ten lines. The gate survives a loaded box: the bsd wall check stops timing a
3 s window, the 11 parts that crossed 70% under load are cut in half, and a red step writes the box's load into
suite.log so the next slowdown names its cause.

## Assumptions
- Measured 2026-11-03 on 0.46.0 (HEAD 500ff05), idle box, one part at a time: `council:seats` 83 s (80 s in
  gate-split round 4, 0.45, 12 jobs), `cycle:bsd` 75 s (75 s). The code did not slow down; the red round ran on a
  box 2-3x slower. Not measured: the whole gate at 12 jobs on this head - the round gate of this spec does that.
- "Newest" = latest `createdAt` per `workflowName` on the commit, picked in shell (sort + awk), not in `--jq`, so
  the fake gh of `cycle.test.sh --part ship` keeps printing plain rows. Rejected: keying by workflow + event (a
  `workflow_dispatch` re-run would then never clear a red `push` run, which is the reviewer's case).
- The weekly-budget-10 story (branch `vulyk/weekly-budget`) is rewritten to `--part <topic>` at that branch's
  rebase, not here: the right part depends on where its tests land after the rebase, and `wave-check.sh` refuses
  the bare `bash tests/cycle.test.sh` cell, so it cannot slip through.
- `memory/map/cycle.md` already says `VULYK_SUITE_TIMEOUT` is read nowhere (line 64); nothing to do.
- `defects-check.sh <dir>` stays red, as on the base (portability-check refuses a directory too); `<arg>` is a
  file. No change.
- A split keeps every old part name (its first half) and adds one new name per part, so done stories that name
  `--part seats` and the like still run.
- LOAD line: sampled at the start and the end of each step, written only under a FAIL step. Windows reads
  `Win32_PerfFormattedData_PerfProc_Process` through CIM (counter names there are not localized); macOS/Linux
  read `ps -A -o pcpu= -o comm=`. A sampler that fails writes `LOAD: unavailable - <why>`, never fails the step.

## Stories

**Wave 1**
- `post-046-tails-01-ship-receipt` — ci: newest run per workflow; /vulyk-ship red-run line; vulyk-build.md push line; red receipt carries the red_reason line (asks 1-3)

**Wave 2**
- `post-046-tails-02-load-line` — bsd wall check off the 3 s window; a red step's LOAD lines in suite.log (asks 4, 6)

**Wave 3**
- `post-046-tails-03-split-parts` — cut council seats/judge/walks/replays/escalate and telemetry rg/crlf/constitution/mods/ysk/wrapper in half (ask 5)

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

- post-046-tails-03, ask 5: telemetry parts constitution3, mods and mods2 stay over the 70 s idle line (86, 74, 72 s idle; 106, 90, 87 s in the round-1 gate). Each is one chain of install.sh runs (20-27 s each) on one hive, and a further cut rebuilds that hive with the same runs. wrapper2, the one projected past the 300 s cap under a 3x load, is cut again in repair round 1 (wrapper2 + wrapper3). The owner chose the option «wrapper2 режем, 3 в Descoped» on 2026-11-03; a faster install.sh goes to the next circle.

## Plan deltas

**Approved:** Andrei, 2026-11-03
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path (--go, Tier 1): "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"). Alternative to **Approved:** above.>
**Branch:** vulyk/post-046-tails
**Council:** RED round 1, 2026-11-03, at 5614844, pack 362e08dea806
**Checked:** ACCEPTED by Andrei, 2026-11-04, at 250f77f - owner chose option 1 (ACCEPTED, narrow fix) in chat on 2026-11-04 after the repair-round-1 diff was shown in the reply; repair 250f77f + descope 7decc88
**Shipped:** 0.47.0, 2026-11-04, at c548324 - merged to main; owner accepted round 1 (human-check ACCEPTED 2026-11-04); push, tag and release run by the Queen per the owner's rule
