---
story: local-beta-rollout-02
status: done
returned: DONE
worker: worker-code
model: opus
wave: 2
blocked_by: []
red: required
red_reason: hives-behind: a hold more than 7 days ahead is red
red_verified_at: 2026-11-12T17:53:11Z 2a01525e1e415c85dc8500639ff0230b60649797a07971507cdffbe804305470
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

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 2a01525e1e415c85dc8500639ff0230b60649797a07971507cdffbe804305470 (tests/maintenance.test.sh)
- impl: db143392137d0f9f8dc438f238d50de3b87e0982397c74e99e03acc088eba5ed
- stamped: 2026-11-12T17:53:11Z

```
::error::hives-behind: a hold more than 7 days ahead is red - expected '[exit=1]' in:
        2a. Local beta, only in the VULYK source repo (`install.sh` and `VERSION` at the root; anywhere else skip this step silently). With no registry at `${VULYK_HIVES_FILE:-~/.vulyk/hives}`, print `local beta: no hive registry, rollout skipped` and go on. Otherwise every local hive takes this merge now, unasked (card public-release-per-change): - Bump `VERSION` to the next local build (`X.Y.Z-dev.N` -> `X.Y.Z-dev.<N+1>`, a plain `X.Y.Z` -> `X.<Y+1>.0-dev.1`) and commit it alone as `release: <version> (local, unpublished)`: no tag and no push. - Upgrade a hive: if it has no live hold, is on the branch it ships from and `git -C <hive> status --porcelain` prints nothing, run `./install.sh <hive> --upgrade` from this clone, merge every `.vulyk-new` it leaves into the hive's own edit by hand (card upgrade-overwrites-host-edits), then commit in the hive (`chore(vulyk): upgrade to <version>`), never push. A hive that cannot take it now (another branch, a dirty tree, a running build, a red suite) gets ` | hold <YYYY-MM-DD> <reason>` on its registry line, the date at most 7 days ahead. - Canaries first: upgrade each hive `bash scripts/hives-behind.sh --canaries` prints (registry lines marked ` | canary`, two hives of different shape), then run one quick test row from each canary's own `## Commands` table, preferring a row that runs its tests or `close-story` path. Green on every canary: upgrade the other hives the same way. a red canary stops the rollout: revert that canary's upgrade commit, hold every hive not yet upgraded with the canary's failure as the reason, and tell the owner. - End on `bash scripts/hives-behind.sh` exit 0, and print its `held` lines to the owner with their reasons. 3. Publish: print, then stop. Under a `to publish, run:` heading, print the publish step exactly as the 
::error::ship 2a: the dev build gets a local tag for the next upgrade - expected 'git tag v<version>' in:
        2a. Local beta, only in the VULYK source repo (`install.sh` and `VERSION` at the root; anywhere else skip this step silently). With no registry at `${VULYK_HIVES_FILE:-~/.vulyk/hives}`, print `local beta: no hive registry, rollout skipped` and go on. Otherwise every local hive takes this merge now, unasked (card public-release-per-change): - Bump `VERSION` to the next local build (`X.Y.Z-dev.N` -> `X.Y.Z-dev.<N+1>`, a plain `X.Y.Z` -> `X.<Y+1>.0-dev.1`) and commit it alone as `release: <version> (local, unpublished)`: no tag and no push. - Upgrade a hive: if it has no live hold, is on the branch it ships from and `git -C <hive> status --porcelain` prints nothing, run `./install.sh <hive> --upgrade` from this clone, merge every `.vulyk-new` it leaves into the hive's own edit by hand (card upgrade-overwrites-host-edits), then commit in the hive (`chore(vulyk): upgrade to <version>`), never push. A hive that cannot take it now (another branch, a dirty tree, a running build, a red suite) gets ` | hold <YYYY-MM-DD> <reason>` on its registry line, the date at most 7 days ahead. - Canaries first: upgrade each hive `bash scripts/hives-behind.sh --canaries` prints (registry lines marked ` | canary`, two hives of different shape), then run one quick test row from each canary's own `## Commands` table, preferring a row that runs its tests or `close-story` path. Green on every canary: upgrade the other hives the same way. a red canary stops the rollout: revert that canary's upgrade commit, hold every hive not yet upgraded with the canary's failure as the reason, and tell the owner. - End on `bash scripts/hives-behind.sh` exit 0, and print its `held` lines to the owner with their reasons. 3. Publish: print, then stop. Under a `to publish, run:` heading, print the publish step exactly as the 
