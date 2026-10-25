---
story: horizon-intake-03
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
> 7. Живой прогон: Здесь, на образце - три drone-horizon и отбор по-настоящему, токены через token-report, разрешение WebFetch в обычном режиме.

## Findings
1. docs/specs/horizon-intake/live-run.md:71-72 [ask 7] the live run must record the WebFetch permission result in default mode against a control, not infer it from WebSearch: both web rows show `0 × WebFetch` and no WebFetch prompt or refusal is observed anywhere in the file, while ask 7 names WebFetch by word and `## Descoped` is empty - repro: `grep -n "WebFetch" docs/specs/horizon-intake/live-run.md` (one `--allowedTools` line, one `no WebFetch`, one `0 × WebFetch`, no result line); a headless `drone-horizon` dispatch told to fetch one named URL under `--setting-sources project --permission-mode default`, with the granted control, closes it.

## Files
- .claude/agents/drone-horizon.md
- scripts/telemetry.sh
- README.md
- .claude/commands/vulyk-plan.md
- templates/grill.md
- docs/adr/022-horizon-step.md
- docs/command-reference.md
- docs/architecture.md
- CHANGELOG.md
- docs/specs/horizon-intake/live-run.md

## Verification
`bash tests/telemetry.test.sh`
`bash tests/solo.test.sh`
