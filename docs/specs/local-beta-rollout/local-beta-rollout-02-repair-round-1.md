---
story: local-beta-rollout-02
status: todo
returned:
worker: worker-code
model: opus
wave: 2
blocked_by: []
red: required
red_reason:
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 1. Every change merged to the local main of VULYK rolls out to every local hive automatically: a private hive registry with holds (reason and date), a check that goes red when a registered hive lags the local version without a live hold (the card public-release-per-change's check, with fixtures), and a `/vulyk-ship` step that bumps the local dev build, upgrades every registered hive from the local clone, commits in each and lists the hives held and why.

## Findings
1. .claude/commands/vulyk-ship.md:46 [ask 1] the dev bump of step 2a must leave the repo's own gate green: `VERSION` committed alone breaks the plugin.json pin (tests/mods.test.sh:22-28, tests/telemetry.test.sh:2436), so the next spec's suite is red after the first rollout - repro: on a copy of the head (`git archive 0ad50bf7 | tar -x -C <tmp>`) set `<tmp>/VERSION` to `0.52.0-dev.1`, then `bash <tmp>/tests/mods.test.sh` prints `plugin.json version '0.51.0' is not VERSION '0.52.0-dev.1'` and exits 1 (seen this round); the same state sat at bdd64af9 (VERSION 0.51.0-dev.1 beside plugin.json 0.50.3).
2. .claude/commands/vulyk-ship.md:46 [ask 1] a hive stamped with a dev build by step 2a must find that build as `v<version>` in the clone at its next upgrade (a local ref, never pushed): with "no tag", from the second rollout on install.sh treats every hive as PREV_UNKNOWN (install.sh:1748), so a hook the new build brings is named, not wired (install.sh:1754, 1794, 1804), every hive-edited framework file gets a `.vulyk-new` even when the build left it alone (install.sh:219-240), and a retired file the hive edited is removed, not kept (install.sh:1668-1673); tests/maintenance.test.sh:1134 pins the phrase `no tag and no push`.

## Files
- scripts/hives-behind.sh
- tests/maintenance.test.sh
- docs/defects/public-release-per-change.md
- docs/defects/public-release-per-change.original.fixture
- docs/defects/public-release-per-change.neighbour.fixture
- docs/defects/INDEX.md
- .claude/commands/vulyk-ship.md
- CHANGELOG.md

## Verification
`bash tests/maintenance.test.sh`
