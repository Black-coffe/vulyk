# Stack trace autopsy for bug-fix briefs (brief)

**Date:** 2026-10-28 · **Tier:** 2

## Request (verbatim)
> «Git Bisect / Stacktrace Autopsy» — детерминированный пре-парсер ошибок для багфиксов
> Как сейчас в «Вулике»: В /vulyk-plan шаг 2 гласит: «Ошибка, стектрейс и шаги воспроизведения — тоже дословно в brief.md». Дальше Queen или drone-scout идут искать по коду, где это упало.
> 
> Что делают инженеры в Anthropic при Production Debugging: Они не заставляют LLM глазами парсить стектрейс и искать файлы через Grep. Перед тем как отдать баг модели, лёгкий скрипт вырезает из стектрейса все пути file:line, принадлежащие репозиторию, достаёт git log -n 3 -L <line>,<line>:<file> (кто и каким коммитом последний раз трогал именно эти строки) и прикладывает этот срез в бриф.
> 
> Как внедрить в «Вулик»:
> 
> Добавить скрипт scripts/trace-autopsy.sh, который автоматически вызывается при создании brief.md, если в запросе владельца обнаружен стектрейс (Traceback, at .*\.(js|ts|py|sh):[0-9]+, line [0-9]+).
> 
> Скрипт за 0 токенов и 0.1 секунды находит точные строки в коде и последний коммит, который их менял, и кладёт сводку на 15 строк рядом с брифом.
> 
> Профит: На задачах типа «почини баг по логу» вообще не нужен drone-scout! Queen с первой секунды видит и точную строчку кода, и коммит, который сломал поведение. Скорость планирования Tier 1–2 вырастает вдвое, расход токенов на разведку падает до нуля.

## Recon facts
<!-- The Queen's findings, 2026-10-28; not owner words. -->
- `.claude/commands/vulyk-plan.md:21-23` (step 2): the brief carries a bug report's error text, stack trace and
  reproduction verbatim; step 3 (`:24-30`) already sends no scout at Tier 1 unless the location is unknown, and
  at most one at Tier 2.
- Closest sibling: `scripts/symbol-map.sh` (step 3, Tier 2-4), a deterministic planning helper: no model, capped
  stdout, reports only, blocks nothing; tested by `tests/symbol-map.test.sh` on fixtures.
- `scripts/` is in `install.sh` `OWNED` (`install.sh:54`), so a new script ships to hives with no installer change;
  `tests/full-suite.sh:59` runs every `tests/*.test.sh` with no registration.
- Measured here (git 2.55.0, 837 commits): `git log -n 3 -s --format=... -L 63,63:scripts/symbol-map.py` 0.035 s;
  a line past the end of the file fails with `fatal: file ... has only 22 lines`, exit 128.
- `git log -L` reads line numbers at HEAD; a trace from a deployed build of another commit can point at shifted lines.
- The newest commit that touched a line is not necessarily the one that broke the behaviour; `git bisect` needs
  a reproduction run, which a pre-parser does not do.

## Answers
1. Запуск: Одна строка в шаге 2: если в запросе есть стектрейс, сразу после записи брифа запустить скрипт. Так уже устроен symbol-map.sh в шаге 3. Нет новых хуков и работает в любом улье.
2. Подпись: В сводке будет «последние коммиты по строке» и номер HEAD, на котором читались строки. Queen воспринимает коммит как след, а не как приговор: рефактор или форматирование часто оказываются последними на строке.
3. (horizon H1) H1 пути: Около 40 строк парсера и по одной фикстуре на каждый формат. Без этого на настоящем продовом трейсе не найдётся ни один файл репозитория, и сводка придёт пустой. - adopted
4. (horizon H2) H2 --rev: В сводке и так будет номер HEAD, на котором читались строки. Коммит сборки в баг-репортах обычно не приходит, так что флаг преимущественно простаивал бы. - declined
5. (horizon H3) H3 bisect: Команду воспроизведения в свободном тексте надёжно не выделить, получится догадка. Queen и так пишет красный тест на ошибку (метка red: required), и при нужде может сама запустить с ним bisect. - declined
6. Требования: Требования 1–6 как есть. Я пишу план и показываю его вам на одобрение, строить начинаю только после вашего слова.

## Asks
1. Скрипт scripts/trace-autopsy.sh вырезает из стектрейса в brief.md пути file:line из репозитория и для каждого берёт git log -n 3 -L.
2. Шаг 2 /vulyk-plan: если в запросе есть стектрейс (Traceback, at …:N, line N), Queen сразу после брифа запускает скрипт. Сводка до 15 строк ложится рядом с брифом.
3. В сводке есть точная строка кода, коммиты с подписью «последний, кто менял строку» и HEAD, на котором читались строки.
4. Скрипт работает без модели, на доли секунды.
5. Если сводка нашла хотя бы одну строку репозитория, место считается известным, и drone-scout не посылается.
6. (horizon) Скрипт разбирает трейсы Python, Node, bash и вида путь:строка и находит файл репозитория по хвосту абсолютного или Windows-пути.
