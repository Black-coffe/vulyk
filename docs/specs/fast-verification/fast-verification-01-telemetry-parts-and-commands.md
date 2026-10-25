---
story: fast-verification-01
spec: fast-verification
status: todo
returned:
tier: 3
worker: worker-test
wave: 1
blocked_by: []
---

# telemetry.test.sh in four parts, and the `## Commands` rows that name them

## Goal
`bash tests/telemetry.test.sh --part <name>` runs one topic of the suite in well under the story cap, `--list-parts`
names the parts, and no argument still runs everything. `CLAUDE.md` `## Commands` carries the rows every later story
and the runner rely on: the two `--part <topic>` rows, `bash tests/full-suite.test.sh`, `Full suite / build
(round-only)` = `bash tests/full-suite.sh`, `round-only` on the two full rows, and the blockquote sentence that names
the rule. Council's rows are written here by contract (plan `## Contracts`), story 02 delivers those parts.

## Requirements
> Дальше разделение тестов на быстрые и полные, ты его одобрил. Причина, на которую оно отвечает: telemetry.test.sh идёт 18 минут, а close-story даёт проверке истории максимум 9.
> 1. Каждая строка проверки истории укладывается в минуту-две; telemetry и council получают быстрые части по темам, история берёт часть под свои файлы.
> 4. Медленные строки таблицы команд помечены «только для раунда»; историю, назвавшую такую строку, ловит проверка плана до сборки, а close-story отказывается её запускать.

## Files
- tests/telemetry.test.sh
- CLAUDE.md

## Non-goals
- Do not touch `tests/council.test.sh` (story 02, same wave) or write the runner (story 03).
- Do not change what any case asserts, drop a case, or reorder cases 1-16 (they chain through `$HIVE`/`$LOG`).
- Do not edit `memory/memory.md` `## Verification` (drone-docs at ship) or any agent/command `description:` line.
- Do not remove `bash tests/council.test.sh --quick` from the table.

## Map slice
memory/map/scripts.md `## Tests`, `## install.sh - the upgrade contract`; scout-suites.md `## telemetry.test.sh
sections`, `## Proposed telemetry cut`, `## Gotchas`.

## Acceptance criteria
- [ ] Parts exist exactly as the plan's contract names them: `telemetry` (115-1031 + 1812-2039), `install`
      (1033-1339), `library` (1399-1669), `upgrade` (1340-1398 + 1670-1811 + 2041-2122); the `$TGT`/`$OWNSET`
      creation moves into a helper both `install` and `library` call, so each runs alone and green.
- [ ] `--list-parts` prints the four names, one per line, runs nothing, exit 0; an unknown name exits 1 with the list
      on stderr; `--part` with no name exits 1.
- [ ] No argument runs every part with the summary unchanged (CHECKS/FAILED from LEDGER/FAILS on disk).
- [ ] Each part exits 1 when one of its checks fails (prove once with a deliberately failing `bad` while working,
      then remove it) and still runs the `bash -n` guard at the top.
- [ ] Every part alone <= 180 s on this box; the four wall times are written in `## Implementation notes`. A part
      over 180 s whose fixtures allow it is cut again (new name added to `--list-parts`; the `<topic>` row needs no
      change); one that cannot be cut is recorded with the reason.
- [ ] `CLAUDE.md` `## Commands`: rows added and marked as the plan's `## Commands rows` contract says; the blockquote
      under the heading says a story never names a `round-only` row (wave-check reports it, close-story refuses it).
      The file stays inside the size cap `tests/maintenance.test.sh` enforces (trim Purpose wording, not rows).
- [ ] `bash tests/maintenance.test.sh` is green (the hotfix precondition in plan `## Assumptions` is in place).

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/maintenance.test.sh && bash tests/telemetry.test.sh --part telemetry`

## Implementation notes

## Findings
