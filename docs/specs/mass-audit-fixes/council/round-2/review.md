<!-- seat: review · model: claude-fable-5-1 · round: 2 · head: 2de7768 · pack: 69942212bcbb · attempt: 1 · recorded: 2026-11-09T18:35:15Z · verdict: BLOCK -->
VERDICT: BLOCK
SUITE: FAIL 956s - part intake:functional failed, part telemetry:wrapper failed, part telemetry:wrapper2 failed, part telemetry:wrapper3 failed, part telemetry:launchers failed
MODEL: claude-fable-5-1

## Critical
1. install.sh:1572 [regression] the suite's --upgrade fixtures that model a hive at the current release (fresh_install writes vulyk-version 0.49.0) with the six entries missing must pass again on head: `wire_entry` reads `v0.49.0:.claude/settings.json`, finds each hook there and names it `unwired` instead of wiring it, so tests/intake.test.sh:366 (`.hooks.PostToolUse |= map(select(.matcher != "AskUserQuestion"))` then `--upgrade`) fails `the PostToolUse AskUserQuestion block runs defect-intake.sh answer - expected '1', got '0'` and tests/telemetry.test.sh:2362 `wrapper_hive` (settings.json cut to update-check + anomaly-scan, then `--upgrade`) fails `plain: intake wired in the host's form - expected [...defect-intake.sh], got []` and its inject/reset siblings in parts wrapper, wrapper2, launchers, and wrapper3's `fixture: four defect entries lost their closing quote`; the fixtures must pin an installed release that did not yet wire those hooks (as install-xp2's v0.31.0 neighbour and the library part's `rm -f vulyk-version` at tests/telemetry.test.sh:2309 do) or assert the named `unwired` line - tests/intake.test.sh is outside the repair story's `## Files`, so the next repair story must name it - repro: `bash tests/intake.test.sh --part functional` (118 checks, 1 failed) and `bash tests/telemetry.test.sh --part wrapper` (11 checks, 3 failed); base: round-1 suite.log lines 58, 79, 88-90 `PART intake:functional ok 98s`, `PART telemetry:wrapper ok 55s`, `wrapper2 ok 42s`, `wrapper3 ok 67s`, `launchers ok 73s`.

## Major
None.

## Minor
- docs/specs/mass-audit-fixes/council/round-2/suite.log:1 says `head=7b54bf6`, the reviewed head is 2de7768; `git diff --stat 7b54bf6..2de7768` holds only ROUND, suite.log, journal.md and anomalies.jsonl, so the SUITE line is copied as it stands.
- Round 1's three blocking findings are fixed on head: `PART e2e:green ok 29s`, `e2e:red ok 50s` (fixture commits as `vulyk(demo): plan`), `council:escalate ok 73s` (r2m2 asserts `git (add|commit)`), `council:suite ok 160s` + `suite2 ok 109s`, and ask 18's six-removal case passes in `install-xp2 ok 154s`.
- install.sh:1572 wire_entry decides from `git -C "$SRC" show v$PREV:.claude/settings.json`: an install source with no such tag (an archive, a cache cloned without tags) falls through to wire_hook and puts a removed hook back silently - the same gap the git-guard `cat-file -e` check already has; not a listed configuration.
- install.sh:709 PREV is read on a plain (non --upgrade) `install.sh <hive>` too, so re-running a fresh install over an existing 0.49.0 hive now names a missing shipped hook instead of wiring it; the brief names `--upgrade` only.
