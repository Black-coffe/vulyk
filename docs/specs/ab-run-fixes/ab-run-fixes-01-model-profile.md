---
story: ab-run-fixes-01
spec: ab-run-fixes
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: model-profile: --recommend gives sonnet-builds on every plan
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

## Findings
