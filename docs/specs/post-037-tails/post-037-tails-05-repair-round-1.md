---
story: post-037-tails-05
status: todo
returned:
worker: worker-code
model: opus
wave: 3
blocked_by: []
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 4. symbol-map speed on a bash input is profiled and the cheap fixes made, before/after figures recorded.

## Findings
ASK 4: RED - speed profiled, cheap fixes, before/after figures recorded - run: `time bash scripts/symbol-map.sh scripts/lib.sh` x3 saw: 0.418 / 0.417 / 0.420 s (brief: 1.55 s before; a .py 0.597 s, --exact ship-check.sh 0.415 s), so the speed did move; but run: grep -rn "1\.55|0\.4[0-9] s|0\.3[0-9] s|0\.2 s" over CHANGELOG.md, docs/ (replay.md included), scripts/symbol-map.py header, tests/symbol-map.test.sh saw: no before/after figure anywhere but the brief itself; CHANGELOG `## [Unreleased]` is empty. The owner asked for the figures to be recorded; nothing durable in the tree records them

## Files
- scripts/lib.sh
- scripts/ship-check.sh
- scripts/human-check.sh
- tests/cycle.test.sh
- scripts/telemetry.sh
- tests/telemetry.test.sh
- scripts/symbol-map.py
- scripts/symbol-map.sh
- tests/symbol-map.test.sh
- tests/fixtures/symbol-map/**
- docs/specs/symbol-map/replay.py
- .claude/commands/vulyk-plan.md
- .claude/commands/vulyk-ship.md
- .claude/agents/queen-planner.md
- README.md
- docs/command-reference.md

## Verification
`bash tests/cycle.test.sh`
`bash tests/telemetry.test.sh --part telemetry`
`bash tests/symbol-map.test.sh`
`bash tests/maintenance.test.sh`
