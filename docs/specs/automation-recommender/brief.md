# Brief: automation-recommender

**Date:** 2026-11-11
**Deliverable:** study (report), no code

## Request (verbatim, redacted)

> 2. claude-automation-recommender. Аудитор для твоего кода
>
> Скилл сканирует кодовую базу и предлагает где добавить хуки, где субагентов, какие скиллы стоит подключить, какие MCP-серверы дадут пользу. Файлов не создаёт, только говорит.
>
> Идея ровно та, которую владелец проекта обычно сам не делает. Открыл свой Python-проект для одного клиента, запустил, получил такой план:
>
>     Хук на pre-commit: автоформат через ruff, потому что у меня много .py файлов и нет .pre-commit-config.yaml.
>     Субагент code-reviewer: смотреть только в src/agents/ (там критическая логика), не трогать tests/.
>     Скилл для генерации Pydantic-схем по примерам JSON, потому что в коде нашёл много dict-структур без типизации.
>     MCP-сервер для PostgreSQL: подключить локальную БД проекта, чтобы Claude мог запросы писать с актуальной схемой.
>
> Полезно тем что не надо самому думать «а что вообще можно автоматизировать». Скилл смотрит конкретно на твой код и предлагает релевантное. Из минусов: рекомендации довольно очевидные если ты уже месяц-два с Claude Code. Но если только начинаешь, или пришёл на новый проект, экономит час времени на размышления.
>
> Я думаю нам это стоит включить и добавить (интегрировать) в вулик, предложи с агентами после тройной валидации агентами как лучше и идеальнее эжто сделать

The first paragraphs are a pasted third-party description of the skill; the last line is the owner's own request.

## Asks

1. Integrate a claude-automation-recommender-style auditor into VULYK.
2. Propose the best way to do it, validated three times by independent agents.
