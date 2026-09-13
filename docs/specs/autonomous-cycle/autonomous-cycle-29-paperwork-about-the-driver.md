---
story: autonomous-cycle-29
spec: autonomous-cycle
status: done
tier: 4
worker: worker-code
tracer: false
wave: 11
blocked_by: []
---

# The paperwork about the driver tells the truth: D2's sketch goes, D1 lists every file, R14 gets a real record

## Goal
ADR-001 no longer shows a driver shape an in-force decision forbids: D2's code block is replaced by a pointer to the canonical `.claude/workflows/vulyk-cycle.js` and the four launch `args`; D1's table lists `council/REOPEN`, `council/CEILING` and `ROUND`'s `tier=` line with their writers; D2's `record-seat` precondition says "not stale by `round_is_stale`"; `## Consequences` stops contradicting D5. Story 22's R14 bullet is replaced by a record of a real fetch of the Workflow reference — URL, date, what the page says for every shape and runtime behaviour the driver depends on, what changed — or, if the page cannot be fetched, by the plain statement that the docs were not consulted and the shapes remain unverified.

## Requirements
> Workflow-скрипт + fallback в сессию

> /vulyk-plan: Fable грилит, планирует, пишет стори — и запускает один Workflow

> the illustrative driver in D2 must not show a shape an in-force decision forbids, or it must be removed rather than left as the canonical sketch.

> the story must record a real fetch (URL, date, what changed) or say plainly the docs were not consulted and the shapes remain unverified

> a verification note must point at a record that contains what it says was checked, or say the check did not happen.

> `## Consequences` must not say "Blindness has a mechanism and a detector instead of an honour clause" beside a D5 that now says the opposite.

> D1 must list `council/REOPEN` (one writer, `reopen`, committed) and `tier=` as `ROUND`'s sixth line, and D2's `record-seat` precondition must read "not stale by `round_is_stale`" rather than "`head` in `ROUND` == HEAD", which story 17 made false.

> every file and field the cycle now writes must appear in D1's table with its writer.

## Files
- docs/adr/001-cycle-state-contract.md
- docs/specs/autonomous-cycle/autonomous-cycle-22-driver-acts-on-exit-codes.md

## Non-goals
- Do not rewrite D2 into a new sketch, and do not touch the driver, the commands or `cycle.sh`; if the fetched page contradicts a call the driver makes, record it under "what changed" and return a CONCERNS line — story 26's worker owns that file.
- Do not flip the ADR's status, rewrite Options/Context, or re-amend D4/D5/D6 (story 24 did); add to the existing `### Amendments (2026-09-13)` subsection.
- In story 22, touch only the R14 bullet under `## Implementation notes`; frontmatter, criteria and every other bullet stay byte-identical.
- No paraphrase of the page: quote what it says for each item, short, with the section name.

## Map slice
`docs/adr/001-cycle-state-contract.md` — D1 file table (the `ROUND` and seat-file rows; where `REOPEN`/`CEILING` belong), D2 verb table (`record-seat` precondition cell), D2 "The Workflow driver" code block and `## Resume`, `## Consequences` (the blindness sentence), `### Amendments (2026-09-13)` · story 22 `## Implementation notes`, the R14 bullet · `brief.md` `## Evidence` line 3 (what it does and does not contain) · `plan.md` delta 7: R34, R35 · `council/round-2/review.md` LR M2, N-M5, N-m8, LR minors 12 and 13, N-m6.

## Acceptance criteria
- [ ] ADR D2: the code block containing `record-seat … <<'EOF'` is removed; one paragraph in its place says the canonical driver is `.claude/workflows/vulyk-cycle.js`, launched with `args: { spec, top_model, second_model, stamp }` (`stamp` a per-run random value from the launcher), the `review` seat is `lead-review` (two at Tier 4, folded by the driver, no verdict from a blank), and every clerk result is acted on per the exit-code line; `## Resume` names the same four `args`; `grep -n "<<'EOF'\|schema: LAST_LINE\|council-\${seat}" docs/adr/001-cycle-state-contract.md` is empty.
- [ ] ADR D1: rows for `docs/specs/<slug>/council/REOPEN` (writer `reopen`, committed with `--commit`, read by `status`) and `docs/specs/<slug>/council/CEILING` (writer `reopen`, read by `open-round`); the `ROUND` row lists six lines ending `tier=`; D2's `record-seat` precondition reads "not stale by `round_is_stale`"; `## Consequences` no longer contains "instead of an honour clause"; the `### Amendments (2026-09-13)` subsection gains one line naming plan delta 7 and R34.
- [ ] Story 22: the R14 bullet is replaced by one that opens `R14 (corrected 2026-09-13 by story 29):`, says the earlier bullet claimed a cross-check against `brief.md` `## Evidence` line 3, which carries no script API, then records: the URL `https://code.claude.com/docs/en/workflows`, the fetch date, and for each of `agent(prompt, { agentType, model, effort, phase })`, `parallel([thunks])`, `pipeline(items, …stages)`, `phase(title)`, `log()`, `meta` what the page says and whether the driver's call matches; the page's wording for `agent()` returning `null`, a throwing `parallel` thunk resolving to `null`, and a throwing `pipeline` stage dropping its item; and "what changed" (expected: no call shape; the three behaviours are handled by story 26).
- [ ] If the page cannot be fetched (tool absent, network refused, non-200): the bullet says the docs were not consulted in this round, the shapes remain unverified by VULYK, and the only check on record is the second reviewer's in `council/round-2/review.md` (N-m8); the worker returns a CONCERNS line naming the failure — never a fabricated fetch.
- [ ] The diff touches exactly the two files; the story-22 diff is one bullet.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- D2's code block removed, replaced by one paragraph naming the canonical `.claude/workflows/vulyk-cycle.js`, its four `args`, the Tier-4 `lead-review` fold, and "every clerk result acted on per the exit-code line"; `grep -n "<<'EOF'\|schema: LAST_LINE\|council-\${seat}"` is empty.
- D1: added `council/REOPEN` and `council/CEILING` rows (writer `reopen` for both) right after the `ROUND` row; `ROUND`'s row gained `tier=<1\|2\|3\|4>` as its sixth field (confirmed against `scripts/cycle.sh`'s `build_round`, which writes `head/pack/opened/court/ceiling/tier` in that order).
- D2 `record-seat` precondition cell: `head in ROUND == HEAD` -> `not stale by round_is_stale` (matches `scripts/cycle.sh`'s actual helper name).
- `## Resume`'s `args` tuple was missing `second_model`; added so it names the same four args as the new D2 paragraph.
- `## Consequences`: "Blindness has a mechanism and a detector instead of an honour clause" -> "Blindness is an honour clause with a detector, not a filesystem guarantee (D5)" - now agrees with D5 instead of contradicting it.
- `### Amendments (2026-09-13)` gained one new bullet (`**D1/D2**`) naming plan delta 7 and R34; the five existing amendment bullets are untouched.
- Story 22's R14 bullet replaced by a real fetch: WebFetch on `https://code.claude.com/docs/en/workflows` (2026-09-13), quoted per shape (agent/parallel/pipeline/phase/log/meta) and per the three runtime behaviours; only `agent()` returning `null` is confirmed by the page - the parallel-thunk-throws and pipeline-stage-throws behaviours R28/R29/R32 rest on are not addressed by this reference at all, and `dispatchSeat`'s `phase: 'Round'` key inside `agent()`'s options is not a documented `agent()` option (the page shows `phase()` only as a standalone call) - both gaps are named in the CONCERNS line below since story 26 owns `vulyk-cycle.js`, not this story.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
