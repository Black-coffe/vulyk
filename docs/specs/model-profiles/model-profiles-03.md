---
story: model-profiles-03
spec: model-profiles
status: todo
returned:
tier: 3
worker: worker-code
model: opus # owner, 2026-10-18 approval: framework code this spec moves off Sonnet
wave: 2
blocked_by: [model-profiles-01]
---

# /vulyk-models asks once, recommends by plan, and can be rerun at any time

## Goal
A new command, `.claude/commands/vulyk-models.md`, holds a short quiz. Its frontmatter `description` carries the voice
triggers in ru, uk and en: «поменяй распределение моделей», «покажи распределение моделей», «какие модели», «модельный
профиль», «настройки моделей», «змінити розподіл моделей», "change model distribution", "model profile".

The body does the following:
- runs `bash scripts/model-profile.sh --recommend` and `--explain`;
- asks ONE AskUserQuestion with the three profiles; the recommended one goes first, labelled «(Рекомендую)», with the
  detected plan as the reason;
- gives each option a description and a preview that say what Fable, Opus, Sonnet and Haiku do in that profile, and
  what it costs in limits. The costs are: Fable's share of the Max weekly limit; Opus is the heaviest on code; on Pro,
  Fable bills credits (stated on `opus-builds` there);
- writes the answer with `--set` and confirms in one line, adding that the choice can be changed any time with
  `/vulyk-models` or in words.

The quiz speaks the Profile's *Owner language*, or the language the owner writes in while that row is unfilled.

`session-start-brief.sh` prints the plan's first-run `[VULYK]` line while `model-profile.sh --chosen` exits 1. A case in
`tests/maintenance.test.sh` pins it.

## Requirements
> 1. Квиз задаётся один раз на компьютер в первой сессии VULYK, в том числе после обновления, если выбора ещё нет: три варианта, у каждого написано, что делают Fable, Opus, Sonnet и Haiku и сколько это стоит по лимитам; первым идёт рекомендованный под подписку.
> 6. Поменять выбор можно в любой момент командой /vulyk-models или словами («поменяй распределение моделей»).
> их можно в любое время прийти, поменять, пофиксить как голосом, так и командами.
> 7. Подписка определяется сама; если не определилась, рекомендуется «как сейчас».

## Files
- .claude/commands/vulyk-models.md
- .claude/hooks/session-start-brief.sh
- tests/maintenance.test.sh

## Non-goals
- The hook never runs `--set` and never picks a profile ("offer, never auto-enable"). It keeps no show counter and no
  "declined" state.
- No percentages and no model versions in the quiz text. Name families only.
- Do not edit `model-profile.sh`, `top-model.sh` or `top-model-brief.sh` (story 01). If one needs a change, return
  `NEEDS_CONTEXT`.
- No `!` injection with a relative script path in the command (`scripts/injection-check.sh`). Plain Bash calls in the body
  are enough.
- Do not register the command anywhere: `.claude/commands` is an owned tree, and `install.sh` ships it as it is.

## Map slice
memory/map/scripts.md (`.claude/hooks/session-start-brief.sh`: the bootstrap offer and the `maintenance due` lines as the
pattern); the scout report's `ysk-offer.sh` lines (owner-language detection from `| Owner language |`); plan.md
`## Contracts` (resolver, first-run line); docs/model-cascade.md (what each family does today)

## Acceptance criteria
- [ ] With `CLAUDE_CONFIG_DIR` pointed at a temp folder that has no profile file, `session-start-brief.sh` prints the
      first-run line exactly once. After `model-profile.sh --set sonnet-builds` it prints no such line. Every existing
      `tests/maintenance.test.sh` brief assertion still passes; fixtures point the config folder at a temp folder, so the
      owner's real file decides nothing.
- [ ] The hook fails open: with `model-profile.sh` missing or failing it prints nothing about models, and it exits as it
      does today.
- [ ] The command's options appear in the order `--recommend` gives: the recommended option is first and carries
      «(Рекомендую)» and the reason. On a non-Max plan, `opus-builds` says that Fable bills credits.
- [ ] Each of the three options says in one or two plain sentences what Fable, Opus, Sonnet and Haiku do in it.
- [ ] Without AskUserQuestion (`claude -p`), the command writes nothing and prints one line: run `/vulyk-models` in an
      interactive session.

## Verification
`bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
