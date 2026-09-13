---
story: autonomous-cycle-24
spec: autonomous-cycle
status: done
tier: 4
worker: worker-code
tracer: false
wave: 8
blocked_by: []
---

# The court is an honour clause with a detector: seat prompts, `lead-review`'s first line, ADR-001 amended

## Goal
The words match the mechanism. The three seat prompts, ADR-001 D5, the constitution's council sentence and the command reference stop calling the court "read-only" and stop promising blindness the shared object store cannot give: the court is a shared, writable worktree whose working tree holds only `brief.md`, whose git history is out of bounds, and whose writes `judge` discards. `lead-review.md` states the one line `record-seat … review` parses. ADR-001 D1, D2, D4 and D6 say what stories 19-21 make true — seat files committed at `judge`, the ceiling recorded at `open-round`, `escalate` on its own, `## Verification` from `## Commands`, the `half` floor, the ABSENT row, a report under PAUSE discarded.

## Requirements
> Стори, implementation notes, отчёты воркеров — скрыты.

> Совет = приёмка + стадия 05; lead-review остаётся

> Все трое имеют Bash/Read/Grep и идут по строке Client path.

> `lead-review.md` gains the one rule: the report's first line is `VERDICT: PASS` or `VERDICT: BLOCK`

> a seat working in the court must not be able to recover the spec's stories, plan or journal from the repository the court is attached to, or the guarantee must be restated as the honour clause it currently is.

> either the court must actually be unwritable by a seat, or the word "read-only" must leave D5 and the three prompts, with the concurrent-sharing consequence stated.

> the court is a shared, writable worktree whose working tree holds `brief.md` only, whose git history is out of bounds (`git log`, `git show`, `git diff` against any commit, and the deleted-file lines of `git status` are a BREACH), and whose writes are discarded by `judge` — an honour clause with a detector, not a guarantee; the sonnet seat's suite run may leave files the other two see

> a seat report produced before the pause must survive it, or D6 and `/vulyk-pause`'s wording must say the report is lost.

> the docs must say the seat is re-dispatched.

> either seat files reach git when they are recorded, or D1 stops listing them as committed.

> D1's table says seat files are committed by `judge --commit` (and by the STALE fold), not at record time

> ADR-001 D1, D2, D4, D5, D6 are amended to match by story 24; its status stays proposed.

## Files
- .claude/agents/council-haiku.md
- .claude/agents/council-sonnet.md
- .claude/agents/council-opus.md
- .claude/agents/lead-review.md
- docs/adr/001-cycle-state-contract.md
- docs/command-reference.md
- CLAUDE.md

## Non-goals
- Do not change any seat's frontmatter (`tools`, `disallowedTools`, `model`, `maxTurns` — C10) or add verdict, ceiling or round logic to a prompt.
- Do not rewrite `lead-review.md` beyond the first-line rule; its review of stories, Law 3 and the main-tree rule stay.
- `CLAUDE.md`: touch only the sentence in `## The cycle` that says the seats judge "from a court that cannot see the hive's stories"; marker lines byte-identical (`grep -c 'VULYK:\(PROFILE\|COMMANDS\):\(START\|END\)' CLAUDE.md` = 4).
- Do not touch `docs/cycle.md`, `docs/pipeline.md` (lead-review minor 27 is next circle), `CHANGELOG.md` (story 25) or the command files (story 23).
- Do not flip the ADR's status or rewrite its Options/Context; amend the five decisions and mark the amendment.

