---
story: weekly-budget-03
spec: weekly-budget
status: todo
returned:
tier: 4
worker: worker-code
wave: 2
blocked_by: [weekly-budget-01]
red: required
red_reason: FAIL budget owner-6d-20pct
---

# The governor: `scripts/budget.sh` + `scripts/budget.py`

## Goal
`budget.sh` (bash 3.2, I/O and verbs) and `budget.py` (pure formula, run via `bash scripts/py.sh`) exist exactly as plan.md
`## Contracts` and ADR-028 §1 describe: a per-config-dir journal, a guarded lazy poller, the state machine with hysteresis, the
Fable bucket on its own, the 5h window where present, overrides and the off switch, and four telemetry codes. Table tests on
synthetic journals carry the owner's own examples. Test first (ADR-025): the budget block in `tests/model-profile.test.sh`
is written and stamped red before either script exists.

## Requirements
> 1. Данные: /usage с кэшем, журнал на каждый аккаунт; предохранитель: только бесплатный ответ, иначе стоп.
> 2. Цель: не кончиться до сброса + выбрать 85-95%.
> 3. Формула: (остаток-резерв)/дни; окна 1ч/24ч; прогноз; предупреждение / разгон; 5ч-окно где есть.
> 5. (horizon) Резерв 10%: ниже - пауза, снятие одной командой; проверка перед сборкой и партией агентов.
> 6. Fable: финальный суд T4, архитектор, повтор; effort high; свой суточный бюджет; при недорасходе планировщику/ревью; Fable 5.5 без правки кода.
> 9. Выключатель и «сегодня больше / придержи» с журналом.
> Например, если осталось шесть дней, а мы уже заюзали 20%, значит, предупреждение, что мы пер елимитчиваем

## Files
- scripts/budget.sh
- scripts/budget.py
- scripts/telemetry.sh
- docs/telemetry.md
- tests/telemetry.test.sh
- tests/model-profile.test.sh
- tests/fixtures/budget/journal-overpace.jsonl
- tests/fixtures/budget/journal-underpace.jsonl
- tests/fixtures/budget/journal-two-accounts.jsonl
- tests/fixtures/budget/fake-claude.sh

## Non-goals
- No routing, hook, `cycle.sh` or command edit (stories 05-08). `budget.sh` never writes into a hive, a spec dir or a settings file.
- No statusline reading, no OAuth endpoint, no credentials, no third-party cache. No background process, no daemon.
- No account id, token count or "what's contributing" text stored; telemetry carries the state word and an integer percent only.
- No weekday/work-hour weighting (research F2): ADR-028 chose the forward allowance plus 1 h / 24 h burn.
- Do not edit story 01's fixtures; read them.

## Map slice
`memory/map/scripts.md` «Entry points» (`lib.sh` `run_capped`, `vulyk_python`, `date_epoch`; `py.sh`; `telemetry.sh` `ENUM`
append-only), «Key contracts», «Gotchas». ADR-028 §1, §6, «Invariants». Read `measure-poller.json` (M1 shape, M3, M4 floors).

## Acceptance criteria
- The success band is explicit in `budget.py`:
  - `boost` when the forecast landing at the reset is below 85% used;
  - `warn` when the forecast runs out before the reset (above 100%);
  - 85 and 95 are named, env-overridable constants, and table tests cover both edges.
- The `session` limit kind (the 5-hour window) is used only when the reading carries it, and the window that runs out first sets the state. Table tests cover a reading with `session` and one without it.
- [ ] Cases in a `--- budget` block of `tests/model-profile.test.sh`, each failing as `FAIL budget <case>`, with
      `CLAUDE_CONFIG_DIR` set to a temp dir and a stub `claude` first on `PATH`:
      `owner-6d-20pct` (week 20% used, 6 d to reset, 24 h burn at that pace) -> `warn`, `pace` 1.4, `daily` 11.7, forecast
      before reset · `owner-2d-50pct` (50% used, 2 d left) -> `boost`, `daily` 20 · `fable-90-week-45` -> `fable_state`
      `downgrade-1`, `state` `ok` · `five-hour-present` -> `hourly` = `min(H_7d, R_5h/T_5h)` · `five-hour-absent` -> `hourly` =
      `H_7d` · `no-data` (no row in the window, or newest > 6 h) -> `no-data`, `gate` exit 0 with a warning · `n-a` (`kind:none`)
      -> `n/a` · `single-sample` -> no `warn` from one row · `reserve` (`R <= 10`, > 24 h left) -> `gate` exit 3 · `flap` (one
      1 pp step back) -> state kept · `override-boost|hold|off` and `until` expiry · `off-env` (`VULYK_BUDGET=0`) -> `off`, no poll.
- [ ] Poll guard cases: stub prints `usage-misfire.json` (non-zero `total_cost_usd`) -> no row, `poll-disabled` written, one
      sentence printed, the next `poll` is a no-op until `override poll-on` · a stream with no `local_command_run` -> same ·
      `usage-report.json` -> one row · `usage-noreport.json` -> `{kind:none}` row · newer row than the interval -> no call ·
      `--force` bypasses the interval, never the guard · the call carries `MSYS_NO_PATHCONV=1`, `VULYK_BUDGET_POLLING=1`,
      `--model haiku`, cwd = journal dir, under `run_capped 90`.
- [ ] Rate floors from M4 (`rate_floor_rec`) as defaults, each env-overridable; a window with too few rows abstains.
- [ ] `override` and `announce` behave per Contracts; every override is a journal line with who/when/why.
- [ ] `telemetry.sh` `ENUM` gains the four `budget_*` codes at the end; `docs/telemetry.md` lists them.
- [ ] `budget.sh` passes `portability-check.sh` (inside the Maintenance suite); Python only through `scripts/py.sh`.

## Verification
`bash tests/model-profile.test.sh && bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/telemetry.test.sh --part telemetry`

## Implementation notes

## Findings
