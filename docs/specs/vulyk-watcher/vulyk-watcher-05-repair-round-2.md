---
story: vulyk-watcher-05
status: done
returned: DONE
worker: worker-code
model: opus
wave: 4
blocked_by: []
---

# Repair round 2

## Goal
Make the asks and findings council round 2 left RED pass, and change nothing else.

## Requirements
> 5. install.sh ставит, обновляет и включает мод в каждом улье; твоё false сохраняется, выключатель в settings.local.json.

> (2) Owner's spend decision: the mod appends each fork's usage to memory/stats/watcher.jsonl, scripts/token-report.py shows it as its own line, at most 30 forks per session.

## Findings
ASK 5: RED - install.sh installs, UPDATES and enables in every hive; false kept; switch in settings.local.json - run: VULYK_CLAUDE=stub install.sh <hive> then install.sh <hive> --upgrade saw: first run calls "plugin marketplace add Black-coffe/vulyk" + "plugin install vulyk-watcher@vulyk --scope user"; on --upgrade the only call is "plugin list", then return 0 - no "claude plugin update" / "plugin marketplace update" ever runs (both exist in 2.1.300), so a VULYK upgrade never updates the machine's watcher; docs/watcher.md: "A machine that has it already is left alone"; plugin.json version is a fixed 0.1.0 not tied to VERSION. Install and the kept false ("kept .claude/settings.local.json -> ... false") work
1. install.sh:1046 [ask 5] a VULYK `--upgrade` (or a release) must bring the machine's installed vulyk-watcher@vulyk up to the release's mod, or the loss of "обновляет" must be recorded in plan `## Descoped` with the owner's decision; today a listed plugin returns at once, so the machine keeps the first-installed copy forever while the hive only receives a `.claude/mods/vulyk-watcher` tree that nothing loads (plugin.json stays `0.1.0`, plan `## Descoped` is `(empty)`) - repro: stub `claude` whose `plugin list` prints `vulyk-watcher@vulyk`, `VULYK_CLAUDE=<stub> bash install.sh <hive> --upgrade` logs only `plugin list` (no marketplace update, no `plugin update`); local evidence that a user-scope GitHub install does not refresh itself: `jq -c '.plugins["litopys@litopys"][]|{scope,version}' ~/.claude/plugins/installed_plugins.json` shows user scope at 0.2.1 while `~/.claude/plugins/marketplaces/litopys/.claude-plugin/plugin.json` is 0.4.0.

REOPEN CONDITIONS (Queen, 2026-10-15, owner's decisions in brief `After escalation` and plan `## Plan deltas`):
  A. The finding above: `install.sh --upgrade` (and a fresh run on a machine that already has it) refreshes the installed
     `vulyk-watcher@vulyk`: `claude plugin marketplace update vulyk` then `claude plugin update vulyk-watcher@vulyk`; `--check`
     prints `would update`; no `claude` -> NOTE; never fails the install. `plugin.json` `version` equals `VERSION` (a test
     asserts it, so a release cannot ship a stale mod version). docs/watcher.md drops "a machine that has it already is left alone".
  B. Spend: after every fork the mod appends one JSON row (ts, session id, the fork's `usage` four counts, answered or reason)
     to `memory/stats/watcher.jsonl` in the project; `scripts/token-report.py` prints the watcher's total as its own line (all
     sessions in the window), extended in `tests/token-report.test.sh` (run it yourself as a targeted check; CI runs it).
     A ceiling of 30 forks per session: past it, no fork, silence. Tests for the row and the ceiling in core.test.ts.

Worker question (2026-10-15): close-story exit 4, "verification timed out after 540s: bash tests/telemetry.test.sh". Run standalone the same suite passes, 518 checks, 0 failed, but takes 977 s on this box, so no change within ## Files can bring it under the verb's 540 s VULYK_VERIFY_TIMEOUT default, and the Bash tool's 600 s cap rules out a foreground rerun with a longer limit. Should close-story run with a raised VULYK_VERIFY_TIMEOUT (e.g. 1500, in the background), or is the suite's speed separate work?

## Files
- scripts/token-report.py
- tests/token-report.test.sh
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
- .claude-plugin/marketplace.json

## Verification
`bash tests/watcher.test.sh`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- install.sh: a listed vulyk-watcher@vulyk now runs `plugin marketplace update vulyk` + `plugin update ... --scope user`; `--check` says `would update`; a failed update prints a NOTE, rc 0.
- plugin.json version 0.1.0 -> 0.26.2 (= VERSION); tests/telemetry.test.sh asserts the equality, plus update/--check/failed-update cases (stub gained a `plugin update` fail switch).
- core.ts: MAX_FORKS 30 + `fork-cap` skip reason, SPEND_FILE, spendRow, appendRow; register.tsx counts forks per session and appends a row after every fork (read + write: `$.fs` has no append), session id from `$.session.id()` (found in the 2.1.300 binary).
- core.test.ts: ceiling, row (answered and reason) and append tests; existing skipReason calls pass `forks: 0`.
- token-report.py: `watcher` key in JSON and a `watcher:` line after the table; not attributed to a spec, not in TOTAL; read price 0.1 (rows carry no model). Test rows written inline (fixtures dir is not in Files).
- docs/watcher.md and ADR 005 drop "left alone", describe the update, the 30-fork ceiling and the ledger.
- Not touched: hooks.json, marketplace.json files, settings.json, ci.yml.
- Redispatched with the timeout question unanswered: closed with `VULYK_VERIFY_TIMEOUT=1800` (the verb's own knob) in the background; telemetry.test.sh passes standalone in ~977 s here, its speed is separate work.
