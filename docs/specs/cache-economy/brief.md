# Brief: cache-economy

**Date:** 2026-09-30
**Deliverable:** document (study work, `/vulyk-plan` step 0): `report.md`, no stories, no council.

## Request (verbatim)

> Мне нужно, чтобы ты запустил сабагентов и пошёл в интернет, и вообще почитал всё про все виды кэша, которые можно использовать, работая с Cloud Code. Какие типы кэшей есть, как они работают, есть ли какие-то решения в самой Cloud Code обёртке, как харнесс для кэша, что вообще базового у них с кэшем, что нужно и что вообще люди думают по этому поводу, что на GitHub есть, поресёрч, составь себе список 50 запросов для GitHub разных и поищи там Cloud Code кэш, AI кэш и всё такое, API кэш. Короче, я хочу наш вулик прокачать в экономии токенов, но только сугубо за счёт кэша. Только за счёт кэша.

## Asks

1. Research every kind of cache usable when working with Claude Code (the owner says "Cloud Code"), how each works.
2. What the Claude Code harness itself does for caching, and what is basic/built in.
3. What people think about it (community opinion).
4. GitHub: a list of 50 distinct search queries, run them (Claude Code cache, AI cache, API cache, ...).
5. Goal: token savings for VULYK strictly through cache, nothing else.

## Baseline already in the repo

- `docs/token-economy.md` (cache key table, TTLs, subagent 5 min cache, omitClaudeMd)
- `scripts/token-report.py` (weighted = input + 1.25 w5m + 2 w1h + 0.1 read + output)
- `docs/specs/token-audit/report.md` (1,844 sessions, 13-26 Sep 2026)
