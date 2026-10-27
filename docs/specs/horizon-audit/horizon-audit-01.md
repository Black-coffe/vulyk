---
story: horizon-audit-01
spec: horizon-audit
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
---

# Five horizon fixes, ADR-022 lines and the evolve counter

## Goal
`templates/grill.md`, step 3a of `vulyk-plan.md`, step 1 of `drone-horizon`, ADR-022 and `/vulyk-evolve` carry the
seven asks below. What the court sees is described honestly. Horizon answers are labelled and countable. The gap
label needs a named request item. The lenses get the Profile rows. Questions inside the cap have an order. ADR-022
says what has not run and names two triggers. Evolve counts picks from the third `horizon.md` on.

## Requirements
> делай правки 1–5 из horizon-audit
> 1. Формулировки: суд видит твои решения по предложениям, а не сами предложения; в режиме без вопросов шаг пропускается, только если нет --horizon.
> 2. Каждый ответ horizon в брифе несёт метку (horizon H<n>) и итог: принято, отклонено, предложено.
> 3. «Дыра» остаётся дырой, только если Королева называет просьбу из брифа, которая без неё не выполнится; иначе это расширение.
> 4. В задание каждой линзы вписываются две строки Profile: Configurations that exist today и Owner language.
> 5. Порядок внутри лимита: сначала вопросы, от которых зависит, что строить, потом дыры, потом расширения.
> 6. В ADR-022 три строки: запуск трёх линз в живой сессии ещё не проверен; счётчик; вернувшаяся отклонённая идея помечается при выпуске.
> 7. В /vulyk-evolve одна строка: при 3 и более файлах horizon.md посчитать принятые, отклонённые и незаданные.

## Files
- templates/grill.md
- .claude/commands/vulyk-plan.md
- .claude/agents/drone-horizon.md
- .claude/commands/vulyk-evolve.md
- docs/adr/022-horizon-step.md
- CHANGELOG.md

## Non-goals
- No edit to `vulyk-ship.md`, `council-opus.md` or `council-haiku.md`: trigger 2 is a written trigger, not a guard.
- No check in `trace-check.sh` for the `(horizon)` tag (Law 6: a warn-only check is not a check).
- No new section in `horizon.md` and no new script; the counter is an instruction in evolve.
- No change to the cap (3-7), the one-round rule, the gate signal, or the agent's description line.
- No version bump here: that is ship work.

## Map slice
memory/map/agents-and-commands.md: `/vulyk-plan` steps 3a-4, `drone-horizon`, `/vulyk-evolve` step 1

## Acceptance criteria
- [ ] Ask 1: `grill.md` and ADR-022 say the court never sees proposals or `horizon.md`, but it does see the owner's
      recorded decisions on them in `## Answers`; verdicts stay on `## Asks`. Every place that says no-question mode
      skips the step adds "unless `--horizon`".
- [ ] Ask 2: `grill.md` `## Recording answers` requires each horizon entry to carry `(horizon H<n>)` and its pick:
      adopted, declined, or `(offered, not adopted)` in no-question mode.
- [ ] Ask 3: step 3a of `vulyk-plan.md` keeps `kind: gap` only when the Queen names the ask or verbatim request
      fragment that fails without it, and records that fragment in `horizon.md`; otherwise she relabels it extension.
- [ ] Ask 4: step 3a's dispatch carries the Profile rows *Configurations that exist today* and *Owner language*
      verbatim; `drone-horizon` step 1 uses them and reads the constitution only when they are missing.
- [ ] Ask 5: `grill.md` orders the questions: ordinary questions that change what gets built first, then horizon
      gaps, then extensions; a proposal not asked stays offered in `horizon.md`.
- [ ] Ask 6: ADR-022 gains: the in-session three-lens dispatch has not run yet (the next real new-ground plan is its
      live run, tokens and permission prompts go to that `horizon.md`); trigger 1, the evolve count; trigger 2, a
      blind seat's `UNASKED` repeating a declined proposal gets `/vulyk-ship` to mark it
      `(declined <date>, found again by the court)`, a change made only when that happens.
- [ ] Ask 7: `/vulyk-evolve` has one instruction: when `docs/specs/*/horizon.md` counts 3 or more, count adopted,
      declined and offered `(horizon H` entries across the briefs and the kept proposals with no entry, and report it
      against ADR-022's reversal rule; below 3 it says nothing.
- [ ] CHANGELOG `## Unreleased` has one entry for the change.
- [ ] No suite reads this prompt text. The verification below guards the plan/build mechanics and the size caps
      only; the criteria above are checked by reading the diff.

## Verification
`bash tests/solo.test.sh`
`bash tests/maintenance.test.sh`

## Implementation notes
- Ask 1: `templates/grill.md` `## Recording answers` gains the court paragraph (no proposal, no `horizon.md`; the owner's decisions in `## Answers` are visible; verdicts stay on `## Asks`); ADR-022 Decision 3 says the same. Skip wording: `vulyk-plan.md` 3a already said `--horizon` runs it anyway; ADR-022 Decision 1 and grill no-question mode now say "unless `--horizon`".
- Ask 2: grill `## Answers` rule: `(horizon H<n>)` first, pick last (`adopted`, `declined`, `(offered, not adopted)`); step 3a numbers the kept proposals `H1`-`H3` so the label has a source.
- Ask 3: step 3a keeps `kind: gap` only with a named ask or verbatim fragment, written beside it in `horizon.md`; otherwise `extension`.
- Ask 4: step 3a's dispatch carries the two Profile rows verbatim; `drone-horizon` step 1 takes them from the dispatch and reads the constitution only when missing.
- Ask 5: grill orders inside the cap: build-changing ordinary questions, then gaps, then extensions; the fixed last question stays last.
- Ask 6: ADR-022 Consequences gain the dated amendment: not yet run, trigger 1, trigger 2 (written down, not built).
- Ask 7: `/vulyk-evolve` step 2 ends with the horizon count paragraph, silent below three `horizon.md` files.
- CHANGELOG `[Unreleased]` has one `### Changed (spec horizon-audit)` entry.

## Findings
