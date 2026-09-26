# Grill brief: долгосрочная память проекта (хроника + wiki) поверх VULYK

<!-- supergrill-state
status: done
level: deep
hardness: medium
lens: product
stage: 0
stage_level: deep
questions_asked: 15
requested_inputs: []
open_branches:
  - путь хроники внутри проекта по умолчанию (решается в плане)
plugin_name: litopys
next_question: ""
web_policy: allow
updated: 2026-09-21
-->

Date: 2026-09-21 | deep | medium | product | Claude Code (E:/Projects/vulyk)

## Recon (what was known before the first question)

### VULYK сегодня (диск, 2026-09-21, v0.15.0)
- Хендофф: `.claude/handoff/*.md`, не в git, восстанавливается только свежий; авто-дамп = git status + тронутые файлы + 12 последних запросов обрезанных; «Сводка» пуста без `/handoff`. 11 файлов в репо, осмысленных единицы. — диск
- `memory/learnings/`: хук SessionEnd пишет пустой стаб; реальная дистилляция только при `VULYK_AUTOLEARN=1` через `claude -p` по transcript_path. 9 стабов ждут GC, свежие пустые. — `.claude/hooks/session-end-learnings.sh`
- `docs/specs/<slug>/`: brief.md (просьба verbatim + ответы гриля + Asks), plan.md, истории, journal.md (таймстампы стадий), council/. Хорошая память о решениях внутри круга. — диск
- `docs/adr/` 11 ADR; `docs/grill/` 3 ручных гриль-протокола; `docs/wiki/` пуста («none yet» в memory.md). — диск
- `memory/memory.md` индекс ≤60 строк; `librarian` единственный консолидатор; `/vulyk-gc`, `/vulyk-evolve` еженедельно. — docs/memory-system.md
- Разговор вне спеки не сохраняется нигде. Journal по спеке, не по проекту. Поиска по прошлым сессиям нет.

### Claude Code официально (fact-check 2026-09-21, два источника на пункт)
- Auto memory `~/.claude/projects/<repo>/memory/`, MEMORY.md 200 строк / 25 КБ, локальная, не в git, per-repo, worktree-общая; `autoMemoryEnabled`, `autoMemoryDirectory`. ✅
- Память сабагента `memory: user|project|local`; `project` → `.claude/agent-memory/<agent>/` **в git**. ✅
- 33 хука; SessionStart(startup/resume/clear/compact), SessionEnd, PreCompact/PostCompact, Stop (`last_assistant_message`), SubagentStop, UserPromptSubmit (`user_input`), InstructionsLoaded; все получают `transcript_path`, `session_id`. Доки прямо предлагают архивировать транскрипт хуком SessionEnd. ✅
- Транскрипты `~/.claude/projects/<project>/<session-id>.jsonl`, `cleanupPeriodDays` 30 дней, формат внутренний, меняется между версиями; санкционированный путь — `/export` или `claude -p --resume <id> "summarize…" --output-format json`. ✅
- Плагины: `.claude-plugin/plugin.json`, `skills/`, `agents/`, `hooks/hooks.json`, `.mcp.json`, `monitors/`, `bin/`, `${CLAUDE_PLUGIN_DATA}`; неймспейс `/plugin:skill`. ✅
- «Auto Dream» фоновая консолидация памяти — только сторонние блоги/утечка. ❓
- Контекст: корневой CLAUDE.md переживает компакцию; инструкции «только в разговоре» — нет. ✅

### Противоречия в источниках
- Видение: «хуки автоматически определяют важные моменты». Хук = shell-команда без модели; судить о важности может только модельный вызов (VULYK_AUTOLEARN уже так делает, но выключен по умолчанию).
- Видение: «как Recall, RAG по всему». VULYK ADR/memory-system: «structure-first, embeddings-optional», файлы в git.
- Транскрипт как источник правды vs 30-дневное удаление и внутренний формат.

### Следы (упомянуто, но отсутствует)
- `docs/wiki/` — заявлена как долгосрочная память хайва, пуста.
- `VULYK_AUTOLEARN` — механизм есть, нигде не включён.

