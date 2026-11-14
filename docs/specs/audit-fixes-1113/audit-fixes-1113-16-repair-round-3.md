---
story: audit-fixes-1113-16
status: todo
returned:
worker: worker-code
model: opus
wave: 8
blocked_by: []
red: required
red_reason:
---

# Repair round 3

## Goal
Make the asks and findings council round 3 left RED pass, and change nothing else.

## Requirements
No brief ask is RED in round 3 - the findings below are the whole task.

## Findings
1. tests/full-suite.sh:172 [regression] the round's suite must end `SUITE: ok`: the part `telemetry:wiring` (`bash tests/telemetry.test.sh --part wiring`) must finish under 70% of its 300 s cap (210 s) when it runs inside step 6 beside its eleven neighbours; at the head it took 212 s and the gate cut it (STEP 6/10 FAIL), while the base 11ab8fe3 ran it in 200 s with `SUITE: ok 1192s` (docs/specs/audit-fixes-1113/council/round-2/suite.log). No check failed: rerun alone it gave `85 checks, 0 failed`, exit 0, 174 s, and the round's diff (one agent prompt) changes nothing the part runs, so the condition is time headroom for this part with the cap and the 70% line left as they are (card test-gate-one-long-limit) - repro: `bash scripts/suite-parts-check.sh docs/specs/audit-fixes-1113/council/round-3/suite.log` prints `cut part telemetry:wiring: 212s of cap 300s (grew)` and exits 1; the same command on the round-2 log exits 0.
- [regression] PART telemetry:wiring ok 212s cap 300s

