---
story: mass-audit-fixes-19
status: todo
returned:
worker: worker-code
model: opus
wave: 6
blocked_by: []
red: required
red_reason:
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
- .claude/hooks/defects-inject.sh
- scripts/defects-check.sh
- .claude/hooks/defects_lib.py
- docs/defects/README.md
- tests/inject.test.sh
- tests/defects.test.sh
- .claude/hooks/git-guard.sh
- tests/maintenance.test.sh
- .claude/hooks/defect-intake.sh
- tests/intake.test.sh
- install.sh
- .claude/settings.json
- tests/telemetry.test.sh
- scripts/cycle.sh
- tests/cycle.test.sh
- tests/council.test.sh
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- docs/model-cascade.md
- .claude/hooks/top-model-brief.sh
- tests/model-profile.test.sh
- scripts/top-model.sh
- scripts/redact.sh
- .claude/hooks/handoff.py
- .claude/hooks/handoff.sh
- tests/handoff-hooks.test.py
- tests/handoff.test.sh
- scripts/ship-check.sh
- scripts/scope-check.sh
- scripts/wave-check.sh
- templates/plan.md
- tests/solo.test.sh
- scripts/vulyk-update.sh
- .claude/hooks/vulyk-update-check.sh
- scripts/telemetry.sh
- scripts/lib.sh
- .github/workflows/ci.yml
- .claude/hooks/anomaly-scan.sh
- scripts/leak-check.sh
- scripts/injection-check.sh
- .claude/hooks/skill-usage-counter.sh
- docs/adr/032-story-trust-from-git.md
- docs/adr/025-red-receipt.md
- docs/adr/001-cycle-state-contract.md
- docs/cycle.md
- docs/hooks-reference.md
- CLAUDE.md
- .claude/agents/lead-review.md
- .claude/agents/worker-code.md
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-plan.md
- .claude/commands/vulyk-ship.md
- CITATION.cff
- docs/grill/2026-10-07-sdd-course-improvements.md
- docs/specs/constitution-merge/brief.md
- docs/specs/token-audit/evidence/forensics.md
- docs/specs/token-audit/report.md
- tests/e2e.test.sh

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/maintenance.test.sh`
`bash tests/telemetry.test.sh --part wiring && bash tests/telemetry.test.sh --part install`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
`bash tests/cycle.test.sh --part ship && bash tests/cycle.test.sh --part close && bash tests/cycle.test.sh --part red`
`bash tests/council.test.sh --part verbs && bash tests/council.test.sh --part close`
`bash tests/driver.test.sh`
`bash tests/model-profile.test.sh`
`bash tests/cycle.test.sh --part ship && bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part gates && bash tests/cycle.test.sh --part hooklog`
`bash tests/solo.test.sh`
`bash tests/telemetry.test.sh --part install-xp && bash tests/telemetry.test.sh --part scan`
`bash tests/cycle.test.sh --part red && bash tests/cycle.test.sh --part close`
`bash tests/council.test.sh --part suite && bash tests/council.test.sh --part hardening`
`bash tests/telemetry.test.sh --part install && bash tests/telemetry.test.sh --part install-xp`
`bash tests/cycle.test.sh --part bsd`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/cycle.test.sh --part gates`
`bash tests/telemetry.test.sh --part install-xp && bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part install-xp`
`bash tests/telemetry.test.sh --part install-xp2`
`bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part wiring`
`bash tests/e2e.test.sh`
`bash tests/council.test.sh --part escalate`
`bash tests/council.test.sh --part suite && bash tests/council.test.sh --part suite2`