## Q&A transcript
Q1 (D2): Кто в реальном времени решает, что важно, и когда?
A1: Хуки (Stop/UserPromptSubmit) пишут сырой журнал детерминированно; модель судит только на границах (SessionEnd, PreCompact, /clear, команда). — opinion/design
Q2 (D1): Что в git, что локально?
A2: Выжимки сессий и wiki в git; сырой журнал и хендофф локально в .claude/. — design
Q3 (D2, развилка): Где живёт?
A3: Отдельный плагин Claude Code со своим неймспейсом; владеет захватом, хроникой, wiki. VULYK первый потребитель: отдаёт плагину learnings-хук и сводку хендоффа, сам владеет specs/ADR/map, пишет в хронику ссылки. — design
Q4 (D1): Единица?
A4: Сессия = атомарная запись (длинная сессия делится на блоки по темам внутри записи). Wiki: две оси, темы и календарь (неделя → день → сессии). — design
Q5 (D4): Поиск?
A5: Навигация по индексам wiki + grep сабагентом, в главный контекст только ответ со ссылками. Векторный бэкенд (Recall или другой) как опция позже поверх тех же markdown. Противоречие «как Recall, RAG» vs «structure-first» разрешено в пользу structure-first. — design
Q6 (D2): Кто/когда запускает консолидацию?
A6: SessionStart-хук считает несведённые записи; при ≥N или >24ч баннер просит модель запустить фонового сабагента-консолидатора; плюс ручной скилл. — design
Q7 (D2): Связь с CLAUDE.md?
A7: Ничего в CLAUDE.md. SessionStart-хук плагина подаёт ≤5 строк additionalContext (путь к индексу, число записей, дата сводки, последние темы, имя скилла). Корневой индекс ≤60 строк по требованию. — design
Q8 (D3): Прошлое до установки?
A8: Одноразовый скилл backfill: git log по релизам, спеки, ADR, грили, хендоффы, CHANGELOG, живые jsonl → записи с пометкой «восстановлено задним числом, источник: …». — design
Q9 (D4): Три памяти?
A9: По виду знания: auto memory = личное (как работать с человеком), локально; хроника/wiki = проектное, git; VULYK memory/learnings упраздняется (хук в плагин, librarian читает хронику), memory/map и memory.md остаются картой кода. — design
Q10 (D1): Критерий успеха?
A10: Скилл-валидатор: структурные инварианты скриптом (запись на сессию, сведена, ссылка из темы и календаря, нет битых ссылок, индекс в лимите) + файл золотых вопросов проекта (5-10 с известным ответом и ссылкой), прогон после сводки, доля попаданий и цена в jsonl. — design
Q11 (D4, находка): SessionEnd = 1,5 с общий бюджет, до 60 с через timeout; PreCompact/Stop/SessionStart = 600 с; async без таймаута, поведение на выходе не документировано. VULYK_AUTOLEARN в SessionEnd не мог работать. — public ✅ docs/en/hooks
A11: SessionEnd только закрывает сырой журнал и ставит флаг. Дистилляция: следующий SessionStart (фоновый сабагент по сырому журналу), PreCompact (блок до сжатия), ручной скилл. — design
Q12 (D3): Модель и потолок цены?
A12: Sonnet на дистилляцию и сводку, топ-модель никогда; потолок ~5% токенов сессии, цена каждой дистилляции в jsonl. — design
Q13 (D2): Контракт VULYK → хроника?
A13: Одна CLI-команда `append --kind grill|brief|verdict|ship|handoff --ref <path> --note` в bin/ плагина; VULYK зовёт из journal.sh, /vulyk-handoff, supergrill при синтезе; без плагина вызов тихо пропускается. — design
Q14 (D2): Репо и дистрибуция?
A14: Отдельный репо в E:/Projects/, первые недели --plugin-dir в VULYK и одном хайве, затем свой marketplace, /plugin install в каждый проект. — design
Q15 (D5): Что заставит выключить?
A15: Если ответы сабагента с wiki на золотые вопросы не точнее и не дешевле, чем сабагент с git log и docs/. Цена и шум в git вторичны, крутятся порогами. — opinion

