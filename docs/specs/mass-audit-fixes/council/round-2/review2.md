<!-- seat: review2 · model: claude-sonnet-5-5 · round: 2 · head: 2de7768 · pack: 69942212bcbb · attempt: 1 · recorded: 2026-11-09T18:38:59Z · verdict: BLOCK -->
VERDICT: BLOCK
SUITE: FAIL 956s - part intake:functional failed, part telemetry:wrapper failed, part telemetry:wrapper2 failed, part telemetry:wrapper3 failed, part telemetry:launchers failed
MODEL: claude-sonnet-5-5

## Critical
1. install.sh:1572 [regression] the suite's `--upgrade` fixtures that model a hive stamped at the current release (0.49.0, from `fresh_install`) with hook entries missing must pass again: `wire_entry` finds each hook in `v0.49.0:.claude/settings.json`, reads the missing entry as an owner's removal and names it `unwired` instead of wiring it, so tests/intake.test.sh:366 (`.hooks.PostToolUse |= map(select(.matcher != "AskUserQuestion"))` then `--upgrade`) fails `the PostToolUse AskUserQuestion block runs defect-intake.sh answer - expected '1', got '0'`, and tests/telemetry.test.sh `wrapper_hive` fixtures (settings.json cut to update-check + anomaly-scan, then `--upgrade`) fail `plain: intake wired in the host's form`, `inject wired in the host's form`, `reset wired in the host's form` (parts wrapper, wrapper2, wrapper3, launchers) - the fixtures must pin an installed release that did not yet wire those hooks (as install-xp2's v0.31.0 neighbour and the library part's `rm -f vulyk-version` do) or assert the named `unwired` line, and tests/intake.test.sh is outside story 18's `## Files`, so the next repair story must name it - repro: `bash tests/intake.test.sh --part functional` (118 checks, 1 failed) and `bash tests/telemetry.test.sh --part wrapper` (11 checks, 3 failed), both rerun here; base: round-1 suite.log has `PART intake:functional ok 98s`, `PART telemetry:wrapper ok 55s`, `wrapper2 ok 42s`, `wrapper3 ok 67s`, `launchers ok 73s`.

## Major
None.

## Minor
- docs/specs/mass-audit-fixes/council/round-2/suite.log:1 says `head=7b54bf6`, the reviewed head is 2de7768; `git diff --name-only 7b54bf6..2de7768` holds only ROUND, suite.log, journal.md and anomalies.jsonl, so the SUITE line is copied as it stands.
- Round 1's three blocking findings are fixed on head per the log: `e2e:green ok 29s`, `e2e:red ok 50s`, `council:escalate ok 73s`, `council:suite ok 160s` + `suite2 ok 109s`, `install-xp ok 139s` + `install-xp2 ok 154s`.
- install.sh:1572 wire_entry decides from `git -C "$SRC" show v$PREV:.claude/settings.json`: a source with no such tag (archive, cache cloned without tags) falls through to wire_hook and silently puts a removed hook back; not a listed configuration. PREV is only ever spliced after a `v` prefix into a git rev (no option injection), and `none`/empty PREV falls to wire_hook, so no security or data-loss path found.
- install.sh:709 PREV is read on a plain (non `--upgrade`) `install.sh <hive>` as well, so re-running a fresh install over an existing 0.49.0 hive names a missing shipped hook instead of wiring it; the brief names `--upgrade` only.
