<!-- seat: review · model: claude-opus-5-5 · round: 1 · head: a913d6a · pack: 8abd40c22920 · attempt: 1 · recorded: 2026-10-15T17:56:28Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-opus-5-5

## Critical
None.
## Major
1. install.sh:883 [ask 5] the settings install.sh writes into a hive (and VULYK's own .claude/settings.json:3-8) must actually load vulyk-watcher@vulyk, or the shrink must be recorded in plan ## Descoped with the owner's decision; story -01 measured M1 = NO, and the plan's own rule ("if neither loads without a machine path or a question, the Queen stops and asks the owner") was skipped with ## Plan deltas left empty - repro: in a temp dir holding .claude/mods/vulyk-watcher and the exact shipped keys, `claude -p --debug-file dbg.txt "say ok"; grep vulyk dbg.txt` shows "Skipping orphaned enabledPlugins entry vulyk-watcher@vulyk: marketplace not registered" and "Skipped auto-recording vulyk-watcher@vulyk - enabled only by repo-authored settings", with no hooks-module-loaded line, and `claude plugin list` / `claude plugin marketplace list` there show no vulyk entry (asks 1-4 and 6 depend on this: the mod never runs in a hive).
## Minor
- .github/workflows/ci.yml:701 the install-smoke and tests/telemetry.test.sh:1398-1419 assert only that the keys and tree exist, so they stay green while the mod does not load; nothing checks the load itself.
- tests/telemetry.test.sh:1399 the new `tr -d` calls carry a literal CR byte between the quotes (works, but it is the install-sh-literal-cr-bytes pattern; write `$'\r'`).
- install.sh:1000 a non-object `extraKnownMarketplaces` exits 4 and prints "could not be parsed as JSON", which misnames the cause.
- tests/telemetry.test.sh hit the 540 s timeout locally after all watcher assertions passed (lines 398-411 of the run all ok); the rest of the suite was not reached.
- docs/watcher.md:66 the "Known limit" understates M1: the measured result is that the project-scope keys do not load the mod at all in -p, for every path form tried.
