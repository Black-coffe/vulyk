---
story: symbol-map-02
spec: symbol-map
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 2
blocked_by: [symbol-map-01]
---

# Protocol lines: recon runs the script, the planner reads it, the worker runs it before a root edit

## Goal
After this story the Queen's recon step in `/vulyk-plan` runs `bash scripts/symbol-map.sh <candidate files>` and adds a five-item checklist line, the planner dispatch passes that output on so `## Files` is complete, `queen-planner.md` tells the planner to fold the output into `## Files`, and `worker-code.md` step 2 plus the solo build in `vulyk-build.md` tell the builder to run the script on a root file before editing it and to grep only what it labelled `textual` (`по имени`). Prose only; no script change.

## Requirements
> 3. Королева запускает его на разведке для файлов из плана и передаёт результат планировщику, чтобы ## Files был полным.
> 4. Воркер перед правкой корня запускает скрипт, а не ищет вызовы grep-ом; одна строка в worker-code и в соло-сборке.
> 5. В разведке строка-чеклист: мета-тесты, docs/ADR, .env.example, реэкспорты, соседние файлы с тем же паттерном.
> Перед запуском worker-code или queen-planner скрипт за 0 токенов подкладывает точный граф зависимостей файлов из ## Files.

## Files
- .claude/commands/vulyk-plan.md
- .claude/commands/vulyk-build.md
- .claude/agents/queen-planner.md
- .claude/agents/worker-code.md

## Non-goals
- Do not edit any `description:` frontmatter (the agents' and commands' descriptions share a 4983-byte cap in `tests/maintenance.test.sh`); bodies only.
- One line for the worker in `worker-code.md` step 2 and one in `vulyk-build.md`'s solo build (the "a bug fix greps every caller" line): replace or extend that sentence, do not add a step, a section or a script call elsewhere in the worker's flow.
- Do not make the script's output a gate, a refusal or a NEEDS_CONTEXT trigger; do not add it to `close-story`, `wave-check.sh` or any `scripts/*`.
- Do not touch `CLAUDE.md`, `memory/map/*.md`, `templates/*`, `worker-test.md` or `scripts/symbol-map.*` (story 01's files).
- Do not reword the recon step beyond: the run on candidate files, the checklist line, and the hand-off of the output to the planner dispatch.

## Map slice
`memory/map/agents-and-commands.md`: `## Commands - what each runs` (`/vulyk-plan` steps: recon with scouts, plan via `queen-planner` at T3-4, step 3a horizon; `/vulyk-build` solo path), `## Agents` (worker-code step and close contract; queen-planner never reads source). Contracts `CLI` and `Protocol lines` in `docs/specs/symbol-map/plan.md`.

## Acceptance criteria
- [ ] `.claude/commands/vulyk-plan.md` step 3 (Recon) tells the Queen to run `bash scripts/symbol-map.sh <candidate files>` on the files the plan is likely to name (Tier 2-4) and to add the checklist line listing exactly: meta-tests, docs/ADR, `.env.example`, re-exports, sibling files with the same pattern; the planner dispatch step (step 5) passes the script's output to `queen-planner` as an input next to the scout reports.
- [ ] `.claude/agents/queen-planner.md`'s bullet "`## Files` lists every place the change must reach" names the symbol-map output as a source for `## Files` and tells the planner to take `exact` lines in and judge `textual` ones.
- [ ] `.claude/agents/worker-code.md` step 2 says in one sentence: before editing a root file run `bash scripts/symbol-map.sh <file> --story <story>` first, then grep only what it cannot vouch for: the names it marks `textual`, and every caller of a file it reports `imports not parsed` (a TypeScript, PHP or 1C file), as before; `.claude/commands/vulyk-build.md`'s solo build carries the same one sentence.
- [ ] No `description:` line changed in any of the four files; `bash tests/maintenance.test.sh` stays green.
- [ ] `git diff --stat` of the story touches only the four files under `## Files`.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes
- vulyk-plan.md: step 3 gains the Tier 2-4 symbol-map run on candidate files and the five-item checklist line; step 5 passes "the symbol-map output" to queen-planner beside the scout reports.
- queen-planner.md: the `## Files` bullet names the symbol-map output as a source: `exact` in, `textual` judged.
- worker-code.md step 2 and vulyk-build.md solo build: the grep-every-caller sentence now runs symbol-map first and greps only `textual` names and `imports not parsed` files.
- No description: lines touched; maintenance.test.sh 153/0 locally.

## Findings
