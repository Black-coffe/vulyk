# Brief: post-043-audit

**Date:** 2026-10-28 · **Deliverable:** document (study, `/vulyk-plan` step 0) · no story, no council

## Request (verbatim)

> Сделай быструю ревизию текущих хвостов репозитория после 0.43.0 (без запуска тестов, только чтение файлов):
>
> 1. Прочитай отчёт Совета и `plan.md` / `next-circle.md` в `docs/specs/prompt-check/` и выпиши дословно 4 мелких замечания (minors), оставленных на следующий круг.
> 2. Проверь статус одобренных, но не выпущенных спек в `docs/specs/`: `constitution-merge`, `handoff-ownership` и любых других, где нет строки `**Shipped:**`. Раздели их на две группы:
>    - где код реально ещё НЕ написан (нужна сборка `/vulyk-build`);
>    - где код уже в `main` и `CHANGELOG.md`, но забыта бумажная отметка `**Shipped:**` или `status: done`.
> 3. Проверь `memory/map/*.md` (`scripts.md`, `cycle.md`, `agents-and-commands.md`): перечисли, каких скриптов, глаголов и агентов из версий 0.35.0–0.43.0 там сейчас не хватает.
>
> Выдай результат коротким списком, чтобы мы решили, что собираем в `post-043-tails`, а что запускаем отдельным `/vulyk-build`.
