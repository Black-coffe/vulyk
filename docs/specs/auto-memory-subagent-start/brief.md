# Auto memory and SubagentStart (brief)

**Date:** 2026-10-28 · **Tier:** 2

## Request (verbatim)
<!-- the owner's /vulyk-plan arguments, piped through scripts/redact.sh -->
> Укрощение нативной Auto Memory Claude Code и хук SubagentStart / SubagentStop
> Как сейчас в «Вулике»: В 2026 году в Claude Code активно работает встроенная Auto Memory (~/.claude/projects/.../memory/MEMORY.md, куда сам Claude Code тихо пишет заметки и грузит первые 200 строк / 25 КБ в каждую сессию), плюс появились хуки SubagentStart и SubagentStop. В «Вулике» есть /vulyk-gc memory и memory-triage.sh для разбора приватной памяти, но в обычных сессиях нативная Auto Memory может:
>
> Тихо раздувать стартовый контекст на 25 КБ без ведома «Вулика».
>
> Конфликтовать с docs/defects/ и memory/memory.md (модель записала в Auto Memory старый костыль, который в «Вулике» уже запрещён карточкой дефекта).
>
> Что делают продвинутые команды в 2026:
>
> Либо жёстко контролируют autoMemoryEnabled: false в проектных настройках, делегируя всю память git-системе проекта (как у тебя в memory/ и docs/defects/), чтобы не платить дважды за контекст и не ловить теневые галлюцинации.
>
> Либо используют хук SubagentStart: в Claude Code он позволяет динамически инжектировать additionalContext ровно в момент старта субагента!
>
> Как внедрить в «Вулик»:
>
> Сейчас defects-inject.sh срабатывает на PreToolUse (когда агент уже решил вызвать инструмент). Если подключить его ещё и на SubagentStart (фильтруя карточки по ## Files истории, которую передали воркеру), то worker-code получит нужные карточки «Нельзя / Как надо» (docs/defects/) до первого хода мышления, не читая лишних файлов.
>
> А в session-start-brief.sh добавить проверку размера нативного MEMORY.md: если Claude Code накопил там мусор в обход «Вулика», сразу сигнализировать memory triage due.

## Recon facts (2026-10-28, Claude Code 2.1.312)
- `SubagentStart` input is the common fields plus `agent_id` and `agent_type`, no prompt (docs code.claude.com/docs/en/hooks.md; installed binary `hook_event_name:"SubagentStart",agent_id:n,agent_type:r`).
- Probe in a scratch project: the hook's `additionalContext` reached a general-purpose subagent; at hook time the subagent's own transcript did not exist yet, the parent transcript already held the `Agent` call with its prompt.
- Workflow-driver agents are not `Agent` calls in the parent transcript (`subagents/workflows/<run>/`); whether `SubagentStart` fires for them is not checked.
- `autoMemoryEnabled: false` in project settings turns auto memory off for that project; env `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` (docs code.claude.com/docs/en/memory.md; installed binary schema "Enable auto-memory for this project").
- Docs say the main auto memory is not loaded into subagents; on this machine 108 of the last 180 subagent transcripts of this project carry an `AutoMem` MEMORY.md block.
- Claude Code itself warns after a write that pushes MEMORY.md near or over 200 lines / 25 KB; nothing checks at session start.

## Answers
1. Доставка: Карточки при чтении истории (Рекомендую). Хук срабатывает, когда агент открывает файл истории, и сразу показывает карточки для её ## Files. Работает у любого исполнителя: воркера из Workflow, субагента, самой Королевы на Tier 1-2. SubagentStart не нужен. Цена: хук на каждое чтение, лишние отсекает дешёвая проверка пути в bash.
2. Порог: От 80% лимита (Рекомендую). 160 строк или 20 КБ: сигнал до того, как хвост оглавления начнёт молча отрезаться. В строке размер и /vulyk-gc memory; разбор и так спрашивает ваше «да», прежде чем что-то трогать.
3. Выключатель: Только описать в доке (Рекомендую). VULYK сам ничего не выключает. В docs/memory-system.md строка: как выключить и что тогда пропадёт.
4. Требования: Верно, покажи план (Рекомендую).

## Asks
1. Когда агент читает файл истории, ему сразу показываются карточки docs/defects/ для файлов её ## Files, до первой правки, каждая карточка один раз на агента.
2. Старт сессии пишет «memory triage due» с размером, когда нативный MEMORY.md проекта достиг 160 строк или 20 КБ.
3. В доке описано, как выключить автопамять и что при этом пропадёт; сам VULYK ничего не выключает.
