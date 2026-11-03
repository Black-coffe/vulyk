---
story: post-046-tails-04
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
