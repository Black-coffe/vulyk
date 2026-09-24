---
story: convergent-judge-07
spec: convergent-judge
status: todo
returned:
tier: 2
worker: worker-code
model: opus
tracer: false
wave: 5
blocked_by: [convergent-judge-02, convergent-judge-05]
---

# Only RED rounds count toward the ceiling; the review layout is a contract record-seat enforces (asks 1, 3, 4)

## Goal
A GREEN round no longer spends the tier's budget: the ceiling is compared against the number of this spec's rounds that ended RED (plan `## Contracts`: RED rounds), so a Tier 1 spec judged GREEN and then given one code commit opens round 2 instead of writing `ESCALATE ceiling` beside its GREEN row. `lead-review.md` states the report layout the judge reads - H2 `## Critical` / `## Major`, one finding per list line, its anchor tag on that line - as a contract, and `record-seat … review` refuses a `VERDICT: BLOCK` whose body carries no such tagged line as MALFORMED (exit 4, kept as an attempt, re-asked once), so a real `[ask N]` under `**Major**` or on a wrapped line is sent back to the reviewer instead of being recorded PASS. The judge's downgrade stays only for a BLOCK whose blocking lines are all `[unanchored]` (ask 3).

## Requirements
> Owner (Andrei, 2026-09-24): only rounds that ended RED count toward the tier ceiling - GREEN and STALE rounds never do; lead-review.md states the report layout as a contract (H2 ## Critical / ## Major, one finding per list line, its anchor tag on that line), and record-seat rejects a BLOCK carrying no such line as MALFORMED (retryable) instead of judge downgrading it.

> Потолок раундов зависит от тира: Tier 1 — 1, Tier 2 — 2, Tier 3–4 — 3; reopen добавляет столько же.

> BLOCK засчитывается, только если хоть одно блокирующее замечание помечено `ask N` или `regression`, иначе оно идёт как PASS, а замечания — в заметки к ship.

> Ревьюер ставит BLOCK за любой critical или major, PASS при major запрещён.

## Files
- scripts/cycle.sh
- tests/council.test.sh
- .claude/agents/lead-review.md
- docs/adr/001-cycle-state-contract.md
- docs/cycle.md

## Non-goals
- Do not remove the judge's `[unanchored]`-only downgrade (review `PASS`, note `review BLOCK unanchored`) - ask 3 still wants it; only the no-tagged-line case moves to `record-seat`.
- Do not make `record-seat` validate the ask range of `[ask N]` or the `[regression]` claim - an out-of-range N stays "unanchored" at `judge` as story 02 left it (plan A2/A3).
- Do not change the seats' `ASK` parsing, the two-attempt rule, the exit-code table or the first-line `VERDICT:` contract - the BLOCK layout check is one more MALFORMED reason inside the existing path.
- Do not touch `.claude/workflows/vulyk-cycle.js`, `.claude/commands/vulyk-build.md`, `vulyk-review.md`, `vulyk-ship.md` - both drivers already re-ask once on `record-seat` exit 4 (plan A12); the Tier 4 fold (round-2 minor 12) and step 5 (minor 10) are ship notes.
- Do not touch `no-progress`'s comparison round (minor 8), `write_escalate_row_for_round`'s raw `review` (minor 7), `status`'s `CEILING=3` default (minor 5), `docs/pipeline.md`, `vulyk-resume.md`, `command-reference.md` (minor 4) - ship notes.
- Do not edit `memory/map/cycle.md` (librarian-owned); list its stale lines in `## Implementation notes`.
- ADR-001 is CRLF - preserve it; amend in place with a dated `convergent-judge-07` note, never a rewrite.

## Map slice
memory/map/cycle.md - "Staleness / ceiling / PAUSE-REOPEN-CEILING", "Required seats by tier and the verdict rule", "Seat report contract (D3)", "cycle.sh verbs" (exit 4). Plan `## Contracts`: RED rounds; `review.md` finding line.

## Acceptance criteria
- [ ] `judged_rounds` (cycle.sh:288-294) - or its replacement - counts distinct round numbers that ended RED per the plan contract: a `RED` row, or an `ESCALATE` row whose `escalate` is `ceiling` or `no-progress`; `GREEN`, `STALE` and `ESCALATE` `env`/`half` rows never count. Both `open-round` gates (:2018, :2034) and `judge`'s ceiling row (:944) use it; `status`'s `round` stays the directory count; `reopen` still raises C by `tier_ceiling`.
- [ ] Tests (fixture repo): Tier 1 - round 1 GREEN, one code commit, `open-round` -> `round 2 opened`, exit 0, next `dispatch:sonnet`, no ESCALATE row; round 2 RED -> `ESCALATE ceiling`. Tier 2 - GREEN, commit, RED (`repair`), commit, RED (`ESCALATE ceiling`). Tier 2 after `reopen` (C=4) - RED (`repair`), RED (`ESCALATE ceiling`): exactly two more RED rounds, the escalated round counted. The STALE fixtures of story 05 (`tstale1`, `tstale2`, `ceilstale1`, `ceilstale2`) keep passing.
- [ ] `cmd_record_seat_review` (:1284-1293): when line 1 is `VERDICT: BLOCK` and `review_blocking_lines` (:592-599) yields no line carrying `[ask N]`, `[regression]` or `[unanchored]`, the report is MALFORMED - exit 4, kept as `review.attempt-K.md`, the JSON `error` names the gap (no tagged finding under `## Critical` / `## Major`); nothing else about a BLOCK is validated, and a `PASS` report is accepted regardless of layout. The second attempt follows the seats' existing two-attempt rule (an exhausted review is ABSENT for the round).
- [ ] Tests: BLOCK with `[ask 2]` under `**Major**` (bold, not H2) -> exit 4, `review.attempt-1.md` exists, no `review.md`; the same text with `## Major` -> accepted, `judge` -> RED, `review_asks:[2]`. BLOCK whose only tag sits on a continuation line under `## Major` -> exit 4. BLOCK with `[regression]` in prose only under `## Major` (`anchprose` shape) -> exit 4 at record-seat, no longer judged PASS-with-note. BLOCK with `[unanchored]` list lines only -> accepted, `judge` -> review `PASS`, note `review BLOCK unanchored` (story 02's `unanchr` fixture flipped to tagged lines, not deleted). Every existing council fixture whose BLOCK now lacks a tagged line is given one or flipped to expect exit 4 - none deleted.
- [ ] `lead-review.md` (:30-34) states the layout as a contract: line 1 `VERDICT: PASS|BLOCK`; H2 headings `## Critical`, `## Major`, `## Minor` (`None.` under an empty one); one finding per list line (`N. ` or `- `) with `file:line`, its tag, its routing word and the condition on that one line - no `**Major**`, `### Major`, tables or wrapped findings; says `record-seat` refuses a BLOCK with no tagged critical/major line as MALFORMED and re-asks once. The hunting list (:12-28) is untouched.
- [ ] ADR-001: every "judged (non-STALE)" statement (:159-160, :180, :184, :266-268, :277, :337, :369, :385) reads "rounds that ended RED" per the contract; D2's `record-seat` row and D3's `lead-review keeps its own contract` sentence gain the BLOCK layout check; the D4 anchor amendment (:281-289) says the downgrade fires only on `[unanchored]`-only BLOCKs. `docs/cycle.md` (:52-53, :72, :74) says the same. The `write_stale_row` comment (cycle.sh:1843-1845) no longer says a STALE row counts (round-2 minor 3, same sentence the decision reverses).

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh && bash tests/cycle.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