## Ledger
### ✅ Facts
- Хук = shell без суждения; `Stop` даёт `last_assistant_message`, `UserPromptSubmit` даёт `user_input`, все дают `transcript_path`. — docs/en/hooks
- Транскрипт удаляется через `cleanupPeriodDays` (30), формат внутренний. — docs/en/sessions
- VULYK: learnings-хук выключен (стаб), handoff локальный, wiki пуста, librarian единственный консолидатор. — диск
- SessionEnd-хуки: общий бюджет 1,5 с, до 60 с; command-хуки по умолчанию 600 с; `async: true` без таймаута. — docs/en/hooks ✅
### 🎯 Decisions
- D1 Захват: хуки пишут сырьё, модель судит на границах. Почему: живучесть при крэше, одна модельная плата за сессию.
- D2 Выжимки + wiki в git, сырьё + handoff локально. Почему: переезд с репо, redact только выжимок.
- D3 Отдельный плагин, VULYK первый потребитель. Почему: любой проект, один владелец SessionEnd и хроники.
- D4 Сессия = запись; wiki по темам и календарю. Почему: границу даёт session_id; два типа вопросов.
- D5 Навигация + grep, векторы опционально позже. Почему: ноль инфраструктуры, работает после clone.
- D6 Консолидация на SessionStart по порогу фоном + ручной скилл. Почему: нет демона, работает на любой машине.
- D7 Ничего в CLAUDE.md; ≤5 строк additionalContext на старте. Почему: не растёт, работает без CLAUDE.md.
- D8 Backfill-скилл из git/спек/ADR/грилей/хендоффов/jsonl с пометкой происхождения. Почему: иначе тестовый вопрос без ответа навсегда.
- D9 Разделение по виду знания: auto memory личное, хроника проектное, VULYK learnings упраздняется. Почему: одно место ответа на каждый вопрос.
- D10 Валидация: инварианты скриптом + золотые вопросы с jsonl-метрикой. Почему: число для решения о векторах.
- D11 Дистилляция на следующем SessionStart, PreCompact и по команде; SessionEnd только флаг. Почему: 60-секундный потолок SessionEnd.
- D12 Sonnet на всё, потолок ~5% сессии, цена в jsonl. Почему: лестница ADR-007, число для порогов.
- D13 Контракт: одна команда append в bin/. Почему: один владелец формата, любой скилл подключается.
- D14 Отдельный репо, свой marketplace, --plugin-dir в разработке. Почему: обновление по version, без раскатки файлами.
- D15 Критерий выключения: золотые вопросы не лучше базовой линии (git log + docs/). Почему: измеримо валидатором Q10.
### 🅰 Assumptions
- ✓ (опровергнуто) дистилляция в SessionEnd не успевает: 60 с потолок — docs/en/hooks. Решено D11.
- ✗ Фоновый сабагент на SessionStart не мешает первому запросу пользователя (гонка за файлы хроники) — проверить на VULYK.
- ✗ Сырой журнал из Stop/UserPromptSubmit (user_input + last_assistant_message) достаточен для дистилляции без jsonl — проверить на одной сессии, сравнив с /export.
- ✗ Качество навигации достаточно без векторов — проверяется тестовым вопросом «что было до 0.1».
### ⚠️ Risks
- Двойная дистилляция (VULYK-хук + плагин) → контракт: плагин владеет дистилляцией, VULYK-хук learnings удаляется.
- Сырой журнал растёт без границ на длинных сессиях → ротация по session_id, локально, чистится вместе с транскриптом.
- Секреты в выжимке → redact.sh обязателен на пути в git.
### ❓ Open branches
- имя плагина; путь хроники по умолчанию внутри проекта.
### 🔍 Contradictions
- «хуки определяют важное» vs хук без модели → разрешено: хуки сырьё, модель на границах.
- «как Recall, RAG» vs structure-first → разрешено: навигация первична, векторы опция.
- D1 «модель судит на SessionEnd» vs документированный 60-с потолок → разрешено D11: следующий SessionStart + PreCompact + команда.

## Synthesis (2026-09-21)

