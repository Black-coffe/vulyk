---
story: fable-review-remainders-02
spec: fable-review-remainders
status: done
returned: DONE
tier: 3
worker: worker-code
tracer: false
wave: 1
blocked_by: []
model: opus
---

# `record-seat --file <path>` and `release` without the PAUSE guard

## Goal
`scripts/cycle.sh record-seat` reads its report from `--file <path>` when given (stdin stays the default), refusing a missing, unreadable or empty file with exit 2 `file: <path>` before any attempt file is written; everything after the read is unchanged. `cmd_release` drops its `pause_guard` call so a paused spec's `release` exits 0 on its own stamp. ADR-001 D2 names `release` in the exempt list and shows `--file` in the `record-seat` synopsis. Code only: no new suite scenarios (story 05 writes them).

## Requirements
> `record-seat` принимает `--file <path>` (stdin остаётся); сиды и ревьюер пишут отчёт по пути, который даёт драйвер (вне docs/specs); драйвер записывает по пути с откатом на heredoc, если файла нет; сьют проверяет вариант с файлом.
> `release` не защищён паузой и выходит 0 на поставленном на паузу спеке; ADR-001 называет release в списке исключений; сценарий в сьюте это фиксирует.
> убрать один вызов pause_guard в cmd_release, добавить release в список исключений ADR-001 рядом с pause/resume

## Files
- scripts/cycle.sh
- docs/adr/001-cycle-state-contract.md
- tests/council.test.sh

## Non-goals
- No new scenario in `tests/council.test.sh`. The file is in `## Files` only for the minimal fixture edit that keeps the suite green at this story's close (the 2026-09-14 sizing rule); the planner expects none to be needed. A red that is not caused by your diff is a WALL: record it under `## Findings`, return `WALL`.
- Do not touch `cmd_record_seat_review` / `cmd_record_seat_council` (`:1164-1293`): the read changes, the validation does not. Do not add a `-` stdin alias.
- Do not add `driver_guard` to `release`, do not change `claim`, `pause`, `resume`, and do not touch the stamp match at `:2053-2062`.
- In ADR-001 edit only the exempt sentence at `:160` and the `record-seat` row's synopsis in the D2 table; no `claim`/`release` verb row, no D3/D4 prose.
- Do not read the whole suite. Run `bash tests/council.test.sh` once, at the end, with `timeout: 600000` on the Bash call, through `2>&1 | tail -n 5`; then `grep -c '::error'` on a saved transcript if the tail is not clean.
- Write `returned: DONE` as your last edit; never write `status:`.

## Map slice
`plan.md` C1 and C4 (the exact JSON, exit codes and precondition order) · `recon/driver-and-cycle.md` §"`scripts/cycle.sh` record-seat / judge" (`cmd_record_seat :1302-1373`, `REPORT="$(cat)"` at `:1366`, option parsing above it) and §"`release` vs PAUSE" (`pause_guard :111-119`, `cmd_release :2044-2063`, the call at `:2051`) · `memory/map/scripts.md` "Key types / contracts" (the `emit()` last-line rule) · `docs/adr/001-cycle-state-contract.md` D2 (`:141-169`).

## Acceptance criteria
- [ ] `record-seat ... --file <path>` with a readable non-empty file records exactly as the same content on stdin would (same seat file bytes, same exit); stdin is not read when `--file` is present.
- [ ] `--file` naming a missing, unreadable or empty path: exit 2, last line `{"ok":false,"verb":"record-seat","exit":2,...,"error":"file: <path>"}` with the argument verbatim, no `attempt-K.md` written, no seat file; the check runs after every existing precondition (a paused spec still answers exit 3 first).
- [ ] The usage text of `record-seat` shows `[--file <path>]`; `--file` combines with `--model` and `--stamp` in any order.
- [ ] `release <spec> <stamp>` on a paused spec with a matching stamp or no `DRIVER`: exit 0, `DRIVER` gone; with a foreign stamp: exit 2 `held by <other>`, unchanged. `claim` under PAUSE still exits 3.
- [ ] ADR-001 `:160` lists `status`, `pause`, `resume`, `release` as exempt; the `record-seat` row's synopsis reads `[--model <id>] [--stamp <s>] [--file <path>] [< report]` (or the table's equivalent wording).
- [ ] `bash tests/council.test.sh` exits 0 on the branch; every pre-existing scenario unchanged except a fixture edit this diff forced, named in the notes.

## Verification
`bash tests/council.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `scripts/cycle.sh`: `--file` parsed beside `--model`/`--stamp` (order-free) with a separate `FILE_SET` flag, so `--file ""` is a bad path (exit 2 `file: `) rather than a silent fall-back to stdin; the check replaces the `cat` in place, after every existing precondition, so nothing is written on failure.
- `scripts/cycle.sh`: dropped `pause_guard` from `cmd_release` and updated the `pause_guard` header comment's exempt list (same file, one line) so the code does not contradict ADR-001.
- `docs/adr/001-cycle-state-contract.md`: exempt sentence gains `release`; the D2 `record-seat` row's synopsis now `[--model <id>] [--stamp <s>] [--file <path>] [< report]`.
- `tests/council.test.sh` needed **no** edit and was not touched: `bash tests/council.test.sh` exits 0 unchanged (existing `probe_release` / `probe_pauserelease` already print `ok`).
- Verified by hand on throwaway fixtures: `--file` and stdin produce byte-identical seat/attempt files (modulo the `recorded:` timestamp); stdin is not read when `--file` is present; a paused spec still answers exit 3 before the file check; `release` under PAUSE exits 0 (own stamp / no DRIVER), exit 2 `held by other` on a foreign stamp; `claim` under PAUSE still exits 3.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
