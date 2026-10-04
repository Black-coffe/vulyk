---
story: you-should-know-01
spec: you-should-know
status: done
returned: DONE
tier: 1
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# The installer enables the "You should know" mod in every hive

## Goal
`install.sh` gains `wire_plugin`, called right after `wire_permissions`. It puts
`"enabledPlugins": {"cc-plugin-you-should-know@builtin": true}` into the host's `.claude/settings.json` when the key is
missing, keeps whatever value an owner already set (a `false` gets one `kept` line), and after a real wiring names the off
switch (`.claude/settings.local.json` -> `false`; `/plugin disable` writes user scope and loses to the project key) plus a
NOTE when the installing shell's env shows the mod cannot run. VULYK's own `.claude/settings.json` carries the key, so a
fresh install copies it and prints no wiring line.

## Requirements
> https://t.me/claudedevolper/1092 Изучи текущее событие, текущую новость, пойди на официальный сайт, блог «Антропиков», найди, действительно ли это правда, разбери, изучи, вникни, запусти Fable 5.1, Opus 5.5, Sonnet 5.5. Сделайте брейншторм, грилевку между собой и подумайте, как этой штукой улучшить текущий Wulic. И сделайте минорную версию апдейта, выкатите её на GitHub с применением и принудительным включением этого плагина на все проекты, где используется Wulic.

## Files
- install.sh
- .claude/settings.json
- tests/telemetry.test.sh
- .github/workflows/ci.yml
- docs/adr/005-installer-upgrade-contract.md

## Non-goals
- No SessionStart line, no `claude --version` check, no unwire, no edit of any existing host.
- No other plugin id: the helper wires this one key.

## Acceptance criteria
- [ ] Fresh install: the hive's settings.json has the key `true`; the output has no `enabledPlugins` wire line.
- [ ] An owner's settings.json without the key gets it `true` with a `wire` line and the off-switch line; other
      `enabledPlugins` keys and the owner's permissions survive.
- [ ] A second run is silent about the key and leaves no new backup.
- [ ] An explicit `false` stays `false`, prints one `kept` line, and leaves no backup taken for it.
- [ ] `--check` prints `would wire` and leaves the file byte-identical.
- [ ] An unparseable settings.json is left byte-identical, with a NOTE.
- [ ] CI install-smoke asserts the key with `jq -e`.
- [ ] ADR-005 carries a one-line amendment.

## Verification
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Implementation notes
- `install.sh` `wire_plugin` (after `wire_permissions`): one Python edit with exit codes 0 wired / 3 already true / 6 an
  owner's false (kept line) / 4 unparseable (NOTE, untouched); `--dry` under `--check`; reuses `settings_backup` and drops
  the backup it took when nothing changed. No python: a quoted `"<id>":` grep, then a by-hand line. After a real wiring it
  prints the off switch and, when the installing shell sets DISABLE_TELEMETRY / CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC /
  CLAUDE_CODE_USE_BEDROCK|VERTEX|FOUNDRY, a NOTE that the key will do nothing there.
- `.claude/settings.json`: `enabledPlugins` with the key, so a fresh hive is enabled by the copy and prints no wire line.
- `tests/telemetry.test.sh`: 12 checks beside the OWNSET case (own file, fresh, owner file + off switch + permission kept,
  `--check` byte-identical, other plugin key survives, silent rerun with no backup, false kept with no backup, unparseable
  byte-identical). Suite: 465 checks, 0 failed.
- `ci.yml` install-smoke: `jq -e` on the key. ADR-005: amendment 2026-10-04.

## Findings
