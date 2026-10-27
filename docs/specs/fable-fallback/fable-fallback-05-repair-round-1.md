---
story: fable-fallback-05
status: done
returned: DONE
worker: worker-code
model: opus
wave: 3
blocked_by: []
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 3. Кэш на 1 час только у ревьюера; через неделю замер расхода и решение, распространять ли.

## Findings
1. docs/model-cascade.md:112 [ask 3] the one-hour cache must be the reviewer's alone, or the brief, plan and this doc line must record that `worker-code` and `worker-test` already carry it and the owner accepted that - the diff writes "`lead-review` alone carries `experimental:` / `cacheTtl: 1h`" and plan.md:15 and story 02 say "the only agent that does", yet `.claude/agents/worker-code.md:9` and `.claude/agents/worker-test.md:9` carry `cacheTtl: 1h` on the base (commit ab4f8aa), so the 2026-11-03 "spread or not" decision the owner chose rests on a false baseline - repro: `grep -rn cacheTtl .claude/agents/`

2. NEEDS_CONTEXT (worker-code, 2026-10-27): finding 1 cannot be met inside `## Files`. Option A (reviewer alone) means deleting `cacheTtl: 1h` from `.claude/agents/worker-code.md` and `.claude/agents/worker-test.md`, not in `## Files`, and reverts ab4f8aa (2026-10-01, docs/specs/cache-economy/report.md: close-story suites outlived the 5 min cache 23 times in 10 days, ~40% of worker-code's cost). Option B (record the baseline) needs `docs/specs/fable-fallback/plan.md` (line 15) and `brief.md`, also not in `## Files`, plus an owner acceptance nobody gave. Recommended: B, since the workers' 1h cache is a measured earlier decision; the 2026-11-03 comparison then reads as "spread to the remaining roles", with workers already on 1h. Question for the Queen/owner: does the owner accept that worker-code and worker-test keep `cacheTtl: 1h` (B), and may this story add plan.md and brief.md to `## Files`? Or A, with the two agent files added?

3. NEEDS_CONTEXT again (worker-code, 2026-10-27, redispatch stamp 3054cf77b2cd6259): the redispatch carried no answer to finding 2 and `## Files` is unchanged, so the same question stands; no code edited this attempt.

4. Answer to findings 2-3 (Queen, 2026-10-27): option B. `worker-code` and `worker-test` keep `cacheTtl: 1h` (ab4f8aa, a measured earlier decision outside this spec; the owner's ask 3 is about which judge gets it). Do not touch the two agent files. plan.md line 15 is already corrected by the Queen. Your part: `docs/model-cascade.md:112` and `docs/token-economy.md:59-61` say the same true thing: the workers carry `1h` since cache-economy, `lead-review` is the only judge that does since this spec, the other agents stay at 5 minutes, and the 2026-11-03 comparison is `lead-review`'s spend against the week before. Repro: `grep -rn cacheTtl .claude/agents/` and the two doc lines agree.

5. .claude/workflows/vulyk-cycle.js:41 (Queen, seen live in this build) the refusal detector fires on a normal report that quotes the refusal text: in round 1 `council-opus` ran on Fable, returned a full GREEN report whose ASK 1 line quotes `model_requires_usage_credits` (it tested this very feature), the driver took it for a refusal, threw the report away and redispatched the seat on Opus (`fallbacks: [{council-opus, round-1/opus, fable -> opus}]`). Any judge reviewing a diff that mentions the refusal triggers it. A returned string counts as a refusal only when it is the refusal: trimmed, it starts with `Agent terminated early due to an API error` and carries `reached your Fable limit` (straight or U+2019 apostrophe, the round-1 UNASKED e); a caught error (`threw`) keeps matching either form anywhere. The same narrowing goes into the rule text of `.claude/commands/vulyk-build.md` `## Fable-limit fallback` and its twins in `vulyk-review.md` and `vulyk-plan.md` ("whose returned text or error carries" is the same false positive on the solo path). `tests/driver.test.sh` gains the original case (a report text that quotes `model_requires_usage_credits` and `You've reached your Fable limit` mid-text is not redispatched, no `fallbacks` entry) and a neighbour (the real refusal with a U+2019 apostrophe is redispatched); the existing refusal cases still pass.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- scripts/telemetry.sh
- docs/telemetry.md
- tests/telemetry.test.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- .claude/commands/vulyk-plan.md
- .claude/agents/lead-review.md
- scripts/top-model.sh
- docs/model-cascade.md
- docs/token-economy.md
- docs/adr/015-sonnet-execution-rung-and-model-floor.md
- tests/model-profile.test.sh

## Verification
`bash tests/driver.test.sh`
`bash tests/telemetry.test.sh --part telemetry && bash tests/maintenance.test.sh`
`bash tests/model-profile.test.sh && bash tests/maintenance.test.sh`

## Implementation notes
- .claude/workflows/vulyk-cycle.js: `refused()` matches a caught error anywhere (straight or U+2019 apostrophe, or `model_requires_usage_credits`); a returned string only when, trimmed, it starts with `Agent terminated early due to an API error` and carries `reached your Fable limit`.
- tests/driver.test.sh: original case (GREEN report quoting both refusal forms mid-text: one dispatch, no fallback) and neighbour (real refusal, U+2019, leading whitespace: redispatched on opus).
- .claude/commands/vulyk-build.md, vulyk-review.md, vulyk-plan.md: rule text narrowed the same way.
- docs/model-cascade.md:112 and docs/token-economy.md:59-62: workers carry 1h since cache-economy, `lead-review` the only judge since this spec, others at 5 min, 2026-11-03 compares `lead-review`'s spend with the week before (option B; agent files untouched).
