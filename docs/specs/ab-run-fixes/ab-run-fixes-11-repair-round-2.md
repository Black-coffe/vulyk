---
story: ab-run-fixes-11
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
> 8. Грилевка пачкой до 4 вопросов. Горизонт в существующем репо — только по `--horizon`. Подтверждение требований совмещено с утверждением плана, а утверждение Tier 3–4 сразу запускает сборку.

## Findings
ASK 8: RED - grill batch of 4, horizon only by --horizon in an existing repo, confirm merged with approval, approval launches build - run: grep templates/grill.md, vulyk-plan.md 3a/9/10, vulyk-bootstrap.md:60, memory/memory.md headings saw: batches of up to 4 (grill.md:20), no confirm question (grill.md:36), Tier 3-4 approval starts /vulyk-build in the same turn (plan step 10) all present; but 3a gates the horizon on "`## Codebase map` lists a module", while bootstrap step 4 now writes modules only under `## Unmapped territory` (memory.md:17) and maps none, so a freshly bootstrapped existing repo still fires the grep trigger on its first plan without --horizon - the owner case (old repo, new capability) stays uncovered until something gets mapped

## Files
- scripts/model-profile.sh
- tests/model-profile.test.sh
- .claude/commands/vulyk-models.md
- .claude/agents/lead-review.md
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- docs/model-cascade.md
- docs/token-economy.md
- docs/adr/020-*.md
- .claude/commands/vulyk-plan.md
- templates/grill.md
- templates/plan.md
- docs/adr/022-*.md
- docs/cycle.md
- docs/command-reference.md
- README.md
- scripts/cycle.sh
- tests/cycle.test.sh
- tests/council.test.sh
- docs/adr/029-*.md
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- docs/defects/full-round-for-a-narrow-fix.md
- docs/defects/full-round-for-a-narrow-fix.original.fixture
- docs/defects/full-round-for-a-narrow-fix.neighbour.fixture
- docs/defects/INDEX.md
- docs/adr/013-light-vulyk.md
- .claude/commands/vulyk-bootstrap.md
- bootstrap/interview.md
- .claude/hooks/handoff.py
- .claude/hooks/session-start-brief.sh
- install.sh
- tests/maintenance.test.sh
- tests/telemetry.test.sh
- docs/getting-started.md
- docs/telemetry.md
- docs/hooks-reference.md
- docs/defects/shell-needs-gnu-or-bash4.md
- tests/e2e.test.sh

## Verification
`bash tests/model-profile.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/maintenance.test.sh`
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part gates`
`bash tests/council.test.sh --part suite`
`bash tests/council.test.sh --part roster`
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part verbs`
`bash tests/driver.test.sh`
`bash scripts/defects-check.sh docs/defects/full-round-for-a-narrow-fix.md`
`bash tests/cycle.test.sh --part manual`
`bash tests/cycle.test.sh --part safety`
`bash tests/council.test.sh --part driver`
`bash tests/telemetry.test.sh --part install`
`bash scripts/py.sh -m py_compile .claude/hooks/*.py`
`bash tests/council.test.sh --part advance`
