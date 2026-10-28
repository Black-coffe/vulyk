---
story: cross-platform-06
status: todo
returned:
worker: worker-code
model: opus
wave: 4
blocked_by: []
red: required
red_reason:
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
