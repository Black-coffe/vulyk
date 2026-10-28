---
story: cross-platform-04
spec: cross-platform
status: todo
returned:
tier: 3
worker: worker-test
model: haiku
wave: 2
blocked_by: [cross-platform-01]
---

# The remaining suites and the runner on the helpers

## Goal
`tests/defects.test.sh` (22), `tests/inject.test.sh` (1), `tests/solo.test.sh` (1) edit fixtures through `sed_inplace`;
the `python` resolvers of `defects`, `inject`, `intake`, `mods`, `token-report` suites are `vulyk_python`;
`tests/intake.test.sh`'s bare `timeout` (today `:333`) is `run_capped`; `tests/symbol-map.test.sh`'s `date +%s%N` clock
(today `:223,225`, the trace-autopsy speed check) uses the `$EPOCHREALTIME`-else-Python millisecond idiom of
`tests/inject.test.sh:76`; `tests/full-suite.sh` guards its arrays (`:73,74,76`, `CMDS=(...)` of two possibly empty
groups) and caps each suite with `run_capped` instead of its own `timeout -k 10` branch; `tests/full-suite.test.sh`'s dead-
`timeout` case (today `:106-114`) is split in two: dead `timeout`+`gtimeout` with Python present = still capped (124),
dead stubs with `VULYK_PY=` and no Python on PATH = the uncapped warning. `model: haiku`: a repeated pattern across nine
files; every helper is defined and tested in story 01.

## Requirements
> 3. Перевод всех продуктовых, командных (`.claude/commands/*.md`, `CLAUDE.md:76`) и тестовых файлов на переносимые вызовы.
> 6. Все раскрытия массивов в файлах с `set -u` — на `${a[@]+"${a[@]}"}`, и проверка на незащищённый `"${a[@]}"` в гейте.
> 8. `run_capped` без `timeout` и `gtimeout` падает на `"$VULYK_PY"` (subprocess, код 124), тесты таймаутов идут без `skip`.

## Files
- tests/defects.test.sh
- tests/inject.test.sh
- tests/intake.test.sh
- tests/solo.test.sh
- tests/symbol-map.test.sh
- tests/mods.test.sh
- tests/token-report.test.sh
- tests/full-suite.sh
- tests/full-suite.test.sh

## Non-goals
- `tests/council.test.sh` (story 03), `tests/telemetry.test.sh` (story 02), `tests/maintenance.test.sh` and
  `tests/cycle.test.sh` (stories 05 and 01) are not yours.
- Do not edit `scripts/lib.sh`, `scripts/cycle.sh` or any hook: a suite that cannot use a helper as contracted is
  `NEEDS_CONTEXT`.
- Keep `tests/full-suite.sh`'s exit codes (0 / 1 / 124 / 2), `--jobs`, `--list` and the per-part fan-out unchanged;
  `VULYK_SUITE_TIMEOUT=0` still means uncapped.
- Sourcing `lib.sh` turns on `set -u` in a suite that lacked it: guard the unbound variable in that file, do not drop it.
- No change to what any assertion expects. `tests/mods.test.sh` and `tests/token-report.test.sh` get the resolver line
  only; they run in the round's full suite, not here.

## Map slice
`memory/map/scripts.md` «Tests» (`tests/full-suite.sh` contract, `tests/symbol-map.test.sh`), «Entry points»
(`symbol-map.sh`, `trace-autopsy.sh` wrappers).

## Acceptance criteria
- [ ] `grep -l 'sed -i ' tests/*.sh` lists none of the nine files; `grep -l 'command -v python' tests/*.sh` lists none of
      them.
- [ ] `tests/full-suite.sh` with `EARLY=()` or `LATE=()` empty does not abort under `bash -u` (the runner test covers it).
- [ ] `bash tests/full-suite.test.sh`: a suite that sleeps past the budget exits 124 with dead `timeout`/`gtimeout` stubs
      while Python is present; with `VULYK_PY=` and no Python on PATH the run is uncapped and prints the warning.
- [ ] `tests/intake.test.sh`'s latency case passes with the dead stubs first on PATH, no `skip`.
- [ ] `tests/symbol-map.test.sh`'s speed check uses no `%N` and still measures milliseconds.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/symbol-map.test.sh`
`bash tests/full-suite.test.sh`
`bash tests/solo.test.sh`

## Implementation notes

## Findings
