---
story: weekly-budget-05
spec: weekly-budget
status: todo
returned:
tier: 4
worker: worker-code
wave: 3
blocked_by: [weekly-budget-03]
red: required
red_reason: FAIL ladder downgrade-1-gate
---

# Routing: the budget ladder as the last rung step, the narrower Fable list, version-free pricing

## Goal
`top-model.sh` and `model-profile.sh --role <r>` resolve `env > constitution pin > profile > plan` as today, then apply
`budget.sh state --json` (never a poll) as the last step before the floor check (ADR-028 §2): `downgrade-1` sends every Fable
role to `opus`, `downgrade-2` also sends `worker`/`routine` roles resolving to `opus` to `sonnet` (under `sonnet-builds` it only
warns), `boost` on plans with Fable inside returns the Tier 3-4 planner and Tier 1-3 review to `fable`, and a Fable-bucket
`fable_state` acts on Fable roles alone. The Fable list becomes the Tier 4 `lead-review`, `lead-architect` and the retry; the
planner, Tier 1-3 review and both blind seats resolve to `opus` under every profile. `--explain` prints the step and why.
`token-report.py` prices by family and minimum version. `docs/model-cascade.md` says all of it. Test first (ADR-025).

## Requirements
> 4. Лестница: Fable->Opus, Opus->Sonnet (исполнители), пометка в отчёте; обратно при недорасходе.
> нужно жёстко контролировать, чтобы они не жрали лимиты
> 6. Fable: финальный суд T4, архитектор, повтор; effort high; свой суточный бюджет; при недорасходе планировщику/ревью; Fable 5.5 без правки кода.

## Files
- scripts/top-model.sh
- scripts/model-profile.sh
- scripts/token-report.py
- tests/model-profile.test.sh
- tests/token-report.test.sh
- docs/model-cascade.md

## Non-goals
- No poll from routing: `state --json` only. `VULYK_BUDGET=0` or a missing `budget.sh` = today's resolution, unchanged.
- `--floor` behaviour and the `lib.sh` floor line (`fable 5.1`) stay; a floor is a minimum and Fable 5.5 arrives by alias.
- No dispatch prose, driver or `cycle.sh` edit (stories 07-08 consume this); no `budget.sh` edit (story 03's).
- No Fable for any role where the plan bills Fable to credits, whatever the state; never a judge to the builders' family.
- Do not touch the `--- budget` block story 03 wrote; add a `--- ladder` block.

## Map slice
`memory/map/scripts.md` «Entry points» (`model-profile.sh`, `top-model.sh`), «Tests»; `memory/map/agents-and-commands.md`
«Commands» (profile-aware dispatch). ADR-028 §2, §5, invariants 5, 6, 9; ADR-015; ADR-020.

## Acceptance criteria
- [ ] Cases in a `--- ladder` block, each failing as `FAIL ladder <case>`, on synthetic journals under a temp
      `CLAUDE_CONFIG_DIR`: `downgrade-1-gate` (Tier 4 gate `fable` -> `opus`) · `downgrade-2-worker-opus-builds`
      (`worker` `opus` -> `sonnet`) · `downgrade-2-sonnet-builds` (no change, a warning in `--explain`) ·
      `boost-fable-plan` (planner and Tier 1-3 review -> `fable`) · `boost-credit-plan` (no change) · `fable-bucket-only`
      (`fable_state` `downgrade-1`, `state` `ok`: Fable roles drop, others stay) · `planner-opus-every-profile` · `off`
      (`VULYK_BUDGET=0` = baseline) · `floor` (no step lands below `model_floor`).
- [ ] `--explain` prints `budget: <state>, <role> <from> -> <to>, because <reason>` when a step applies; under `opus-builds`
      it names the Opus-judges-Opus exception for Tier 1-3 (plan.md Assumptions; the owner's approval may flip one `case`).
- [ ] `token-report.py` rates by family + minimum version (`fable >= 5.0`, `mythos >= 5.0`, `opus >= 5.5`); a
      `claude-fable-5-5` id prices as Fable with no edit, asserted in `tests/token-report.test.sh`.
- [ ] `docs/model-cascade.md`: the "four uses" become the three-role Fable list plus `boost`; "never reached by design" is
      replaced by the governor; the profile table gains the Ask 6 row.

## Verification
`bash tests/model-profile.test.sh && bash tests/maintenance.test.sh`

## Implementation notes

## Findings
