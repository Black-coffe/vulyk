---
story: post-045-tails-04
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
1. docs/specs/post-045-tails/council/round-1/suite.log:74 [regression] the round's full suite (`bash tests/full-suite.sh`, round-only) must end `SUITE: ok` at head 6da4657, but it is red: 11 parts ran past 70% of the 300 s cap (council:seats 251s through telemetry:wrapper 288s) and part cycle:bsd failed. This review reran cycle:bsd in the foreground and it passed (rc 0, no non-ok line), and journal.md records two earlier reds caused by machine load, so the gate likely needs a rerun on an idle machine rather than a code change - repro: `bash -c '. scripts/lib.sh && run_capped 300 bash tests/cycle.test.sh --part bsd'`, then `bash scripts/cycle.sh suite docs/specs/post-045-tails`
- [regression] PART council:seats ok 251s cap 300s
- [regression] PART council:judge ok 260s cap 300s
- [regression] PART council:walks ok 263s cap 300s
- [regression] PART council:replays ok 266s cap 300s
- [regression] PART council:escalate ok 272s cap 300s
- [regression] PART cycle:bsd FAIL 138s cap 300s
- [regression] PART telemetry:rg ok 215s cap 300s
- [regression] PART telemetry:crlf ok 218s cap 300s
- [regression] PART telemetry:constitution ok 277s cap 300s
- [regression] PART telemetry:mods ok 277s cap 300s
- [regression] PART telemetry:ysk ok 285s cap 300s
- [regression] PART telemetry:wrapper ok 288s cap 300s

## Files
- CLAUDE.md
- tests/model-profile.test.sh
- scripts/cycle.sh
- scripts/suite-parts-check.sh
- tests/full-suite.sh
- .claude/agents/lead-review.md
- docs/adr/029-gate-split.md
- docs/defects/test-gate-one-long-limit.md
- tests/council.test.sh
- tests/full-suite.test.sh
- scripts/ship-check.sh
- .claude/commands/vulyk-ship.md
- tests/cycle.test.sh

## Verification
`bash tests/model-profile.test.sh`
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part seats2`
`bash tests/council.test.sh --part escalate`
`bash tests/council.test.sh --part suite`
`bash tests/full-suite.test.sh`
`bash tests/cycle.test.sh --part ship`
