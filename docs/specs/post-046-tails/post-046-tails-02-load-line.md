---
story: post-046-tails-02
spec: post-046-tails
status: todo
returned:
tier: 2
worker: worker-code
wave: 2
blocked_by: [post-046-tails-01]
red: required
red_reason: a FAIL step writes LOAD lines into suite.log
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

## Findings