### Вердикт
Отдельный плагин Claude Code («хроника + wiki»), ставится в любой проект, VULYK его первый потребитель. Хуки пишут сырой журнал сессии локально (Stop/UserPromptSubmit), SessionEnd только закрывает его флагом; модель на sonnet дистиллирует журнал в датированную запись сессии на следующем SessionStart, на PreCompact и по команде. Записи и wiki (темы + календарь, сильно перелинкованы) коммитятся в git через redact; сырьё и хендофф остаются локально. Консолидация в wiki запускается фоновым сабагентом на старте сессии по порогу. В CLAUDE.md ничего: пять строк additionalContext на старте. Поиск: навигация по индексам + grep сабагентом; векторы (Recall) как опция, решаемая по метрике золотых вопросов. Auto memory Anthropic остаётся личной памятью; VULYK memory/learnings упраздняется, librarian читает хронику; VULYK и другие скиллы пишут события одной командой append. Backfill-скилл восстанавливает прошлое из git/спек/ADR/грилей/хендоффов с пометкой происхождения. Валидация: инварианты скриптом + золотые вопросы + цена в jsonl; критерий выключения — не лучше базовой линии.

### Roadmap
| Фаза | Что | Выход | Проверяет допущение |
|---|---|---|---|
| 0 Спайк (1-2 дня) | Хуки Stop/UserPromptSubmit → сырой журнал `.claude/<plugin>/raw/<session>.md`; SessionEnd флаг; SessionStart баннер. Только на VULYK через --plugin-dir | Журнал одной реальной сессии 300k | Сырой журнал достаточен vs /export; гонка фонового сабагента с первым запросом |
| 1 v0.1 Дистилляция | Плагин-скелет (manifest, hooks.json, agents/distiller sonnet, skills/distill), запись сессии в `docs/<chronicle>/sessions/`, redact на пути в git, PreCompact-блок | Записи для 5 сессий VULYK | Цена ≤5% сессии |
| 2 v0.2 Wiki + recall | agents/consolidator, wiki темы + календарь + корневой индекс ≤60 строк, скилл recall (сабагент, возвращает ответ со ссылками), скилл validate (инварианты + golden-questions.md + jsonl) | Ответ на 5 золотых вопросов VULYK | Навигация без векторов даёт попадания |
| 3 v0.3 Контракт VULYK | bin/append; VULYK 0.16: journal.sh, /vulyk-handoff, supergrill зовут append; хук learnings удалён; librarian читает хронику; memory.md указывает на wiki | VULYK 0.16 shipped | Нет двойной дистилляции |
| 4 v0.4 Backfill | Скилл backfill по git log/спекам/ADR/грилям/хендоффам/jsonl с пометкой источника; прогон на VULYK | Ответ на «что было до 0.1» | Реконструкция отличима от записи с натуры |
| 5 v0.5 Раскатка | marketplace, /plugin install в 12 хайвов, 2 недели метрик, решение о векторном бэкенде по золотым вопросам | jsonl по 12 проектам | Критерий D15 |

### Assumption ledger
- ✓ SessionEnd ≤60 с — docs/en/hooks (опровергло синхронную дистилляцию в SessionEnd).
- ✓ Хуки получают user_input / last_assistant_message / transcript_path — docs/en/hooks.
- ✓ Транскрипты 30 дней, формат внутренний — docs/en/sessions.
- ✗ Сырой журнал достаточен без jsonl — фаза 0, сравнить с /export одной сессии.
- ✗ Фоновый сабагент на SessionStart не мешает первому запросу — фаза 0.
- ✗ Навигация без векторов достаточна — фаза 2, золотые вопросы.
- ✗ Цена ≤5% — фаза 1, jsonl.
- ✗ async-хук переживает выход процесса — не нужно проверять, дизайн его не использует.

### Fact ledger
См. таблицу fact-check в сессии: auto memory ✅, agent memory project ✅, хуки ✅, транскрипты ✅, плагины ✅, лимит SessionEnd ✅, «Auto Dream» ❓.

### Contradiction log
1. «хуки определяют важное» vs хук без модели → сырьё хуками, суждение моделью на границах.
2. «как Recall, RAG» vs structure-first VULYK → навигация первична, векторы по метрике.
3. «модель судит на SessionEnd» vs 60-с потолок → следующий SessionStart + PreCompact + команда.
4. «сессия / день / степ / блок» (четыре единицы) → сессия как запись, блоки внутри, день/неделя как индекс.

