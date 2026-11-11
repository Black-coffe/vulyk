---
story: upgrade-findings-05
spec: upgrade-findings
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 3
blocked_by: [upgrade-findings-03]
red: required
red_reason: narrow: true in the story does not shrink the round
red_verified_at: 2026-11-11T08:50:18Z b2f1dcaad37d9a5b661690cb5a69c8e493f9da42b9b19a5c22dea633e4add2cc
---

# A round is narrow only by the cycle's own record; a rename cannot hide a risk path

## Goal
`scripts/cycle.sh`, on the store story 03 landed (plan.md `## Contracts` S1, S3). **A3:** `repair` writes the
narrow record `.vulyk/state/<slug>/narrow.round-<n+1>` when it decides a round is narrow, and still writes
`narrow: true` into the repair story for the worker. `open-round` (`build_round`) no longer reads the story's
frontmatter: it freezes `seats=review`, `narrow=1`, `second=none` only when the record names the newest repair
story and the narrow rule (exactly one RED item reaching one non-test file), recomputed from round n's
committed records by the same function `repair` uses, still holds. Record missing, naming another story, or
rule not holding: a full round, with one stderr line saying which. `story_blocks_guard` compares `narrow:`
with the approved version beside `
- [ ] A4 has its own regression case, red on 0.50.2: `git mv` of a risk-path file to a neutral path in the round's range makes `round_second` print `risk`. (Queen, coverage gap ask 4)

## Verification`, `## Files` and `red:`. **A4:** `round_second` lists the
range with `--no-renames`, so both the old and the new path of a moved file meet the risk set.
`docs/cycle.md`: the narrow paragraph says where the flag comes from and that a clone without the record gets
a full round; the risk-set sentence says a rename counts on both sides.

## Requirements
> 3. A3: a round runs narrow only from cycle-owned state written by `cycle.sh repair`, never from the repair story's frontmatter; "exactly one RED item in one non-test file" is re-checked when the round opens, and `narrow:` joins the blocks `story_blocks_guard` compares. A `narrow: true` an agent writes into a repair story does not shrink the round: a regression test that fails on 0.50.2.
> 4. A4: `round_second` sees both sides of a rename: `git mv` of a risk-path file to a neutral path prints `risk`, a regression test that fails on 0.50.2.
> 5. A1-A4 each get a CHANGELOG line, and issue #5 is closed with the release that ships them.

## Files
- scripts/cycle.sh
- tests/council.test.sh
- docs/cycle.md

## Non-goals
- Do not change what counts as narrow, the repair story's shape (`## Files`, `## Verification`, `model: opus`),
  the risk set, the roster, the fold or the verdict rule.
- Do not key the narrow record by HEAD: the repair is built between `repair` and `open-round`.
- Do not write `narrow=` anywhere but `ROUND`, and do not make a missing record an error: it is a full round.
- Do not touch the verify record, `verify_run` or stamp-red (story 03, landed), the cell helpers (story 01),
  the driver, or `docs/defects/full-round-for-a-narrow-fix.*`.
- Tests and docs stay at the level of issue #5: they state the new behaviour, nothing about the old one.
- Do not edit `tests/council.test.sh` outside parts `verbs`, `suite` and `roster`.

## Map slice
`memory/map/cycle.md` → Repair, Seats and the verdict (narrow round, `review2_called`), Verbs (`open-round`,
Story trust from git), Staleness; `docs/cycle.md` → the council paragraphs (C2, C3, C5).

## Acceptance criteria
- [ ] `--part verbs`: a RED round with two RED items whose repair story carries `narrow: true`: the next
  `open-round` freezes the tier's full seats, no `narrow=1`, and `suite` runs its step. The failing label
  contains `narrow: true in the story does not shrink the round`.
- [ ] `--part verbs`: a genuinely narrow RED round: `repair` writes the record and the story; the next round
  is `seats=review`, `narrow=1`, as before. With the record absent it opens as a full round and stderr says
  the record is missing; with a record present but round n's records giving two files, a full round and
  stderr names the re-check.
- [ ] `--part verbs`: `close-story` on a repair story whose `narrow:` line differs from its approved version
  exits 4 with `story blocks differ from the approved version (<sha7>): narrow:`; an untouched repair story
  closes.
- [ ] `--part suite`: the narrow round still writes `SUITE: none - narrow repair round`; the two-item round
  above does not.
- [ ] `--part roster`: Tier 4, a range whose only change is `git mv app/auth/login.php app/misc/login.php`:
  ROUND has `second=risk` (label contains `a rename off a risk path is still risk`); a move between two
  neutral paths stays `second=none`; a move onto a risk path is `risk` as before.
- [ ] `docs/cycle.md` matches: no sentence says the round reads the story's `narrow: true`.
- [ ] `bash scripts/portability-check.sh scripts/cycle.sh` is clean.
- [ ] `## Implementation notes` ends with two `CHANGELOG:` lines, one for A3 and one for A4.

## Verification
`bash tests/council.test.sh --part verbs`
`bash tests/council.test.sh --part suite`
`bash tests/council.test.sh --part roster`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->
- scripts/cycle.sh: repair_asks, repair_findings and narrow_file lifted out of cmd_repair, so repair and open-round decide narrow by one function.
- scripts/cycle.sh: repair writes .vulyk/state/<slug>/narrow.round-<n+1> (story=, file=, from=); build_round asks narrow_round_holds and never reads `narrow:`.
- scripts/cycle.sh: narrow_round_holds recomputes from round n-1's row (round_row), seat files and done stories minus the repair story itself; stderr only when round n-1 has a repair story.
- scripts/cycle.sh: story_blocks_guard compares `narrow:`; round_second lists with --no-renames.
- docs/cycle.md: narrow paragraph names the record as the flag's source and the full round on a clone without it; the risk set counts a rename on both sides.
- tests/council.test.sh: written before the red receipt (previous attempt); unchanged since.
CHANGELOG: A3 - a council round runs narrow only from the record `cycle.sh repair` writes in .vulyk/state, re-checked when the round opens; a `narrow: true` written into a repair story no longer shrinks the round, and close-story refuses a changed `narrow:` line.
CHANGELOG: A4 - the Tier 4 second-reviewer check sees both sides of a rename: moving a risk-path file to a neutral path still calls `review2`.

## Findings

## Red receipt
- command: bash tests/council.test.sh --part verbs
- exit: 1
- tests: b2f1dcaad37d9a5b661690cb5a69c8e493f9da42b9b19a5c22dea633e4add2cc (tests/council.test.sh)
- impl: 2071307de2b7d373bcf6b48d4bc576a71b9fa434e091c117663b217abc12675c
- stamped: 2026-11-11T08:50:18Z

```
::error::narrow: true in the story does not shrink the round - ROUND=head=8f08f94
narrow=1 stderr=
::error::re-check: ROUND=head=0c54c6b
pack=6a467b5c2928
opened=2026-11-10T22:25:43Z
court=
ceiling=3
tier=3
seats=review
since=2513b63
narrow=1 stderr=
```
