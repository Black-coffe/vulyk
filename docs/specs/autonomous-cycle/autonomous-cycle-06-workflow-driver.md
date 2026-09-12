---
story: autonomous-cycle-06
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 3
blocked_by: [autonomous-cycle-03, autonomous-cycle-05]
---

# The Workflow driver: `.claude/workflows/vulyk-cycle.js`

## Goal
One script that loops over `cycle.sh status --json` through a Haiku clerk, performs the single action `next` names - dispatch a wave of workers, open a round, dispatch the missing seats, judge, cut repair stories - and returns when `next` is terminal. No verdict, ceiling or staleness logic; no prose parsing.

## Requirements
> Workflow-скрипт + fallback в сессию. /vulyk-plan: Fable грилит, планирует, пишет стори — и запускает один Workflow: волны воркеров → story-close (скрипт) → lead-review ∥ совет → фикс-стори → повтор, потолок 3. Королева просыпается дважды: итоговый отчёт (мерж) или эскалация.

> оркестратором у волыка, королем, королевой всегда должен быть фейбл последней модели. И он должен делать минимум.

> Оба параллельно, как сейчас.

## Files
- .claude/workflows/vulyk-cycle.js

## Non-goals
- Do not compute anything from seat reports, story files or git - the clerk's JSON is the only input; if a decision seems to need more, the `status` contract is missing a key: report it in `INTERFACES`, do not work around it.
- Do not use `resumeFromRunId`, a run-local round counter, retries on a clerk exit code, or any `Date`/filesystem/shell API (the runtime has none).
- Do not ask a human (no `AskUserQuestion` in a Workflow); `escalated` and `paused` are returns, not prompts.
- Do not write the fallback loop or command prose here - stories 08-10.
- Do not exceed ~120 lines; a driver that fits on one screen is the ADR's consequence, not a style preference.

## Map slice
`docs/specs/autonomous-cycle/plan.md` `## Contracts` C2 (last-line JSON), C3 (every key the loop switches on: `next`, `wave_stories`, `missing`, `court`, `round`, `round_dir`, `red`), C10 (agent names), C11 (meta, args, agent types, terminal states) · `docs/adr/001-cycle-state-contract.md` D2 "The Workflow driver" paragraph and its JS skeleton (follow its shape; fix the `review` seat to `agentType: 'lead-review'`), D6 (pause is observed at the next clerk call) · `docs/specs/autonomous-cycle/recon/scout-commands.md` §Answer 3 (worker return contract - the driver passes the story path and the map slice from the story's `## Map slice`, nothing else).

## Acceptance criteria
- [ ] `export const meta` per C11; `args.spec`, `args.top_model`, `args.stamp` read once; `stamp` is logged and never used for logic.
- [ ] `clerk(cmd)` dispatches `cycle-clerk` (`effort: 'low'`) with "Run exactly: `bash scripts/cycle.sh <cmd>` … return the last stdout line verbatim", parses that line as JSON, and returns the object; a non-JSON last line ends the run with the raw text in the return value (the Queen reads it at wake).
- [ ] Loop: `status <spec> --json`; on `green|escalated|paused|shipped` return the status object; `build:<wave>` -> `phase('Build')`, `parallel` over `wave_stories` dispatching the story's `worker:` agent with the story path and its `## Map slice`, then `close-story <file> --commit` per returned worker (a `close-story` exit 4 leaves the story for the next `status`, which reports it again - no in-script retry); `open-round` -> `phase('Round')`, `clerk('open-round … --commit')`; `dispatch:<seats>` -> `pipeline` over the listed seats: `council-<seat>` (or `lead-review` with `model: args.top_model` for `review`), prompt built only from `slug`, `round`, `court`, `round_dir`; result piped into `clerk("record-seat <spec> <round> <seat> <<'EOF' … EOF")`; `judge` -> `phase('Judge')`, `clerk('judge … --commit')`; `repair` -> `phase('Repair')`, one `queen-planner` dispatch (`model: args.top_model`) told the `red` ask numbers, `round_dir` and the story file convention, then loop.
- [ ] `briefed` and `branch` are also handled (`clerk` with `--commit`) so a run started right after the grill needs no Queen turn.
- [ ] `log()` once per state change with the journal-style line the clerk's `next` implies; no per-turn chatter.
- [ ] The file contains no string `GREEN`, `RED`, `ceiling`, `stale` or `paperwork` outside comments - grep-checkable evidence it holds no verdict logic.
- [ ] Where node exists, `node --check .claude/workflows/vulyk-cycle.js` passes - record the outcome in `## Implementation notes`; it is not a gate command in this repo.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
