---
story: autonomous-cycle-27
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 11
blocked_by: []
---

# `emit` is always JSON, the review verdict is line 1, `status` names the review verdict

## Goal
The last stdout line of every verb parses whatever the hive's `## Commands` cells contain — `emit` escapes every value it interpolates. `record-seat … review` reads the verdict from the report's first line and nothing else, so a report that does not open with `VERDICT: PASS|BLOCK` is MALFORMED and leaves an attempt file — the property story 26's fold relies on. `status --json` carries `"review"`, the newest row's review verdict, so a driver can say why a round with `red:[]` is RED without reading the verdict table.

## Requirements
> Красный = хотя бы один BROKEN (ask из brief не работает, с доказательством: команда/вывод/URL) у любого из трёх или BLOCK от lead-review.

> Workflow-скрипт + fallback в сессию

> every value `emit` places in the JSON must be escaped so the last line is parsable whatever the hive's commands contain.

> the verdict must be read from the line the contract names, so a report that does not open with it is MALFORMED.

> C3 gains `"review"` — the newest row's `review` value verbatim (`PASS`, `BLOCK`, `ABSENT`, `""`), `null` when no row exists

> A repair step that lands nothing must end the run, and the Workflow's repair prompt must name the `lead-review` BLOCK when `red` is empty

## Files
- scripts/cycle.sh
- tests/council.test.sh

## Non-goals
- Do not change any verb's exit code, `next` value or precondition; this story changes how `emit` serialises, which line `record-seat … review` reads, and adds one `status` key.
- Do not add `error` to the four `ok:false` emits that lack one, unify exit 6, dedupe the seat scan or touch the ceiling/idempotency checks (lead-review r2 minors 1, 4-8; N-m1 — next circle); do not touch `lib.sh`, `journal.sh`, the driver, the commands or the docs.
- Do not loosen the blind seats' C5 parsing or the taint rule; the first-line rule is for seat `review` only.
- Do not validate `worker:` in `wave_story_json` (R29 bounds the loop instead).

## Map slice
`scripts/cycle.sh` — `emit` (the JSON writer every verb ends with), `review_verdict_of_text` and `cmd_record_seat_review` (stories 03/24), `cmd_status` (the key list beside `verdict`/`red`/`round_dir`, story 19) and the newest-row reader it already uses for `verdict` · `tests/council.test.sh` — the fixture `CLAUDE.md` `## Commands` table (story 21), the `cstory*` close-story scenarios, `envpartial2` (review ABSENT), `realverbs` (`status --json` assertions) · `plan.md` delta 7: R28 (N-m4 folded), R30, R33 · `## Contracts` C2, C3, C4, C5.

## Acceptance criteria
- [ ] `emit`: every value it interpolates (`error` and any other string field) is escaped — `\` → `\\`, `"` → `\"`, tab/newline → `\t`/`\n` — through one helper every emit path uses. Test: the fixture `## Commands` table gains the cells `sh -c "exit 1"` and `sh -c 'echo a\b; exit 1'`; a story whose `## Verification` is each of them in turn fails `close-story` with exit 4, and the last stdout line satisfies `jq -e .` with `jq -r .error` equal to the cell text byte for byte.
- [ ] `record-seat … review` (C5 amended): the verdict is read from line 1 of the report only — `^VERDICT: (PASS|BLOCK)\b` or `^(PASS|BLOCK)\b`; any other first line (prose, empty, `NO VERDICT: …`) is exit 4 with `error` `MALFORMED: review: first line is not VERDICT: PASS|BLOCK` and writes `review.attempt-<k>.md` as for any seat. Tests: `VERDICT: BLOCK` first → recorded BLOCK; `VERDICT: PASS` first with a body line `PASS/BLOCK decision: BLOCK` → PASS; a prose first line with `VERDICT: PASS` on line 3 → exit 4, `attempt-1.md` present; `NO VERDICT: top=(no report) · second=VERDICT: PASS` then `(no report)` then `VERDICT: PASS` → exit 4; a second rejection → `attempt-2.md`, `status` `missing` without `review`, `judge` → row `review:"ABSENT"`, `escalate:"env"` (the `envpartial2` shape).
- [ ] `status --json` gains `"review"`: the newest `council.jsonl` row's `review` value verbatim (`PASS`, `BLOCK`, `ABSENT`, `""`), `null` when the spec has no row; asserted in `realverbs` after a judged round with review BLOCK and every seat GREEN (`.review == "BLOCK"`, `.red == []`, `.next == "repair"`), after a GREEN round (`"PASS"`), and on a fresh spec (`null`); the rest of the C3 key set is unchanged.
- [ ] Both suites green, exit 0, no `::error::`; the four syntax gates pass.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/council.test.sh && bash tests/cycle.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
