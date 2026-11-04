---
story: post-046-tails-02
spec: post-046-tails
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 2
blocked_by: [post-046-tails-01]
red: required
red_reason: a FAIL step writes LOAD lines into suite.log
red_verified_at: 2026-11-03T17:25:15Z 67adbd2fc6e8ae9cd97dff833beae1ecc4a0af0724323015b64244045f8b5269
---

# The gate survives a loaded box and names the load

## Goal
`cycle:bsd`'s run_capped case stops timing a 3 s window: the child sleeps long enough (for example a 10 s
grandchild and a 20 s parent) that the assertion `el < 10` plus "no late output" and "no marker" proves the cap
killed the group, with a 3x slowdown still well inside it. `cycle.sh suite` samples the box at the start and
the end of each step and, only when the step is FAIL, appends under its PART line(s):
`LOAD: start|end cpu <N>% top: <name> <pct>%, ...` (five processes, the suite's own included, so the reader
sees both). Sampler: a function in `scripts/lib.sh`; Windows (Git Bash, `powershell.exe` on PATH) through
CIM `Win32_PerfFormattedData_PerfProc_Process` (not localized) and `Win32_Processor.LoadPercentage`; else
`ps -A -o pcpu= -o comm=` and `uptime`. Any failure or a sampler running past 10 s writes `LOAD: unavailable -
<why>` and never changes the step's verdict. A test seam (an env var naming a stub sampler) keeps the test
off the real box.

## Requirements
> - Descoped post-045-tails-04: гейт раунда 1 был красным только из-за нагрузки, вы приняли раунд (ACCEPTED, 2026-11-03). Проверка «3 с» в bsd, дробление 11 частей за 70 % и причина замедления машины переходят в следующий круг.
> 4. проверка «3 с» в bsd выдерживает нагрузку.
> 6. suite.log пишет нагрузку машины.

## Files
- tests/cycle.test.sh
- scripts/cycle.sh
- scripts/lib.sh
- tests/council.test.sh

## Non-goals
- No load gate: a loaded box never refuses or re-runs a step by itself; the line is evidence for the reader.
- No LOAD line under an ok step; no change to PART/STEP/SUITE line formats, `suite-parts-check.sh` or `judge`.
- Do not split any part here (story 03).

## Map slice
memory/map/cycle.md: `suite` verb, full-suite line; memory/map/scripts.md: `lib.sh` run_capped

## Acceptance criteria
- [ ] With a stub sampler, a FAIL step's suite.log has `LOAD: start` and `LOAD: end` lines after its PART line; an ok step has none.
- [ ] A sampler that exits non-zero gives `LOAD: unavailable - ...` and the step verdict is unchanged.
- [ ] `suite-parts-check.sh` and `suite_verdict` read a log with LOAD lines exactly as without them.
- [ ] bsd run_capped case passes on this box and has no assertion on a window under 10 s.
- [ ] The real sampler, run once by hand on this Windows box, prints a cpu figure and five names (noted under Implementation notes).

## Verification
`bash tests/cycle.test.sh --part bsd`
`bash tests/council.test.sh --part suite`

## Implementation notes
- bsd: the run_capped case is a 10 s grandchild and a 20 s parent under a 1 s cap, `el < 10`; the marker is read
  at the end of part bsd, 12 s after the start, so the wait is spent on the cases between (part still 74 s here).
- `lib.sh` `load_sample`: Windows (MINGW/MSYS/CYGWIN + powershell.exe) through CIM `Win32_Processor.LoadPercentage`
  and `Win32_PerfFormattedData_PerfProc_Process`; else `ps -A -o pcpu= -o comm=`, cpu = sum / cores, plus
  `uptime`'s load. Per-process percent is of one core on both (can pass 100); Linux `pcpu` is a lifetime average.
- `cycle.sh` `suite_load <start|end> [cap]`: the sampler under run_capped (10 s), or `VULYK_LOAD_SAMPLER` (the seam,
  exported once at the top of council.test.sh so no test call touches the box); any failure prints
  `LOAD: unavailable - <when>: <why>` and returns 0.
- `cmd_suite`: the start sample runs in the background while the step runs (the real sampler takes 2-5 s here:
  powershell startup), the end sample only for a FAIL step, capped to what is left of the 600 s call
  (`580 - SECONDS`, at most 10; none under 2 s - a stepped step killed at 590 s gets `end: no time left`).
  Rejected: two synchronous samples per step (+5-10 s of wall time per green step for nothing).
- Real sampler run by hand on this Windows box: `cpu 4% top: WmiPrvSE#3 17%, claude#15 13%, node#49 8%, System 8%,
  WmiPrvSE 4%` (2.2 s). Linux branch under WSL: `cpu 33% top: journalctl 74.6%, systemd 15.3%, bash 11.7%,
  systemd 11.1%, systemd-journal 4.1%; load 0.96, 0.93, 0.97`. Git Bash's own ps has no `-o`: that path prints
  `ps -A printed no process` (only reached on a Windows box without powershell.exe). macOS not run.

## Findings

## Red receipt
- command: bash tests/council.test.sh --part suite
- exit: 1
- tests: 67adbd2fc6e8ae9cd97dff833beae1ecc4a0af0724323015b64244045f8b5269 (tests/council.test.sh, tests/cycle.test.sh)
- impl: 2c431dd6fea7afef62dfa3f4086851c9ca460e7e6e47b9ac6a9e81ccb067da92
- stamped: 2026-11-03T17:25:15Z

```
::error::a FAIL step writes LOAD lines into suite.log - expected LOAD: start/end after PART fx:b2 only: head=d6a57e2 steps=2
  ok    sole row '| Full suite (round-only) |  |' -> STEP FAIL, a PART line names the row, SUITE: FAIL
  ok    sole row '| Full suite (round-only) |' -> STEP FAIL, a PART line names the row, SUITE: FAIL
  ok    unit=true + e2e empty -> steps 2, the e2e row is named FAIL, SUITE: FAIL
suite: a step beyond the row count fails, two rows with one Purpose get distinct PART names (gate-split-10 finding 3)
  ok    two rows named 'Full suite (round-only)' -> PART full-suite-round-only-1 and PART full-suite-round-only-2, the verdict names the failed one
  ok    step 3 of a log over 2 rows -> STEP 3/3 FAIL, PART step-3-no-row, SUITE: FAIL
suite: a stepped step killed at its call cap names the parts that never ended, in the STEP note and the SUITE line (post-045-tails ask 5)
  ok    the hung part is named in the STEP note and the SUITE line, the ended one is not
suite: no round-only full-suite row -> SUITE: none, done at once
  ok    no row -> SUITE: none, steps 0, done
```
