---
story: ab-run-fixes-04
spec: ab-run-fixes
status: todo
returned:
tier: 3
worker: worker-code
model: opus
wave: 2
blocked_by: [ab-run-fixes-01, ab-run-fixes-02, ab-run-fixes-03]
red: required
red_reason: seats: Tier 3 with a Client path requires review and haiku only
---

# Council: one blind seat, a second reviewer with a reason, no stale carry, a narrow repair path

## Goal
Why `model: opus`: three changes to the state contract (roster, carry, narrow repair) meet in the verdict rule, and a wrong call weakens the gate without a sound.

After this story:
- **One blind seat.** Tier 3-4 rounds require `review` plus one blind seat: `haiku` when the Client path is filled, else `opus` (plan C1).
- **Tier 4 second reviewer.** It runs only on a risk path in the round's diff, or after the first reviewer's BLOCK (C2, C3). The driver dispatches exactly the seats `next` names.
- **No stale carry.** A blind seat is not carried over an ask the repair touched (C4).
- **Narrow repair.** A one-item, one-file RED round gets a narrow repair story and a review-only next round, with no blind seat and no suite (C5). The worker still builds it (Law 5).
- **Card check.** Card `full-round-for-a-narrow-fix` gets a `check:`, an original fixture and a neighbour fixture (Law 6).

## Requirements
> 2. Совет Tier 3–4: одно слепое место (если у проекта есть Client path, это «чёрный ящик», иначе судья замысла); второй ревьюер Tier 4 — только при BLOCK первого или если дифф задел файлы безопасности и данных.
> 3. Раунд 2 и дальше не переносит место, чей пункт задела ремонтная история.
> 5. Узкая правка (один пункт, один файл): одна история исполнителю, проверка тестами этого файла, один ревьюер по диффу. Без слепых мест и полного прогона, карточка дефекта тем же коммитом.

## Files
- scripts/cycle.sh
- .claude/workflows/vulyk-cycle.js
- tests/council.test.sh
- tests/driver.test.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- .claude/agents/lead-review.md
- docs/defects/full-round-for-a-narrow-fix.md
- docs/defects/full-round-for-a-narrow-fix.original.fixture
- docs/defects/full-round-for-a-narrow-fix.neighbour.fixture
- docs/defects/INDEX.md
- docs/cycle.md
- docs/model-cascade.md
- docs/token-economy.md
- docs/adr/013-light-vulyk.md
- docs/command-reference.md
- README.md

## Non-goals
- Unchanged: the fold rule (BLOCK if either), the half/no-progress/ceiling thresholds, and the `unanchored` rule.
- No configurable risk list: no Profile row, no env.
- No Queen path for the narrow repair, and no `git-guard.sh` change.
- Leave `claim`, the dirty tree and the driver's wave loop alone (story 05). Do not merge suite parts.

## Map slice
memory/map/cycle.md (Seats and the verdict; Repair; `suite`; Full-suite line; `advance`; The Workflow driver); memory/map/agents-and-commands.md (`lead-review`, `council-opus` / `council-haiku`); docs/wiki/rules-tree.md (card `check:`, fixtures)

## Acceptance criteria
- [ ] Roster: Tier 3 with no Client path requires `review opus`; Tier 3 and Tier 4 with a Client path require `review haiku`; Tier 1-2 require `review`. The test labelled `seats: Tier 3 with a Client path requires review and haiku only` fails on HEAD and passes after.
- [ ] Tier 4, second reviewer:
  - With no risk path, the first dispatch is `review` plus the blind seat. A PASS is judged without `review2`; a BLOCK gives `next` = `dispatch:review2` once, and then the fold.
  - A risk path such as `app/Auth/Login.php` or `db/migrations/x.sql` puts `review2` in the first dispatch.
  - The driver test shows `review2` dispatched on `second_model`, and no doubling by tier.
- [ ] Carry: after a repair whose requirements cite ask 2, a blind seat with an `ASK 2:` line is not carried. After a repair of regressions only, it is.
- [ ] Narrow repair:
  - A narrow RED round (one item, one file) yields a `narrow: true` repair story shaped as C5. The next round freezes `seats=review`; `suite` writes `SUITE: none - narrow repair round` without running a step; `record-seat` accepts the review; `judge` decides.
  - The neighbour case (two files, or two items) still gets a full round.
- [ ] `bash scripts/defects-check.sh docs/defects/full-round-for-a-narrow-fix.md` passes. The card's `check:` fails on the original fixture (a narrow round that still requires blind seats) and passes on the neighbour. `INDEX.md` is regenerated.
- [ ] Docs carry C1-C5, with the risk set named in `docs/cycle.md`:
  - `docs/cycle.md`: stage 05, the council paragraphs and the tiers table;
  - `docs/model-cascade.md`: the Tier 4 second reviewer;
  - `docs/token-economy.md`: dispatches per tier;
  - ADR-013: one dated amendment to D1 and D4;
  - README: the second-reviewer row, the council row, the routing-matrix rows for Tier 3-4, and the `/vulyk-review` row;
  - `docs/command-reference.md`, `vulyk-build.md`, `vulyk-review.md`, and `lead-review.md` wherever it says Tier 4 means two dispatches.
- [ ] `## Implementation notes` ends with one `CHANGELOG:` line.

## Verification
`bash tests/council.test.sh --part roster`
`bash tests/council.test.sh --part seats`
`bash tests/council.test.sh --part verbs`
`bash tests/council.test.sh --part suite`
`bash tests/driver.test.sh`
`bash scripts/defects-check.sh docs/defects/full-round-for-a-narrow-fix.md`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
