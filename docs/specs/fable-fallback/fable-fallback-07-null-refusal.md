---
story: fable-fallback-07
status: done
returned: DONE
worker: worker-code
model: opus
wave: 5
blocked_by: []
---

# Repair after the live probe: inside a Workflow a Fable refusal comes back as null

## Goal
Ask 1 works on the hive path. A live probe on 2026-10-27 (account 1, Fable exhausted) showed that inside a Workflow `agent()` with `model: 'fable'` neither throws nor returns the refusal text: it returns `null`, and the refusal (`You've reached your Fable limit. Switch to another model, or manage usage credits at https://claude.ai/settings/usage?from=cc_cli_limit_message, to continue.`) shows only in the run's own Failures list, which the script cannot read. So `refused()` never fires in the driver and the build stalls on an "empty return" as before this spec. The owner chose (2026-10-27, AskUserQuestion, option text by the Queen): an empty return from a Fable dispatch triggers one cheap Fable ping; an empty or refused ping means the limit.

## Requirements
> 1. Когда у судьи, планировщика или архитектора кончается Fable, роль один раз перезапускается на Opus: строка в журнал, код телеметрии, одна строка мне; сборка не встаёт.

## Findings
1. .claude/workflows/vulyk-cycle.js `dispatch()` (Queen, live probe, journal 2026-10-27T21:55:09Z) a Fable refusal inside a Workflow is `agent()` -> `null`; `refused(null)` is false, so no fallback. Probe script, verbatim: `const r = await agent('Reply with the single word OK.', { label: 'probe', model: 'fable' })` returned `{"returned":null}` with `agents_error: 1`, `subagent_tokens: 0`, `duration_ms: 422`. For contrast, the Agent tool in a session returns the 317-character text `Agent terminated early due to an API error: You've reached your Fable limit. ...`, which `refused()` already catches (the solo path is fine; do not touch the commands).
   Shape to meet, in `dispatch()`: when the dispatch passed a model other than `FALLBACK_MODEL` and the result is empty (`null`, `undefined` or a blank string) and not already `refused()`, make one ping: `agent('Reply with the single word OK.', { label: \`ping:${where}\`, model: opts.model })` through `caught()`. If the ping is empty or `refused()`, it is the Fable limit: push the `fallbacks` entry, log as today, and redispatch the original prompt and agent once on `FALLBACK_MODEL`. If the ping answers, return the original empty result unchanged, so the turn-cap path (`reasonFor`) behaves exactly as before. A refusal in text keeps its current path (no ping). Never more than one ping per dispatch, and never a ping on a redispatch.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh

## Non-goals
- No change to `refused()`, `REFUSAL`, `REFUSAL_MAX`, `REPORT_HEADER`, the commands' prose, the docs, `CAPS` or `reasonFor`'s wording.
- No ping when the dispatch passed no model or passed `FALLBACK_MODEL`.

## Acceptance criteria
- [ ] Original case in `tests/driver.test.sh`: a fable seat dispatch returns `null`, the ping returns `null` -> one redispatch on opus with the same prompt and agent type, one `fallbacks` entry, the round goes on.
- [ ] Neighbour: a fable dispatch returns `null`, the ping returns `OK` -> no redispatch, no `fallbacks` entry, the existing empty-return (turn cap) handling runs as before.
- [ ] Neighbour: a dispatch with no model (or `opus`) returns `null` -> no ping at all.
- [ ] The existing fallback and refusal cases pass unchanged.

## Verification
`bash tests/driver.test.sh`

## Implementation notes
- .claude/workflows/vulyk-cycle.js: `dispatch()` pings once on the same model when a non-opus dispatch returns empty (null, undefined, blank) and is not `refused()`; an empty or refused ping takes the existing fallback path, an answer returns the original empty result. New helper `empty()`.
- The ping goes through `agent()` with no `agentType` (label `ping:<where>`, the passed model), so the frontmatter of no agent applies; the redispatch never pings (it returns `caught(agent(...))` directly, as before).
- tests/driver.test.sh: null+null ping -> one opus redispatch and one fallback; null+OK ping -> no redispatch (review round and worker turn-cap stop); null with opus or no model -> no ping; null redispatch -> no second ping.
