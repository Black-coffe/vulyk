---
story: vulyk-watcher-04
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
> 5. install.sh ставит, обновляет и включает мод в каждом улье; твоё false сохраняется, выключатель в settings.local.json.
> 6. Заметки пишутся на языке, на котором ты ведёшь разговор, язык определяется сам.
> 7. Выпускаю минорную версию и довожу её до живых ульев.

## Findings
ASK 5: RED - install.sh installs/upgrades/enables in every hive, false kept, local off switch - run: install.sh fresh, --upgrade with false, --upgrade of a keyless hive saw: files copied, both keys wired, "kept ... vulyk-watcher@vulyk is false (the owner's choice)"; BUT run: claude plugin list / marketplace list / plugin details vulyk-watcher@vulyk in that hive saw: no vulyk marketplace, "Plugin "vulyk-watcher@vulyk" not found" - enabled on paper, not loaded; docs/watcher.md "Known limit" admits the project-scope marketplace is not registered and may need an approval per hive
ASK 6: RED - notes in the user's language, auto-detected - run: probe test of detectLang saw: "почини install.sh: wire_plugin должен писать enabledPlugins в settings.local.json, а не settings.json" -> en (Latin identifiers outside backticks outnumber Cyrillic); a user row carrying an English slash-command expansion plus "сделай наблюдателя" -> en; "Bitte repariere den Test" -> en and the prompt tells the fork "detected: English"
ASK 7: RED - minor version released and taken to live hives - run: cat VERSION; grep CHANGELOG.md saw: VERSION 0.26.2, top entry [0.26.2] 2026-10-14, no watcher entry, no minor bump; no rollout evidence in the tree
1. install.sh:883 [ask 5] the settings install.sh writes into a hive (and VULYK's own .claude/settings.json:3-8) must actually load vulyk-watcher@vulyk, or the shrink must be recorded in plan ## Descoped with the owner's decision; story -01 measured M1 = NO, and the plan's own rule ("if neither loads without a machine path or a question, the Queen stops and asks the owner") was skipped with ## Plan deltas left empty - repro: in a temp dir holding .claude/mods/vulyk-watcher and the exact shipped keys, `claude -p --debug-file dbg.txt "say ok"; grep vulyk dbg.txt` shows "Skipping orphaned enabledPlugins entry vulyk-watcher@vulyk: marketplace not registered" and "Skipped auto-recording vulyk-watcher@vulyk - enabled only by repo-authored settings", with no hooks-module-loaded line, and `claude plugin list` / `claude plugin marketplace list` there show no vulyk entry (asks 1-4 and 6 depend on this: the mod never runs in a hive).

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

## Verification
`bash tests/watcher.test.sh`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
