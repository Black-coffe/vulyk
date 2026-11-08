---
story: ab-run-fixes-03
spec: ab-run-fixes
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: status: an unknown story status is an error
red_verified_at: 2026-11-08T21:24:44Z 61cd5ead0fd403a1dbb0f50da6d26916291a5556013ce964a17661ffd7abf29c
---

# cycle.sh: `verify_run` stdin, an unknown story status, a ready-line hint, one suite commit

## Goal
After this story:
- **stdin.** `verify_run` runs each verification line with stdin from `/dev/null`, at both call sites (capped and uncapped, `scripts/cycle.sh:2011,2018`). A line that reads stdin can no longer eat the next line. `stamp-red` shares the runner.
- **Unknown status.** A story whose `status:` is a value `cycle.sh` does not recognise (for example `open`) is now an error in `status` and every verb that derives it (plan C6). It used to be counted as todo and listed in no wave (`:591-596, 606`).
- **Ready-line hint.** `close-story`'s refusal of a segment that is not a `## Commands` cell suggests the ready line (C7).
- **One suite commit.** `suite --commit` commits `suite.log` once, on the call that finishes the suite (C8).

## Requirements
> 11. Прогон частей без отдельного коммита на каждую часть. Сами части остаются, по правилу «гейты дробить».
> 16. Строка проверки в `verify_run` не съедает ввод следующей строки.
> 17. Неизвестный статус истории (`open`) — ошибка в `status`, а не молчаливый пропуск.
> 19. Отказ `close-story` из-за строки проверки вне Commands подсказывает готовую строку.

## Files
- scripts/cycle.sh
- tests/cycle.test.sh
- tests/council.test.sh
- docs/adr/029-*.md

## Non-goals
- Do not merge suite steps or parts, raise a cap, or change the one-step-per-call clerk loop in `vulyk-cycle.js` (owner rule: split gates, never raise the limit; card `test-gate-one-long-limit`).
- Leave alone: the dirty-tree predicate of `claim` / `open-round` (story 05, then `mass-audit-fixes`), seats, carry and repair (story 04), and `wave-check.sh`.
- No new status value. No hint in `stamp-red` or `wave-check`.

## Map slice
memory/map/cycle.md (Verbs: `close-story` and the verify runner, `suite`; `status --json` `next`); memory/map/scripts.md (Key contracts, Gotchas: anchored matches, bash 3.2)

## Acceptance criteria
- [ ] `verify_run: a line that reads stdin leaves the next line its turn`: in a two-line block whose first line reads stdin, the second line also runs.
- [ ] `status: an unknown story status is an error`: a story with `status: open` makes `status` exit 2 naming the file and the value. It fails on HEAD and passes after. Known values behave as before.
- [ ] `close-story: a non-cell segment names a ready line`: given `bash tests/x.test.sh --part a --verbose` and a fixture cell `bash tests/x.test.sh --part <topic>`, the refusal keeps its exit code and prints `try: bash tests/x.test.sh --part <topic>`.
- [ ] `suite: a middle step makes no commit`: with `--commit`, step 1 of 2 leaves HEAD unchanged with `suite.log` written, and step 2 commits it.
- [ ] ADR-029 gets a dated amendment line about the commit. The parts touched stay under 70% of their cap.
- [ ] `## Implementation notes` ends with one `CHANGELOG:` line.

## Verification
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part gates`
`bash tests/council.test.sh --part suite`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- scripts/cycle.sh: `verify_run` gives both call sites `< /dev/null`; the redirect covers the whole `run_capped_as` call.
- scripts/cycle.sh: `story_status_guard` (todo, in-progress, done, blocked; an absent `status:` stays todo) runs in the dispatcher before status, judge, branch, record-seat, resume, manual-done, open-round, suite, reopen, repair, advance and close-story (the story's spec dir); exit 2 `unknown story status '<v>' in <file>`. claim, pause, release, escalate, briefed and stamp-red do not derive status and are left alone.
- scripts/cycle.sh: `verify_cell_hint` prints up to 3 `try: <cell>` lines (non-round-only cells, same first two words) or `try: see ## Commands in <file>`, on stderr after the refusal message, close-story only; the JSON error is unchanged.
- scripts/cycle.sh: `cmd_suite` commits `suite.log` only when `is_done`, subject `suite round N <ok|FAIL>`; the no-op, none and no-step-count commits are unchanged.
- tests/cycle.test.sh: C6 in part gates (status, repair, the four known values); stdin and C7 in part close (stray-08..10 and four fixture cells).
- tests/council.test.sh: the sxstep case now checks HEAD unchanged after step 1 and one commit after step 2.
- docs/adr/029-gate-split.md: dated amendment on the one suite commit.
- Part times on this box: cycle close 38 s, cycle gates 23 s, council suite 108 s (cap 300, 70% = 210).
- CHANGELOG: cycle.sh - verification lines read stdin from /dev/null, an unknown story status is an error (exit 2), close-story's non-cell refusal suggests a ready line, `suite --commit` commits suite.log once when the suite finishes.

## Findings

## Red receipt
- command: bash tests/cycle.test.sh --part gates
- exit: 1
- tests: 61cd5ead0fd403a1dbb0f50da6d26916291a5556013ce964a17661ffd7abf29c (tests/council.test.sh, tests/cycle.test.sh)
- impl: b72a8d7dc7481c7097f294fa2be9b8f4fd4b47db39e0a5d6108426a8e7aaa916
- stamped: 2026-11-08T21:24:44Z

```
::error::status: an unknown story status is an error - exit=0 out={"spec":"docs/specs/ustat","slug":"ustat","stage":"01-spec","next":"briefed","briefed":false,"approved":false,"branch":null,"head":"3732baf","pack":"1d269ecac1d3","stories":{"todo":2,"in-progress":0,"done":0,"blocked":0},"wave":1,"wave_stories":[{"file":"docs/specs/ustat/ustat-02-u.md","story":"ustat-02","worker":"worker-code","model":"","repeat":1}],"round":0,"ceiling":3,"tier":null,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}
  ok    a fragment of an item is not an item
one ## Asks parser (lib.sh brief_asks, read by cycle.sh and trace-check.sh): numbered lines when the block has any, else each > line's text
  ok    a numbered block reads as before: its > lines are not items
  ok    a block of > lines alone: each non-empty line's text, nothing past the next ## heading
  ok    briefed counts the quoted asks (it refused '## Asks missing or empty' before)
ab-run-fixes C6: status and every verb that derives it refuse a story status cycle.sh does not recognise
::error::status: an unknown story status is an error - exit=0 out={"spec":"docs/specs/ustat","slug":"ustat","stage":"01-spec","next":"briefed","briefed":false,"approved":false,"branch":null,"head":"3732baf","pack":"1d269ecac1d3","stories":{"todo":2,"in-progress":0,"done":0,"blocked":0},"wave":1,"wave_stories":[{"file":"docs/specs/ustat/ustat-02-u.md","story":"ustat-02","worker":"worker-code","model":"","repeat":1}],"round":0,"ceiling":3,"tier":null,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}
::error::repair on an unknown story status - exit=2 out=cycle: repair - ustat's status says next is 'briefed', not repair
{"ok":false,"verb":"repair","exit":2,"next":"error","error":"next is briefed, not repair"}
  ok    the known values todo, in-progress, done, blocked behave as before
```
