---
story: vulyk-watcher-03
spec: vulyk-watcher
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
wave: 2
blocked_by: [vulyk-watcher-01]
---

# The installer ships and enables the watcher in every hive

## Goal
After this story, every hive ships and enables the watcher. The enabling mechanism is the one recorded in plan
`## Plan deltas` from -01 (default: `extraKnownMarketplaces.vulyk` + `enabledPlugins["vulyk-watcher@vulyk"]`).

- **`install.sh`:**
  - `.claude/mods/vulyk-watcher` joins `OWNED` (:52), so `--upgrade` replaces the tree. A fresh install already copies
    it through the `.claude` tree loop (:1092).
  - `wire_plugin` (:951) takes the plugin id as a parameter instead of hardcoding it, with no copy of the function. It
    keeps its contract: rc 0 wired, 3 already set, 6 owner value kept (one `kept` line, no backup left behind), 4
    unparseable (untouched + NOTE); `--check` prints `would wire` and leaves the file byte-identical.
  - It is called for the built-in id and for `vulyk-watcher@vulyk`, the marketplace key first, by the same rule:
    missing is written; equal is silent; a different owner value is kept with one line.
  - The off-switch line names `.claude/settings.local.json` for the wired id. The built-in's telemetry NOTE is printed
    for the watcher only if M4 showed it cannot run without telemetry.
- **VULYK's own `.claude/settings.json`** carries both new keys, so a fresh hive comes out enabled and prints no wiring
  line.
- **Tests and CI.** The `wire_plugin` cases in `tests/telemetry.test.sh` cover the second id. CI `install-smoke`
  asserts both keys with `jq -e` and checks that `.claude/mods/vulyk-watcher/hooks/hooks.json` exists after a fresh
  install and after an upgrade.
- **Docs.** ADR-005 gets a one-line amendment: the first mod tree is `OWNED`, and its marketplace key is wired like
  `enabledPlugins`. `docs/watcher.md` (about a page) covers what the watcher does, when it stays silent, cost, the
  buttons, the off switch, and how a note becomes a card.

## Requirements
> 5. install.sh ставит, обновляет и включает мод в каждом улье; твоё false сохраняется, выключатель в settings.local.json.
> 1. Свой наблюдатель VULYK работает рядом со встроенным «You should know», а не вместо него.
> Наш мод в составе VULYK (ставится в каждый улей через install.sh) работает рядом со встроенным.

## Files
- install.sh
- .claude/settings.json
- tests/telemetry.test.sh
- .github/workflows/ci.yml
- docs/adr/005-installer-upgrade-contract.md
- docs/watcher.md

## Non-goals
- Do not change `copy_tree` or how `OWNED` trees are replaced or audited. Host-edit handling is spec
  `upgrade-keeps-host-edits` (card `upgrade-overwrites-host-edits`); this story only adds one path to the list.
- No unwire, no SessionStart line, no `claude --version` check, no edit of any existing hive.
- No `.gitattributes` or CRLF rule for `*.tsx` and no `shippable()` change, since the tree has no `node_modules`.
  Report a measured need instead.
- Do not touch `CLAUDE.md` (-02 edits it in this wave), `CHANGELOG.md` or `VERSION` (`/vulyk-ship` writes them).
- Never write a hive's name or path into the docs page or tests (card `host-internals-in-public-repo`).

## Map slice
`memory/map/scripts.md` `## install.sh - the upgrade contract`, `## Gotchas`; `docs/specs/you-should-know/you-should-know-01.md`
`## Implementation notes` (the `wire_plugin` contract); recon.md `## VULYK side`; plan `## Contracts`, `## Plan deltas`.

## Acceptance criteria
- [ ] The built-in key's existing `wire_plugin` checks stay green, unchanged.
- [ ] Fresh install: both watcher keys are present, the mod tree is present, and there is no wiring line for them.
- [ ] An owner settings.json without the keys gets both, with `wire` lines and the off-switch line. Other
      `enabledPlugins` and `extraKnownMarketplaces` entries and the permissions survive.
- [ ] A second run is silent and leaves no new backup. An explicit `false` for `vulyk-watcher@vulyk` stays `false`
      with one `kept` line and no backup. An owner's different `vulyk` marketplace entry is kept with one line.
- [ ] `--check` is byte-identical with `would wire` lines. An unparseable settings.json is byte-identical, with a NOTE.
- [ ] `--upgrade` of a hive installed before this release brings in `.claude/mods/vulyk-watcher/`.
- [ ] CI `install-smoke` asserts the above with `jq -e` and a file test. ADR-005 has the amendment line, and
      `docs/watcher.md` exists.

## Verification
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Implementation notes
- Files: install.sh, .claude/settings.json, tests/telemetry.test.sh, .github/workflows/ci.yml, ADR-005, docs/watcher.md.
- `wire_plugin [section key json-value what]`: no args = the built-in, so its existing cases are unchanged; the marketplace is wired first, then the id. Equal value (same type) = rc 3; any other owner value = rc 6.
- Plan `## Plan deltas` was empty, so the default mechanism is used. -01 measured M1 = NO (project-scope directory marketplace not loaded in `-p`, "marketplace not registered"), so the committed keys may not load the mod; the marketplace path is `./.claude/mods/vulyk-watcher` (unmeasured form). M4 = yes, so no telemetry NOTE for the watcher.
- docs/watcher.md carries a one-paragraph "Known limit" about M1.

## Findings
