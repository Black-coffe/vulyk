---
story: ab-run-fixes-02
spec: ab-run-fixes
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
---

# Plan command: profile in the header, no scout for a fresh map, batched grill, horizon by flag, one approval that builds, early commit

## Goal
`/vulyk-plan` and its templates change as follows:
- **(a) Profile in the header.** `templates/plan.md` gains a `**Model profile:** <name>` header line (plan C11). The command names the call that fills it (recon Q1).
- **(b) Recon (step 3).** An area whose `memory/map/` slice is fresh gets no scout. Fresh means the slice exists and `git log -1 --format=%cs -- <area paths>` is not newer than its `last-verified:` date. Scouts go only to unmapped or stale areas, and the tier cap is a ceiling, not a quota.
- **(c) Grill in batches.** The grill asks in batches of up to 4 questions per `AskUserQuestion` call, still 3-7 in total and recommended first.
- **(d) Horizon by flag (step 3a).** In a repo whose `memory/memory.md` `## Codebase map` lists a module, the horizon step runs only with `--horizon`. The grep trigger stays only for a repo with no mapped module. `--no-horizon` is unchanged.
- **(e) One approval.** The grill's fixed Confirm question is gone. The approval stop shows `## Asks` with the plan, and one word approves both; a correction edits `## Asks`, re-runs `trace-check.sh` and shows the plan again.
- **(f) Approval builds at Tier 3-4.** There, approval writes `**Approved:**`, commits it and starts `/vulyk-build` in the same turn. Tier 2 keeps its fresh-session build, and `--go` is unchanged.
- **(g) Early commit.** Once `wave-check.sh` and `trace-check.sh` pass, before the approval stop, the spec directory is committed as one commit. `claim` then never meets an uncommitted plan.

## Requirements
> 1. Профиль моделей: `--recommend` всегда даёт `sonnet-builds`, `opus-builds` включается только явным выбором владельца, профиль печатается в шапке плана.
> 7. Разведка плана: если у области есть свежая карта, разведчика туда не шлём.
> 8. Грилевка пачкой до 4 вопросов. Горизонт в существующем репо — только по `--horizon`. Подтверждение требований совмещено с утверждением плана, а утверждение Tier 3–4 сразу запускает сборку.
> 10. План коммитится раньше, чем `claim` начнёт отказывать из-за грязного дерева.

## Files
- .claude/commands/vulyk-plan.md
- templates/grill.md
- templates/plan.md
- docs/adr/022-*.md
- docs/cycle.md
- docs/command-reference.md
- README.md

## Non-goals
- No script changes: no `cycle.sh`, `trace-check.sh` or `wave-check.sh`. The commit is a plain `git add docs/specs/<slug>/ && git commit` step in the command text.
- Do not change the 3-7 cap, the recommended-first rule, the `drone-horizon` lenses or the `horizon.md` format.
- No README result paragraph (story 06), and no README roster lines (story 04).

## Map slice
memory/map/agents-and-commands.md (`/vulyk-plan`, including step 3, step 3a horizon and the approval stop; `queen-planner`)

## Acceptance criteria
- [ ] `templates/grill.md` allows up to 4 questions per call, and "one question per turn, never a bundle" is gone.
- [ ] In a repo with a mapped module, a `/vulyk-plan` without `--horizon` runs no horizon lens and asks no horizon question. With no mapped module, today's trigger still fires.
- [ ] No Confirm question is left in `grill.md`. The approval stop text presents `## Asks` and the plan as one approval.
- [ ] At Tier 3-4, the command says approval writes and commits `**Approved:**`, then starts `/vulyk-build` via the Skill tool in the same turn.
- [ ] The command commits `docs/specs/<slug>/` before the approval stop, and the approval commit carries only the `**Approved:**` line.
- [ ] `templates/plan.md` has the `**Model profile:**` line, and `vulyk-plan.md` names the call that fills it for both the Queen and `queen-planner`. `prompt-check.sh --touched` passes.
- [ ] Step 3 states the freshness rule.
- [ ] Docs:
  - ADR-022 gets a dated amendment line: horizon runs only on `--horizon` in a mapped repo.
  - README: the `drone-horizon` row, the grill/plan bullet in "The build discipline", and the `/vulyk-plan` command row.
  - `docs/command-reference.md`, and the stage 02 row of `docs/cycle.md`.
- [ ] `## Implementation notes` ends with one `CHANGELOG:` line.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes
- `.claude/commands/vulyk-plan.md`: step 3 freshness rule, scout cap as a ceiling, `bash scripts/model-profile.sh` (no argument, recon Q1) once; 3a mapped-repo gate; step 5 profile line for the Queen and `queen-planner` (passed as `model profile: <name>`, the planner has no Bash); step 8 early `git add docs/specs/<slug>/` commit; step 9 one approval of `## Asks` + plan, asks correction re-runs `trace-check.sh` and commits; approval commit adds only `plan.md` + `journal.md` (the 02-approved journal line rides with it); step 10 Tier 3-4 starts `/vulyk-build` via the Skill tool.
- Decision: the grill's straight-through opt-in lived on the removed Confirm question, so `--go` is now the only opt-in.
- `templates/grill.md`: batches of up to 4 per call, Confirm question and read-back removed, `## Asks` derived from the request and confirmed at the approval stop; horizon section reworded without the last question.
- `templates/plan.md`: `**Model profile:**` header line (not a cycle marker).
- Docs: ADR-022 amendment 2026-11-08, README (drone-horizon row, build-discipline bullet, `/vulyk-plan` row), `docs/command-reference.md`, `docs/cycle.md` stage 02 row.
- Surprise: the working copies are CRLF (index LF); edits kept CRLF so diffs show only content lines.
- CHANGELOG: `/vulyk-plan` sends no scout to a freshly mapped area, grills in batches of up to four with no confirm question, runs the horizon step only on `--horizon` in a mapped repo, commits the plan before the stop, approves asks and plan in one word (Tier 3-4: the same turn starts `/vulyk-build`), and prints the model profile in the plan header.

## Findings
