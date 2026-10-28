---
story: post-043-tails-04
status: done
returned: DONE
worker: worker-code
model: opus
wave: 3
blocked_by: []
red: required
red_reason: handoff.sh starts a working python3 once per call, never a probe beside it - expected 'starts=1;'
red_verified_at: 2026-10-28T20:39:31Z 7db76bc881a76db7c7b81616e55c6ed7268a8bdd7e6998096850a22b7106985f
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

## Implementation notes
- Finding 1. `handoff.sh` no longer probes with `-c ''`. Each candidate runs `handoff.py` once. If it exits with 49
  (the Store stub), 126 or 127 (it did not launch), the loop moves on to the next name; any other code is the hook's
  exit, as with the old `exec`. So a working Python starts once per call, and a stub is still passed over.
  Rejected: skipping paths under `WindowsApps`, because a real Python installed from the Store lives there too.
- Red first: a new neighbour test in `tests/maintenance.test.sh` counts the starts of a real `python3` behind a shim.
  Before the fix it saw `starts=2;`, and that is the receipt. The reviewer's repro was added to `## Verification` as
  `bash tests/telemetry.test.sh --part scan`. Before the fix it gave 164 checks, 6 failed; after the fix, 0 failed.
- The stub test from story 01 still passes. The round-1 minor (no blank line before `**Shipped:**` in
  self-learning/plan.md) is not among this story's findings and was left alone.

## Verification
`bash tests/maintenance.test.sh`
`bash tests/cycle.test.sh`
`bash tests/symbol-map.test.sh`
`bash tests/telemetry.test.sh --part scan`

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 7db76bc881a76db7c7b81616e55c6ed7268a8bdd7e6998096850a22b7106985f (tests/cycle.test.sh, tests/maintenance.test.sh, tests/symbol-map.test.sh)
- impl: 002a08ccd96242e8b3f9ed7d0b08196ee7e2a296632350a9bf60a88b25812273
- stamped: 2026-10-28T20:39:31Z

```
  ok    prompt-check: the hive deletion is a warn line
  ok    prompt-check: an agent name inside a longer span (post-043-tails) exits 1
  ok    prompt-check: an agent name inside a longer span (post-043-tails) names rule agent
  ok    prompt-check: a cycle.sh without a verb dispatcher exits 0
  ok    prompt-check: a cycle.sh without a verb dispatcher is one warn line, not a silent skip
--- handoff.sh: a python3 that is a stub (the Windows Store alias, exit 49) is passed over (post-043-tails)
  ok    handoff.sh status with a stub python3 first on PATH reaches a working Python or exits 0
::error::handoff.sh starts a working python3 once per call, never a probe beside it - expected 'starts=1;' in:
        starts=2;
maintenance.test.sh: 211 checks, 1 failed
```
