# Brief: haiku-5-5-floor

**Date:** 2026-10-07
**Tier:** 1 - one module (model routing): the haiku floor line, the floor check that reads it, the clerk's frontmatter, their tests and the docs that name the rung
**Source:** owner request with a pasted Telegram post about Claude Haiku 5.5; verified 2026-10-07 against
https://www.anthropic.com/claude-haiku-5-5 (model ID `claude-haiku-5-5`, released October 7, 2026, effort Low..Max),
https://platform.claude.com/docs/en/models/overview (`claude-haiku-5-5`, default effort `medium`, 1M context),
Claude Code CHANGELOG 2.1.293 ("Added Claude Haiku 5.5 (`claude-haiku-5-5`), now the default Haiku model on the
Anthropic API"), and a local probe: Claude Code 2.1.292 `claude -p --model haiku` ran `claude-haiku-4-5-20251001`,
`--model claude-haiku-5-5` ran `claude-haiku-5-5` with `[claude-code:unrecognized_model]`.

## Request (verbatim)

> https://www.anthropic.com/claude-haiku-5-5 Ты идёшь, собираешь информацию, анализируешь и вносишь правки в WULIK Setup, чтобы теперь Hiku работал на модели 5,5 и не ниже. Минимум Hiku 5,5. Кроме этого, идёшь в recall по MCP и смотришь информацию, транскрибацию вот из этого ролика. RECALL · ЗАПИС #7103 И после сбора информации про full-курс Spec-Driven Development с «Кодинговыми агентами» запускаешь супергриль вместе со мной, чтобы прогрилевать, что мы можем улучшить в текущей версии «Вулика».

Sent mid-turn, same session:

> Haiku 5.5 вышла только сегодня, поэтому слово `haiku` в Claude Code может пока вести на старую 4.5. Проверка VULYK этого не заметит. УЧТИ

The Recall #7103 study and the supergrill are a separate deliverable (a grill with the owner), not this spec.

## Asks

1. вносишь правки в WULIK Setup, чтобы теперь Hiku работал на модели 5,5 и не ниже. Минимум Hiku 5,5.
2. слово `haiku` в Claude Code может пока вести на старую 4.5. Проверка VULYK этого не заметит. УЧТИ
