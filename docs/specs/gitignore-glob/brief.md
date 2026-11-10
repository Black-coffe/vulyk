# Brief: gitignore-glob

Date: 2026-11-10 · Tier: 1

## Request

The owner's words, this session (the paragraph before them, which they quoted, is the model's own proposal:
fix install.sh's `ensure_gitignore` glob expansion as a small 0.50.3, or defer it):

> Давай это сделаем сейчас маленькой правкой дополнительной. А также пойди на официальный сайт Anthropic и найди новость, которую они дропнули по промтингу для Fable 5.2. Посмотри, что они там написали в инструкции, так как это официальная документация. Есть ли что-то оттуда, что мы можем взять для Улья? Если найдется то, что мы можем взять для нашего улья, вулика, то давай мы добавим это на уровне фреймворка и вместе с этим маленьким обновлением выкатим.

## Recon (2026-11-10)

- install.sh `ensure_gitignore` iterates `for line in $wanted` unquoted: `docs/specs/*/DRIVER`, `docs/specs/*/PAUSE` and
  `*.vulyk-new` glob-expand in the installer's working directory, so a hive's .gitignore gets that directory's paths
  (`docs/specs/weekly-budget/DRIVER` from the VULYK clone) instead of the patterns.
- "Prompting Claude Fable 5.2" (platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-2,
  read 2026-11-10; the same advice in the claude-api skill's model-migration.md, Claude Code 2.1.321): at `low` or
  `medium` effort the model is more likely to end agentic work early; for that case the guide offers a "# Finishing
  work" system-prompt block that separates ordinary obstacles (diagnose, work through) from deliberate blockers.
  In opus-builds the blind council seats run on Fable: council-opus at `effort: medium`, council-haiku with no effort line.
- The rest of the guide checked against the Fable roles (lead-review, council seats, queen-planner, lead-architect):
  no think-less lines, no reasoning-in-response asks, no token budget text, no delegation pushes; effort `high` where set.

## Asks

1. install.sh writes the .gitignore patterns themselves, whatever directory it runs from, and the two council seats that run on Fable carry the guide's finishing-work text.