## Map slice
`.claude/agents/council-haiku.md:13`, `council-sonnet.md:13`, `council-opus.md:13` (the "read-only git worktree" sentence and the `BREACH:` rule) · `.claude/agents/lead-review.md` (report shape) · `docs/adr/001-cycle-state-contract.md` D1 table (seat-file row), D2 verb table (`open-round`, `escalate`, `close-story`, `record-seat` taint clause, exit-code line), D4 table, D5, D6 first sentence · `docs/command-reference.md:18` · `CLAUDE.md` `## The cycle` paragraph (story 18's wording) · `plan.md` delta 6: R3, R15, R19, R26 and the contract-amendments line.

## Acceptance criteria
- [ ] Each seat prompt: "read-only" is gone; the court paragraph says shared, writable, working tree holds `brief.md` only, writes are forbidden and discarded by `judge`, the sonnet seat's suite run may leave files; the history rule lists `git log`, `git show`, `git diff` against any commit and the deleted-file lines of `git status` as out of bounds and names them under `BREACH:`; the seat is told it receives the court path and the round number, never a round directory.
- [ ] `lead-review.md`: the report's first line is `VERDICT: PASS` or `VERDICT: BLOCK`, stated once, with the reason (`record-seat … review` reads it); nothing else in the file changes.
- [ ] ADR-001: a dated line under `## Decision` ("Amended 2026-09-13, plan delta 6 of `docs/specs/autonomous-cycle`"); D1 seat-file row `Committed: at judge --commit`; D2 `open-round` row records the ESCALATE row, `**Council:**` line and `## Needs a human` at the ceiling before exiting 6, `escalate` row is a standalone verb with `--reason`, `close-story` precondition names the `## Commands` rule, `record-seat`'s taint clause is the path-anchored one, the exit-code line says 4 is MALFORMED / red verification and a RED verdict exits 0; D4 table: `half` row reads `|RED_e| >= max(2, ceil(A / 2))`, a new row after `REJECTED` for a required seat ABSENT with nothing RED → ESCALATE `env`; D5 restated per R15; D6's first sentence says an in-flight seat's report is discarded and the seat re-dispatched on resume.
- [ ] `docs/command-reference.md:18` says the same about pause.
- [ ] `CLAUDE.md` `## The cycle`: the blindness sentence reads as an honour clause with a detector (working tree holds only the brief; history out of bounds; `record-seat` taints); marker count still 4.
- [ ] `grep -rn 'read-only' .claude/agents/council-*.md docs/adr/001-cycle-state-contract.md` returns nothing about the court.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- Seat prompts (council-haiku/sonnet/opus): rewrote the COURT paragraph to drop "read-only", state shared/writable, working-tree-only-brief.md, writes forbidden+discarded by `judge`, sonnet's suite run may leave files, and a new history-BREACH sentence (`git log`/`git show`/`git diff` against any commit, deleted-file lines of `git status`). Added "receives COURT and the round number, never a round directory" up front. Also dropped "read-only" from each frontmatter `description:` line (not covered by the C10 frontmatter freeze, which is scoped to `tools`/`disallowedTools`/`model`/`maxTurns`).
- `lead-review.md`: appended one sentence to the existing Verdict-format line - report's first line is exactly `VERDICT: PASS`/`VERDICT: BLOCK`, read by `record-seat … review`. Nothing else in the file touched.
- ADR-001: added a dated `*Amended 2026-09-13…*` line plus an `### Amendments (2026-09-13)` subsection right under `## Decision`, summarizing all five decision changes with R-numbers, per the team's "mark the amendment, don't rewrite history" instruction; Options/Context and Status (`proposed`) untouched.
- ADR D1: seat-file row `Committed` column changed from `yes` to `at judge --commit (or the STALE fold)` (R26).
- ADR D2: `open-round` effect now names writing the ESCALATE row/`**Council:**`/`## Needs a human` idempotently before exit 6 (R5); `escalate` is now a standalone verb signature `[--reason <ceiling|half|env>] ["<note>"]` with precondition "seats missing, court removed" (R5); `close-story` precondition gained the byte-for-byte `## Commands` match rule (R11); `record-seat` taint clause rewritten path-anchored (`docs/specs/<slug>/plan.md` etc., story-id word-bounded) instead of bare-word (R9); exit-code line clarifies 4 is `record-seat` MALFORMED/`close-story` red-verification only and a RED `judge` verdict exits 0 (R24).
- ADR D4: `half` row formula changed to `|RED_e| >= max(2, ceil(A / 2))` (R10); replaced the old fixed "all three seats ABSENT" row with the general "any required seat (C15) ABSENT, nothing RED, review != BLOCK → ESCALATE env" row in the same table position (R16) - judged this a row update, not an addition, since required seats now vary by tier and the old wording was the narrower special case.
- ADR D5: retitled "The court - an honour clause with a detector" and fully restated per R15 - shared/writable, working tree holds only `brief.md`, git-history-out-of-bounds list, writes discarded by `judge`, sonnet's suite leftovers noted, plus the new reduction-commit detail from story 21 (`open-round` commits the brief.md-only reduction inside the court so `git status`/`HEAD:plan.md` read clean). Avoided the literal word "read-only" entirely (including negated forms) so the acceptance grep stays clean.
- ADR D6: first sentence of "Human intervention" now says an in-flight seat's report is discarded on pause and the seat is re-dispatched on resume, not recorded (R19).
- `docs/command-reference.md:18` (`/vulyk-pause`): same discarded/re-dispatched wording, replacing "its result is recorded once resumed" (R19).
- `CLAUDE.md` `## The cycle`: rewrote only the "Every seat still judges…" sentence to the honour-clause/detector phrasing (working tree holds only the brief, history out of bounds, `record-seat` taints); left the rest of the paragraph, the routing matrix, and all four `VULYK:PROFILE`/`VULYK:COMMANDS` marker lines untouched (grep count still 4).
- CONCERN carried to lead-review, not fixed (out of the five named decisions): ADR `## Consequences` still says "Blindness has a mechanism and a detector instead of an honour clause" (line ~293), which now reads backwards against the restated D5 - left alone since Non-goals scoped this story to D1/D2/D4/D5/D6 only.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
