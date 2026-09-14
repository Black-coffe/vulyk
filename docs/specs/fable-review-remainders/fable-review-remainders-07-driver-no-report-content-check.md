---
story: fable-review-remainders-07
spec: fable-review-remainders
status: done
returned: DONE
tier: 3
worker: worker-code
tracer: false
wave: 2
blocked_by: [fable-review-remainders-03]
model: opus
---

# The driver's third reason is real: a return without a report marker is `returned no report`

## Goal
`.claude/workflows/vulyk-cycle.js` classifies a non-empty dispatch return by content: a worker return with no line starting `STATUS:` is `worker returned no report` (a miss, like the other two reasons); a seat or reviewer return with no line starting `VERDICT:` logs `seat <seat> returned no report` / `reviewer returned no report` and still goes to `record-seat` unchanged. Today that string is reachable only for a non-string value (story 06's finding, plan delta 2026-09-14). The existing stub reports in `tests/driver.test.sh` gain a `STATUS: DONE` line so the pre-existing scenarios stay green - the minimal fixture edit, no new scenario.

## Requirements
> Драйвер различает три причины провала диспатча - исключение (`worker threw`), пустой ответ (подозрение на кэп ходов, с именем агента и его maxTurns), текст без отчёта - для воркеров, сидов совета и ревьюера; tests/driver.test.sh это проверяет.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh

## Non-goals
- No new scenarios in `tests/driver.test.sh` - story 06 (wave 3) writes them. Touch only the stub strings that the content check would turn into misses (`'a worker report'`, `'report 1'`, `'report 2'` and any seat/reviewer stub with no `VERDICT:` line): add the marker line, change nothing else about those scenarios.
- Do not change C3's other two strings, `CAPS`, the `{threw}` catch, K2's stop shape, or the `record-seat` flow (C2). A seat's non-report is a `log()` line only; `record-seat` and its MALFORMED handling decide the seat's fate.
- Do not read the story's `returned:` frontmatter or the disk to classify - the driver has no shell; the check is on the returned string alone.
- Do not apply `recon/06-attempt-2-kept.patch` - it is story 06's, and a scope-check on this story must see only your two files.
- Write `returned: DONE` as your last edit; never write `status:`.

## Map slice
`plan.md` C3 (amended 2026-09-14) and `## Plan deltas` (the 2026-09-14 entry) · `recon/driver-and-cycle.md` §"Driver" · story 03 `## Implementation notes` (where `reasonFor` lives, `:31` at `a67d7e3`) · `.claude/agents/worker-code.md:27` (`STATUS: DONE | NEEDS_CONTEXT | WALL`) · `docs/adr/001-cycle-state-contract.md` D3 (seat header carries `VERDICT`).

## Acceptance criteria
- [ ] `reasonFor('worker', <agent>, 'prose with no marker')` yields `worker returned no report`; the same string with a `STATUS: DONE` line anywhere yields no reason (`null`). Case-sensitive, line-anchored (`/^STATUS:/m`), so a `STATUS:` mentioned mid-sentence does not count.
- [ ] `reasonFor('seat sonnet', 'council-sonnet', 'text without a verdict')` yields `seat sonnet returned no report`; `reasonFor('reviewer', 'lead-review', ...)` likewise with `reviewer`; a return containing a line starting `VERDICT:` yields none. The seat/reviewer path only logs; the recording call count and arguments are unchanged.
- [ ] A worker return without `STATUS:` counts as a miss under the two-attempt rule: `lastError`, one `log()` line, and `stop.error` after the second miss - the same handling as `''`.
- [ ] `bash tests/driver.test.sh` exits 0 on the branch with the fixture edit; the diff to the test file touches only stub report strings (`git diff --stat` and `## Implementation notes` say which).
- [ ] `## Implementation notes` names the line where the marker check lives and the exact regexes.

## Verification
`bash tests/driver.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->
- The marker check lives in `.claude/workflows/vulyk-cycle.js`: `:30` defines `const MARKER = (who) => (who === 'worker' ? /^STATUS:/m : /^VERDICT:/m)`, and `:33` (the non-empty-string branch of `reasonFor`) returns `MARKER(who).test(r) ? null : ${who} returned no report`. Both regexes are line-anchored and case-sensitive.
- No new parameter: a seat's `who` is `seat <name>` and the reviewer's is `reviewer`, so "anything not `'worker'`" already selects `VERDICT:`.
- Ordering matters - the marker test sits inside the non-empty-string branch, before the empty/turn-cap branch, so a markerless non-empty string is `returned no report`, never `returned empty`. The `{threw}`, empty, `null` and non-string paths are unchanged, as is the whole `record-seat` flow (a seat's non-report only adds a `log()` line).
- `tests/driver.test.sh`: stub report strings only - 7 insertions / 7 deletions, no new scenario, no assertion touched. Six worker stubs (scenarios c, d, e, f, k and the retry-prompt one) gained a leading `STATUS: DONE\n`; the one seat stub (`record-seat exit 3`) gained `VERDICT: PASS\n`.
- Left alone deliberately: the Tier-4-guard scenario's `agents: ['report']` (that run refuses at launch and never classifies anything), the whitespace-only `'   '` pair, the `{throw: ...}` pair and the `null`s - those fixtures prove the other two reasons.
- Surprise: writing the fixtures through a shell heredoc turned the two-character `\n` into a real newline and broke the JS string literals; redone via a script file so the escape survives. `bash tests/driver.test.sh` exits 0 (59 ok lines, no FAIL).

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
