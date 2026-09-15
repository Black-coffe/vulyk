---
story: driver-hardening-04
spec: driver-hardening
status: todo
returned:
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 3
blocked_by: [driver-hardening-02, driver-hardening-03]
---

# The driver polls status only at start and after parallel steps (ask 5, driver side)

## Goal
The Workflow driver polls `status --json` six times in a steady Tier 3 round (before branch, build, open-round, dispatch, judge, green). After this story it holds one status object, reads every field from it, refreshes it from a sequential verb's embedded `status` (story 03, plan C5) when one is present, and polls only at loop start and after a step that ran zero or several verbs or whose single verb did not carry `status`. Steady round: 13 clerk calls, 3 polls (plan A5). No verdict or ordering logic enters the driver.

## Requirements
> Меняющие глаголы cycle.sh возвращают next в своём JSON, драйвер опрашивает статус только на старте.

## Files
- .claude/workflows/vulyk-cycle.js
- tests/driver.test.sh

## Non-goals
- Do not drop the poll after `build:<wave>` or `dispatch:<seats>` by choosing "the last returned" result - plan tradeoffs reject it (clerk latency reorders resolution vs completion).
- Do not read any field from a verb result other than `ok`, `exit`, `error`, `next`, `status` - and `status` only when `ok` is true; never synthesise a status from `next` alone.
- Do not change the stop shapes, the `Paused` path, the `BadLine` retry (story 02), the `record-seat` `--file`/heredoc scheme or the two-miss bound.
- Do not touch `cycle.sh`, `cycle-clerk.md`, `vulyk-build.md` (the fallback loop keeps polling; it runs verbs in the Queen's Bash where a poll costs no clerk).
- Do not update the `CAPS` map or any agent frontmatter.
- Keep the file LF-only.

## Map slice
`docs/specs/driver-hardening/recon/driver-and-clerk.md` §1 (:143 status call, :159/:212/:260 `res.ok` branches, :187-206 close-story handling) and §2 (the 16-call table); plan.md `## Contracts` C5, C6 and A5; `memory/map/cycle.md` "Drivers" and "`status --json` keys and `next`"; ADR-001 D2 "The Workflow driver"; ADR-009 invariants.

## Acceptance criteria
- [ ] C6: a scenario walking claim -> branch -> build (one worker, close-story ok with `status`) -> open-round (with `status`) -> dispatch four seats (each record-seat ok with `status`) -> judge GREEN (with `status`) counts exactly 3 `status` prompts to the `agent` stub and 13 clerk prompts in all; the run ends at `green`.
- [ ] The same walk with the stubbed verbs returning **no** `status` key (an older `cycle.sh`) counts 6 `status` prompts and ends at `green` - the old path still works.
- [ ] After a `close-story` exit 4 (miss) the next iteration polls `status` (a non-ok result never carries state); the existing two-miss scenarios (d)(e)(f)(g)(v2)(v3) pass unchanged.
- [ ] A `judge` result carrying `status` with `next: "repair"` and `red: [2]` routes the next iteration to the repair dispatch with no `status` poll in between.
- [ ] Every existing driver scenario passes; the header comment names the poll rule in one sentence.

## Verification
`bash tests/driver.test.sh`

## Implementation notes

## Findings
