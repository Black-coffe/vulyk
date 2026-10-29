---
story: cross-platform-10
status: todo
returned:
worker: worker-code
model: opus
wave: 6
blocked_by: []
red: required
red_reason:
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
