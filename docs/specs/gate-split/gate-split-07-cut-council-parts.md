---
story: gate-split-07
spec: gate-split
status: done
returned: DONE
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
Cuts (tests/council.test.sh): seats at the review-seat section, ceilings before the judged-rounds block, walks before Story 16, roster before the repair verb (the shared 0.18 fixture guard also runs for roster2). Ok-line counts match the old parts: seats 54+28=82, roster 32+12=44, ceilings 15+14=29, walks 29 (output identical, line for line).
Alone times, measured 2026-11-02 on a quiet box (s): verbs 47, judge 70, seats 61, seats2 31, close 33, escalate 77, ceilings 35, ceilings2 52, replays 70, replays2 43, walks 71, walks2 31, driver 69, roster 56, roster2 28, advance 100, suite 53. No part needed further cutting; advance (100 s) was left whole.

## Findings
