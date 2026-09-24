---
story: convergent-judge-05
spec: convergent-judge
status: done
returned: DONE
tier: 2
worker: worker-code
model: opus
tracer: false
wave: 4
blocked_by: [convergent-judge-01, convergent-judge-02, convergent-judge-04]
---

# Judged-rounds ceiling, anchor tags read only on blocking lines (asks 1, 3)

## Goal
A STALE-folded round no longer consumes a tier's round budget: the ceiling counts *judged* rounds (rows whose verdict is not STALE), so a Tier 1 spec whose round 1 goes stale still gets its one verdict, and a Tier 2 spec still gets two. The judge reads `[ask N]` / `[regression]` only on list lines under a critical or major heading, so the literal `[regression]` in a reviewer's prose (what held round 1 of this very spec as RED with `review_asks:[]`) no longer anchors a BLOCK. ADR-001, the `reopen` comment and `docs/cycle.md` say the tier-sized ceiling everywhere they still say 3 / +3.

## Requirements
> Потолок раундов зависит от тира: Tier 1 — 1, Tier 2 — 2, Tier 3–4 — 3; reopen добавляет столько же.

> BLOCK засчитывается, только если хоть одно блокирующее замечание помечено `ask N` или `regression`, иначе оно идёт как PASS, а замечания — в заметки к ship.

> Так зачем было три цикла гонять и сотни тысяч токенов тратить? Как-то вот там нужно это пересмотреть.

## Files
- scripts/cycle.sh
- tests/council.test.sh
- tests/cycle.test.sh
- docs/adr/001-cycle-state-contract.md
- docs/cycle.md

## Non-goals
- Do not change `no-progress`'s comparison round (review minor 8: N-1 newest row, STALE resets the streak) - ship notes, plan A4 stands.
- Do not touch `write_escalate_row_for_round`'s raw `review:"BLOCK"` (minor 7) or add the two missing test cases of minor 9 - ship notes.
- Do not add a separate cap on STALE folds; `paperwork_only` already keeps the cycle from staling itself, and a mid-round commit is the owner's own act.
- Do not edit `.claude/agents/lead-review.md` - its format paragraph already scopes the tag to critical/major lines; the judge is what is out of step.
- Do not edit `memory/map/cycle.md` (librarian-owned); note the stale lines in `## Implementation notes` instead.
- Do not touch `.claude/workflows/vulyk-cycle.js`, `docs/pipeline.md`, `docs/architecture.md` - story 06 owns them this wave.

## Map slice
memory/map/cycle.md - "Staleness / ceiling / PAUSE-REOPEN-CEILING", "Required seats by tier and the verdict rule", "Seat report contract (D3)".

## Acceptance criteria
- [ ] `open-round` (`NEXTN -le CEILING`, :1999-2007) and `judge` (`ROUND_COUNT -lt CEILING`, :2014) compare the ceiling against the count of this spec's non-STALE `council.jsonl` rows (plan `## Contracts`: judged rounds), not the round number; ESCALATE rows count, STALE rows never do; `status`'s `round` key stays the directory count.
- [ ] Tests: Tier 1 - round 1 seat recorded, code commit lands, `open-round` writes the STALE row and opens round 2 with exit 0 (not 6); round 2 RED -> ESCALATE `ceiling`. Tier 2 - STALE, RED (`repair`), RED (ESCALATE `ceiling`); after `reopen` the next RED is `repair` again. The existing fixture asserting "STALE counts toward the ceiling" is flipped, not deleted.
- [ ] `review_anchor_asks` / `review_has_regression` (:576-587) read a tag only on a list line (`- `, `* `, `N. `) between a `## Critical` or `## Major` heading (case-insensitive) and the next `## ` heading; tests: `[regression]` in prose under `## Major` does not anchor; `[ask 2]` on a `## Minor` list line does not anchor; `[ask 2]` on a `## Major` list line still does.
- [ ] ADR-001: STALE lines (:159, :330, :377 invariant) and D4's definition of N/C (:264, :273) amended in place with a dated `convergent-judge-05` note; the D4 anchor amendment (:277-282) states the critical/major-list-line scope; no line in the file still states a flat ceiling of 3 or a +3 `reopen` step (:92, :125, :183, :332, :361).
- [ ] `cycle.sh:2026` `reopen` header comment and any `docs/cycle.md` sentence about STALE folds state the tier-sized step and the judged-rounds count.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh && bash tests/cycle.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `scripts/cycle.sh`: new `judged_rounds <slug> [exclude]` (distinct rounds with a non-STALE row; ESCALATE counts) drives both `open-round` gates and `judge`'s ceiling row (`judged-before-this-round + 1 >= C`); `status`'s `round` untouched. New `review_blocking_lines` (awk) feeds `review_anchor_asks` / `review_has_regression`.
- Decision: count distinct round numbers, not rows - a RED then ceiling-ESCALATE on one round is one judged round, so `reopen` does not lose budget to a double row.
- The AC's ":2014 judge" pointer names open-round's fresh-round gate; the judge ceiling itself was `N -ge RCEILING` (~:927). Both changed.
- `tests/council.test.sh`: existing anchor fixtures gained `## Major` / `## Critical` headings (untagged-heading `- major [ask N]` lines no longer anchor); `ceilstale1` flipped (exit 0, round 2, no ESCALATE); its r2m5/r2m6 red-asks assertion moved to a new `ceilstale2` whose round 1 is already judged, the only way the STALE-fold ceiling branch is still reachable. `tests/cycle.test.sh` needed no change (no ceiling fixture).
- Relaunch 2026-09-24: the implementation was already on disk (uncommitted). I checked each AC against the files and re-ran the verification; nothing was edited.
- Stale map lines for the librarian: `memory/map/cycle.md` :74-77 ("either way counts toward the ceiling", "default ceiling 3", "raises CEILING by 3") and :65 ("RED if round N < ceiling").

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
