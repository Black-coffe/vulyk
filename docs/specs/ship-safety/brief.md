# Brief: ship-safety

**Date:** 2026-10-19
**Source:** docs/specs/software-factory-study/report.md, "Recommended work" item 1 and "Owner decisions"; grill docs/grill/2026-10-19-software-factory.md.

## Request (verbatim)

> принять Чтобы начать, скажите своими словами что-нибудь вроде «делаем ship-safety», и я запущу /vulyk-plan.и зупустить вулик план

## Owner decisions carried in (grill 2026-10-19, options the owner selected)

- Spec branches after ship: «Удалять после выпуска + почистить старые (Рекомендую)» — the 24 merged branches were deleted the same day.
- Study order: ship-safety first.

## Scope from the study report (item 1)

A safe merge at ship (git merge-tree precheck, merge --abort, refuse on conflict); a branch guard on claim, close-story and open-round; refuse to reuse a merged spec branch; delete the spec branch after ship with git branch -d.

## Answers

1. Conflict — Стоп + предложить починку (Рекомендую): Выпуск NOT READY с файлами конфликта; королева предлагает влить main в ветку спеки и заново прогнать совет (правка конфликта — новый код, старый GREEN его не видел).
2. Wrong branch — Отказать и назвать обе ветки (Рекомендую): Выход 2 с текстом «сейчас на X, коммиты спеки живут на Y»; сборка останавливается, ничего не двигает.
3. Asks — Всё верно, покажи план (Рекомендую): шесть пунктов как есть, план останавливается на одобрение.

## Asks

1. Перед выпуском ship-check проверяет, что ветка спеки вливается в main без конфликта. Конфликт или «не смог проверить» = NOT READY с списком файлов.
2. При конфликте королева останавливается и предлагает починку: влить main в ветку спеки и снова прогнать совет.
3. /vulyk-ship мержит только на чистой main. Сорвавшийся мерж откатывается, выпуск останавливается.
4. После выпуска ветка спеки удаляется безопасным git branch -d.
5. cycle.sh отказывает и называет обе ветки, если захват, закрытие истории или открытие раунда запущены не на ветке спеки. ship-check тоже сравнивает ветки.
6. cycle.sh не строит поверх старой, уже влитой ветки с тем же именем.
