---
story: gate-split-05
spec: gate-split
status: todo
returned:
tier: 3
worker: worker-code
wave: 3
blocked_by: [gate-split-03, gate-split-04]
red: required
red_reason:
---

# The driver, the clerk, the reviewer and the Queen's commands run the gate before the seats

## Goal
Every path that opens a round's seats first runs the stepped gate: the Workflow driver's `council(st)` calls
`suite <spec> --commit --stamp <S>` through the clerk until `done:true`, then dispatches; `/vulyk-build` (solo and
no-Workflow paths) and `/vulyk-review` do the same in the main session, one Bash call per step. `cycle-clerk` accepts the
`suite` verb. `lead-review` stops running the whole suite: it reads `council/round-N/suite.log`, copies its SUITE line,
and may rerun single parts to look at a FAIL. The escalation texts stop naming `VULYK_SUITE_TIMEOUT`.
`tests/driver.test.sh` without node prints `SKIP: node not found` and exits 77.

## Requirements
> 2. Тесты идут один раз за раунд, по шагам, до запуска проверяющих; проверяющие читают лог и могут перезапустить часть.
> 8. Тест без нужного инструмента показывается как SKIP, а в CI SKIP считается ошибкой.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh
- tests/e2e.test.sh
- .claude/agents/cycle-clerk.md
- .claude/agents/lead-review.md
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md

## Non-goals
- Do not change `scripts/cycle.sh` (the verb is `gate-split-04`); a contract gap is `NEEDS_CONTEXT`.
- Do not give the driver a clock or a shell of its own (`vulyk-cycle.js` 19-20): every step goes through the clerk.
- `tests/e2e.test.sh` is here only if its driver run needs the `suite` step (recon question 3); its parts and SKIP are
  done (`gate-split-03`).

## Map slice
memory/map/cycle.md `## The Workflow driver`, `## advance`; memory/map/agents-and-commands.md `lead-review`,
`cycle-clerk`, `/vulyk-build`, `/vulyk-review`; plan.md `## Contracts` (Driver, `cycle.sh suite`, SUITE from the log);
scout report C:/Users/Andrei/AppData/Local/Temp/claude/E--Projects-vulyk/aeafb186-f7ba-4c02-b8a1-680b8386863e/scratchpad/gs/scout-round.md.

## Acceptance criteria
- [ ] `council(st)` (vulyk-cycle.js 191-227) loops `ask("suite <spec> --commit --stamp <S>")` until `done:true`, at
      most 32 calls, before any seat dispatch; `ok:false` or a BadLine stops the run as other refused verbs do;
      a resumed run with a finished log goes straight to the seats (one no-op call).
- [ ] `tests/driver.test.sh` asserts the order (suite calls before the first seat dispatch), the bound, and the stop
      on `ok:false`; with no `node` it exits 77 with `SKIP: node not found`.
- [ ] `cycle-clerk.md` lists `suite` among the verbs it runs; its 600000 ms Bash timeout stays (a step < 590 s).
- [ ] `lead-review.md` (55-60, 88, 100): no whole-suite run; line 3 is the log's SUITE line; it may rerun a single
      part (`bash tests/<suite>.test.sh --part <topic>` or one hive row) in the foreground under `run_capped 300`
      (ADR-024) and reports what it saw; a FAIL in the log stays a `[regression]` Critical.
- [ ] `vulyk-build.md` (dispatch 81-98, escalated text 122-123) and `vulyk-review.md` (9-16, 38): before dispatching
      seats, `bash scripts/cycle.sh suite docs/specs/<slug> --commit [--stamp S]` until `done:true`, one Bash call
      each (timeout 600000); no `VULYK_SUITE_TIMEOUT` advice anywhere.
- [ ] `bash scripts/prompt-check.sh --touched` over these files has no `error` line (close-story runs it).

## Verification
`bash tests/driver.test.sh`
`bash tests/e2e.test.sh`

## Implementation notes

## Findings
