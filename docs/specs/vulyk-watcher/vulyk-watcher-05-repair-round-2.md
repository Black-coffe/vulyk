---
story: vulyk-watcher-05
status: todo
returned:
worker: worker-code
model: opus
wave: 4
blocked_by: []
---

# Repair round 2

## Goal
Make the asks and findings council round 2 left RED pass, and change nothing else.

## Requirements
> 5. install.sh ставит, обновляет и включает мод в каждом улье; твоё false сохраняется, выключатель в settings.local.json.

## Findings
ASK 5: RED - install.sh installs, UPDATES and enables in every hive; false kept; switch in settings.local.json - run: VULYK_CLAUDE=stub install.sh <hive> then install.sh <hive> --upgrade saw: first run calls "plugin marketplace add Black-coffe/vulyk" + "plugin install vulyk-watcher@vulyk --scope user"; on --upgrade the only call is "plugin list", then return 0 - no "claude plugin update" / "plugin marketplace update" ever runs (both exist in 2.1.300), so a VULYK upgrade never updates the machine's watcher; docs/watcher.md: "A machine that has it already is left alone"; plugin.json version is a fixed 0.1.0 not tied to VERSION. Install and the kept false ("kept .claude/settings.local.json -> ... false") work
1. install.sh:1046 [ask 5] a VULYK `--upgrade` (or a release) must bring the machine's installed vulyk-watcher@vulyk up to the release's mod, or the loss of "обновляет" must be recorded in plan `## Descoped` with the owner's decision; today a listed plugin returns at once, so the machine keeps the first-installed copy forever while the hive only receives a `.claude/mods/vulyk-watcher` tree that nothing loads (plugin.json stays `0.1.0`, plan `## Descoped` is `(empty)`) - repro: stub `claude` whose `plugin list` prints `vulyk-watcher@vulyk`, `VULYK_CLAUDE=<stub> bash install.sh <hive> --upgrade` logs only `plugin list` (no marketplace update, no `plugin update`); local evidence that a user-scope GitHub install does not refresh itself: `jq -c '.plugins["litopys@litopys"][]|{scope,version}' ~/.claude/plugins/installed_plugins.json` shows user scope at 0.2.1 while `~/.claude/plugins/marketplaces/litopys/.claude-plugin/plugin.json` is 0.4.0.

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

## Verification
`bash tests/watcher.test.sh`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
