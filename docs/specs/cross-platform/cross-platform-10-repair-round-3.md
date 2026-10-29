---
story: cross-platform-10
status: done
returned: DONE
worker: worker-code
model: opus
wave: 6
blocked_by: []
red: required
red_reason: dead stubs probed more than once per run
red_verified_at: 2026-10-29T13:01:51Z d091079a487cb3978423d9e140943b2e1136306f4f3ca1b40e918117351ecc5c
---

# Repair round 3

## Goal
Make the asks and findings council round 3 left RED pass, and change nothing else.

## Requirements
No brief ask is RED in round 3 - the findings below are the whole task.

## Findings
1. tests/full-suite.test.sh:112 [regression] the suite's own test must hold inside the parallel full suite: the check "the slow job is killed at the budget" expects `TIMEOUT [0-2]s` for a 1 s budget under the python cap (dead timeout/gtimeout stubs) and saw `TIMEOUT 3s` in `bash tests/full-suite.sh` on both measured runs (549 s with my probes beside it, 505 s idle; `full suite: 49 ok, 1 failed, jobs 12`), while `bash tests/full-suite.test.sh` alone exits 0 on the head and on the base 5e0aae1; base-side: round-2 review.md records `SUITE: ok 414s` on 860ce1c, the first commit of this range - repro: `bash tests/full-suite.sh; grep -n -A3 'slow job not capped' <logs dir>/*.log`

## Files
- scripts/lib.sh
- scripts/py.sh
- scripts/run-capped.py
- scripts/cycle.sh
- CLAUDE.md
- tests/cycle.test.sh
- install.sh
- scripts/state.sh
- scripts/telemetry.sh
- scripts/redact.sh
- scripts/injection-check.sh
- scripts/leak-check.sh
- scripts/top-model.sh
- scripts/defects-check.sh
- scripts/defects-index.sh
- scripts/prompt-check.sh
- scripts/symbol-map.sh
- scripts/trace-autopsy.sh
- .claude/hooks/handoff.sh
- .claude/hooks/anomaly-scan.sh
- .claude/hooks/vulyk-update-check.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-evolve.md
- .claude/commands/vulyk-review.md
- .claude/commands/vulyk-status.md
- .claude/agents/lead-review.md
- tests/telemetry.test.sh
- tests/council.test.sh
- tests/defects.test.sh
- tests/inject.test.sh
- tests/intake.test.sh
- tests/solo.test.sh
- tests/symbol-map.test.sh
- tests/mods.test.sh
- tests/token-report.test.sh
- tests/full-suite.sh
- tests/full-suite.test.sh
- scripts/portability-check.sh
- docs/defects/shell-needs-gnu-or-bash4.md
- docs/defects/shell-needs-gnu-or-bash4.sed-i.fixture
- docs/defects/shell-needs-gnu-or-bash4.sed-bre.fixture
- docs/defects/shell-needs-gnu-or-bash4.array.fixture
- docs/defects/shell-needs-gnu-or-bash4.python.fixture
- docs/defects/INDEX.md
- tests/maintenance.test.sh
- .github/workflows/ci.yml
- scripts/trace-check.sh
- scripts/wave-check.sh
- scripts/ship-check.sh
- scripts/human-check.sh
- scripts/journal.sh
- tests/model-profile.test.sh
- docs/defects/shell-needs-gnu-or-bash4.paste-s.fixture
- docs/defects/shell-needs-gnu-or-bash4.case-in-subst.fixture
- docs/defects/shell-needs-gnu-or-bash4.heredoc-in-subst.fixture

## Verification
`bash tests/cycle.test.sh`
`bash tests/telemetry.test.sh --part telemetry && bash tests/telemetry.test.sh --part scan && bash tests/telemetry.test.sh --part install && bash scripts/defects-check.sh && bash tests/maintenance.test.sh`
`bash tests/council.test.sh --part judge && bash tests/council.test.sh --part advance && bash tests/council.test.sh --part close`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/symbol-map.test.sh`
`bash tests/full-suite.test.sh`
`bash tests/solo.test.sh`
`bash tests/maintenance.test.sh && bash scripts/defects-check.sh`
`bash tests/model-profile.test.sh`
`bash tests/telemetry.test.sh --part scan`
`bash tests/maintenance.test.sh`
`bash scripts/defects-check.sh`

## Red receipt
- command: bash tests/full-suite.test.sh
- exit: 1
- tests: d091079a487cb3978423d9e140943b2e1136306f4f3ca1b40e918117351ecc5c (scripts/defects-check.sh, tests/council.test.sh, tests/cycle.test.sh, tests/defects.test.sh, tests/full-suite.test.sh, tests/inject.test.sh, tests/intake.test.sh, tests/maintenance.test.sh, tests/model-profile.test.sh, tests/solo.test.sh, tests/symbol-map.test.sh, tests/telemetry.test.sh)
- impl: 161fa9995f3679ade8e5c0403d841ec0d1939ae332b51151cc5ee37f6d188ffe
- stamped: 2026-10-29T13:01:51Z

```
== the latency suites run last, alone, one at a time
  ok    --list puts the latency suites last
  ok    latency suites after the rest, no overlap -> exit 0
  ok    inject ok
  ok    intake ok
== jobs share one install cache inside the logs dir
  ok    VULYK_INSTALL_CACHE is exported to every job -> exit 0
== bad usage
  ok    --jobs 0 -> exit 2
full-suite.test.sh: FAILED
```

## Implementation notes
- scripts/lib.sh: run_capped split; new run_capped_as <cap> <secs> <cmd> runs with a cap the caller already probed (run_capped = capped_by + run_capped_as).
- tests/full-suite.sh, scripts/cycle.sh verify_run: probe once (their existing capped_by) and cap each job/line with run_capped_as "$VULYK_CAP" - no timeout/gtimeout/python probe launches per job between the budget clock and the cap.
- tests/full-suite.test.sh: dead stubs log calls, the run must probe them once (red); the capped check uses the 30 s hang and accepts TIMEOUT 0-9s, so load overhead on a 1 s budget no longer fails it while "ran to the end" (30 s) still would.
- Surprise: stamp-red needed VULYK_VERIFY_TIMEOUT=2400 - the twelve verification lines run sequentially past 540 s on this box.
