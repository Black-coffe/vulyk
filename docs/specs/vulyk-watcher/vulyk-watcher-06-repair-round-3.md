---
story: vulyk-watcher-06
status: todo
returned:
worker: worker-code
model: opus
wave: 5
blocked_by: []
---

# Repair round 3

## Goal
Make the asks and findings council round 3 left RED pass, and change nothing else.

## Requirements
No brief ask is RED in round 3 - the findings below are the whole task.

## Findings
1. .claude/mods/vulyk-watcher/hooks/register.tsx:63 [regression] the fork ledger the mod writes into a hive's working tree must not make `cycle.sh claim`/`open-round` refuse the tree; today `memory/stats/watcher.jsonl` is not in `is_paperwork_path` (scripts/lib.sh:56-58, the list that already carries anomalies.jsonl for the same reason), so the first tool-calling turn of the Queen's main session leaves an untracked non-paperwork file and `dirty_outside_paperwork` (scripts/cycle.sh:2216, 2472) exits 2 "working tree not clean" - repro: `bash -c 'source scripts/lib.sh; is_paperwork_path memory/stats/watcher.jsonl; echo $?'` prints 1 (anomalies.jsonl prints 0); base evidence: `git show 6819ff5:.claude/mods/vulyk-watcher/hooks/register.tsx | grep -c fs.write` prints 0, so on the base the watcher leaves the tree clean.

## Files
- tests/watcher.test.sh
- .claude/mods/vulyk-watcher/.claude-plugin/plugin.json
- .claude/mods/vulyk-watcher/.claude-plugin/marketplace.json
- .claude/mods/vulyk-watcher/hooks/hooks.json
- .claude/mods/vulyk-watcher/hooks/register.tsx
- .claude/mods/vulyk-watcher/hooks/core.ts
- .claude/mods/vulyk-watcher/hooks/core.test.ts
- .claude/mods/vulyk-watcher/hooks/fixtures/
- install.sh
- .claude/settings.json
- tests/telemetry.test.sh
- .github/workflows/ci.yml
- docs/adr/005-installer-upgrade-contract.md
- docs/watcher.md
- .claude-plugin/marketplace.json
- scripts/token-report.py
- tests/token-report.test.sh

## Verification
`bash tests/watcher.test.sh`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
