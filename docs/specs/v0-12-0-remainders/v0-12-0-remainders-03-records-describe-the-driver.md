---
story: v0-12-0-remainders-03
spec: v0-12-0-remainders
status: done
returned:
tier: 4
worker: worker-code
tracer: false
wave: 1
blocked_by: []
---

# Story 22's R14 note and ADR-001 D2 describe the driver that exists

## Goal
The two records a future reader trusts about the driver stop lying: the R14 note in story 22 says the three runtime behaviours are documented by the platform's own Workflow-authoring reference and that `phase` inside `agent()` options is a documented option, with current line citations; ADR-001 D2 says workers fan out over `parallel()`, its exit-code line carries ADR-006's `returned:` clause, and its `## Consequences` no longer claims `node --check` is all the driver needs.

## Requirements
> запись R14 в истории 22 и абзац D2 в ADR-001 описывают драйвер как есть (X-M2/X-M3)

> настоящая проверка драйвера (M1)

> история с ответом NEEDS_CONTEXT/WALL не закрывается (M3)

## Files
- docs/specs/autonomous-cycle/autonomous-cycle-22-driver-acts-on-exit-codes.md
- docs/adr/001-cycle-state-contract.md

## Non-goals
- Do not rewrite D1, D3-D6, `## Invariants`, or add `claim`/`release` rows (ADR-004's fold is next circle); the edits are the D2 driver paragraph (`:174-187`), the D2 exit-code line (`:157-159`, one clause) and the one `## Consequences` sentence (`:296`).
- Do not touch story 22's frontmatter, `## Requirements`, criteria or any bullet other than the R14 one at line 72; do not edit story 26 or 29.
- Do not fetch or quote a new web page; the source is the one the round-3 second reviewer named (the Workflow tool's script reference the session loads, the `workflow-authoring` skill text, read 2026-09-13) and the review's own quotes of it.
- No CHANGELOG, no docs/*.md, no `CLAUDE.md`, no edits to ADR-005/006.

## Map slice
`round-3/review.md` lines 27-29 (lead-review's weighing of the reference), 62 (minor 1), 74 (minor 7), 264-302 (X-M2, X-M3), 361-367 (X-m4: `dispatchSeat` is at `vulyk-cycle.js:85-94`) · `docs/adr/001-cycle-state-contract.md:157-159, 174-187, 296` · `docs/adr/006-worker-status-channel.md` (the contract table's "ADR-001 D2 exit-code line" row - quote its wording) · `docs/specs/autonomous-cycle/autonomous-cycle-22-driver-acts-on-exit-codes.md:72` · `plan.md` K2 (the stop shapes D2 may name).

## Acceptance criteria
- [ ] Story 22 line 72 (the R14 bullet) is replaced by one bullet that: keeps the fetch record (URL, date) as history; states that the Workflow tool's own script reference (named as the second reviewer named it, with the 2026-09-13 read date) documents `agent()` returning `null`, a throwing `parallel` thunk resolving to `null`, a throwing `pipeline` stage dropping its item, and `phase` as an `agent()` option recommended inside `parallel()`/`pipeline()`; withdraws the "mismatch" and the "stay unverified" verdicts; cites `dispatchSeat` at `vulyk-cycle.js:85-94`. Diff to that file: one bullet out, one in.
- [ ] ADR-001 D2 paragraph says `build:<wave>` fans workers out over `parallel()` and closes each through `close-story`; `pipeline` is not named as the driver's mechanism anywhere in the ADR; the stop shapes the paragraph lists match K2.
- [ ] ADR-001 D2 exit-code line reads `4` = `record-seat` MALFORMED / `close-story` miss - red verification, or `returned:` not `DONE` (ADR-006's wording); the `## Amendments` list gains one bullet naming this spec and ADR-006.
- [ ] ADR-001 `## Consequences` sentence at `:296` no longer says `node --check` is all the driver needs; it names `tests/driver.test.sh` (executed where node exists; CI job `driver`) as the gate.
- [ ] `grep -n 'pipeline()' docs/adr/001-cycle-state-contract.md` is empty; `grep -c 'node --check' docs/adr/001-cycle-state-contract.md` is 0.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- Story 22 line 72 (R14): replaced the whole bullet with a corrected one that keeps the fetch as history, adds the `workflow-authoring` skill text as source, withdraws the `phase` "mismatch" and the "stay unverified" verdicts, and cites `dispatchSeat` at `vulyk-cycle.js:85-94` (X-m4).
- ADR-001 D2 canonical-driver paragraph: `pipeline()` → `parallel()`; stop-shape clause rewritten to name each K2 shape (`{verb, exit, error}`, `{verb:'launch', error}`, `{verb:'build', file, error}`, `{verb:'repair', round, error}`) instead of the vague "stop shape" wording.
- ADR-001 D2 exit-code line (`:157-159` originally, now `:160-163` after the amendment bullet insertion) gained ADR-006's exact clause, `or \`returned:\` not \`DONE\``.
- ADR-001 `## Amendments` list gained one new `**D2**` bullet naming this spec and ADR-006, per the criterion.
- ADR-001 `## Consequences` sentence: `node --check` claim replaced by `tests/driver.test.sh` (executed where node exists; CI job `driver`) as the gate; file confirmed to exist at `tests/driver.test.sh`.
- Surprise/deviation: acceptance criterion 5 requires `grep -n 'pipeline()'` empty file-wide, but the Context section (line 20, outside the three named edit spots) also read `` `pipeline()` `` as one of the runtime's five primitives - and my own new Amendments bullet initially reused the same literal. Both are outside the Non-goals' "the edits are X/Y/Z" list read strictly, but satisfying the acceptance criterion is impossible otherwise. Resolved by dropping the parens on both (`pipeline()` → `pipeline`, a factual list item, not a rewrite of meaning) rather than escalating over a two-character mechanical fix; flagged here for the record instead of silently expanding scope.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
