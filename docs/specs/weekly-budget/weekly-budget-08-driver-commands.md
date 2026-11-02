---
story: weekly-budget-08
spec: weekly-budget
status: todo
returned:
tier: 4
worker: worker-code
wave: 4
blocked_by: [weekly-budget-03, weekly-budget-05]
red: required
red_reason:
---

# Consumers: the driver steps families mid-run; the commands gate and dispatch the new Fable list

## Goal
`.claude/workflows/vulyk-cycle.js` takes each role's family from the latest `status.budget.ladder` (in the `advance`/`status`
line the clerk returns) when present, else from its launch arguments, so a long run steps down or back up between waves; each
applied step is logged and returned as `budget_steps` beside `fallbacks` (plan.md `## Contracts`). Fable dispatches (Tier 4
review, retry) pass `effort: high`. `/vulyk-build` (both paths, beside `top-model.sh --floor`), `/vulyk-plan` (before the
Tier 3-4 planner batch) and `/vulyk-review` run `bash scripts/budget.sh gate` once before a multi-agent dispatch (exit 3: stop
and print its line), dispatch the planner, Tier 1-3 review and blind seats on the resolved family (`opus` by default, `fable`
only on `boost`), `lead-architect` and Tier 4 review at `effort: high`, and journal each `budget_steps` entry plus
`telemetry.sh record budget_downgrade`, one sentence to the owner. Test first (ADR-025).

## Requirements
> 4. Лестница: Fable->Opus, Opus->Sonnet (исполнители), пометка в отчёте; обратно при недорасходе.
> 5. (horizon) Резерв 10%: ниже - пауза, снятие одной командой; проверка перед сборкой и партией агентов.
> 6. Fable: финальный суд T4, архитектор, повтор; effort high; свой суточный бюджет; при недорасходе планировщику/ревью; Fable 5.5 без правки кода.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-plan.md
- .claude/commands/vulyk-review.md

## Non-goals
- No new clerk verb and no shell in the driver (ADR-011): it reads the JSON the clerk already returns.
- The Fable-refusal fallback (`REFUSAL`, `FALLBACK_MODEL`) stays as is; a budget step is not a fallback and not an attempt.
- The Queen's own typing is never gated; a gate on `off|n/a|no-data` prints its warning and proceeds.
- No `cycle.sh`, routing-script or agent frontmatter edit; no version string anywhere (`fable` is a family).
- Command prose calls Python only as `bash scripts/py.sh` and keeps dates portable (card `shell-needs-gnu-or-bash4`).

## Map slice
`memory/map/cycle.md` «The Workflow driver»; `memory/map/agents-and-commands.md` «Commands» (`/vulyk-build`, `/vulyk-plan`,
`/vulyk-review`, Fable-limit fallback session path, profile-aware dispatch). ADR-028 §2 «Mid-run», §3; ADR-015.

## Acceptance criteria
- [ ] Cases in `tests/driver.test.sh` (canned clerk lines): `budget.ladder.worker` changes between two waves -> wave 2
      workers dispatch on the new family and one `budget_steps` entry is returned · no `budget` object -> launch arguments,
      no entry · `ladder.gate` `opus` under a `fable` launch -> Tier 4 review dispatched on `opus`, entry returned · a
      Fable-family dispatch carries `effort: high` · a refusal still falls back once to `opus` as today.
- [ ] `/vulyk-build` records each returned step three ways (journal line, `budget_downgrade`, one sentence), as it does fallbacks.
- [ ] `/vulyk-plan` no longer dispatches the Tier 4 `queen-planner` on the top model; `lead-architect` stays on it at `effort: high`.
- [ ] Prompt-check passes on the three commands; the portability scan in the Maintenance suite passes on them.

## Verification
`bash tests/driver.test.sh && bash tests/maintenance.test.sh`

## Implementation notes

## Findings
