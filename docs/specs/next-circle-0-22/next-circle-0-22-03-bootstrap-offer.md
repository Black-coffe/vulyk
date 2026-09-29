---
story: next-circle-0-22-03
spec: next-circle-0-22
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 2
blocked_by: [next-circle-0-22-02]
---

# The brief offers bootstrap once in an unfilled hive (ask 3)

## Goal
`session-start-brief.sh` prints one more line only when the constitution's Profile block (`CLAUDE.vulyk.md`
if present, else `CLAUDE.md`) still holds a `<fill in` row, the repo is not VULYK itself (`telemetry/inbox/`
absent) and the Profile has no `| Bootstrap | declined` row: ask the owner once, before the first task,
whether to run `/vulyk-bootstrap` now (Skill `vulyk-bootstrap`); a no adds `| Bootstrap | declined <date> |`
to the Profile so it is never asked again.

## Requirements
> (3) в ненастроенном проекте Вулик один раз предлагает bootstrap

> В ненастроенном проекте Вулик сам предложит настройку перед первой задачей и проведёт её на «да».

## Files
- .claude/hooks/session-start-brief.sh
- tests/maintenance.test.sh
- docs/hooks-reference.md
- .claude/commands/vulyk-bootstrap.md

## Non-goals
- Never run bootstrap without the owner's yes.
- No output in a filled hive: the quiet-brief size check in `tests/maintenance.test.sh` still holds.

## Map slice
`memory/map/scripts.md` - the brief's due rules.

## Acceptance criteria
- [ ] Fixtures: a `<fill in` Profile → offer; filled → none; `telemetry/inbox/` present → none; a `Bootstrap | declined` row → none; `CLAUDE.vulyk.md` preferred over `CLAUDE.md`.
- [ ] This repo's own brief prints no offer.
- [ ] `/vulyk-bootstrap` says the brief offers it and how a decline is recorded.

## Verification
`bash tests/maintenance.test.sh`
`bash tests/telemetry.test.sh`

## Implementation notes

## Findings
