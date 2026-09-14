---
story: fable-review-remainders-06
spec: fable-review-remainders
status: todo
returned:
tier: 3
worker: worker-test
tracer: false
wave: 2
blocked_by: [fable-review-remainders-03]
model: sonnet
---

# The driver suite proves the three reasons and the `--file` record path

## Goal
`tests/driver.test.sh` gains scenarios that execute the driver against stubs and assert story 03's behaviour: for a worker, a seat and the reviewer, a thrown dispatch, an empty return and a non-report each produce their C3 string in the log (and, for the worker, in `stop.error` after two misses); a seat prompt ends with the C2 path sentence; recording calls `record-seat --file` first and falls back to the heredoc only on exit 2 `file:`. Each new scenario is shown red against the driver at the commit before story 03.

## Requirements
> Драйвер различает три причины провала диспатча - исключение (`worker threw`), пустой ответ (подозрение на кэп ходов, с именем агента и его maxTurns), текст без отчёта - для воркеров, сидов совета и ревьюера; tests/driver.test.sh это проверяет.
> драйвер записывает по пути с откатом на heredoc, если файла нет

## Files
- tests/driver.test.sh

## Non-goals
- Do not edit `.claude/workflows/vulyk-cycle.js`. A red on the branch is a WALL: record it under `## Findings`, return `WALL`.
- Do not change the stub interface (K4 of the previous plan: `run(args, script)`, `script.clerk`, `script.agents`, `{throw:'msg'}`); extend `script.agents` entries only where the existing shape already allows `''`, `null`, `{throw}`.
- Do not test the seat's cwd or a real file: the stub clerk answers `{"ok":false,"exit":2,"error":"file: <path>"}` to simulate an absent file.
- Do not add a Tier 4 fold scenario (unchanged path).
- Write `returned: DONE` as your last edit; never write `status:`.

## Map slice
`plan.md` C2, C3 (exact strings and path shape) · `recon/driver-and-cycle.md` §"Driver" (`tests/driver.test.sh` harness `:39-41`, `run :100-146`, `withClaim :151-153`, scenario (g) `:265-280` as the template for an `''` return) · `docs/specs/v0-12-0-remainders/plan.md` K4 · story 03 `## Implementation notes`. The pre-story driver is `git show <sha>^:.claude/workflows/vulyk-cycle.js` where `<sha>` is `git log -1 --format=%h --grep='story(fable-review-remainders-03)'`.

## Acceptance criteria
- [ ] Worker scenarios: `{throw:'boom'}` twice -> `stop.error` = `worker threw: boom` and two log lines of that text; `''` twice -> `stop.error` = `worker returned empty - turn cap suspected (worker-code, maxTurns 90 in .claude/agents/worker-code.md)`; `'some prose'` twice -> `worker returned no report`. The mixed case (`''` then `'prose'`) stops with the second miss's string.
- [ ] Seat and reviewer scenarios: a seat `{throw}`, `''` and non-report each log `seat <seat> threw/returned empty/returned no report` with the C3 wording (the empty case names `council-<seat>` and `60`); the reviewer likewise with `reviewer` and `lead-review`; the run still proceeds to `record-seat` for each.
- [ ] Prompt scenario: the recorded seat dispatch prompt ends with the C2 sentence and `.vulyk/reports/<slug>/round-1/sonnet.attempt-1.md`; the attempt-2 re-ask names `attempt-2`.
- [ ] Record scenarios: good case -> exactly one `record-seat` clerk call, containing `--file .vulyk/reports/...` and no heredoc delimiter; stub exit 2 `file:` -> a second `record-seat` call with the `VULYK_<stamp>_` delimiter and the chat reply; stub exit 2 with another error -> the run ends `{verb:'record-seat', exit:2}` with one call.
- [ ] Each new scenario is run once against the pre-story driver (see map slice) and `## Implementation notes` records which printed `FAIL` there and `ok` on the branch - an `ok` pre-story is recorded with its reason, never forced.
- [ ] `bash tests/driver.test.sh` exits 0 on the branch; pre-existing scenarios unchanged.

## Verification
`bash tests/driver.test.sh`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
