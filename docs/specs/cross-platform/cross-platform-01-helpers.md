---
story: cross-platform-01
spec: cross-platform
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason:
# red_verified_at:      # written by `cycle.sh stamp-red`, never by hand
---

# The four helpers in lib.sh, py.sh, cycle.sh on them, the constitution's Python cell

## Goal
`scripts/lib.sh` carries `vulyk_python`, `sed_inplace`, `date_epoch`/`date_shift` and `run_capped` exactly as
`plan.md ## Contracts` states them; `scripts/py.sh` and `scripts/run-capped.py` exist. `cycle.sh` no longer defines
`sed_inplace` (it sources `lib.sh` already), parses the verdict with `sed -nE 's/^VERDICT: (PASS|BLOCK).*/\1/p'`, runs
`close-story`/`stamp-red` verification and the court setup through `run_capped` (the `timeout 5 true` probes and the
uncapped-warning branches move into the helper), and every `"${a[@]}"` it expands under `set -u` is guarded. The
`Python` cell of `CLAUDE.md ## Commands` reads `bash scripts/py.sh -m py_compile .claude/hooks/*.py`. Tests first
(ADR-025): the helper tests and the extended BSD stub in `tests/cycle.test.sh` are written and stamped red before
`lib.sh` changes.

## Requirements
> 1. Четыре хелпера в `scripts/lib.sh`: `vulyk_python`, `sed_inplace`, `date_epoch`/`date_shift`, `run_capped`.
> 2. Фикс `cycle.sh:853` на `sed -nE`.
> 8. `run_capped` без `timeout` и `gtimeout` падает на `"$VULYK_PY"` (subprocess, код 124), тесты таймаутов идут без `skip`.
> 9. Замена голого `python` в `CLAUDE.md:76` совместима с `verify-cell` и апгрейдом ульев.
> 6. Все раскрытия массивов в файлах с `set -u` — на `${a[@]+"${a[@]}"}`, и проверка на незащищённый `"${a[@]}"` в гейте.

## Files
- scripts/lib.sh
- scripts/py.sh
- scripts/run-capped.py
- scripts/cycle.sh
- CLAUDE.md
- tests/cycle.test.sh

## Non-goals
- No call site outside `cycle.sh` switches here: `install.sh`, hooks, `telemetry.sh`, `state.sh` and the other suites are
  stories 02-05. Do not touch them even where a one-line fix is obvious.
- No gate, no CI change, no `## Commands` row beyond the one cell; do not shorten other `CLAUDE.md` lines.
- `vulyk_python` is not a hook helper: hooks keep their own run-and-fall-through form (story 02).
- Do not change `VULYK_VERIFY_TIMEOUT` / `VULYK_SETUP_TIMEOUT` semantics or the `124 -> exit 4` / `exit 2 timed out`
  messages the council tests assert.

## Map slice
`memory/map/scripts.md` «Entry points» (the `lib.sh` line, `## Commands` parser), «Gotchas» (`close-story` probes
`timeout 5 true`); `memory/map/cycle.md` «Verbs» (close-story verification, court setup under `VULYK_SETUP_TIMEOUT`,
red receipt), «Tests».

## Acceptance criteria
- [ ] With a `python3` stub on PATH exiting 9009 and another case exiting 49, `vulyk_python` sets `VULYK_PY` to the next
      working interpreter; with no working interpreter it returns 1 and `bash scripts/py.sh -c pass` exits 2 with the
      one stderr line.
- [ ] Under the `part bsd` sed stub, extended to refuse `\|` in a basic regex as well as a bare `-i`,
      `review_verdict_of_text` still yields `PASS`/`BLOCK`, and `sed_inplace` edits a file leaving no `.bak`.
- [ ] `date_epoch 2026-01-02T03:04:05Z` prints `1767323045`, `date_epoch 2026-01-02` prints `1767312000`,
      `date_epoch garbage` prints nothing and returns 1; `date_shift -7` prints a `YYYY-MM-DD` seven days before today.
- [ ] With a dir holding dead `timeout` and `gtimeout` stubs (exit 1 on any call) first on PATH,
      `run_capped 1 bash -c 'sleep 5; echo late'` exits 124 within about 2 s, prints no `late`, and a grandchild
      marker the command would have written after 3 s never appears (the process group was killed).
- [ ] With the same dead stubs and `VULYK_PY=` plus a PATH without Python, `run_capped 1 true` runs uncapped, exits 0 and
      prints the `running ... uncapped` warning; `run_capped 0 true` prints nothing.
- [ ] `tests/cycle.test.sh` `part red`'s stamp-red timeout case (today `cycle.test.sh:1038-1042`) passes with no `skip`
      branch, and also passes with the dead `timeout`/`gtimeout` stubs on PATH (the Python path inside `cycle.sh`).
- [ ] Every `sed -i` of `tests/cycle.test.sh` (24, report §2) is `sed_inplace`; its two unguarded array expansions are
      guarded; `cycle.sh`'s expansions at the report's `:931,932,2092,2093,2257,2344,2423,2426,2435,3127` are guarded.
- [ ] `command_cell_exists CLAUDE.md 'bash scripts/py.sh -m py_compile .claude/hooks/*.py'` is true (one assertion in
      `part bsd`, beside the existing `command_cell_exists` cases) and `CLAUDE.md` stays under 7168 bytes.
- [ ] Ask 9, verify-cell half: with the new cell, `cycle.sh close-story` on a fixture story whose `## Verification` is
      `bash scripts/py.sh -m py_compile .claude/hooks/*.py` accepts the cell and runs it green, and one whose
      `## Verification` is the old `python -m py_compile .claude/hooks/*.py` is refused as not a `## Commands` cell
      (exit 2) - an old story stales loudly, never runs a bare `python`.

## Verification
`bash tests/cycle.test.sh`

## Implementation notes

## Findings
