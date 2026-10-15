---
story: vulyk-watcher-06
status: done
returned: DONE
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

Question (worker, NEEDS_CONTEXT): the fix this finding names is one more case in `is_paperwork_path` (scripts/lib.sh:54-56, add `memory/stats/watcher.jsonl` beside anomalies.jsonl), and `scripts/lib.sh` is not in `## Files`. The only in-scope alternative is moving the ledger out of the tree (e.g. under gitignored `.vulyk/`), which breaks the owner's 2026-10-15 ruling that names `memory/stats/watcher.jsonl` and the path token-report.py and docs/watcher.md read. Please add `scripts/lib.sh` to `## Files` (and, if a regression test is wanted, `tests/cycle.test.sh`); I would then add the one whitelist entry and nothing else.

RULING (Queen, 2026-10-15): yes - `scripts/lib.sh` and `tests/cycle.test.sh` join `## Files`. Add the one `is_paperwork_path` case for `memory/stats/watcher.jsonl` beside anomalies.jsonl and a regression check in tests/cycle.test.sh (the repro above prints 0); nothing else in lib.sh.

## Implementation notes
- scripts/lib.sh: `memory/stats/watcher.jsonl` added to `is_paperwork_path` beside anomalies.jsonl; nothing else changed.
- tests/cycle.test.sh: regression check right after lib.sh is sourced - `is_paperwork_path memory/stats/watcher.jsonl` must return 0.

## Files
- scripts/lib.sh
- tests/cycle.test.sh
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
`bash tests/cycle.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
