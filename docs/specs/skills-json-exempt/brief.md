# Brief - skills-json-exempt

Date: 2026-09-29 · Owner: Andrei · Deliverable: code · Tier: 1 · Source: the owner's delegation after v0.21.0

## Request (verbatim)

The Queen's question after v0.21.0 (decision 1 of 3):

> `memory/stats/skills.json` — счётчик меняется при каждом вызове скилла, дерево всегда «грязное», и он сегодня остановил проверку перед релизом. Раньше ты решил, что он должен считаться настоящим изменением. Рекомендую пропускать его в этой проверке так же, как уже пропускается журнал аномалий, но это разворот твоего решения, поэтому спрашиваю.

The owner's answer, 2026-09-29:

> Вопросы, которые ты задал, я даю право тебе решить на твоё усмотрение. Если у нас зелёный ревью, то можешь запускать Wulic Ship.

## Asks

1. ship-check stage 03 passes a tree dirty only in hook-written stats (`memory/stats/anomalies.jsonl` and `memory/stats/skills.json`), naming them, instead of refusing on the skill counter.
