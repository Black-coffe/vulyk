---
story: mass-audit-fixes-19
status: todo
returned:
worker: worker-code
model: opus
wave: 6
blocked_by: []
---

# Repair round 2

## Goal
Make the asks and findings council round 2 left RED pass, and change nothing else.

## Requirements
No brief ask is RED in round 2 - the findings below are the whole task.

## Findings
1. install.sh:1572 [regression] the suite's --upgrade fixtures that model a hive at the current release (fresh_install writes vulyk-version 0.49.0) with the six entries missing must pass again on head: `wire_entry` reads `v0.49.0:.claude/settings.json`, finds each hook there and names it `unwired` instead of wiring it, so tests/intake.test.sh:366 (`.hooks.PostToolUse |= map(select(.matcher != "AskUserQuestion"))` then `--upgrade`) fails `the PostToolUse AskUserQuestion block runs defect-intake.sh answer - expected '1', got '0'` and tests/telemetry.test.sh:2362 `wrapper_hive` (settings.json cut to update-check + anomaly-scan, then `--upgrade`) fails `plain: intake wired in the host's form - expected [...defect-intake.sh], got []` and its inject/reset siblings in parts wrapper, wrapper2, launchers, and wrapper3's `fixture: four defect entries lost their closing quote`; the fixtures must pin an installed release that did not yet wire those hooks (as install-xp2's v0.31.0 neighbour and the library part's `rm -f vulyk-version` at tests/telemetry.test.sh:2309 do) or assert the named `unwired` line - tests/intake.test.sh is outside the repair story's `## Files`, so the next repair story must name it - repro: `bash tests/intake.test.sh --part functional` (118 checks, 1 failed) and `bash tests/telemetry.test.sh --part wrapper` (11 checks, 3 failed); base: round-1 suite.log lines 58, 79, 88-90 `PART intake:functional ok 98s`, `PART telemetry:wrapper ok 55s`, `wrapper2 ok 42s`, `wrapper3 ok 67s`, `launchers ok 73s`.
1. install.sh:1572 [regression] the suite's `--upgrade` fixtures that model a hive stamped at the current release (0.49.0, from `fresh_install`) with hook entries missing must pass again: `wire_entry` finds each hook in `v0.49.0:.claude/settings.json`, reads the missing entry as an owner's removal and names it `unwired` instead of wiring it, so tests/intake.test.sh:366 (`.hooks.PostToolUse |= map(select(.matcher != "AskUserQuestion"))` then `--upgrade`) fails `the PostToolUse AskUserQuestion block runs defect-intake.sh answer - expected '1', got '0'`, and tests/telemetry.test.sh `wrapper_hive` fixtures (settings.json cut to update-check + anomaly-scan, then `--upgrade`) fail `plain: intake wired in the host's form`, `inject wired in the host's form`, `reset wired in the host's form` (parts wrapper, wrapper2, wrapper3, launchers) - the fixtures must pin an installed release that did not yet wire those hooks (as install-xp2's v0.31.0 neighbour and the library part's `rm -f vulyk-version` do) or assert the named `unwired` line, and tests/intake.test.sh is outside story 18's `## Files`, so the next repair story must name it - repro: `bash tests/intake.test.sh --part functional` (118 checks, 1 failed) and `bash tests/telemetry.test.sh --part wrapper` (11 checks, 3 failed), both rerun here; base: round-1 suite.log has `PART intake:functional ok 98s`, `PART telemetry:wrapper ok 55s`, `wrapper2 ok 42s`, `wrapper3 ok 67s`, `launchers ok 73s`.
- [regression] PART intake:functional FAIL 98s cap 300s
- [regression] PART telemetry:wrapper FAIL 48s cap 300s
- [regression] PART telemetry:wrapper2 FAIL 48s cap 300s
- [regression] PART telemetry:wrapper3 FAIL 76s cap 300s
- [regression] PART telemetry:launchers FAIL 79s cap 300s

## Files
- tests/intake.test.sh
- tests/telemetry.test.sh

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/telemetry.test.sh --part wrapper && bash tests/telemetry.test.sh --part wrapper2`
`bash tests/telemetry.test.sh --part wrapper3 && bash tests/telemetry.test.sh --part launchers`
`bash tests/telemetry.test.sh --part install-xp2`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- Revised by the Queen: the generated Files and Verification inherited all 18 stories; the finding is test fixtures only, so the story names the two test files whose parts went red and those parts (install-xp2 stays as the ask-18 guard). Only the Critical finding above is in scope; the seats' Minor and UNASKED lines are not.
- install.sh is correct per both reviewers and council-opus (ask 18 GREEN): do not edit it. Fix the fixtures: a hive that models an upgrade wiring these hooks pins an installed release that did not yet ship them (as install-xp2's v0.31.0 neighbour or the library part's `rm -f vulyk-version` do), so the wrapper-form wiring each test checks keeps its coverage; assert the `unwired` line only where a test means an owner's removal.
- red mark dropped by the Queen: the change touches no implementation (tests only, HEAD's install.sh already behaves as ask 18 wants), so no test can fail before an implementation edit and stamp-red has nothing to seal; the proof is the five red parts going green in this story's verification.