### Risk register
- Двойная дистилляция VULYK+плагин → хук learnings удаляется в фазе 3.
- Секреты в git → redact обязателен на пути записи; сырьё никогда не в git.
- Рост сырого журнала → ротация по session_id, чистится с транскриптом.
- Гонка фонового консолидатора с сессией → lock-файл, консолидатор пишет только в wiki, не в записи.
- Мусорная wiki с правильной перелинковкой → золотые вопросы, не только инварианты.
- Формат хроники меняется → единственный писатель через append, версия формата во frontmatter.

### Residual ambiguity
goal clarity 8/10 · decision-tree coverage 8/10 · evidence strength 7/10 (три допущения фазы 0 не проверены на живой сессии).

### Next step
Фаза 0: спайк сырого журнала на VULYK через --plugin-dir, одна сессия, сравнить с /export. До этого — выбрать имя плагина.

## Act 2 - adversarial review (2026-09-21, fresh opus reviewer, brief only)

Findings (condensed, verbatim in session):
1. Weakest assumption: distillation is irreversible while raw is deleted with the transcript; "как брейнштормили" is exactly what a 5%-capped distiller drops first; golden questions written after seeing distiller output calibrate to it.
2. Missed risks: chronicle entries born on a work branch die with an abandoned branch (and abandoned branches ARE the brainstorm); linked wiki conflicts across parallel branches; several simultaneous SessionStarts each drain the distillation queue; after a week's pause the owner pays for N sessions at once.
3. Cheaper alternative: `docs/chronicle/YYYY-MM.md` appended by journal.sh/handoff/grill + a recall subagent over git log, CHANGELOG, spec briefs, ADR, grills. Phase 3 without phases 0-2, one day. Gives up out-of-spec conversation and intra-day timeline. Baseline measured in phase 5 makes D15 unfalsifiable.
4. Unasked question: who reads, model or human, and how often.

Owner's answers:
- Reader: the model via recall, several times a week; human rarely. → wiki simplifies to a flat corpus of entries with date/topics/links in frontmatter + one root topic index; the calendar axis is generated by script from frontmatter, never written by the model. (amends D4)
- Accepted: baseline first (phase 0 becomes "append + recall over what exists, measured on golden questions"); raw journal kept indefinitely in a gitignored project dir, re-distillable (amends D2 risk); chronicle commits bypass work branches (main or a long-lived chronicle branch) + lock and per-start cap N on the distillation queue; golden questions are written at the moment of the event (grill synthesis, ship), before any distillation (amends D10).

### Roadmap v2
| Фаза | Что | Выход |
|---|---|---|
| 0 Базовая линия (1 день) | Репо litopys с VULYK; `bin/litopys append`; `docs/chronicle/YYYY-MM.md`; recall-сабагент по git log/CHANGELOG/брифам/ADR/грилям; 5 золотых вопросов VULYK, записанных до любой дистилляции; замер попаданий и цены в jsonl | baseline.jsonl |
| 1 Сырой журнал | Хуки Stop/UserPromptSubmit → `.litopys/raw/<session>.md` (gitignored, бессрочно); SessionEnd флаг; SessionStart баннер ≤5 строк; сравнение одной сессии с /export | журнал 1 сессии 300k |
| 2 Дистилляция | agents/distiller sonnet; запись сессии = плоский файл с frontmatter (date, topics, links, source: live\|backfill); redact; коммит мимо рабочих веток; lock + cap N очереди; PreCompact-блок; повторный замер золотых вопросов vs baseline | delta vs baseline |
| 3 Recall + index | root index тем (≤60 строк) генерируется консолидатором; календарь скриптом из frontmatter; скилл recall; validate (инварианты + золотые вопросы + jsonl) | зелёный validate |
| 4 VULYK 0.16 | journal.sh / handoff / supergrill зовут append; хук learnings удалён; librarian читает хронику; memory.md указывает на индекс | VULYK 0.16 shipped |
| 5 Backfill + раскатка | backfill-скилл с пометкой источника; marketplace (образец: E:/Projects/tools/crisp); 12 хайвов; 2 недели метрик; решение о векторах и о том, оправдали ли фазы 1-3 базовую линию (D15) | решение D15 |
