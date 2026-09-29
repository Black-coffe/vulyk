---
story: next-circle-0-22-02
spec: next-circle-0-22
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# A green build asks «Выпускаем?» and ships on yes (ask 2)

## Goal
The `green` terminal of `/vulyk-build` (both solo and hive paths end there) and of `/vulyk-review` asks the
owner one question through `AskUserQuestion`, in the owner's language, e.g. «<slug>: council GREEN, round
<n>. Выпускаем?» with the recommended option first. Yes: run `/vulyk-ship <slug>` through the Skill tool in
this session. No, or no `AskUserQuestion` (`claude -p`): the old one-line recommendation. Publishing stays
printed-not-run (`/vulyk-ship` step 3 unchanged).

## Requirements
> (2) после зелёного ревью сборка спрашивает «Выпускаем?» и на «да» запускает ship сама

> После зелёного ревью сборка задаёт один вопрос с кнопкой, и на «да» сама запускает ship: слияние в main, версия, запись.

## Files
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-review.md
- docs/cycle.md
- tests/maintenance.test.sh

## Non-goals
- Do not touch `.claude/workflows/vulyk-cycle.js`: the driver returns to the Queen, who reads the terminal.
- Do not change `/vulyk-ship` itself; do not push or tag.
- Do not change a `description:` line (the descriptions cap in `tests/maintenance.test.sh`).

## Map slice
`memory/map/agents-and-commands.md` - build, review, ship.

## Acceptance criteria
- [ ] `vulyk-build.md` `green` names the question, the Skill `vulyk-ship` on yes, and the one-line fallback.
- [ ] `vulyk-review.md` `green` does the same.
- [ ] `docs/cycle.md` stage 06 says the build asks.
- [ ] A contract case in `tests/maintenance.test.sh` fails if either command's green terminal loses the question or the Skill call.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
