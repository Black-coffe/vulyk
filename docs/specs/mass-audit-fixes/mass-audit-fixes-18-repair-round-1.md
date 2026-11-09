---
story: mass-audit-fixes-18
status: todo
returned:
worker: worker-code
model: opus
wave: 5
blocked_by: []
red: required
red_reason:
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 18. (Added by the owner mid-build on 2026-11-09, choice «Сказать + раскатка (Рекомендую)».) `install.sh --upgrade` names every hook this release ships that the hive's `settings.json` does not wire, one line each with the command that wires it, and never wires it unasked; at rollout the Queen wires, per hive, the hooks the old installer bug dropped.

## Findings
ASK 18: RED - --upgrade names unwired hooks and never wires unasked - run: fresh 0.49.0 hive, removed the entries for git-guard.sh and ysk-offer.sh as an owner would (both shipped by v0.49.0), install.sh --upgrade saw: git-guard reported "unwired PreToolUse: git-guard.sh - to wire it: ... --wire PreToolUse:git-guard.sh" and left out (good), but ysk-offer.sh was silently re-wired ("wire ... SessionStart: ysk-offer.sh"); a second hive showed anomaly-scan.sh and "defects-inject.sh reset" re-wired the same way - install.sh uses unconditional wire_hook for anomaly-scan, defect-intake (2 events), defects-inject (2 events) and ysk-offer, while only git-guard and the wire_shipped set honour a removal; the decision in the brief «удалённый владельцем намеренно хук не возвращается» is not met for those hooks
1. tests/e2e.test.sh:117 [regression] the e2e seam (real driver + real cycle.sh) must close its Tier 3 story again: `make_fixture` commits plan and story as `git commit -q -m init`, so story 05's `story_blocks_guard` (scripts/cycle.sh:2313 approved_rev, :2328) finds no `vulyk(demo): ` commit and refuses `close-story` with exit 2 `no approved version in git for docs/specs/demo/demo-01-app.md: commit the plan or a revision first`; the worker returns, the story stays todo and the run stops at `next: build:1` (same fixture for `--part red`) - repro: `bash tests/e2e.test.sh --part green` (E2E_DEBUG=1 shows the stop), and a throwaway repo with the fixture's files + `cycle.sh close-story ... --commit` gives the exit 2 above; base: `git show main:docs/specs/ab-run-fixes/council/round-3/suite.log` has `PART e2e:green ok`, `PART e2e:red ok`.
2. tests/council.test.sh:2115 [regression] close-story on a locked index must still satisfy r2m2 (exit 2 and an error that names the commit): head's `cs_add` (scripts/cycle.sh:2918, G6) refuses with `git add failed: docs/specs/cstorylock1/cstorylock1-01-first.md: fatal: Unable to create '.git/index.lock'` and no word "commit" in the output, so `grep -qiF 'commit'` fails - the refusal names the commit it could not make, or the r2m2 assertion follows the G6 wording - repro: `bash tests/council.test.sh --part escalate` (`::error::exit=2 out=... git add failed ...`); base: main suite logs `PART council:escalate ok 48-110s`.
3. tests/council.test.sh (part suite) [regression] the council:suite part must run under 70 % of its 300 s cap again: head ran it 247 s and suite-parts-check cuts it (`cut part council:suite`), base logs on main show 70-182 s for the same part; every `status --json` now pays D2's `git log -- <spec>` (scripts/cycle.sh:2360 close_subjects; measured here 978 ms vs 826 ms per call on this spec, base cycle.sh from `git archive 704eb85 scripts`) and story 10 added sleeping X-08 cases - split the part or take the per-call cost back under 210 s (card test-gate-one-long-limit ->) - repro: `bash tests/council.test.sh --part suite` timed against `bash scripts/suite-parts-check.sh`.
1. tests/e2e.test.sh:117 [regression] the e2e seam (real driver + real cycle.sh) must close its Tier 3 story again: `make_fixture` commits plan and story as `git commit -q -m init`, so story 05's `story_blocks_guard` (scripts/cycle.sh:2313 `approved_rev`, :2328) finds no `vulyk(demo): ` commit and `close-story` exits 2 "no approved version in git"; the run stays at `next: build:1`, no GREEN row, tree dirty (` M app.txt`, ` M demo-01-app.md`) - repro: `E2E_DEBUG=1 bash tests/e2e.test.sh --part green` (same for `--part red`); base: `PART e2e:green ok` / `PART e2e:red ok` in the main suite logs.
2. tests/council.test.sh:2115 [regression] close-story on a locked index must still satisfy r2m2 (exit 2 and an error that names the commit): head's G6 `cs_add` refuses with `git add failed: ...index.lock` and the output carries no word "commit", so `grep -qiF 'commit'` fails (`::error::exit=2 out=...git add failed...`) - either the refusal names the commit it could not make or the r2m2 assertion follows the new wording - repro: `bash tests/council.test.sh --part escalate` (rerun here, rc=1, same line); base: `PART council:escalate ok` on main.
3. tests/council.test.sh (part suite) [regression] the council:suite part must stay under 70 % of its 300 s cap: head ran it 247 s and suite-parts-check cuts it (`cut part council:suite`), main logs show 70-182 s; split the part or take it back under 210 s (card test-gate-one-long-limit) - repro: `bash tests/council.test.sh --part suite` timed, then `bash scripts/suite-parts-check.sh`.
- [regression] PART council:escalate FAIL 69s cap 300s
- [regression] PART council:suite ok 247s cap 300s
- [regression] PART e2e:green FAIL 9s cap 300s
- [regression] PART e2e:red FAIL 9s cap 300s

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
