---
story: symbol-map-04
status: done
returned: DONE
worker: worker-code
model: opus
wave: 3
blocked_by: []
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 3. Королева запускает его на разведке для файлов из плана и передаёт результат планировщику, чтобы ## Files был полным.

## Findings
1. .claude/commands/vulyk-plan.md:27 [ask 3] the recon run must reach every candidate file before its output goes to the planner: one call on N files stops after 1-3 blocks under the per-run 1536-byte cap, so the line must run the script once per candidate file (or re-run until no `inputs not shown` tail remains) or the cap must apply per block, and plan.md `## Descoped` is empty while story 03 `## Findings` leaves it open - repro: `bash scripts/symbol-map.sh scripts/lib.sh scripts/cycle.sh scripts/wave-check.sh scripts/model-profile.sh scripts/top-model.sh scripts/redact.sh scripts/ship-check.sh scripts/release-check.sh` prints 2 blocks and `... N more (6 inputs not shown)`; docs/specs/symbol-map/replay.md:169 records the cap cutting 8 of the 9 stories with an unfound path after 1-3 of 8-73 inputs.

## Files
- scripts/symbol-map.sh
- scripts/symbol-map.py
- tests/symbol-map.test.sh
- tests/fixtures/symbol-map/**
- CLAUDE.md
- .claude/commands/vulyk-plan.md
- .claude/commands/vulyk-build.md
- .claude/agents/queen-planner.md
- .claude/agents/worker-code.md
- docs/specs/symbol-map/replay.py
- docs/specs/symbol-map/replay.md

## Verification
`bash tests/symbol-map.test.sh && bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/maintenance.test.sh`
`bash tests/symbol-map.test.sh`

## Implementation notes
- .claude/commands/vulyk-plan.md step 3: recon runs `symbol-map.sh <file>` once per candidate file and keeps every output, so the per-run 1536-byte cap no longer cuts later files.
- Chose the protocol fix over a per-block cap: the script contract (whole stdout <= 1536 B) and its tests stay as story 01 built them.
- Repro: each of the 8 scripts run alone prints no `inputs not shown` tail.
