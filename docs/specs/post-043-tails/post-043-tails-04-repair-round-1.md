---
story: post-043-tails-04
status: todo
returned:
worker: worker-code
model: opus
wave: 3
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
1. .claude/hooks/handoff.sh:13 [regression] the Python probe must not add a second interpreter start to every `handoff.sh measure` call: `scripts/telemetry.sh:241` goes through the hook and the scan's python-start bound (one start per unmeasured file, `tests/telemetry.test.sh:648-660` shim) now counts double - repro: `bash tests/telemetry.test.sh --part scan` on the head gives `164 checks, 6 failed` (`the first scan starts python for the transcript and both subagents - expected [3], got [6]`, `a second scan starts no python for an already-recorded subagent - expected [1], got [2]`, `... --final scan ... expected [1], got [2]`); on the base 7f7c86e (`git show 7f7c86e:.claude/hooks/handoff.sh`, line 10 execs after `command -v` alone) the same part gives `164 checks, 0 failed`; `bash tests/full-suite.sh` is red on `bash tests/telemetry.test.sh --part scan` for the same six checks.

## Files
- scripts/prompt-check.py
- scripts/cycle.sh
- scripts/state.sh
- .claude/hooks/handoff.sh
- tests/maintenance.test.sh
- tests/cycle.test.sh
- scripts/trace-autopsy.py
- tests/symbol-map.test.sh
- docs/architecture.md
- docs/specs/upgrade-keeps-host-edits/upgrade-keeps-host-edits-01.md
- docs/specs/upgrade-keeps-host-edits/plan.md
- docs/specs/self-learning/plan.md
- memory/stats/ship.jsonl

## Verification
`bash tests/maintenance.test.sh`
`bash tests/cycle.test.sh`
`bash tests/symbol-map.test.sh`
