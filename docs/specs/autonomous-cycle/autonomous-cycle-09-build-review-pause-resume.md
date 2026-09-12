---
story: autonomous-cycle-09
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 3
blocked_by: [autonomous-cycle-03]
---

# `/vulyk-build`, `/vulyk-review`, `/vulyk-pause`, `/vulyk-resume`: the driver from the session side

## Goal
`/vulyk-build` detects the driver mode and either launches the Workflow or runs the same `status -> act` loop in the session with its own Bash and Agent tool; `/vulyk-review` is one round on demand with no stage-05 stop; `/vulyk-pause` and `/vulyk-resume` are thin wrappers over `cycle.sh` that tell the human what the loop holds and how to get the tree back.

## Requirements
> Где Workflow недоступен — сегодняшняя петля в сессии, но через те же скрипты.

> Королева просыпается дважды: итоговый отчёт (мерж) или эскалация.

> Королева печатает ту же строку в терминал каждый раз, когда у неё есть ход.

> У человека в терминале должно идти логирование. Логирование должно быть понятным. Не так, что система ушла, и мы вообще не понимаем, что происходит.

> Оба параллельно, как сейчас.

> Все «Принять» из таблицы входят в бриф: скрипт судит раунды, worktree-слепота, ## Asks, PAUSE, Briefed:, N/A, пороги.

## Files
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- .claude/commands/vulyk-pause.md
- .claude/commands/vulyk-resume.md

## Non-goals
- Do not write the JS driver (story 06) or `/vulyk-plan` (story 08); do not duplicate the grill.
- Do not let the session loop compute a verdict, count rounds, or decide staleness - every branch is `case "$next"` on `cycle.sh status --json`; if the Queen finds herself reading a seat report to decide anything, that is the defect.
- Do not keep the `drone-acceptance` dispatch, the `acceptance-log.sh` call, the check card, or the "wait for the owner" step in `/vulyk-review`.
- Do not add a `resumeFromRunId` path anywhere.
- Do not touch `lead-review.md` or its dispatch shape beyond passing its report to `record-seat … review`.

## Map slice
`docs/specs/autonomous-cycle/plan.md` `## Contracts` C2, C3 (`next` vocabulary), C9, C11 (Workflow launch args), C12 and `## Assumptions` (mode detection rule) · `docs/adr/001-cycle-state-contract.md` D2 "The fallback driver" and "Resume is the disk" paragraphs, D6 · `docs/specs/autonomous-cycle/recon/scout-commands.md` §Answer 1 rows `vulyk-build.md` (step 1 refuses without Approved - now Briefed or Approved via `cycle.sh branch`), `vulyk-review.md` (steps 3-4, 6-7 are the acceptance/human machinery to replace) and §Answer 3 (`lead-review` report shape).

## Acceptance criteria
- [ ] `vulyk-build.md` step 1: mode detection - if the `Workflow` tool is in the session's tool list, `Workflow` `vulyk-cycle` with `args {spec, top_model (from the session brief), stamp (from `date -u`)}`; else the fallback loop; print which, plus the line "the loop holds the working tree of `vulyk/<slug>`; to edit, run `/vulyk-pause <slug>`" (also journaled).
- [ ] Fallback loop, step 2: `bash scripts/cycle.sh status docs/specs/<slug> --json`, then exactly one action per `next` (C3) with the same agents and the same `cycle.sh` verbs the Workflow uses, every verb with `--commit`; stops on `green` (prints the final report: rounds, the newest `**Council:**` line, `## Next circle` items) or `escalated` (prints `## Needs a human` verbatim) or `paused`; `repair` dispatches `queen-planner` with the top model for fix stories, then loops.
- [ ] Every state change prints the `journal.sh` stdout line and nothing else on the terminal between changes.
- [ ] Wake-up after a Workflow run: read `journal.md` tail and the newest round's seat files - never the transcript - and print the same final report / escalation.
- [ ] `vulyk-review.md`: precondition all stories done on the branch; `open-round --commit`; dispatch `lead-review` (top model, main tree) in parallel with the three seats (court path from status); `record-seat` each (re-ask once on exit 4 with the `error` named); `judge --commit`; print the verdict line; on `repair` say "fix stories go through `/vulyk-build`"; no stage-05 stop, no check card. Tier 4's second reviewer stays as a second `record-seat … review`-shaped dispatch whose `BLOCK` is folded into the same round (say how: the stricter of the two).
- [ ] `vulyk-pause.md`: `bash scripts/cycle.sh pause docs/specs/<slug> "<why>"`; prints what a running Workflow does with it (finishes the current agent, stops at the next clerk call) and that the tree is now the human's.
- [ ] `vulyk-resume.md`: `bash scripts/cycle.sh resume docs/specs/<slug>`; if `stale: true`, says a new round will open; then the same launch as `/vulyk-build` step 1 - a fresh run, never `resumeFromRunId`.
- [ ] Both new commands have `description:` and `argument-hint:` frontmatter in the house style of the existing commands.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
