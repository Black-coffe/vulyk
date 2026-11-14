---
story: audit-fixes-1113-15
status: todo
returned:
worker: worker-code
model: opus
wave: 7
blocked_by: []
red: required
red_reason:
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 4. Only the owner's own words record his acceptance (`human-check.sh ACCEPTED|REJECTED`) or a plan's straight-through `--go`: a subagent is always refused; the main session passes only when the note quotes, verbatim and after the latest verdict, an owner prompt or AskUserQuestion answer from this session, with whitespace normalised and a bare «ок» not enough; direct edits of the record file and of the `**Approved:**` line are guarded the same way; without Python the guard refuses with a loud message.
> 5. git-guard covers every git form that discards uncommitted work or commits, including git run through a shell, an alias or a heredoc fed to a shell. Every form it leaves open on purpose is named in its header.
> 6. git-guard without Python: a pure-bash fallback with the same verb list (a test compares both lists) still denies the work-losing verbs in Bash and PowerShell; a real interpreter that crashes on a git command denies it; the SessionStart brief says when Python is missing.

## Findings
1. tests/telemetry.test.sh:247 [regression] suite telemetry, part `telemetry`: the check `enum is exactly 11 codes` must agree with the ENUM list, which now holds twelve (scripts/telemetry.sh:47 adds `redact_degraded`) - repro: `bash tests/telemetry.test.sh --part telemetry` prints `enum is exactly 11 codes - expected [11], got [12]`, 147 checks, 1 failed; on the base f66a24db the list holds eleven and the part is `ok` in the previous specs' suite logs.
2. tests/telemetry.test.sh:1906 [regression] suite telemetry, part `terminal`: the self-update case (`... and leaves the release's updater in place`) must be green on the head; its fixture upgrades from a source with no `v*` tag and expects the hive's edited updater to be replaced, which install.sh:136-140 (contract U1) now keeps - repro: `bash tests/telemetry.test.sh --part terminal` prints `expected [0], got [1]`, 9 checks, 1 failed; on the base the tagless source replaced the file (`git show f66a24db:install.sh`, `NO_HISTORY` branch of `release_copy`) and the part is `ok` in the previous specs' suite logs.
3. tests/maintenance.test.sh [regression] suite part `maintenance` must run under 70% of its 300 s cap or be split into parts that do (card test-gate-one-long-limit) - repro: `bash scripts/suite-parts-check.sh docs/specs/audit-fixes-1113/council/round-1/suite.log` prints `cut part maintenance: 216s of cap 300s (grew)`, exit 1; the base ran it in 134-138 s (suite logs of the two previous specs), and this branch adds 403 lines to the file.
1. .claude/hooks/owner-guard.sh:417 [ask 4] the guard must judge an `**Approved:**` or `**Checked:**` line of a spec's plan.md as it stands after the edit, for a subagent and for the main session alike: an Edit or MultiEdit whose new text does not itself begin with the marker (it replaces only the text after it), and a shell command that rewrites the line without spelling the marker (the scan at owner-guard.sh:376), yield no guarded action today and pass unjudged - repro: `bash .claude/hooks/owner-guard.sh --check <hook-input fixture: Edit of a plan.md, agent_id set, old_string the placeholder alone>` exits 0, while the same edit with the marker inside both strings exits 1.
2. .claude/hooks/git-guard.sh:231 [ask 5] a listed verb must be denied, or its form named in the header's left-open list (git-guard.sh:29-36), when git stands after a shell keyword (`then`, `do`, `else`, `!`), behind `eval`, or behind a wrapper command (`timeout`, `nohup`, `nice`, `sudo`, `xargs`): `command_word` skips only assignments, `&`, `command`, `exec`, `time` and `env`, and the header names none of these forms - repro: `bash .claude/hooks/git-guard.sh --check <fixture: agent_id set, a dirty porcelain, the verb inside an if/then or a for/do body>` exits 0, while the bare verb exits 1.
3. .claude/hooks/git-guard.sh:114 [ask 6] outside `--check`, an interpreter that ends with status 1 on a command naming git must deny like any other crash: 1 is Python's own status for an uncaught exception (a Python 2, a broken install), the Python half never exits 1 by design outside `--check`, yet 1 counts as "it ran" and the command passes with the fallback never consulted; the blanket `except Exception: sys.exit(0)` at git-guard.sh:626 lets an error inside the Python half through the same way - repro: `printf '%s' '<hook input naming a listed verb>' | VULYK_PY=<a stub that exits 1> bash .claude/hooks/git-guard.sh` prints nothing, the same call with a stub that exits 3 prints the deny.
- [regression] PART telemetry:telemetry FAIL 52s cap 300s
- [regression] PART maintenance ok 216s cap 300s
- [regression] PART telemetry:terminal FAIL 81s cap 300s

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

## Verification
`bash tests/telemetry.test.sh --part install-xp`
`bash tests/maintenance.test.sh`
`bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part wiring`
`bash tests/telemetry.test.sh --part edits`
`bash tests/telemetry.test.sh --part install-xp2`
`bash tests/telemetry.test.sh --part library`
`git ls-files '*.sh' | xargs -n1 bash -n`
