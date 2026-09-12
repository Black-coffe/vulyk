---
story: autonomous-cycle-11
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 4
blocked_by: [autonomous-cycle-08, autonomous-cycle-09, autonomous-cycle-10]
---

# Constitution and cycle docs: `CLAUDE.md`, `docs/cycle.md`, `docs/pipeline.md`, `bootstrap/interview.md`

## Goal
The documents that define the cycle say what v0.12.0 does: stage 05 is the council, the human is one stop at the grill and an optional override afterwards, Tier 1+ gets the council and Tier 0 does not, the Profile has a `Browser MCP` row and the bootstrap interview asks for it, and the gates table describes `cycle.sh` and the court.

## Requirements
> Tier 1+ — совет; Tier 0 — нет. Tier 1 получает мини-brief (сама фраза задачи verbatim, без гриля) и полный совет в один раунд. Tier 0 — прямая правка королевы, без совета: нет brief — нет суда.

> Профиль получает необязательную строку «Browser MCP: chrome-devtools | claude-in-chrome | none»; если заполнена — её получает ТОЛЬКО место Haiku, с запретом на любое действие наружу и требованием отдельного тестового профиля.

> Совет = приёмка + стадия 05; lead-review остаётся. Совет заменяет drone-acceptance и человека (слепой взгляд «делает ли оно то, что просили»). lead-review остаётся как второй, независимый по информации гейт — код, не намерение. Оба параллельно, как сейчас.

> Человек может включиться на любом этапе, если у него есть желание, но пока он сам желания не проявляет, система должна максимально быть автономной.

## Files
- CLAUDE.md
- docs/cycle.md
- docs/pipeline.md
- bootstrap/interview.md

## Non-goals
- Do not touch the Five Laws, `## Working with a frontier model`, `## Token economy` prose, `## Secrets`, `## Memory protocol` or `## Compact instructions` in `CLAUDE.md` beyond the cycle table, the routing matrix, the `## Commands` table (add the two test rows) and the Profile block.
- Do not fill VULYK's own Profile placeholders - they stay `<fill in>` (the framework repo is unbootstrapped by design; `recon/scout-commands.md` §Gotchas).
- Do not describe the Workflow runtime or the JS driver here beyond one sentence with a pointer - `docs/architecture.md` (story 12) owns that.
- Do not rewrite `docs/cycle.md` from scratch: keep its six-stage frame and invalidation table; replace the stage-05 rationale ("Why 05 is red") with the council's, citing the `human.jsonl` / `acceptance.jsonl` evidence lines from `brief.md`.
- No new interview batches; one question, Client-path-adjacent.

## Map slice
`docs/specs/autonomous-cycle/plan.md` `## Contracts` C4, C7, C9, C12 (Profile row) and `## Goal` · `docs/adr/001-cycle-state-contract.md` D1 table (the new files, for the gates table), D4 last paragraph, D5, D6 · `docs/specs/autonomous-cycle/recon/scout-docs.md` §Answer 1 (`CLAUDE.md` cycle row 05; `docs/cycle.md:11,26-27,30-42,49-56`; `docs/pipeline.md:24,55`), §Answer 2 (approval row 02, publish row 06 in both files), §Answer 6 (interview Batch 2 Q9/Q10 pattern for the new question) · `docs/grill/2026-09-12-autonomous-cycle-council.md` "Производные решения" (the cycle-table change) and Decision 13.

## Acceptance criteria
- [ ] `CLAUDE.md` cycle table: row 01+02 confirmation `**Briefed:**` (or `**Approved:**` in two-stop mode), command `/vulyk-plan` with the grill; row 04+05 `Council` - `**Council:** GREEN` + `council.jsonl`, command `/vulyk-build` (driver) or `/vulyk-review` (one round); *Human* becomes a sentence under the table: optional at any stage via `/vulyk-pause` and `human-check.sh` as override, never a mandatory stage; row 06 says merge local, publish printed. The paragraph "Stage 05 is the one mandatory human control…" is replaced by the council's one-paragraph statement and the ceiling/escalation rule.
- [ ] Routing matrix: Tier 0 "no brief, no council"; Tier 1 "mini-brief + 1 worker + one council round"; Tier 2-4 protocols name `/vulyk-plan` (grill) -> driver -> `/vulyk-ship`; Tier 4's second reviewer sentence unchanged; the ceremony-floor sentence updated (`## Asks` at Tier 1+).
- [ ] `## Profile` gains `| Browser MCP | <chrome-devtools \| claude-in-chrome \| none - optional; read by the Haiku seat only, read-only, separate test profile> |` after *Client path*, with two sentences in the block's preamble about why the row exists.
- [ ] `## Commands` gains rows for `bash tests/cycle.test.sh` and `bash tests/council.test.sh` and a `bash scripts/cycle.sh status docs/specs/<slug> --json` row; the "Full suite" row's honesty sentence stays.
- [ ] `docs/cycle.md`: the diagram and stage list show `04 Tests` and `05 Council` with `Human` as an override arrow; each stage's "cannot skip / what reopens it" covers `Briefed`, the round, STALE on a code commit, PAUSE, ESCALATE and the three exits after it.
- [ ] `docs/pipeline.md`: gate rows for `cycle.sh record-seat` (what it rejects), `cycle.sh judge` (the D4 table in prose), the court (what a seat cannot see), `human-check.sh` re-labelled override; the staleness table gains council rows; the environmental-failure-is-N/A sentence is kept and pointed at from the seat contract.
- [ ] `bootstrap/interview.md` Batch 2 gains, after Q9, a closed-choice question for the *Browser MCP* row (`none` recommended unless a test profile exists), with the one-line reason it goes in the Profile, quoted back per the "After the interview" rule.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
