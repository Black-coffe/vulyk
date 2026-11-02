---
story: gate-split-07
spec: gate-split
status: todo
returned:
tier: 3
worker: worker-test
wave: 3
blocked_by: [gate-split-04]
---

# Cut the council parts that sit on the 210 s growth line

## Goal
On 2026-11-02 the council parts `walks`, `seats`, `roster` and `ceilings` ran 102-117 s alone and 205-225 s contended:
at or over the 70% growth line (210 s of 300) that `gate-split-01` makes red, so the first stepped round would fail on
them. Each is cut in two, the first half keeping its name (existing `--part` callers keep working) and the second
taking a new one: `walks`+`walks2`, `seats`+`seats2`, `roster`+`roster2`, `ceilings`+`ceilings2`. `roster` and `seats`
also carry the cases `gate-split-02` and `gate-split-04` added, so cut them as they stand after wave 2.

## Requirements
> 5. solo, e2e, model-profile и длинные части telemetry и council разрезаны до ~100 с.
> 4. Часть дольше 210 с даёт красную проверку заранее, и карточка получает настоящую проверку.

## Files
- tests/council.test.sh

## Non-goals
- Do not speed a test up by deleting or weakening asserts: a cut moves code, it removes no check.
- Do not touch `replays`/`replays2` or `suite` (`gate-split-04`), the runner, or any script under test.
- Do not cut a part that already runs alone in about 100 s or less; record its time instead.

## Map slice
memory/map/scripts.md `## Tests`; plan.md `## Contracts` (Suites with parts); `tests/council.test.sh` lines 23-41
(`PARTS`, `part()`): every part rebuilds the shared setup, so a new part needs no setup of its own beyond what its
cases read from the half before it.

## Acceptance criteria
- [ ] `PARTS` lists `walks2`, `seats2`, `roster2`, `ceilings2`; `--list-parts` prints them and `--part <new>` runs them.
- [ ] State a second half reads from the first (a fixture spec dir, a variable, a commit) is rebuilt inside the second
      half; each half passes alone.
- [ ] Every council part, old and new, runs alone in about 100 s or less on this box; `## Implementation notes`
      record each part's alone time once (measured, not estimated).
- [ ] Every existing assert still runs in exactly one part; the assert count with no flag is unchanged.

## Verification
`bash tests/council.test.sh --part walks`
`bash tests/council.test.sh --part walks2`
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part seats2`
`bash tests/council.test.sh --part roster`
`bash tests/council.test.sh --part roster2`
`bash tests/council.test.sh --part ceilings`
`bash tests/council.test.sh --part ceilings2`

## Implementation notes

## Findings