## Files
- scripts/version-order.sh
- .claude/hooks/vulyk-update-check.sh
- scripts/vulyk-update.sh
- tests/telemetry.test.sh
- scripts/redact.sh
- .claude/hooks/handoff.py
- scripts/telemetry.sh
- docs/telemetry.md
- tests/maintenance.test.sh
- tests/handoff-hooks.test.py
- scripts/cycle.sh
- scripts/lib.sh
- scripts/ship-check.sh
- scripts/scope-check.sh
- .claude/commands/vulyk-ship.md
- docs/defects/public-release-per-change.md
- docs/defects/INDEX.md
- tests/cycle.test.sh
- tests/council.test.sh
- scripts/leak-check.sh
- docs/defects/host-internals-in-public-repo.md
- .claude/hooks/defects-inject.sh
- .claude/settings.json
- tests/inject.test.sh
- tests/defects.test.sh
- docs/specs/self-learning/contract.md
- docs/defects/command-injection-follows-cwd.md
- docs/grill/2026-09-27-self-learning-corrections.md
- docs/grill/2026-09-27-self-learning-pilot-feedback.md
- docs/specs/beta-feedback-1113/brief.md
- docs/specs/beta-fixes-1113/brief.md
- docs/specs/claude-code-mods-9/research-anthropic.md
- docs/specs/claude-code-mods-9/research-budget-memory.md
- docs/specs/claude-code-mods-9/research-ui.md
- docs/specs/close-story-scope-refusal/close-story-scope-refusal-02-repair-round-1.md
- docs/specs/close-story-scope-refusal/council/round-1/review.md
- docs/specs/constitution-merge/brief.md
- docs/specs/constitution-merge/constitution-merge-02.md
- docs/specs/constitution-merge/plan.md
- docs/specs/fable-budget/brief.md
- docs/specs/gate-split/gate-split-03-cut-long-suites.md
- docs/specs/gate-split/gate-split-04-round-suite-verb.md
- docs/specs/gate-split/gate-split-05-driver-and-reviewer.md
- docs/specs/handoff-cwd/brief.md
- docs/specs/handoff-ownership/brief.md
- docs/specs/handoff-ownership/plan-review/BRIEF.md
- docs/specs/handoff-ownership/plan.md
- docs/specs/hindsight-harvest/hindsight-harvest-01.md
- docs/specs/hindsight-memory/evidence/brief-r2.md
- docs/specs/hindsight-memory/evidence/r1-opus.md
- docs/specs/hindsight-memory/evidence/r1-sonnet.md
- docs/specs/hindsight-memory/evidence/r2-fable.md
- docs/specs/hindsight-memory/evidence/r2-opus.md
- docs/specs/hindsight-memory/evidence/r2-sonnet.md
- docs/specs/next-circle-0-22/council/round-1/review.md
- docs/specs/self-learning/plan.md
- docs/specs/token-audit/evidence/scripts/council_collect.py
- docs/specs/token-audit/evidence/scripts/specs_collect.py
- tests/intake.test.sh
- docs/specs/handoff-ownership/plan-review/fable.md
- docs/specs/token-audit/evidence/scripts/item6c.py
- docs/specs/v0-12-0-remainders/brief.md
- docs/specs/token-audit/evidence/forensics.md
- docs/specs/token-audit/evidence/scripts/item3b.py
- docs/specs/token-audit/evidence/scripts/item4b.py
- docs/specs/token-audit/evidence/scripts/item6b.py
- docs/specs/token-audit/evidence/scripts/parse_all.py
- docs/specs/anomaly-telemetry/council/round-1/opus.md
- docs/specs/anomaly-telemetry/council/round-4/opus.md
- docs/specs/anomaly-telemetry/council/round-5/opus.md
- docs/specs/anomaly-telemetry/council/round-6/opus.md
- docs/grill/2026-09-21-project-memory-chronicle.md
- docs/specs/next-circle-0-22/plan.md
- docs/specs/post-037-tails/brief.md
- docs/specs/mass-audit-fixes/mass-audit-fixes-14-client-name-scrub.md
- docs/specs/vulyk-pulse/study-recon-sonnet.md
- docs/specs/anomaly-telemetry/plan.md
- docs/adr/034-busy-hives-are-held-one-green-canary-carries.md
- docs/specs/post-052-tails/plan.md
- docs/specs/post-052-tails/post-052-tails-01.md
- docs/specs/post-052-tails/post-052-tails-03.md
- docs/specs/post-052-tails/post-052-tails-04-repair-round-1.md
- docs/specs/rules-tree/council/round-1/review.md
- docs/specs/rules-tree/council/round-2/review.md
- docs/specs/rules-tree/rules-tree-07-repair-round-1.md
- docs/specs/autonomous-cycle/council/round-3/review.md
- docs/specs/convergent-judge/council/round-2/sonnet.md
- docs/specs/trace-autopsy/horizon.md
- docs/specs/trace-autopsy/trace-autopsy-01-script.md
- docs/specs/uncommitted-work-guard/uncommitted-work-guard-04-repair-round-1.md
- docs/specs/uncommitted-work-guard/uncommitted-work-guard-05-repair-round-2.md
- .claude/hooks/session-start-brief.sh
- .claude/hooks/context-guard.sh
- .claude/hooks/ysk-offer.sh
- .claude/hooks/top-model-brief.sh
- .claude/hooks/handoff.sh
- .claude/hooks/skill-usage-counter.sh
- README.md
- docs/getting-started.md
- tests/handoff.test.sh
- install.sh
- scripts/upgrade-base-check.sh
- templates/memory.md
- .github/workflows/ci.yml
- .claude/commands/vulyk-update.md
- docs/defects/upgrade-overwrites-host-edits.md
- docs/defects/upgrade-overwrites-host-edits.original.fixture
- docs/defects/upgrade-overwrites-host-edits.neighbour.fixture
- scripts/defects-check.sh
- docs/defects/.scrub-revs
- .claude/hooks/git-guard.sh
- docs/defects/work-discarded-by-git-verb.md
- docs/defects/work-discarded-by-git-verb.shell.fixture
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- .claude/hooks/owner-guard.sh
- .claude/hooks/court-guard.sh
- docs/defects/owner-words-by-builder.md
- docs/defects/owner-words-by-builder.original.fixture
- docs/defects/owner-words-by-builder.neighbour.fixture
- .claude/agents/council-opus.md
- .claude/agents/council-haiku.md
- tests/solo.test.sh
- tests/e2e.test.sh
- docs/hooks-reference.md
- CHANGELOG.md
- scripts/human-check.sh
- scripts/acceptance-log.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-plan.md
- docs/cycle.md
- docs/adr/032-*.md
- docs/adr/032-story-trust-from-git.md

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`
