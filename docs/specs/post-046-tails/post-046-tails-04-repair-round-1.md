---
story: post-046-tails-04
status: done
returned: DONE
worker: worker-code
model: opus
wave: 4
blocked_by: []
red: required
red_reason: WmiPrvSE and powershell are listed apart from the top five
red_verified_at: 2026-11-03T22:28:26Z ae8dafcad0ca76558d50f5b1b0b023440f2911482829674240c296bfbab49d9b
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 5. 11 частей разрезаны.

## Findings
1. docs/specs/post-046-tails/post-046-tails-03-split-parts.md:202-205 [ask 5] the four halves that stay over the story's 70 s idle line (constitution3 86 s, mods 74 s, mods2 72 s, wrapper2 99 s idle; 106/90/87/120 s under the gate's 12 jobs in council/round-1/suite.log, so a 3x load puts wrapper2 at ~360 s against the 300 s cap) must be cut once more as the story's own acceptance line says, or the plan's `## Descoped` must record that the owner's approved "40-65 s per half, the gate holds a 3x load" shrank to these four - today `## Descoped` is `*(empty)*` (plan.md:48-50) - repro: `grep -n '\*\*' docs/specs/post-046-tails/post-046-tails-03-split-parts.md`

## Files
- scripts/ship-check.sh
- .claude/commands/vulyk-ship.md
- .claude/commands/vulyk-build.md
- scripts/cycle.sh
- tests/cycle.test.sh
- scripts/lib.sh
- tests/council.test.sh
- tests/telemetry.test.sh

## Implementation notes
- Finding 1, by the owner's choice of the option «wrapper2 режем, 3 в Descoped» (2026-11-03): wrapper2 is cut again.
  `wrapper_hive` (the fixture part of `wrapper_case`, unchanged lines) builds a host-form hive; wrapper2 keeps the
  bash -c case, wrapper3 rebuilds that hive and runs the repair of its broken entries. ok: wrapper 11, wrapper2 11,
  wrapper3 7 = the old 25 + two syntax oks per extra part. Times: wrapper 57 s, wrapper2 57 s, wrapper3 91 s with
  four parts in parallel, 74 s alone (old wrapper2: 99 s with five in parallel). The rebuild costs one fresh hive
  and one upgrade (~36 s), so the gain on the longest part is modest and the gate pays ~36 s more in total.
  constitution3, mods, mods2 are recorded in plan.md `## Descoped`, taken into brief.md `## Answers` (7decc88).
- Added at the owner's request (two notes they forwarded mid-build): `load_sample` on Windows had its own
  processes at the head of the top five (WmiPrvSE 26% and 21% on a 1% box). PowerShell now prints raw
  `name<TAB>pct` rows (top 12); awk takes the five from the other names and lists `WmiPrvSE[#n]` and
  `powershell[#n]` after them, `; named like the sampler: ...`, so a real powershell or WMI load stays visible
  (the second note: a name filter alone would hide it). Tested with a stub powershell.exe (part bsd); the test
  first asserted the drop, was re-stamped for the listed-apart form (stamped impl restored, test changed,
  re-stamped, impl re-applied). Real run here: `cpu 2% top: msedgewebview2#25 117%, msedgewebview2#27 31%,
  dllhost#2 18%, bash#8 13%, Notepad 13%; named like the sampler: WmiPrvSE#3 18%`. Also fixed: `rc` took
  `tr`'s exit, not powershell's.
- Minor 3: the cycle.sh comment says `LOAD: start` reads the box during the step's first seconds.
- Minors 1-2 left as they are: a duplicated reason line in a receipt is harmless; story 01's receipt predates
  its own fix and is history.

## Verification
`bash tests/cycle.test.sh --part ship`
`bash tests/cycle.test.sh --part red`
`bash tests/cycle.test.sh --part bsd`
`bash tests/council.test.sh --part suite`
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part seats3`
`bash tests/council.test.sh --part judge`
`bash tests/council.test.sh --part judge2`
`bash tests/council.test.sh --part walks`
`bash tests/council.test.sh --part walks3`
`bash tests/council.test.sh --part replays`
`bash tests/council.test.sh --part replays3`
`bash tests/council.test.sh --part escalate`
`bash tests/council.test.sh --part escalate2`
`bash tests/telemetry.test.sh --part rg`
`bash tests/telemetry.test.sh --part rg2`
`bash tests/telemetry.test.sh --part crlf`
`bash tests/telemetry.test.sh --part crlf2`
`bash tests/telemetry.test.sh --part constitution`
`bash tests/telemetry.test.sh --part constitution3`
`bash tests/telemetry.test.sh --part mods`
`bash tests/telemetry.test.sh --part mods2`
`bash tests/telemetry.test.sh --part ysk`
`bash tests/telemetry.test.sh --part ysk2`
`bash tests/telemetry.test.sh --part ysk3`
`bash tests/telemetry.test.sh --part wrapper`
`bash tests/telemetry.test.sh --part wrapper2`
`bash tests/telemetry.test.sh --part wrapper3`

## Red receipt
- command: bash tests/cycle.test.sh --part bsd
- exit: 1
- tests: ae8dafcad0ca76558d50f5b1b0b023440f2911482829674240c296bfbab49d9b (tests/council.test.sh, tests/cycle.test.sh, tests/telemetry.test.sh)
- impl: 558852ca4f2f5e5fb262f4f829991f64d7b47949bc8075c1ce477fb22dba6913
- stamped: 2026-11-03T22:28:26Z

```
::error::WmiPrvSE and powershell are listed apart from the top five - exit=0 got: cpu	40
  ok    yes: bash -n deploy.sh
  ok    yes: the constitution's Python cell is bash scripts/py.sh -m py_compile .claude/hooks/*.py
  ok    CLAUDE.md stays under 7168 bytes
cross-platform: a BSD (macOS) awk refuses a newline inside a -v value; install.sh's block restore and reopen's insertion under it
  ok    the stub refuses a -v value holding a newline
  ok    a fresh install under BSD awk resets both blocks
  ok    the Browser MCP row keeps \| byte for byte
  ok    install.sh --upgrade under BSD awk restores both blocks, byte for byte as a fresh install writes them
  ok    reopen under BSD awk inserts the decision after ## Answers, \| byte for byte
  ok    the run_capped grandchild died with its process group (read 12 s after the start)
```
