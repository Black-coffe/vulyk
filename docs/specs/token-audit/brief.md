# Brief - token-audit

Date: 2026-09-26 · Owner: Andrei · Deliverable: document (study work) · Tier: none

## Request (verbatim)

The owner's words, 2026-09-26 (speech-to-text renders VULYK as "Vultr"):

> Работаю с последней версией Vultr, и я замечаю, что у него в среднем на задачу, которую я даю, независимо большая, маленькая задача, уходит до 3 млн токенов в некоторых проектах, где я его использую. И он постоянно какие-то круги запускает, один-два круга. Есть у меня проекты, где я даю такого же уровня сложности задачи, но там и время в пять раз меньше, и количество токенов меньше.

> Можешь заняться глубокой аналитикой текущей системы Vultr, архитектуры, логики, как он работает, сколько сабагентов запускает, и найти все его дыры, где он дырявый, где недоделано, какие проблемы, почему так происходит и что нужно оптимизировать, переделать?

> И самое главное — учти всё, что говорят про последние модели Claude кода, Anthropic, потому что Vultr писался ещё год назад, и многое чего могло устареть, и принципы могли устареть.

## Asks

1. Measure where the tokens go: per task, per agent, per round, in the owner's real VULYK projects.
2. Explain why a task of any size costs up to ~3M tokens and runs one or two extra circles.
3. Compare with the owner's non-VULYK projects where same-size tasks take ~5x less time and tokens.
4. Map the architecture and logic: how the loop works, how many subagents a task dispatches.
5. List every hole: what leaks tokens, what is unfinished, what is broken.
6. Check VULYK's principles against current Anthropic / Claude Code guidance for the latest models; name what is outdated.
7. Say what to optimize and what to rebuild, recommended option first and why.

## Evidence

- Transcripts: `~/.claude/projects/<project>/*.jsonl` and `<session>/subagents/`, `<session>/workflows/`.
- Council ledger per project: `memory/stats/council.jsonl`.
- Working notes of the three recon agents: `docs/specs/token-audit/evidence/`.
