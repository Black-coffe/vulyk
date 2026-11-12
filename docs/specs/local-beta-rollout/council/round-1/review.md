<!-- seat: review · model: claude-fable-5-2 · round: 1 · head: 0ad50bf7 · pack: 3efc00cf5778 · attempt: 1 · recorded: 2026-11-12T17:46:29Z · verdict: BLOCK -->
VERDICT: BLOCK
SUITE: ok 1158s
MODEL: claude-fable-5-2

## Critical
None.
## Major
1. .claude/commands/vulyk-ship.md:46 [ask 1] the dev bump of step 2a must leave the repo's own gate green: `VERSION` committed alone breaks the plugin.json pin (tests/mods.test.sh:22-28, tests/telemetry.test.sh:2436), so the next spec's suite is red after the first rollout - repro: on a copy of the head (`git archive 0ad50bf7 | tar -x -C <tmp>`) set `<tmp>/VERSION` to `0.52.0-dev.1`, then `bash <tmp>/tests/mods.test.sh` prints `plugin.json version '0.51.0' is not VERSION '0.52.0-dev.1'` and exits 1 (seen this round); the same state sat at bdd64af9 (VERSION 0.51.0-dev.1 beside plugin.json 0.50.3).
2. .claude/commands/vulyk-ship.md:46 [ask 1] a hive stamped with a dev build by step 2a must find that build as `v<version>` in the clone at its next upgrade (a local ref, never pushed): with "no tag", from the second rollout on install.sh treats every hive as PREV_UNKNOWN (install.sh:1748), so a hook the new build brings is named, not wired (install.sh:1754, 1794, 1804), every hive-edited framework file gets a `.vulyk-new` even when the build left it alone (install.sh:219-240), and a retired file the hive edited is removed, not kept (install.sh:1668-1673); tests/maintenance.test.sh:1134 pins the phrase `no tag and no push`.
## Minor
- scripts/hives-behind.sh:41 the 7-day cap on a hold (plan Assumptions: "a hold cannot become the new later") lives only in the ship prose: `<hive> | hold 2099-12-31 later` and `hold 2026-99-99 later` on a lagging hive both exit 0.
- tests/maintenance.test.sh:1100 `expect ... "exit=1"` is a substring match that also passes on `exit=127` (lines 1103-1124 too); the story's Red receipt shows the red_reason check as `ok` with the script absent, the red came from the other nine checks.
- .claude/commands/vulyk-ship.md:30 step 2 still makes its own semver bump in the VULYK repo, so each ship turns `X.Y.Z-dev.N` into a plain number and 2a then jumps to the next minor's `-dev.1`; the `-dev.<N+1>` branch of 2a is reached only when step 2 bumps nothing.
- .claude/commands/vulyk-ship.md:56 a reverted canary lags with no hold while the step must end on `hives-behind.sh` exit 0; "hold every hive not yet upgraded" should name the reverted canary too.
- docs/specs/local-beta-rollout/council/round-1/suite.log reads `head=5d232ff3` (the ROUND head); 8e9f7996 and 0ad50bf7 after it hold only round paperwork, so the SUITE line is copied as is.