::error::ship 2a: a reverted canary is held too - expected 'the reverted canary' in:
        2a. Local beta, only in the VULYK source repo (`install.sh` and `VERSION` at the root; anywhere else skip this step silently). With no registry at `${VULYK_HIVES_FILE:-~/.vulyk/hives}`, print `local beta: no hive registry, rollout skipped` and go on. Otherwise every local hive takes this merge now, unasked (card public-release-per-change): - Bump `VERSION` to the next local build (`X.Y.Z-dev.N` -> `X.Y.Z-dev.<N+1>`, a plain `X.Y.Z` -> `X.<Y+1>.0-dev.1`) and commit it alone as `release: <version> (local, unpublished)`: no tag and no push. - Upgrade a hive: if it has no live hold, is on the branch it ships from and `git -C <hive> status --porcelain` prints nothing, run `./install.sh <hive> --upgrade` from this clone, merge every `.vulyk-new` it leaves into the hive's own edit by hand (card upgrade-overwrites-host-edits), then commit in the hive (`chore(vulyk): upgrade to <version>`), never push. A hive that cannot take it now (another branch, a dirty tree, a running build, a red suite) gets ` | hold <YYYY-MM-DD> <reason>` on its registry line, the date at most 7 days ahead. - Canaries first: upgrade each hive `bash scripts/hives-behind.sh --canaries` prints (registry lines marked ` | canary`, two hives of different shape), then run one quick test row from each canary's own `## Commands` table, preferring a row that runs its tests or `close-story` path. Green on every canary: upgrade the other hives the same way. a red canary stops the rollout: revert that canary's upgrade commit, hold every hive not yet upgraded with the canary's failure as the reason, and tell the owner. - End on `bash scripts/hives-behind.sh` exit 0, and print its `held` lines to the owner with their reasons. 3. Publish: print, then stop. Under a `to publish, run:` heading, print the publish step exactly as the 
::error::ship 2: in the VULYK source the build number comes from 2a - expected 'step 2a numbers the build' in:
        2. History. The spec branch (`**Branch:**`) holds one commit per story; do not squash them, they are the rollback points and the review units. Work out the version from the Profile's *Commit convention* (a semver bump sized to the change). If a story on this branch already wrote `VERSION` and the top `CHANGELOG.md` entry for that version, there is nothing to bump. Otherwise add one commit on the branch with the version bump and the CHANGELOG entry. When the repo has a `CITATION.cff`, the same commit sets its `version` to the new `VERSION` and its `date-released` to today. This is release paperwork: Law 5 does not apply, and `VERSION`, `CHANGELOG.md` and `CITATION.cff` are paperwork to the cycle, so this commit does not stale a GREEN round. Then merge into the default branch the way the Profile's *Release / deploy* row says; a local merge is reversible and yours to run. A local merge: switch to the default branch only when `git status --porcelain` prints nothing, then `git merge --no-ff <branch>`. If it fails, run `git merge --abort`, switch back to the spec branch, tell the owner what git printed, and stop. After a clean merge, delete the spec branch with `git branch -d <branch>`, never `-D`; if `-d` refuses, quote what it printed and leave the branch. 2a. Local beta, only in the VULYK source repo (`install.sh` and `VERSION` at the root; anywhere else skip this 
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
maintenance.test.sh: 556 checks, 6 failed
```

## Implementation notes
- Major 1: ship 2a bumps every tracked `.claude-plugin/plugin.json` `version` with `VERSION` in the same commit (tests/mods.test.sh, telemetry mods2 pin them).
- Major 2: ship 2a tags the dev build locally (`git tag v<version>`), never pushed; card Allowed already permits a local -dev.N tag. Test phrase `no tag and no push` replaced by `never pushed`.
- Minor hold cap: `day_number` (days-from-civil, bash arithmetic, no GNU date) rejects a day that does not exist, an expired hold and one more than `HOLD_MAX_DAYS=7` ahead; tests cover 7 vs 8 days, 2026-02-30, both sides of a year end.
- Minor exit match: `hb` prints `[exit=N]` and every needle matches the bracketed form, so `exit=127` no longer passes for `exit=1`.
- Minor step 2: in the VULYK source with a registry step 2 makes no bump; the entry goes under `[Unreleased]` and 2a numbers the build.
- Minor canary: a red canary's revert holds the canary too.
- Minor suite.log head: informational (only round paperwork after 5d232ff3), no change.
- maintenance.test.sh: 556 checks, 0 failed.
