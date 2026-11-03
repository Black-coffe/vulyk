---
story: post-046-tails-03
spec: post-046-tails
status: todo
returned:
tier: 2
worker: worker-code
wave: 3
blocked_by: [post-046-tails-02]
---

# Cut the 11 parts that crossed 70% under load in half

## Goal
Each of the 11 parts named red in post-045-tails round 1 becomes two parts of roughly equal time on an idle box
(target: each under 70 s here, so a 3x slowdown stays under 70% of the 300 s cap). council.test.sh: `seats`,
`judge`, `walks`, `replays`, `escalate` keep their names for their first half and add `seats3`, `judge2`,
`walks3`, `replays3`, `escalate2` (the `*2` names that exist already are taken). telemetry.test.sh: `rg`,
`crlf`, `constitution`, `mods`, `ysk`, `wrapper` add `rg2`, `crlf2`, `constitution3`, `mods2`, `ysk2`,
`wrapper2`. Cut on section boundaries; a section that reads state an earlier section built moves with it or
rebuilds it. `PARTS` lists the new names, so `--list-parts` and `full-suite.sh` pick them up; no Commands row
changes. Not one assertion is dropped: the count of `  ok ` lines across the two halves equals the old part's.

## Requirements
> - Descoped post-045-tails-04: гейт раунда 1 был красным только из-за нагрузки, вы приняли раунд (ACCEPTED, 2026-11-03). Проверка «3 с» в bsd, дробление 11 частей за 70 % и причина замедления машины переходят в следующий круг.
> 5. 11 частей разрезаны.

## Files
- tests/council.test.sh
- tests/telemetry.test.sh

## Non-goals
- Do not split any other part, raise `VULYK_PART_CAP`, or change `--jobs`.
- Do not rewrite or speed up a test body; move sections only.
- No change to CLAUDE.md.

## Map slice
memory/map/cycle.md: full-suite line (part naming)

## Acceptance criteria
- [ ] `--list-parts` of both files lists the 11 new names.
- [ ] Each of the 22 halves passes alone; measured times go under Implementation notes, each under 70 s on an idle box (a part over it is cut once more).
- [ ] `  ok ` line count per old part = sum over its two halves (before/after numbers under Implementation notes).

## Verification
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part seats3`
`bash tests/council.test.sh --part judge`
`bash tests/council.test.sh --part judge2`
`bash tests/council.test.sh --part walks`
`bash tests/council.test.sh --part walks3`
`bash tests/council.test.sh --part replays`
`bash tests/council.test.sh --part replays3`
`bash tests/council.test.sh --part escalate`
`bash tests/council.test.sh --part escalate2`
`bash tests/telemetry.test.sh --part rg`
`bash tests/telemetry.test.sh --part rg2`
`bash tests/telemetry.test.sh --part crlf`
`bash tests/telemetry.test.sh --part crlf2`
`bash tests/telemetry.test.sh --part constitution`
`bash tests/telemetry.test.sh --part constitution3`
`bash tests/telemetry.test.sh --part mods`
`bash tests/telemetry.test.sh --part mods2`
`bash tests/telemetry.test.sh --part ysk`
`bash tests/telemetry.test.sh --part ysk2`
`bash tests/telemetry.test.sh --part wrapper`
`bash tests/telemetry.test.sh --part wrapper2`

## Implementation notes

## Findings
