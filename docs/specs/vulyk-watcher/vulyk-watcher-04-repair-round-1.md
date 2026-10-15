---
story: vulyk-watcher-04
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
> 5. install.sh ставит, обновляет и включает мод в каждом улье; твоё false сохраняется, выключатель в settings.local.json.
> 6. Заметки пишутся на языке, на котором ты ведёшь разговор, язык определяется сам.
> 7. Выпускаю минорную версию и довожу её до живых ульев.

## Findings
ASK 5: RED - install.sh installs/upgrades/enables in every hive, false kept, local off switch - run: install.sh fresh, --upgrade with false, --upgrade of a keyless hive saw: files copied, both keys wired, "kept ... vulyk-watcher@vulyk is false (the owner's choice)"; BUT run: claude plugin list / marketplace list / plugin details vulyk-watcher@vulyk in that hive saw: no vulyk marketplace, "Plugin "vulyk-watcher@vulyk" not found" - enabled on paper, not loaded; docs/watcher.md "Known limit" admits the project-scope marketplace is not registered and may need an approval per hive
ASK 6: RED - notes in the user's language, auto-detected - run: probe test of detectLang saw: "почини install.sh: wire_plugin должен писать enabledPlugins в settings.local.json, а не settings.json" -> en (Latin identifiers outside backticks outnumber Cyrillic); a user row carrying an English slash-command expansion plus "сделай наблюдателя" -> en; "Bitte repariere den Test" -> en and the prompt tells the fork "detected: English"
ASK 7: RED - minor version released and taken to live hives - run: cat VERSION; grep CHANGELOG.md saw: VERSION 0.26.2, top entry [0.26.2] 2026-10-14, no watcher entry, no minor bump; no rollout evidence in the tree
1. install.sh:883 [ask 5] the settings install.sh writes into a hive (and VULYK's own .claude/settings.json:3-8) must actually load vulyk-watcher@vulyk, or the shrink must be recorded in plan ## Descoped with the owner's decision; story -01 measured M1 = NO, and the plan's own rule ("if neither loads without a machine path or a question, the Queen stops and asks the owner") was skipped with ## Plan deltas left empty - repro: in a temp dir holding .claude/mods/vulyk-watcher and the exact shipped keys, `claude -p --debug-file dbg.txt "say ok"; grep vulyk dbg.txt` shows "Skipping orphaned enabledPlugins entry vulyk-watcher@vulyk: marketplace not registered" and "Skipped auto-recording vulyk-watcher@vulyk - enabled only by repo-authored settings", with no hooks-module-loaded line, and `claude plugin list` / `claude plugin marketplace list` there show no vulyk entry (asks 1-4 and 6 depend on this: the mod never runs in a hive).

QUESTION (worker, 2026-10-15) on finding 1 / ask 5 - the plan's own stop rule fires, the owner must choose:
-01 measured that no committed project file loads the mod (M1 NO for all four path forms; M2: CLAUDE_CODE_PLUGIN_DIRS is ignored in project settings, works only from user/managed settings or the shell, and yields id `vulyk-watcher@inline`). The plan says "if neither loads without a machine path or a question, the Queen stops and asks the owner". Options I see, recommended first:
  (a) install.sh, when `claude` is on PATH, registers the hive's mod per machine: `claude plugin marketplace add <abs hive>/.claude/mods/vulyk-watcher --scope local` then `claude plugin install vulyk-watcher@vulyk --scope local`; this writes an absolute path into the user's ~/.claude plugin registry (a machine-level write outside the hive) and must be re-measured with `--debug-file` before it is trusted;
  (b) descope: keep the project keys, record in plan `## Descoped` that the owner enables the mod once per hive by hand, docs/watcher.md says how;
  (c) user-scope CLAUDE_CODE_PLUGIN_DIRS in ~/.claude/settings.json (one absolute path per hive, id changes to @inline, the off-switch key changes).
Either answer changes the work materially, and (b) needs an edit of plan.md, which is not in this story's `## Files`.
Ask 7 (minor release + rollout to live hives) is publishing: per the plan it is the Queen's after GREEN, and VERSION / CHANGELOG.md are not in `## Files`; it cannot be met by this story.
Ask 6 (detectLang: strip backticked/Latin identifiers and slash-command expansions, do not call German "English") is fixable inside core.ts/core.test.ts; left untouched so the tree stays clean until finding 1 is decided.
Re-dispatch (worker, 2026-10-15, stamp 448d4bdc45ed22ea): the story arrived again with no answer to the question above - plan.md `## Descoped` and `## Plan deltas` are still "(empty)", no new commit on the branch. Nothing in `## Files` can be built until the owner picks (a), (b) or (c); returned NEEDS_CONTEXT again without touching code.

RULING (Queen, 2026-10-15, the owner chose (d) machine-wide from GitHub; see plan `## Plan deltas`): build these
conditions, then close the story.
  1. Root `.claude-plugin/marketplace.json` (marketplace `vulyk`, plugin `vulyk-watcher`, source `./.claude/mods/vulyk-watcher`);
     drop the mod-folder marketplace.json if nothing needs it.
  2. `install.sh`: with `claude` on PATH and `vulyk-watcher@vulyk` not installed, `claude plugin marketplace add <VULYK GitHub repo>`
     then `claude plugin install vulyk-watcher@vulyk --scope user`; idempotent; `--check` prints `would install`; no `claude` -> NOTE
     naming both commands; never fails the install. Drop the project `extraKnownMarketplaces` wiring; keep `enabledPlugins` handling
     only so an owner's `false` turns a hive off.
  3. The mod is silent (no fork, no band) outside a VULYK hive: no `CLAUDE.vulyk.md` and no `scripts/cycle.sh` at the project root.
  4. Measure with `claude -p --debug-file` that a user-scope install from a DIRECTORY marketplace at this working copy loads
     (`hooks module vulyk-watcher@vulyk loaded`), and that project `enabledPlugins["vulyk-watcher@vulyk"]: false` in a temp hive
     turns it off; restore your user settings and plugin registry afterwards (uninstall + marketplace remove) and say so.
  5. Ask 6: drop letter counting; the fork reply carries `lang:` chosen by the model from the user's own messages; tests cover
     the three repros in finding ASK 6 (mixed Russian+identifiers -> ru, slash-command expansion + Russian -> ru, German -> de
     with English button labels).
  6. `docs/watcher.md` and the ADR-005 line describe the machine-wide install and the off switch.
Ask 7 is not this story's (plan `## Plan deltas`).

## Files
- .claude-plugin/marketplace.json
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

## Implementation notes
- .claude-plugin/marketplace.json: new root marketplace `vulyk`, plugin source `./.claude/mods/vulyk-watcher`; the mod-folder marketplace.json is removed (nothing read it).
- install.sh: `install_watcher` replaces the two project wire_plugin calls (WATCHER_MKT gone): list -> skip, `--check` -> `would install`, else marketplace add Black-coffe/vulyk (skipped when listed) + install --scope user; no claude / failure -> NOTE with both commands, exit 0; an owner's `false` in settings.json or settings.local.json gets a `kept` line, the key is never written. `VULYK_CLAUDE` names the binary (tests point it at a stub so no suite touches the real plugin registry).
- .claude/settings.json: dropped `extraKnownMarketplaces.vulyk` and `enabledPlugins["vulyk-watcher@vulyk"]`.
- core.ts / register.tsx: `detectLang` (letter counting) removed; the prompt asks for a `lang:` line (ISO 639-1, judged from the person's own words, not code/identifiers/slash-command expansions); `labelLang` maps ru/uk to their labels, anything else to en; `isHive` gates the fork on `CLAUDE.vulyk.md` or `scripts/cycle.sh` at the root.
- core.test.ts + fixtures: the three ASK 6 repros as fixtures, each paired with a model reply (ru, ru, de -> English buttons); a hive-gate test. The tests cannot run the model, so they prove the contract (no claimed language, lang: parsed, labels), not the model's choice.
- tests/watcher.test.sh also validates the root marketplace; tests/telemetry.test.sh watcher block rewritten around a `claude` stub; ci.yml checks the hive carries no watcher key.
- Measured (condition 4, build 2.1.300): `claude plugin marketplace add E:/Projects/vulyk` + `install vulyk-watcher@vulyk --scope user`; temp hive with no settings: "hooks module vulyk-watcher@vulyk loaded (worker, environment 1, tier user)"; project settings.json false: "enabled=false; will NOT register", no module line; settings.local.json false: same. Restored: plugin uninstalled, marketplace removed, ~/.claude/plugins/cache/vulyk deleted; ~/.claude/settings.json and known_marketplaces.json byte-identical to the backup, installed_plugins.json equal under `jq -S` (one other entry's keys reordered by the CLI).
