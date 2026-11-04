---
story: post-046-tails-03
spec: post-046-tails
status: done
returned: DONE
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
`bash tests/telemetry.test.sh --part ysk3`
`bash tests/telemetry.test.sh --part wrapper`
`bash tests/telemetry.test.sh --part wrapper2`

## Implementation notes
Cuts are on section boundaries, measured first (each part's output timestamped per line, 2026-11-03). Times: the
halves run 5-10 at a time on this 28-core box (one install.sh run alone takes 20-27 s here, so these are near
idle). `ok` counts: council halves sum to the old part exactly; every telemetry part prints two `bash -n` syntax
oks of its own, so each extra part adds 2.

| old part (ok, s) | halves: ok, s |
|---|---|
| council seats (54, 79) | seats 37, 43 · seats3 17, 31 |
| council judge (67, 88) | judge 20, 51 · judge2 47, 47 |
| council walks (29 + 24 probe lines, 89) | walks 29 + b9f36e8 probes, 61 · walks3 the 12 branch probe lines, 37 |
| council replays (32, 91) | replays 15, 62 · replays3 17, 36 |
| council escalate (86, 96) | escalate 54, 51 · escalate2 32, 54 |
| telemetry rg (14, 112) | rg 8, 46 · rg2 8, 48 |
| telemetry crlf (31, 116) | crlf 11, 49 · crlf2 22, 48 |
| telemetry constitution (35, 158) | constitution 19, 60 · constitution3 18, **86** |
| telemetry mods (29, 157) | mods 20, **74** · mods2 11, **72** |
| telemetry ysk (16, 164) | ysk 8, 24 · ysk2 8, 60 · ysk3 4, 47 |
| telemetry wrapper (25, 168) | wrapper 11, 52 · wrapper2 16, **99** |

- council: seats cut at the R9 live proof (its `--quick` block is closed and reopened across the cut); judge right
  after its `--quick` block; replays at the stale-round section (the review-key section continues the `realverbs`
  spec, so it stays); escalate at the escalate verb; walks keeps the b9f36e8 replay, walks3 the branch replay, the
  probe functions in a block both run.
- telemetry: shared stubs and helpers moved into `part_on <a> <a2>` blocks; constitution's CR hive is one function
  `cr_hive` both halves call; mods2 rebuilds PI with one silent stub install, then the cc-mkt/cc-list state the
  first half leaves; ysk was cut once more (ysk3) because it needed no rebuild.
- Over 70 s, not cut again: constitution3, mods, mods2, wrapper2. Each is one chain of install.sh runs (20-27 s
  each) on one hive; a further part has to rebuild that hive with the same runs, so it costs what it saves
  (wrapper2 split = ~42 s + ~75 s with the rebuild; constitution3 = an install plus four replace runs). Under a 3x
  load these four reach ~215-300 s against the 300 s cap. Not done: a faster install.sh (non-goal here).
- Also run green after the cut: constitution2, ysk-hook, launchers, seats2 (they share the blocks I touched).

## Findings
