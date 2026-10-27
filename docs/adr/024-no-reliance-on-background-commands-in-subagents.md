# ADR-024: A subagent's protocol never relies on a background command finishing

- Status: accepted (2026-10-28, owner: Andrei, «принимаю»)
- Date: 2026-10-28
- Spec: docs/specs/fable-fallback (story 03, `## Descoped`)

## Context
The `fable-budget` study (F3) found a third of the judges' cache writes were full rewrites after `lead-review` waited
5-13 minutes on `tests/full-suite.sh`. Ask 2 of `fable-fallback` proposed starting the suite in the background and
reading the diff meanwhile. Story 03 probed it first (2026-10-27, Claude Code 2.1.312): a subagent that started
`sleep 45; date -u > probe-done` with `run_in_background: true` returned after 9.7 s (parent wall time 15.4 s) with
`probe-done` absent; the command finished about 54 s after the start, after the subagent and its parent session had
both ended. Nothing told the subagent or its parent that the command ended.

## Options
1. Background start, review the diff, one blocking wait on an exit-code file - needs a second probe (does a blocking
   wait hold inside a subagent) and risks a missing `SUITE:` line, which `record-seat` refuses.
2. The driver or the Queen runs the suite before dispatching the reviewer - the reviewer stops measuring the suite
   itself, and the change spans `vulyk-cycle.js` and `cycle.sh`.
3. Keep the foreground suite and cut the cache cost another way - the one-hour cache on `lead-review` (same spec,
   story 02) targets F3 directly.

## Decision
Option 3. The owner dropped ask 2 after the failed probe (2026-10-27, AskUserQuestion, option text by the Queen).
`lead-review` runs the full suite in the foreground, as before.

## Consequences
The reviewer still waits for the suite, so a round takes as long as before; the cache cost of that wait is carried by
`cacheTtl: 1h`, measured on 2026-11-03 against the week before. No `SUITE:` line can go missing through a background
command.

## Invariants created
No agent protocol may depend on a `run_in_background: true` command finishing, or on being told it finished, before
the agent returns: a subagent returns when its turn ends.

## Revisit when
A Claude Code release makes a subagent wait for its background commands, or delivers their completion to it; or the
2026-11-03 measurement shows the one-hour cache does not carry F3.
