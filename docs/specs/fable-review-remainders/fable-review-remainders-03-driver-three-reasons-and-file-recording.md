---
story: fable-review-remainders-03
spec: fable-review-remainders
status: done
returned: DONE
tier: 3
worker: worker-code
tracer: false
wave: 1
blocked_by: []
model: opus
---

# The Workflow driver names three failure reasons and records seats by file

## Goal
`.claude/workflows/vulyk-cycle.js` tells a thrown dispatch, an empty return (turn cap suspected, with the agent and its `maxTurns` from a static `CAPS` map) and text-without-a-report apart, for workers, the three seats and the reviewer, in `lastError`, the build stop and the log. Every seat and single-reviewer dispatch prompt ends with the report path under `.vulyk/reports/`; recording tries `record-seat --file <path>` in one clerk line and falls back to today's heredoc when the clerk answers exit 2 `file:`. Code only; story 06 writes the scenarios.

## Requirements
> Драйвер различает три причины провала диспатча - исключение (`worker threw`), пустой ответ (подозрение на кэп ходов, с именем агента и его maxTurns), текст без отчёта - для воркеров, сидов совета и ревьюера; tests/driver.test.sh это проверяет.
> драйвер даёт сиду путь под `.vulyk/reports/<slug>/round-N/<seat>.attempt-K.md` (вне docs/specs, чтобы не задеть taint-правило), сид сохраняет туда отчёт последним действием, клерк вызывает `record-seat --file <путь>` одной короткой строкой. Если файла нет, драйвер откатывается на сегодняшний heredoc.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh

## Non-goals
- No new scenario in `tests/driver.test.sh`; it is in `## Files` only for the minimal fixture edit if the extra `--file` clerk call or the changed prompt text reddens an existing assertion (keep the assertion's intent, adjust the stub sequence). A red not caused by your diff is a WALL.
- Do not change the two-miss rule, the retry prompt, K2's stop shapes, `foldReviews`, the `Stop/Paused/BadLine` classes, or how an empty seat return is recorded (it still goes to `record-seat`; the exit 4 attempt files are how `ABSENT` is counted). The clerk's own empty return stays `BadLine`.
- Do not give the Tier 4 folded review a path; it records through the heredoc as today.
- Do not read agent files from the driver (no shell); `CAPS` is the only source of the number.
- Do not edit `.gitignore` (`.vulyk/` is already ignored) or any agent/command file (story 04).
- Write `returned: DONE` as your last edit; never write `status:`.

## Map slice
`plan.md` C1, C2, C3 (exact strings, path shape, the `file:` match, the `CAPS` literal and its comment) · `recon/driver-and-cycle.md` §"Driver" (`parallel` catch `:145-152`, classification `:159-171`, `dispatchSeat :93-102`, `recordSeat :183-187`, exit 4 retry `:196-198`) · `memory/map/cycle.md` §"Drivers" · `docs/specs/v0-12-0-remainders/plan.md` K2, K4.

## Acceptance criteria
- [ ] A rejected worker `agent()` yields `lastError` = `worker threw: <message>` and a `log()` line of the same text; a `null`/`''`/whitespace resolve yields `worker returned empty - turn cap suspected (<agent>, maxTurns <N> in .claude/agents/<agent>.md)` with `<N>` from `CAPS` (`maxTurns unknown` when absent); a non-empty non-report yields `worker returned no report`. After two misses `stop.error` is the second miss's own string.
- [ ] The same three classes for a seat log `seat <seat> threw: ...` / `seat <seat> returned empty - turn cap suspected (...)` / `seat <seat> returned no report`, and for the single reviewer `reviewer threw/returned empty/returned no report`; the recording flow after the log is unchanged.
- [ ] `CAPS` is a top-level `const` with the eight entries of C3 and the one-line "update both together" comment.
- [ ] Each seat dispatch and each Tier 1-3 review dispatch prompt ends with `As your last action, write your full report verbatim to <path> (mkdir -p its directory); your chat reply is the same text.` where `<path>` is `.vulyk/reports/<slug>/round-<N>/<seat>.attempt-<K>.md`; the Tier 4 review prompts carry no such sentence.
- [ ] Recording: first clerk call is `bash scripts/cycle.sh record-seat <spec> <N> <seat> --model <id> --stamp <stamp> --file <path>` (no heredoc); on `exit:2` with `error` matching `/^file: /` the driver makes today's heredoc call with the chat reply; any other outcome is handled exactly as today (exit 4 re-ask once, `ok:false` ends the run).
- [ ] `bash tests/driver.test.sh` exits 0 on the branch; every pre-existing scenario unchanged except a stub-sequence fixture edit this diff forced, named in the notes.

## Verification
`bash tests/driver.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `.claude/workflows/vulyk-cycle.js`: `CAPS` + one `reasonFor(who, agentType, r)` shared by workers, seats and the reviewer (returns null when the value is a usable report); the worker thunk and both seat dispatches now `.catch` into `{ threw: msg }` so a rejection stays distinct from an empty resolve. The `worker threw:` log moved from the catch into the classifier so each miss logs exactly one line.
- Recording: `record(seat, report, attempt)` tries `record-seat ... --stamp <s> --file .vulyk/reports/<slug>/round-<N>/<seat>.attempt-<K>.md` first and falls back to today's heredoc only on `exit === 2 && /^file: /`; Tier 4's folded review skips the `--file` try entirely and carries no path sentence. `recordSeat`'s body is now `typeof report === 'string' ? report : ''` so a `{ threw }` never becomes "[object Object]".
- Decision: the first clerk call carries no `--model`, exactly as today - the driver knows no model id for a council seat (its frontmatter decides) and `cycle.sh` falls back to the report's own `MODEL` field. C2's `--model <id>` was read as `cycle.sh`'s optional synopsis slot, not a new value to invent.
- `tests/driver.test.sh`: three pre-existing assertions reddened by the new reason strings and were updated in place, intent kept - (f) `red+empty` now expects the empty-return reason (label and its `expect` line renamed), (g) whitespace-only expects the same reason (label unchanged, still asserts close-story is never called), (o) a thrown worker now expects `stop.error === 'worker threw: subagent died again'` and its stale comment was corrected. No scenario added, no stub sequence changed.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
