---
story: audit-fixes-1113-17
status: todo
returned:
worker: worker-code
model: opus
wave: 9
blocked_by: []
red: required
red_reason:
---

# Repair round 4

## Goal
Make the asks and findings council round 4 left RED pass, and change nothing else.

## Requirements
> 5. git-guard covers every git form that discards uncommitted work or commits, including git run through a shell, an alias or a heredoc fed to a shell. Every form it leaves open on purpose is named in its header.

## Findings
ASK 5: RED - git-guard covers every work-losing form, open ones named in its header - run: git-guard.sh --check on about 80 forms x subagent / main session with a dirty tree saw: listed verbs, bash -c, sh -c, pwsh -Command, -c alias (plain and bang), heredoc to a shell, env / timeout / xargs / eval, line continuation, quoted verb all denied; the forms found uncovered were named in the header or fixed (details (moved to a private file before publishing))

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
`bash tests/telemetry.test.sh --part install-xp`
`bash tests/maintenance.test.sh`
`bash scripts/py.sh -m py_compile .claude/hooks/*.py`
`bash tests/cycle.test.sh --part red`
`bash tests/cycle.test.sh --part red2`
`bash tests/cycle.test.sh --part ship`
`bash tests/cycle.test.sh --part gates`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part hooklog`
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part escalate`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
`bash tests/handoff.test.sh`
`bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part wiring`
`bash scripts/defects-check.sh`
`bash tests/telemetry.test.sh --part edits`
`bash tests/telemetry.test.sh --part install-xp2`
`bash tests/telemetry.test.sh --part library`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/cycle.test.sh --part scope`
`bash tests/cycle.test.sh --part close2`
`bash tests/council.test.sh --part verbs`
`bash tests/council.test.sh --part close`
`bash tests/solo.test.sh`
`bash tests/e2e.test.sh`
`bash tests/cycle.test.sh --part approved`
`bash tests/cycle.test.sh --part paperwork`
`bash tests/telemetry.test.sh --part wiring2`
