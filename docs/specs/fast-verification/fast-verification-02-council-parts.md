---
story: fast-verification-02
spec: fast-verification
status: done
returned: DONE
tier: 3
worker: worker-test
wave: 1
blocked_by: []
---

# council.test.sh in four parts

## Goal
`bash tests/council.test.sh --part <name>` runs one topic of the suite on its own fresh fixture repo, `--list-parts`
names the parts, `--quick` still works with or without a part, and no argument runs everything as today. Later
stories put their new cases into named parts (`verbs`, `escalate`) and verify with those parts alone.

## Requirements
> 1. Каждая строка проверки истории укладывается в минуту-две; telemetry и council получают быстрые части по темам, история берёт часть под свои файлы.

## Files
- tests/council.test.sh

## Non-goals
- Do not touch `CLAUDE.md` (story 01 writes the council rows this wave) or `tests/telemetry.test.sh`.
- Do not change what any case asserts, drop a case, or replace the pinned-sha replays (they need real history).
- Do not add the close-story round-only case or the suite-timeout cases: stories 04 and 06 do, in `verbs` and
  `escalate`.

## Map slice
memory/map/cycle.md `## Tests`; scout-suites.md `## council.test.sh`, `## Gotchas`, `## Running two copies at once`.

## Acceptance criteria
- [ ] Parts exist exactly as the plan's contract names them: `verbs` (today's 1-1655), `escalate` (1656-2166),
      `replays` (2167-3588), `advance` (3589-4002); each rebuilds the shared setup (repo, fixture CLAUDE.md, HEAD7,
      helpers) and runs green alone, in a fresh checkout and in the same checkout as another part running at once.
- [ ] `--list-parts` prints the four names, one per line, runs nothing, exit 0; an unknown name exits 1 with the list
      on stderr. `--quick --part <name>` skips the same blocks `--quick` skips today; `--quick` alone is unchanged.
- [ ] Each part exits non-zero when one of its checks fails: `expect()` failures reach the exit code even when
      `expect` ran on the right of a pipe (record failures in a file, as telemetry's LEDGER/FAILS does); prove it
      once with a deliberately failing `expect` while working, then remove it.
- [ ] A block that relied on a spec an earlier block created is either given its own fixture or moved with its
      maker into one part; no part depends on another having run.
- [ ] Every part alone <= 180 s on this box; the four wall times are written in `## Implementation notes`. A part
      over 180 s whose fixture state allows it is cut again (new name in `--list-parts`, the four names kept); one
      that cannot be cut is recorded with the reason.

## Verification
`bash tests/council.test.sh --quick`

## Implementation notes

- Switches: `--part <name>`, `--list-parts` (exits before any fixture is built), `--quick`; any order. Unknown or
  empty part name: exit 1, list on stderr; an unknown flag stays exit 2 (usage). `part()` wraps each range;
  every part runs lines 1-~345 (repo, fixture CLAUDE.md, HEAD7, helpers) on its own `mktemp -d` repo.
- Eight parts, file order: `verbs seats escalate ceilings replays walks driver advance`. The four contract names are
  kept; two were over 180 s alone (verbs 249 s, replays 432 s) and were cut again:
  - `verbs` = status/tier/judge/journal/briefed/branch/git failures/court setup + PAUSE guard, pause/resume,
    close-story (the 1488-1505 refusal site stays here for story 04); `seats` = the record-seat block (was 883-1354).
  - `escalate` unchanged (story 16 fixes, open-round, the escalate verb, review-ABSENT; story 06 goes here).
  - The old 2167-3588 block is now `ceilings` (reopen walk, tier/judged/RED ceilings), `replays` (status after
    committed verbs, LR19-25/m-4/N-m7, story 14 pinned replay), `walks` (stories 15-16 + their pinned replays),
    `driver` (story 17 DRIVER + its pinned replay, C5). Each is `if part <x> && full` (all --quick-skipped as before).
  - The pinned-replay toolkit (`pin_cycle`, `check_probe_result`, `probe_lr19..probe_nm7`, `run_wall_probes`) moved
    unchanged into the shared helpers, since replays/walks/driver all call it. No case text or assertion changed.
- Cross-part state: grep of every slug a part creates against later parts found only comment/text mentions and
  escalate's tolerant `git rm ... pwseat1` (2>/dev/null, rm -f). Each part ran green alone, so none depends on another.
- Exit code: `expect()` also appends its label to `$FAILS` (a `mktemp` outside the fixture repo); the last line sets
  `fail=1` when it is non-empty. Proven once with a deliberate `echo x | expect ... "y"` in `escalate`: exit 1 with
  the ledger, exit 0 with the ledger line disabled (the old leak). Both removed.
- Wall times, each part alone, sequential, this 28-core box: verbs 144 s, seats 83, escalate 45, ceilings 78,
  replays 115, walks 101, driver 68, advance 138 (all <= 180). All eight at once in this checkout: green, 75-185 s
  (verbs 184, advance 185 under 8-way load). All eight at once in a fresh `git clone` (test file copied in) + a
  `--quick` in this checkout simultaneously: green, 62-174 s.
- Equivalence (in the clone, against `git show HEAD:tests/council.test.sh`): no-arg run 532 ok / 0 error both,
  identical sorted ok lines (914 s vs 918 s); `--quick` 269 ok both, identical ok lines; `--quick --part` sums to
  269 (verbs 118, seats 32, escalate 48, advance 71, the four quick-skipped parts 0). Part ok counts sum to 532.
- Gap: timings are one run each on this box under whatever else was running; a slower machine is not measured.

## Findings
