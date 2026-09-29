# Brief - auto-maintenance

Date: 2026-09-29 · Owner: Andrei · Deliverable: code · Tier: 2 · Source: `docs/specs/rrsi-self-improvement/report.md` §6 variant A, §8

## Request (verbatim)

The owner's words, 2026-09-29 (speech-to-text renders VULYK as "Vultr"). The owner pasted the report's variant A, then wrote:

> Рекомендую вариант A, четыре небольшие задачи Tier 0–2, без новых агентов и хуков:
> 1. Запустить /vulyk-gc и починить ложный счётчик.
> 2. Добавить тест размера всегда загружаемых файлов, который падает при превышении.
> 3. Добавить журнал гипотез и правила приёма изменений в /vulyk-evolve.
> 4. Один реальный прогон evolve. Если после него evolve снова не запускается, отправить его в graveyard, а не достраивать.

> Можешь этот кусок взять на себя и прогнать, протестировать, проверить? И ещё такой момент: можем ли мы автоматизировать команду Vultr GC? Возможно, можно какими-то хуками вызывать. Я честно тебе скажу, я уже и забыл, что эта команда есть и за что она отвечает. А тем более про людей, которые не делали Vultr, пользуются им. Откуда вообще им знать, что оно есть и за что оно отвечает? То есть количество команд в Vultr очень большое, и я знаю только vultr plan, vultr build, vultr update, vultr handoff. Всё! Все остальные команды я вообще понятия не имею, что они дают. Их нужно максимально автоматизировать.

## Answers

Автозапуск - Вулик запускает сам (Рекомендую):
> Хук старта сессии уже есть. Он сам вычисляет, что пора делать (накопились learnings, неделя без evolve, устарела карта), и велит главной сессии выполнить это после твоей текущей задачи. Новых хуков нет, если делать нечего, контекст не тратится. Такая инструкция уже работает: так приходит строка про litopys.

Evolve - Готовит ветку сам (Рекомендую):
> Делает правки в отдельной папке-копии (git worktree) на ветке vulyk/evolve-<дата>, твою рабочую папку не трогает. В main ничего не попадает без твоего merge. Ты получаешь одну строку: «правки готовы к ревью». Так цикл реально замыкается, а решение остаётся за тобой.

CLAUDE.md - Подрезать до 7 KB (Рекомендую):
> Нужно убрать около 1,4 KB. Раздел Commands занимает 2 835 байт, и большая его часть — пояснения, которые нужны только в репо Вулика. CLAUDE.md грузится в каждый субагент, а постоянный пакет инструкций — 23% всех расходов.

Требования - Верно, строй сразу (Рекомендую), confirmed:
> (1) один раз запустить gc и починить ложный счётчик
> (2) тест размера всегда загружаемых файлов, который падает при превышении
> (3) журнал гипотез и правила приёма изменений в evolve
> (4) один реальный прогон evolve, а если потом он не запускается — в graveyard
> (5) gc, evolve и обновление карты запускаются сами, и никому не нужно знать эти команды
> (6) всё прогнать, протестировать и проверить
> Остальные команды (ship, status, pause и др.) войдут в план таблицей с рекомендациями на следующий круг.

## Asks

1. Run /vulyk-gc once and fix the false "learnings awaiting GC" counter.
2. A size test for the always-loaded files that fails on excess; trim CLAUDE.md to the ADR-013 cap (7 KB, 120 lines).
3. A hypothesis ledger and change-admission rules in /vulyk-evolve.
4. One real evolve run; if evolve does not run again afterwards, it goes to the graveyard.
5. gc, evolve and map refresh run themselves; neither the owner nor another user needs to know these commands.
6. Run, test and verify all of it.
7. The remaining commands (ship, status, pause and others) go into the plan as a table with recommendations for the next circle.
