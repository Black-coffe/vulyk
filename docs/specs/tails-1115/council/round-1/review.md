<!-- seat: review · model: claude-fable-5-2 · round: 1 · head: d60a9b51 · pack: 2d6f016f0a85 · attempt: 1 · recorded: 2026-11-17T17:39:41Z · verdict: BLOCK -->
VERDICT: BLOCK
SUITE: FAIL 1688s - cut part council:round-scope2, cut part council:round-scope, part telemetry:rg2 failed
MODEL: claude-fable-5-2

## Critical
1. tests/telemetry.test.sh:2855 [regression] suite telemetry part rg2 is red (also :2859, :2868): its three "nothing is written locally" checks must hold now that install.sh:2243 only offers the model pin, since they still expect the `null` that a settings.local.json created by the unconditional pin used to give - repro: `bash tests/telemetry.test.sh --part rg2` -> `8 checks, 3 failed` (expected [1 null], got [1 ]); base: `git show 8291c19b:install.sh` lines 2059-2067 run `top-model.sh --apply` with no flag, and `PART telemetry:rg2 ok 48s` in docs/specs/narrow-repair-1115/council/merge-suite.log
2. tests/council.test.sh:5388 [regression] suite council parts round-scope (282 s) and round-scope2 (234 s) are cut for running past 70% of their 300 s cap after story 13 added its cases to both: each part must end under 210 s, by a split, never a raised cap (card test-gate-one-long-limit, How-to) - repro: `bash scripts/suite-parts-check.sh docs/specs/tails-1115/council/round-1/suite.log` -> two `cut part ... (grew)` lines, exit 1; base: 156-187 s for both parts in docs/specs/narrow-repair-1115/council/*/suite.log
## Major
1. .claude/commands/vulyk-gc.md:15 [ask 6] with the PreCompact snapshot retired, `/vulyk-gc` must not delete snapshot files already in a hive: the line this diff rewrote still runs `find memory/snapshots -type f -mtime +14 ! -name .gitkeep -delete` (also vulyk-gc.md:2 and :10, .claude/agents/librarian.md:21), so the first gc after 14 days removes every snapshot the hive holds, against the ask's "without deleting any data already in a hive" and story 06's own "memory/snapshots/ is never touched"
2. scripts/token-report.py:65 [unanchored] the cache-read share for Sonnet 5.5 must follow the checked fact (cc-facts.md F13: 0.05) in token-report.py and in .claude/mods/vulyk-pulse/hooks/core.ts:50 with its pin in core.test.ts, or the gap must be recorded as descoped: both tables keep 0.1 and the code comment says so (story 04 notes, line 90)
## Minor
- install.sh:2033 the UserPromptExpansion entry is wired again on every upgrade whose source has no `v$PREV` tag (a ZIP, an untagged build), even after the owner removed it; the stamped-commit base is not consulted
- .claude/hooks/defects-inject.sh `read_only` judges only command words, so a PowerShell block that writes can read as read-only and get no card
- install.sh:2222 `report_blind_cards` reads only an inline `paths: [...]`; a card with a multi-line YAML list would be named as reaching no worker
- scripts/cycle.sh:5466 `reopen <spec> --full "<decision>"` records `--full` as the decision text; the flag is honoured only after the decision
- docs/memory-system.md:19 still describes the retired PreCompact snapshot as compaction insurance
