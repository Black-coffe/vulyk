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
- .claude/commands/vulyk-plan.md
- tests/maintenance.test.sh

## Queen note
Files narrowed by the Queen (2026-11-09): the RED item is one sentence in `/vulyk-plan` step 3a. Today it reads
"In a repo whose `memory/memory.md` `## Codebase map` lists a module, it runs only with `--horizon`". Bootstrap step 4
now lists modules only under `## Unmapped territory` and maps none, so a freshly bootstrapped existing repo still takes
the grep trigger. The gate must count a module listed under either heading (`## Codebase map` or `## Unmapped
territory`) as an existing repo; "Only a repo with no mapped module" becomes a repo whose memory.md lists no module
under either. No other change to step 3a, to bootstrap or to `memory/memory.md`.
Red: a check in `tests/maintenance.test.sh` that step 3a's existing-repo gate names `## Unmapped territory` beside
`## Codebase map` (it fails on HEAD).

## Verification
`bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
