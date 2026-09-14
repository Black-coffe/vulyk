---
story: fable-review-remainders-09
spec: fable-review-remainders
status: done
returned: DONE
tier: 3
worker: worker-code
tracer: false
wave: 4
blocked_by: [fable-review-remainders-04]
model: sonnet
---

# The fallback loop classifies a non-empty return without a report the way the Workflow driver does (round-1 major 2)

## Goal
`.claude/commands/vulyk-build.md`'s fallback loop applies the same bound as the Workflow driver after story 08 (R6: the two drivers share a bound). The `build:<wave>` row says that `close-story` runs on every non-empty worker return, that exit 4 with `error` `returned: missing` is reported as `worker returned no report`, and that any other exit 4 `error` is reported as that text - all under the existing two-miss rule; the sentence that reading `STATUS:` by eye is for the one-line log and never for the decision stays. The `dispatch:<seats>` row says that a `record-seat` exit 4 (on the `--file` try or the heredoc) for a non-empty seat or reviewer return is logged `seat <seat> returned no report` / `reviewer returned no report` before the one re-ask, and that the empty case is named before the call as today.

## Requirements
> Драйвер различает три причины провала диспатча - исключение (`worker threw`), пустой ответ (подозрение на кэп ходов, с именем агента и его maxTurns), текст без отчёта - для воркеров, сидов совета и ревьюера; tests/driver.test.sh это проверяет.
> Оба драйвера и три описания становятся правдой без правки.

## Files
- .claude/commands/vulyk-build.md

## Non-goals
- Do not touch `.claude/workflows/vulyk-cycle.js` or `tests/driver.test.sh` (story 08, same wave) or `.claude/commands/vulyk-review.md` (major 2 names only the build loop; the review command's seat recording already mirrors C2 and gains no new rule here).
- Do not restate the C3 strings differently from `plan.md` C3; copy them verbatim. Do not change the `--file` / heredoc fallback text, the `release` sentence, or any row other than `build:<wave>` and `dispatch:<seats>`.
- Do not tell the fallback loop to grep, read, or judge the return's text - the only inputs to the decision are `close-story` / `record-seat` exit codes and their `error` field.
- Write `returned: DONE` as your last edit; never write `status:`.

## Map slice
`plan.md` C3 as amended by the round-1 delta (`## Plan deltas`, second entry) · `council/round-1/review.md` major 2 · `docs/adr/006-worker-status-channel.md` §"The fallback driver under this decision" · story 04 `## Implementation notes` (which rows it rewrote and where the C3 strings sit) · story 08 (the Workflow side this row must match).

## Acceptance criteria
- [ ] `build:<wave>` row: for every non-empty worker return `close-story` runs; exit 4 with `error` `returned: missing` is `worker returned no report`; exit 4 with any other `error` is reported with that `error` text; a throw and an empty return keep the story-04 wording and skip `close-story`. All four are misses under the same two-attempt rule and the second miss blocks the story with the reason as its text.
- [ ] `dispatch:<seats>` row: a `record-seat` exit 4 on a non-empty return is logged with the C3 string for that seat or the reviewer before the single re-ask; an empty return is logged with the empty-case string before the call and gets no second line.
- [ ] The sentence that `STATUS:` is read by eye only for the one-line log, never for the decision, is still present and true.
- [ ] `git diff --stat` shows only `.claude/commands/vulyk-build.md`; the diff touches only the two rows.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- `.claude/commands/vulyk-build.md`: `build:<wave>` row now derives a single "reason" from `close-story` exit 4 (`returned: missing` -> `worker returned no report`; any other `error` -> that text verbatim) and reuses "the reason" through the first/second-miss sentences instead of restating the classification twice.
- `dispatch:<seats>` row: added the empty-return log line (`seat <seat> returned empty - ...` / `reviewer returned empty - ...`) before `record-seat` is called, and a `seat <seat> returned no report` / `reviewer returned no report` log line before the single re-ask on a non-empty `record-seat` exit 4 - matching C3's amended third class.
- Diff confined to the two named rows; `git diff --stat` on this file shows only those two paragraphs changed. Unrelated working-tree changes to `vulyk-cycle.js`/`plan.md`/`tests/driver.test.sh` were already present before this story started (story 08 running concurrently) and were not touched.

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
