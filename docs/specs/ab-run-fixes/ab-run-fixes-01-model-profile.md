---
story: ab-run-fixes-01
spec: ab-run-fixes
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: model-profile: --recommend gives sonnet-builds on every plan
red_verified_at: 2026-11-08T21:20:24Z 7683861a11fcf8b3b2caf2cbb22ca67b690b8232487101a91e0621fdb4c6167d
---

# Model profile: `sonnet-builds` is the recommendation; no 1 h cache on three agents

## Goal
After this story:
- `bash scripts/model-profile.sh --recommend` prints `sonnet-builds` for every account shape: Max/Ultra, a premium seat, Pro, a standard seat, an API key, and no profile.
- `opus-builds` is reached only through the owner's own `--set opus-builds`.
- `/vulyk-models` lists `sonnet-builds` first, marked «(Рекомендую)» with the reason (the A/B run compared Opus with Opus because workers ran on Opus), and presents `opus-builds` as the owner's explicit choice.
- `lead-review`, `worker-code` and `worker-test` no longer carry `experimental: cacheTtl: 1h`; an `experimental:` block left empty goes too.
- The docs that state either rule state the new one.

The plan-header line is story 02's.

## Requirements
> 1. Профиль моделей: `--recommend` всегда даёт `sonnet-builds`, `opus-builds` включается только явным выбором владельца, профиль печатается в шапке плана.
> 4. Убрать `cacheTtl: 1h` у `lead-review`, `worker-code` и `worker-test`.

## Files
- scripts/model-profile.sh
- tests/model-profile.test.sh
- .claude/commands/vulyk-models.md
- .claude/agents/lead-review.md
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- docs/model-cascade.md
- docs/token-economy.md
- docs/adr/020-*.md

## Non-goals
- Do not change `--set`, the role table `--explain` prints, the `economy` profile or any dispatch rule. Only the recommendation and its wording change.
- Leave alone:
  - the plan header (story 02);
  - `README.md` (its line 138 already calls `sonnet-builds` the default; the result paragraph is story 06's);
  - `memory/map/` (`drone-docs` updates it at ship).
- Set no TTL anywhere else, and add no `subagentPromptCacheTtl` or env variable.

## Map slice
memory/map/scripts.md (`model-profile.sh`, `top-model.sh` entries); memory/map/agents-and-commands.md (`lead-review`, `worker-code` / `worker-test` frontmatter; `/vulyk-models`)

## Acceptance criteria
- [ ] `--recommend` prints `sonnet-builds` on synthetic profiles for Max, Ultra, a premium seat, Pro, a standard seat, an API key and no profile. The test labelled `model-profile: --recommend gives sonnet-builds on every plan` fails on HEAD (a premium plan gives `opus-builds`) and passes after.
- [ ] `--set opus-builds` still writes `opus-builds`, and no other path produces it.
- [ ] `/vulyk-models` asks one question with `sonnet-builds` first, «(Рекомендую)» and why; `opus-builds` reads as the owner's choice.
- [ ] None of the three agent files mentions `cacheTtl`, and `prompt-check.sh --touched` passes on them.
- [ ] These docs state the new rules:
  - `docs/token-economy.md`, in the time row of the cache table and in the worker paragraph. It says the 1 h choice is reversed on the A/B run's evidence and what that costs: a worker idle past 5 min re-writes its prefix.
  - `docs/model-cascade.md`, in its profiles section.
  - ADR-020, in one dated amendment line.
- [ ] `## Implementation notes` ends with one `CHANGELOG:` line for `## [Unreleased]`.

## Verification
`bash tests/model-profile.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- scripts/model-profile.sh: `--recommend` prints `sonnet-builds <plan>` on every plan; the help line says so; output shape unchanged.
- tests/model-profile.test.sh: one labelled check over seven synthetic shapes (Max, Ultra, premium seat, Pro, standard seat, API key, none); the old `opus-builds max` expectation now reads `sonnet-builds max`.
- Ultra fixture is `claude_max` with an `ultra` rate tier (top-model.sh has no separate Ultra organizationType); the real field value was not checked.
- Agents: removed the two-line `experimental: / cacheTtl: 1h` block from lead-review, worker-code, worker-test.
- /vulyk-models: sonnet-builds first with «(Рекомендую)» and the Opus-vs-Opus A/B reason; opus-builds marked the owner's own choice; the credits note keys on the plan word now.
- Docs: token-economy time row + worker paragraph (reversal and the 5-min re-write cost), model-cascade profiles section + cache paragraph, ADR-020 one amendment line.
- Surprise: the docs are CRLF in the working tree; edits were made line-ending-aware.
CHANGELOG: `--recommend` and `/vulyk-models` recommend `sonnet-builds` on every plan (`opus-builds` only by the owner's own choice); `lead-review`, `worker-code` and `worker-test` drop `cacheTtl: 1h`.

## Findings

## Red receipt
- command: bash tests/model-profile.test.sh
- exit: 1
- tests: 7683861a11fcf8b3b2caf2cbb22ca67b690b8232487101a91e0621fdb4c6167d (tests/model-profile.test.sh)
- impl: 94faab54bd40a1222e78399188a7523cd20af78eccc74ece7c1a3134558df979
- stamped: 2026-11-08T21:20:24Z

```
::error::model-profile: --recommend gives sonnet-builds on every plan - expected [max=sonnet-builds ultra=sonnet-builds premium-seat=sonnet-builds pro=sonnet-builds standard-seat=sonnet-builds api=sonnet-builds missing=sonnet-builds], got [max=opus-builds ultra=opus-builds premium-seat=opus-builds pro=sonnet-builds standard-seat=sonnet-builds api=sonnet-builds missing=sonnet-builds]
  ok    the USERPROFILE fallback reads back
  ok    nothing else appeared under the fallback home
--- top-model-brief.sh
  ok    the brief ends with the default, not chosen
  ok    the brief ends with the chosen profile
  ok    the brief says the profile decided the gate
--- CLAUDE.md
  ok    the ## Commands row is there
  ok    CLAUDE.md is no bigger than at baa5219 (7156 <= 7162 B)
model-profile.test.sh: 2 of 81 checks failed
```
