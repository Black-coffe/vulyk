---
story: cross-platform-06
status: done
returned: DONE
worker: worker-code
model: opus
wave: 4
blocked_by: []
red: required
red_reason: CLAUDE.md grew past its baa5219 size
red_verified_at: 2026-10-28T23:02:45Z 8f1e24567ae06826a1aaedf89e0c348070b080fb90a18666c7e0f11e59586301
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
No brief ask is RED in round 1 - the findings below are the whole task.

## Findings
1. CLAUDE.md:76 [regression] the full suite must be green: `bash tests/full-suite.sh` fails on `tests/model-profile.test.sh:165` with `CLAUDE.md grew: 7165 B > 7162 B at baa5219` (base b7e87b7 is 7153 B and passes; the head's `bash scripts/py.sh -m py_compile` cell makes it 7165 B; the test file is untouched by the branch, and the plan budgeted only the 7168 B cap of tests/maintenance.test.sh) - repro: `bash tests/model-profile.test.sh`

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

## Verification
`bash tests/cycle.test.sh`
`bash tests/telemetry.test.sh --part telemetry && bash tests/telemetry.test.sh --part scan && bash tests/telemetry.test.sh --part install && bash scripts/defects-check.sh && bash tests/maintenance.test.sh`
`bash tests/council.test.sh --part judge && bash tests/council.test.sh --part advance && bash tests/council.test.sh --part close`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/symbol-map.test.sh`
`bash tests/full-suite.test.sh`
`bash tests/solo.test.sh`
`bash tests/maintenance.test.sh && bash scripts/defects-check.sh`

## Red receipt
- command: bash tests/telemetry.test.sh --part telemetry && bash tests/telemetry.test.sh --part scan && bash tests/telemetry.test.sh --part install && bash scripts/defects-check.sh && bash tests/maintenance.test.sh
- exit: 1
- tests: 8f1e24567ae06826a1aaedf89e0c348070b080fb90a18666c7e0f11e59586301 (scripts/defects-check.sh, tests/council.test.sh, tests/cycle.test.sh, tests/defects.test.sh, tests/full-suite.test.sh, tests/inject.test.sh, tests/intake.test.sh, tests/maintenance.test.sh, tests/solo.test.sh, tests/symbol-map.test.sh, tests/telemetry.test.sh)
- impl: 72e4192fa3b507686ab83d73b017a18b88158a652b977783a8874dd70f60a46f
- stamped: 2026-10-28T23:02:45Z

```
  ok    portability-check: bash scripts/py.sh -m py_compile x.py is not a hit
  ok    portability-check: sed -i 's/a/b/' "$f" # portable: this line runs only on the GNU CI image is not a hit
  ok    portability-check: a # portable: line is counted as allowed
  ok    portability-check: |& inside a Python heredoc body is not a hit
  ok    portability-check: the line after the heredoc is read again
  ok    portability-check: timeout in an .md sentence outside backticks is not a hit
  ok    portability-check: the bare python cell of CLAUDE.md:76 is a hit
  ok    portability-check: a missing named file exits 2
  ok    portability-check: nothing to scan exits 2
maintenance.test.sh: 286 checks, 1 failed
```

## Implementation notes
- tests/maintenance.test.sh: red check that CLAUDE.md is no bigger than at baa5219 (the tighter cap model-profile.test.sh enforces), skipped when baa5219 is absent.
- CLAUDE.md: Compact instructions "scout reports: they are on disk." -> "scout reports: on disk." (7165 -> 7156 B, CR-stripped; baa5219 is 7162 B).
- Surprise: stamp-red timed out at the default 540 s budget on this box; reran with VULYK_VERIFY_TIMEOUT=1800.
