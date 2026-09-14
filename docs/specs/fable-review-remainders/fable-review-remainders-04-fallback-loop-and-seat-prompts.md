---
story: fable-review-remainders-04
spec: fable-review-remainders
status: todo
returned:
tier: 3
worker: worker-code
tracer: false
wave: 1
blocked_by: []
model: sonnet
---

# The fallback loop records by file and the seat files know the report path

## Goal
The `/vulyk-build` fallback loop and `/vulyk-review` hand each seat and the single reviewer the C2 report path, record through `record-seat --file <path>` and fall back to the heredoc on exit 2 `file:`; the fallback loop's stop text for a dead worker names the three C3 reasons. The three seat files and `lead-review.md` gain one sentence: when the dispatch names a report path, the report is written there as the last action, and writing there is not a BREACH. The `/vulyk-build` "harmless, exit 0" sentence about `release` stays: story 02 makes it true.

## Requirements
> сиды и ревьюер пишут отчёт по пути, который даёт драйвер (вне docs/specs); драйвер записывает по пути с откатом на heredoc, если файла нет
> То же для сидов совета и ревьюера.
> Оба драйвера и три описания становятся правдой без правки.

## Files
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- .claude/agents/council-haiku.md
- .claude/agents/council-sonnet.md
- .claude/agents/council-opus.md
- .claude/agents/lead-review.md

## Non-goals
- Do not edit the `release` sentence at `vulyk-build.md:87-88`; it is now true (C4).
- Do not change any `maxTurns:`, `model:` or `tools:` line in the agent files; do not add the report-path sentence to `cycle-clerk.md` or the worker files.
- Do not restate C3's strings differently from the driver: copy them from `plan.md` C3 verbatim into the fallback loop's stop text.
- Do not touch `.claude/workflows/vulyk-cycle.js` (story 03) or `scripts/cycle.sh` (story 02).
- The Tier 4 second reviewer in `/vulyk-review` keeps the folded heredoc path and gets no report path (C2).
- Write `returned: DONE` as your last edit; never write `status:`.

## Map slice
`plan.md` C2, C3, C4 (the sentence, the path shape, the strings) · `memory/map/agents-and-commands.md` (the seat files' report contract and the `/vulyk-build` / `/vulyk-review` verb tables) · `memory/map/cycle.md` §"Drivers" (Fallback) and §"Seat report contract (D3) and the court (D5)" (the BREACH rule the new sentence must not contradict) · `recon/driver-and-cycle.md` §"`release` vs PAUSE" (the prose sites).

## Acceptance criteria
- [ ] `/vulyk-build` fallback `dispatch:<seats>` row: each seat's and the single reviewer's Agent prompt ends with the C2 sentence and path; recording runs `record-seat ... --stamp $stamp --file <path>` first and, on `exit:2` with `error` starting `file: `, the heredoc form with the chat reply; exit 4 re-ask once as today.
- [ ] `/vulyk-build` fallback `build:<wave>` row: a worker that threw, returned empty, or returned text without a report is reported with the C3 string (the empty case names the agent and its `maxTurns` from the agent file), and after the second miss the story is blocked with that string as the reason.
- [ ] `/vulyk-review` dispatches and records with the same path and fallback; the Tier 4 pair is unchanged.
- [ ] `council-haiku.md`, `council-sonnet.md`, `council-opus.md`, `lead-review.md` each carry one sentence: when the dispatch names a report path, write the full report there verbatim as the last action (`mkdir -p` its directory), the chat reply is the same text, and writing there is not a BREACH. Nothing else in those files changes (`git diff --stat` shows one hunk per file).
- [ ] The `release` sentence at `vulyk-build.md:87-88` is byte-identical to before.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
