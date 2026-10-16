---
story: vulyk-pulse-02
spec: vulyk-pulse
status: todo
returned:
tier: 3
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# Ship the pulse beside the watcher: marketplace, installer, tests, docs

## Goal
After this story, `install.sh` installs `vulyk-pulse@vulyk` beside `vulyk-watcher@vulyk`, once per machine, from the
same root marketplace.

- **`.claude-plugin/marketplace.json`** gains the `vulyk-pulse` entry from plan `## Contracts`.
- **`install.sh`:**
  - `.claude/mods/vulyk-pulse` joins `OWNED` (around :52).
  - `install_watcher` (around :1024-1080) becomes `install_mod <id>`. It is called for both ids where
    `install_watcher` is called today (around :1262). There is no copy of the function body.
  - Per id, its output and behaviour are the ones `install_watcher` has today: `would install` and `would update`
    under `--check`, the machine refresh on `--upgrade`, the NOTE when `claude` is absent, and an owner's
    `enabledPlugins[id]: false` respected.
- **`tests/telemetry.test.sh`.** The stubbed-`claude` watcher cases (around :15-17 and :1416-1430) also cover the pulse
  id: install, already installed, `--check`, `false` kept, no `claude`.
- **CI.** `.github/workflows/ci.yml` `install-smoke` (around :249-256) asserts that
  `.claude/mods/vulyk-pulse/hooks/hooks.json` exists after a fresh install and after an upgrade, beside the watcher
  line.
- **`docs/pulse.md`,** about a page, covers the behaviour list in plan `## Contracts`, in plain words:
  - what the row shows and where;
  - the task definition;
  - motion in `/config`;
  - what `≈tok` counts and misses;
  - hive-only and terminal-only;
  - the off switch.
- **`docs/token-economy.md`** gets one paragraph. The live row's `≈tok` is the same weighted unit as `token-report.py`,
  except that every cache write is weighted 1.25. It is a gauge: the transcripts stay the ledger of record.

## Requirements
> 7. Installed by the installer into every hive beside the watcher.
> 3. Tokens of all agents together (the Queen, subagents, workers), live, weighted as in the weekly token report.

## Files
- .claude-plugin/marketplace.json
- install.sh
- tests/telemetry.test.sh
- .github/workflows/ci.yml
- docs/pulse.md
- docs/token-economy.md

## Non-goals
- **The mod tree.** Do not touch `.claude/mods/vulyk-pulse/` or `tests/watcher.test.sh`; they are -01's. Write no
  local test that needs the pulse tree to exist (plan `## Contracts`, "Order inside wave 1").
- **`install.sh`.** Do not change `copy_tree`, the `OWNED` replace or audit logic, or `wire_plugin`.
- **No other installer changes:** no project `extraKnownMarketplaces` key and no settings wiring.
- **Other files.** Do not edit `docs/watcher.md`, `memory/memory.md` (that is drone-docs'), `CLAUDE.md`,
  `CHANGELOG.md` or `VERSION` (that is `/vulyk-ship`).
- **No hive names** or paths in docs or tests (card `host-internals-in-public-repo`).
- **No rollout.** Do not run `install.sh` against any real hive.

## Map slice
- `memory/map/scripts.md`: `## install.sh - the upgrade contract` and `## Gotchas`.
- `docs/specs/vulyk-watcher/plan.md`: `## Plan deltas`, the machine-wide install ruling and the round-2 refresh on
  upgrade.
- [recon.md](recon.md): `## Shipping`.
- Plan: `## Assumptions` and `## Contracts`.

## Acceptance criteria
- [ ] The watcher's existing install checks in `tests/telemetry.test.sh` stay green, unchanged.
- [ ] With `claude` stubbed, a fresh run installs both ids at user scope. A second run is silent for both.
- [ ] `--check` prints `would install` (or `would update`) once per id and changes nothing.
- [ ] An owner's `enabledPlugins["vulyk-pulse@vulyk"]: false` is respected, as for the watcher.
- [ ] With no `claude`, one NOTE names the commands for both ids, and the install still exits 0.
- [ ] `--upgrade` refreshes both machine installs, and `OWNED` lists `.claude/mods/vulyk-pulse`.
- [ ] CI `install-smoke` asserts the pulse tree after a fresh install and after an upgrade.
- [ ] `docs/pulse.md` exists and states each item of the plan's behaviour list. `docs/token-economy.md` has the
      paragraph.

## Verification
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Implementation notes

## Findings
