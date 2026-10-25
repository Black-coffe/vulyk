---
story: fast-verification-02
spec: fast-verification
status: todo
returned:
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

## Findings
