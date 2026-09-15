# Brief - driver-hardening

Date: 2026-09-15 · Owner: Andrei · Deliverable: code · Tier: 3
**Escaped from:** anomaly-telemetry (v0.14.0) - every defect below was met while that circle's driver ran.

## Request (verbatim)

The owner's words, end of the anomaly-telemetry session (2026-09-15) and the start of this one:

> Хайвы не кати, а лучше сделай хендофф и потом в новой сессии сделай все хвосты

> Стартуй хвосты

The tail this brief takes, verbatim from `docs/specs/anomaly-telemetry/plan.md` `## Next circle`:

> ### Driver defects met during this circle (Queen's notes, personal memory `vulyk-next-circle-clerk-json-loss`)

> - `cycle-clerk` dropped a `]` relaying `status --json` in a hive; the driver died at `vulyk-cycle.js:78` on launch (retry once / status-to-file).
> - `open-round` refused `working tree not clean` twice: hook-written `memory/stats/skills.json`, `memory/learnings/*.md`, `memory/stats/anomalies.jsonl` between driver steps (story 09 fixed the last one).
> - A repair worker wrote `status: done` itself; `close-story` refused `already done` and the run stopped with uncommitted edits.
> - `taint_reason()` rejected both haiku attempts of round 6 for a `--story <slug>-13` argument the seat typed itself; the round escalated `env` with every judging seat GREEN.
> - The clerk costs ~55k tokens per dispatch in a hive with a 68 KB + 39 KB constitution vs ~22k here; the harness baseline (~22k) is fixed, the constitution is the lever.

The same five, as the Queen's personal memory records them (`vulyk-next-circle-clerk-json-loss`, 2026-09-14/15):

> 1. `cycle-clerk` dropped a `]` relaying `status --json` -> driver died at JSON.parse on launch in a hive; fix candidates: retry once, or status-to-file.
> 2. `open-round` refuses `working tree not clean` on hook-written files (`memory/stats/skills.json`, `memory/learnings/*.md`; `anomalies.jsonl` fixed by story 09).
> 3. A worker that writes `status: done` itself makes `close-story` refuse `already done` and the run stops with uncommitted edits.
> 4. `taint_reason()` false positive: a seat that types `--story <slug>-NN` in its own `run:` command is rejected as leaking a story id; round 6 escalated `env` with every judging seat GREEN.
> 5. The clerk costs ~55k tokens per dispatch in a hive with a 68 KB + 39 KB constitution vs ~22k here; the harness baseline is fixed, the constitution is the lever.

Not in this brief (recorded elsewhere, carried by a later spec): the `telemetry-hardening` carry-list in the same `## Next circle` (round-6 UNASKED, review minors 2-6).

## Answers

1. **Статус JSON** - Повтор один раз: Драйвер при нечитаемой строке от клерка вызывает его ещё раз, один раз, и только потом останавливается. Ровно так драйвер уже поступает с испорченным отчётом сидения (переспрашивает один раз), новых договорённостей не нужно, цена — один лишний вызов клерка в редком случае.
2. **Файлы хуков** - Считать их бумагами цикла: Добавить оба файла в белый список is_paperwork_path в lib.sh: открытие раунда их не замечает, их коммит не старит раунд. Ровно этот патч mmorpg уже три апгрейда подряд возвращает руками — пора в upstream. Скоуп-гейт для skills.json не трогаем (ваше решение прошлого круга).
3. **status: done** - Закрытие терпит самоотметку: close-story отказывает «уже готово» только если история уже закоммичена как done; если в её файлах есть незакоммиченный дифф, оно идёт по обычному пути (скоуп, проверка, коммит) и пишет в журнал «воркер отметил сам». Плюс одна строка в worker-code.md: status: не трогать.
4. **Утечка** - Только файл истории, не голый номер: Утечка — это путь к скрытому файлу: plan.md, journal.md, council/ и теперь файл истории <slug>-NN.md или docs/specs/<slug>/<slug>-NN. Голый токен <slug>-NN перестаёт считаться: его любое сидение синтезирует из слага (раунд 6 это и показал: история 14 в команде и в эхо вывода). Одна регулярка в taint_reason, тесты на оба случая.
5. **Цена клерка** - Глаголы сами возвращают next: Каждый меняющий глагол cycle.sh (branch, close-story, open-round, record-seat, judge) добавляет в свою JSON-строку то, что драйвер иначе спрашивает отдельным статусом, и драйвер опрашивает статус только на старте. Минус около трети вызовов на проход, без изменения самой схемы статуса — добавление ключа, старый драйвер его просто не читает.
6. **Требования** - Подтверждаю все пять, план на одобрение.

## Asks

1. Нечитаемая строка от клерка — драйвер повторяет вызов один раз, потом останавливается.
2. skills.json и memory/learnings/*.md — бумаги цикла: не блокируют открытие раунда, не старят его.
3. close-story принимает историю с самоотметкой status: done, если есть незакоммиченный дифф; воркеру сказано status: не трогать.
4. Голый номер истории <slug>-NN — не утечка; утечка — файл истории и прежние пути.
5. Меняющие глаголы cycle.sh возвращают next в своём JSON, драйвер опрашивает статус только на старте.

## Confirmed (verbatim, quotable)

<!-- trace-check.sh reads only `> ` lines: the confirmed asks repeated here as quotes. -->

> Нечитаемая строка от клерка — драйвер повторяет вызов один раз, потом останавливается.
> skills.json и memory/learnings/*.md — бумаги цикла: не блокируют открытие раунда, не старят его.
> close-story принимает историю с самоотметкой status: done, если есть незакоммиченный дифф; воркеру сказано status: не трогать.
> Голый номер истории <slug>-NN — не утечка; утечка — файл истории и прежние пути.
> Меняющие глаголы cycle.sh возвращают next в своём JSON, драйвер опрашивает статус только на старте.
