# Brief - convergent-judge

Date: 2026-09-23 · Owner: Andrei · Deliverable: code · Tier: 2

## Request (verbatim)

The owner's words, 2026-09-23, watching `web-accounts-p0` in wild-world-rpg announce "максимум 3 раунда":

> Заметил такую штуку, что в абсолютно любом проекте, где есть сидбулик, всегда он три цикла делает. Говорит: «Максимум три цикла». И он всегда три делает. Он никогда не делает один, никогда не делает два, всегда делает три.

> Есть какой-то арбитр, который скажет: «После первого цикла достаточно» или «Нужен максимум второй»? Или они просто по умолчанию гоняют три цикла, потом такие: «Ой, мы упёрлись в потолок, давайте что-то делать». Так с таким темпом можно и пять поставить циклов, и они все пять будут гонять.

> И всегда в три цикла не может вложиться, всегда у него что-то там не получается, и он такой: «А ну, принимай решение ты». Так зачем было три цикла гонять и сотни тысяч токенов тратить? Как-то вот там нужно это пересмотреть.

The Queen's study answered from `memory/stats/council.jsonl` in 17 projects (21 real specs: 9 GREEN at round 1, yet 9 spent 3+ rounds; RED rounds mostly `lead-review` BLOCK with every seat GREEN; GREEN followed by repair waves on PASS-with-majors in worklog and acr-class-a-autorun; the `autonomous-cycle` 1 RED / 2 RED / 3 GREEN rows identical in every project) and proposed, as option 1, verbatim:

> Переделать арбитра так, чтобы он смотрел на сходимость (Рекомендую).

> потолок зависит от тира: Tier 1 — 1 раунд, Tier 2 — 2, Tier 3–4 — 3;

> один и тот же вопрос RED два раунда подряд → сразу ESCALATE `no-progress`;

> BLOCK обязан ссылаться на номер вопроса из брифа или на регрессию, всё прочее уходит в заметки к ship;

> PASS при major-баге в продукте запрещён: либо BLOCK, либо minor;

> `council.jsonl` исключается из установки, так же как уже исключён `anomalies.jsonl`.

The owner's answer:

> Cjukfcty

> Согдласен

## Answers

1. PASS/BLOCK - Major тоже блокирует (Рекомендую): BLOCK, если есть хоть один critical или major; всё остальное minor. Рекомендую: в worklog вред нанесли именно major-замечания при PASS, а третьего уровня, который «не блокирует, но чинить надо», больше не будет.
2. Проверка - Скриптом, механически (Рекомендую): Каждое блокирующее замечание помечается `ask N` или `regression`. BLOCK, в котором нет ни одного помеченного замечания, арбитр засчитывает как PASS, а замечания уходят в заметки. Рекомендую: правило прозой в контракте ревьюера уже было, и именно оно не сработало.
3. Старые строки - Чистить при обновлении (Рекомендую): `install.sh --upgrade` удаляет из council.jsonl только строки `"spec":"autonomous-cycle"` и только там, где в проекте нет спека `docs/specs/autonomous-cycle`. Рекомендую: иначе все 17 проектов продолжат показывать ложные «3 раунда» в /vulyk-status и /vulyk-evolve.
4. Требования - Верно, покажи план (Рекомендую): Список принят как есть, план показываю на утверждение.


**After escalation (round 2, 2026-09-24).**
> Owner (Andrei, 2026-09-24): only rounds that ended RED count toward the tier ceiling - GREEN and STALE rounds never do; lead-review.md states the report layout as a contract (H2 ## Critical / ## Major, one finding per list line, its anchor tag on that line), and record-seat rejects a BLOCK carrying no such line as MALFORMED (retryable) instead of judge downgrading it.
## Asks

1. Потолок раундов зависит от тира: Tier 1 — 1, Tier 2 — 2, Tier 3–4 — 3; reopen добавляет столько же.
2. Один и тот же вопрос RED два раунда подряд — сразу ESCALATE no-progress.
3. BLOCK засчитывается, только если хоть одно блокирующее замечание помечено `ask N` или `regression`, иначе оно идёт как PASS, а замечания — в заметки к ship.
4. Ревьюер ставит BLOCK за любой critical или major, PASS при major запрещён.
5. Установщик не копирует council.jsonl в новые проекты, а --upgrade убирает строки autonomous-cycle там, где такого спека нет.

## Confirmed (verbatim, quotable)

The owner's confirmed asks (grill's last question, 2026-09-23), repeated as quotable lines:

> Потолок раундов зависит от тира: Tier 1 — 1, Tier 2 — 2, Tier 3–4 — 3; reopen добавляет столько же.

> Один и тот же вопрос RED два раунда подряд — сразу ESCALATE no-progress.

> BLOCK засчитывается, только если хоть одно блокирующее замечание помечено `ask N` или `regression`, иначе оно идёт как PASS, а замечания — в заметки к ship.

> Ревьюер ставит BLOCK за любой critical или major, PASS при major запрещён.

> Установщик не копирует council.jsonl в новые проекты, а --upgrade убирает строки autonomous-cycle там, где такого спека нет.
