---
story: gate-split-03
spec: gate-split
status: todo
returned:
tier: 3
worker: worker-code
wave: 2
blocked_by: [gate-split-01, gate-split-02]
---

# Cut the long suites into parts of about 100 s alone

## Goal
The suites measured over 140 s alone on 2026-11-02 become parts the runner runs one job each: `solo.test.sh` gains
`--list-parts`/`--part` with `green`, `block`, `rejected`; `e2e.test.sh` with `green`, `red`; `model-profile.test.sh`
with `defaults`, `set`, `edges`; `telemetry.test.sh` splits `install` (| `install-xp` at 1273), `constitution`
(| `constitution2` at 1570) and `ysk` (| `ysk-hook` at 1727). `e2e.test.sh` without node prints `SKIP: node not found`
and exits 77 instead of a vacuous 0. Cut lines and shared-state notes: scout report `gs/scout-cuts.md`.

## Requirements
> 5. solo, e2e, model-profile и длинные части telemetry и council разрезаны до ~100 с.
> 8. Тест без нужного инструмента показывается как SKIP, а в CI SKIP считается ошибкой.

## Files
- tests/solo.test.sh
- tests/e2e.test.sh
- tests/model-profile.test.sh
- tests/telemetry.test.sh

## Non-goals
- Do not speed a test up by deleting or weakening asserts: a cut moves code, it removes no check.
- Do not touch the council `replays` cut (`gate-split-04`), `tests/driver.test.sh` (`gate-split-05`) or the runner.
- Do not change what `e2e.test.sh` drives (the driver flow is `gate-split-05`); only its parts and its SKIP.

## Map slice
memory/map/scripts.md `## Tests`; memory/map/cycle.md `## The Workflow driver` (for e2e only); plan.md `## Contracts`
(Suites with parts, SKIP); scout report
C:/Users/Andrei/AppData/Local/Temp/claude/E--Projects-vulyk/aeafb186-f7ba-4c02-b8a1-680b8386863e/scratchpad/gs/scout-cuts.md.

## Acceptance criteria
- [ ] Each of the four files answers `--list-parts` and `--part <topic>` the way `council.test.sh` (PARTS word list,
      unknown topic refused) or `telemetry.test.sh` (`part_on`) does; with no flag it runs every part, as today.
- [ ] Shared setup each part needs runs inside that part: solo's header 8-60; e2e's `make_fixture`/`run_driver`
      helpers with `cd "$SRC"` per part; model-profile's `edges` runs `mp --set opus-builds` itself (it read
      `$CFG/vulyk-model-profile` left by line 95), `PLANFILE` set per part, the LEDGER/FAILS summary per part;
      telemetry `install-xp` calls `fresh_install`/`seed_ownset`/`$T`, `constitution2` the helpers at 1503-1507,
      `ysk-hook` sets `$YSK` and its `YO/YH/YC/yo` values; `install_fixtures` still keys on every install part.
- [ ] Every new part runs alone in about 100 s or less on this box; the `## Implementation notes` record each part's
      alone time once (measured, not estimated).
- [ ] `bash tests/e2e.test.sh` with no `node` on PATH prints `SKIP: node not found` and exits 77.
- [ ] Every existing assert still runs in exactly one part; the per-file assert count with no flag is unchanged.

## Verification
`bash tests/solo.test.sh`
`bash tests/model-profile.test.sh`
`bash tests/e2e.test.sh`
`bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part install-xp`
`bash tests/telemetry.test.sh --part constitution`
`bash tests/telemetry.test.sh --part constitution2`
`bash tests/telemetry.test.sh --part ysk`
`bash tests/telemetry.test.sh --part ysk-hook`

## Implementation notes

## Findings
