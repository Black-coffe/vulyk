---
story: convergent-judge-02
spec: convergent-judge
status: todo
returned:
tier: 2
worker: worker-code
model: opus
tracer: false
wave: 2
blocked_by: [convergent-judge-01]
---

# Anchored BLOCK, major blocks (asks 3, 4)

## Goal
`lead-review` blocks on any critical or major finding and tags each one `[ask N]`, `[regression]` or `[unanchored]`. `judge` keeps a BLOCK only when at least one tag is `[ask N]` (N a real brief ask) or `[regression]`; otherwise it records review `PASS` with note `review BLOCK unanchored`, and those findings go to the next circle instead of a repair wave. The row carries `review_asks`.

## Requirements
> BLOCK обязан ссылаться на номер вопроса из брифа или на регрессию, всё прочее уходит в заметки к ship;

> PASS при major-баге в продукте запрещён: либо BLOCK, либо minor;

> И всегда в три цикла не может вложиться, всегда у него что-то там не получается, и он такой: «А ну, принимай решение ты».

## Files
- scripts/cycle.sh
- tests/council.test.sh
- .claude/agents/lead-review.md
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-ship.md
- .claude/commands/vulyk-review.md
- docs/adr/001-cycle-state-contract.md

## Non-goals
- Do not add the no-progress rule - story 04.
- Do not change the first-line contract (`VERDICT: PASS|BLOCK`) or record-seat's exit-4 MALFORMED path (:1212); anchors are read from the body in addition.
- Do not make the judge validate a `[regression]` claim - only the tag (plan A3).
- Do not touch the seats' ASK-line parsing (`seat_ask_lines`, :532) or the Tier 4 second-reviewer fold beyond passing anchors through the same parse.
- Do not rewrite `lead-review.md`'s hunting list; change the verdict and report-format paragraphs (:26-32) only.

## Map slice
memory/map/cycle.md - "Required seats by tier and the verdict rule", seat/court contracts; memory/map/agents-and-commands.md - lead-review, vulyk-build, vulyk-ship.

## Acceptance criteria
- [ ] lead-review.md: `BLOCK` = at least one critical **or major** finding; every critical/major line carries exactly one of `[ask N]`, `[regression]` (with base-side evidence), `[unanchored]`; PASS with a major is named as a contract breach.
- [ ] `cmd_judge`: parses review.md's body with `\[(ask [0-9]+|regression)\]`; BLOCK with no valid anchor → review recorded `PASS`, note `review BLOCK unanchored`; `[ask N]` with N outside 1..A counts as unanchored.
- [ ] Row gains `review_asks:[...]` after `red_unevidenced` (empty when none); older rows still parse.
- [ ] vulyk-build.md repair row (:101): stories only for anchored findings. vulyk-ship.md step 5 (:16): also carries every finding of an unanchored BLOCK. vulyk-review.md: same verdict reading, if it restates it.
- [ ] ADR-001: row shape and D4 amended in place with a dated note.
- [ ] Tests: anchored BLOCK → RED/repair; unanchored BLOCK with seats GREEN → GREEN; out-of-range `[ask 9]` → unanchored; `review_asks` recorded.

## Verification
`bash tests/council.test.sh && bash tests/cycle.test.sh && bash tests/driver.test.sh`

## Implementation notes

## Findings
