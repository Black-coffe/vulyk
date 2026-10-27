---
story: fable-fallback-01
spec: fable-fallback
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
---

# The Workflow driver redispatches a Fable-refused role once on Opus

## Goal
After this story `.claude/workflows/vulyk-cycle.js` no longer lets one Fable-limit refusal end a build. Every `agent()` dispatch goes through one helper: when the result (or the error `caught()` swallowed) carries the Fable-limit text and the model passed was not already `opus`, the helper dispatches the same prompt and agent type once more with `model: 'opus'`, records the event in a `fallbacks` array that the driver's final return value carries, and prints one console line. A refusal on that second call goes down the existing path (absent seat, missed story). `tests/driver.test.sh` gains the case that fails when the branch breaks.

## Requirements
> делай вариант A из fable-budget, судья при отказе — Opus
> 1. Когда у судьи, планировщика или архитектора кончается Fable, роль один раз перезапускается на Opus: строка в журнал, код телеметрии, одна строка мне; сборка не встаёт.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh

## Non-goals
- No journal line, no `telemetry.sh record`, no clerk call from the driver: the driver has no shell but `cycle-clerk`, whose verbs stay `advance|status|release`. The record is written by `/vulyk-build` from the returned `fallbacks` (story 02).
- No change to `CAPS`, to the rejected-report redispatch of seats, to the `RETRY` model rule or to the `attempt-<k>` numbering: the refused call wrote no report, so the fallback is not an attempt.
- No fallback for any other error text (an Opus or Sonnet limit, `usage_limit_reached`, a thrown clerk call): those behave as today.
- No new argument from `/vulyk-build`: the fallback family is the constant `FALLBACK_MODEL = 'opus'`, not a profile lookup.
- Do not touch `.claude/commands/vulyk-build.md` or `scripts/telemetry.sh` (story 02 owns them).

## Map slice
- memory/map/cycle.md `## The Workflow driver`, `## advance` (what `--ingest` reads per seat and attempt)
- memory/map/agents-and-commands.md `## Commands` the `/vulyk-build` bullet (hive path: how the driver is launched and what a thrown call records)

## Acceptance criteria
- [ ] With the test's stubbed `agent()` returning `Agent terminated early due to an API error: You've reached your Fable limit. ...` for a `lead-review` dispatch passed `model: 'fable'`, the driver makes exactly one more call with the same prompt and `agentType` and `model: 'opus'`, then continues the round; the driver's return value has `fallbacks.length === 1` with `{agent: 'lead-review', where: 'round-1/review', from: 'fable', to: 'opus'}`; the console shows `fallback: lead-review round-1/review fable -> opus (Fable limit)`.
- [ ] A stubbed refusal on the second call too: no third call; the seat is handled as an absent/empty report exactly as before this story (the existing driver test for that path still passes unchanged).
- [ ] A refusal matched as `model_requires_usage_credits` in a caught error's message is treated the same as the text form.
- [ ] A dispatch passed `model: 'opus'`, or no model, that returns the refusal text is not redispatched.
- [ ] Worker dispatches and the retry on `top_model` go through the same helper; a run with no refusal returns `fallbacks: []` and every existing driver test passes unchanged.
- [ ] The `tests/driver.test.sh` case fails against the 0.38.0 driver (the worker states in `## Implementation notes` that it ran it once before the change).

## Verification
`bash tests/driver.test.sh`

## Implementation notes

## Findings
