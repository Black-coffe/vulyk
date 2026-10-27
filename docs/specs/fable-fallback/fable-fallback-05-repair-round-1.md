---
story: fable-fallback-05
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
> 3. Кэш на 1 час только у ревьюера; через неделю замер расхода и решение, распространять ли.

## Findings
1. docs/model-cascade.md:112 [ask 3] the one-hour cache must be the reviewer's alone, or the brief, plan and this doc line must record that `worker-code` and `worker-test` already carry it and the owner accepted that - the diff writes "`lead-review` alone carries `experimental:` / `cacheTtl: 1h`" and plan.md:15 and story 02 say "the only agent that does", yet `.claude/agents/worker-code.md:9` and `.claude/agents/worker-test.md:9` carry `cacheTtl: 1h` on the base (commit ab4f8aa), so the 2026-11-03 "spread or not" decision the owner chose rests on a false baseline - repro: `grep -rn cacheTtl .claude/agents/`

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- scripts/telemetry.sh
- docs/telemetry.md
- tests/telemetry.test.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- .claude/commands/vulyk-plan.md
- .claude/agents/lead-review.md
- scripts/top-model.sh
- docs/model-cascade.md
- docs/adr/015-sonnet-execution-rung-and-model-floor.md
- tests/model-profile.test.sh

## Verification
`bash tests/driver.test.sh`
`bash tests/telemetry.test.sh --part telemetry && bash tests/maintenance.test.sh`
`bash tests/model-profile.test.sh && bash tests/maintenance.test.sh`
