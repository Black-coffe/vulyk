---
story: fable-fallback-06
status: done
returned: DONE
worker: worker-code
model: opus
wave: 4
blocked_by: []
---

# Narrow fix after GREEN round 2: the refusal detector misses a prefixed refusal

## Goal
The driver's `refused()` catches the real Fable refusal also when the runtime puts text before it, and still never takes a judge's report that quotes the refusal for a refusal. Owner's choice after round 2: narrow fix, no new council round, closed by the owner's ACCEPTED.

## Requirements
> 1. Когда у судьи, планировщика или архитектора кончается Fable, роль один раз перезапускается на Opus: строка в журнал, код телеметрии, одна строка мне; сборка не встаёт.

## Findings
1. .claude/workflows/vulyk-cycle.js:45 (round-2 Fable review, Major [unanchored], report discarded by the false fallback; Queen accepted it) `REFUSAL_TEXT` is anchored at `^Agent terminated early due to an API error`, but the only real sample on this box reads `"<description>" failed: Agent terminated early due to an API error: You've reached your Fable limit. Run /usage-credits ...`: a prefix before the early-stop line, which the anchor misses, so the build would stall as before this spec. Repro: `node -e 'const s="x\" failed: Agent terminated early due to an API error: You\x27ve reached your Fable limit."; console.log(/^Agent terminated early due to an API error[\s\S]*reached your Fable limit/.test(s.trim()))'` prints `false`.
   Shape to meet: a returned string is a refusal when it carries `reached your Fable limit` (straight or U+2019 apostrophe) or `model_requires_usage_credits` AND it is not a report: it is short (the real refusal is about 250 characters; pick a bound such as 600 and name it in the comment) and its first line is not a report header (`VERDICT:`, `COUNCIL:`, `STATUS:`). The caught-error arm (`threw`) stays as it is.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh

## Non-goals
- Nothing else in the driver, the commands' prose or the docs changes; the round-1 live case and the U+2019 case in `tests/driver.test.sh` keep passing unchanged.

## Acceptance criteria
- [ ] `tests/driver.test.sh` gains the original case: the prefixed real sample above (`"<description>" failed: Agent terminated early ...`) is redispatched on opus with a `fallbacks` entry.
- [ ] And a neighbour: a short `STATUS: DONE` worker return that mentions `model_requires_usage_credits` is not redispatched, no `fallbacks` entry.
- [ ] The existing fallback cases (refused reviewer, refusal twice, thrown `model_requires_usage_credits`, quoting report, U+2019) pass.

## Implementation notes
- .claude/workflows/vulyk-cycle.js: `REFUSAL_TEXT` (anchored) replaced by `REFUSAL` + `REFUSAL_MAX = 600` + `REPORT_HEADER`; the `threw` arm is unchanged.
- Decision: the header check looks at every line (`/^\s*(VERDICT|COUNCIL|STATUS)\b/m`), not just the first: the existing quoting case opens with `COUNCIL REPORT` and has `VERDICT:` on line 2, and a wider guard only errs towards keeping a report.
- tests/driver.test.sh: added the prefixed real sample (redispatched on opus, one fallback) and a fable worker's short `STATUS: DONE` return naming `model_requires_usage_credits` (one dispatch, no fallback).
- Mutation: dropping `!REPORT_HEADER.test(r)` turns 2 checks red (the quoting case and the new neighbour).

## Verification
`bash tests/driver.test.sh`
