# Brief - next-circle-0-22

Date: 2026-09-29 · Owner: Andrei · Deliverable: code + host rollout · Tier: 2 · Source: the Queen's next-circle list after v0.21.1

## Request (verbatim)

The owner answered "да" and pasted the Queen's list:

> В следующий круг:
> - три минорных замечания ревьюера:
>   - ADR-010 ещё описывает старое правило для skills.json;
>   - файл-маркер провала в tests/cycle.test.sh лежит внутри временного репозитория;
>   - подпись одной секции теста устарела;
> - строка v0.21.0 в README;
> - /vulyk-ship одним «да» после зелёного ревью и автозапуск /vulyk-bootstrap;
> - обновление хостов: они всё ещё на 0.19.

## Answers

Ship - Один вопрос «Выпускаем?» (Рекомендую):
> После зелёного ревью сборка задаёт один вопрос с кнопкой, и на «да» сама запускает ship: слияние в main, версия, запись. Команду помнить не нужно, а решение о выпуске остаётся за тобой.

Bootstrap - Спросить один раз (Рекомендую):
> В ненастроенном проекте Вулик сам предложит настройку перед первой задачей и проведёт её на «да». Настройка — это интервью, без твоих ответов её не сделать. Репо самого Вулика не трогаем: его профиль — шаблон.

Хосты - Обновить и влить локально (Рекомендую):
> В каждом хосте обновлю существующую ветку, заменю конституцию с сохранением профиля и команд хоста (старая ложится рядом копией), проверю хуки и волью в основную ветку локально, без push.

Требования - Верно, строим в свежей сессии (Рекомендую), confirmed:
> (1) закрыть три минорных замечания ревьюера и добавить строку v0.21 в README
> (2) после зелёного ревью сборка спрашивает «Выпускаем?» и на «да» запускает ship сама
> (3) в ненастроенном проекте Вулик один раз предлагает bootstrap
> (4) все хосты обновить до новой версии и влить локально, без push

## Asks

1. Close the three round-1 minors of skills-json-exempt and add the v0.21 line to README.
2. After a green review the build asks «Выпускаем?» once and, on yes, runs ship itself.
3. In a project whose Profile is not filled, VULYK offers /vulyk-bootstrap once.
4. Every host is upgraded to the new version and merged locally into its default branch, no push.
