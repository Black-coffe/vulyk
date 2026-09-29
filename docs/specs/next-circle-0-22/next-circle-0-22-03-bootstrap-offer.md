---
story: next-circle-0-22-03
spec: next-circle-0-22
status: done
returned: DONE
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
- [x] Fixtures: a `<fill in` Profile → offer; filled → none; `telemetry/inbox/` present → none; a `Bootstrap | declined` row → none; `CLAUDE.vulyk.md` preferred over `CLAUDE.md`.
- [x] This repo's own brief prints no offer.
- [x] `/vulyk-bootstrap` says the brief offers it and how a decline is recorded.

## Verification
`bash tests/maintenance.test.sh`
`bash tests/telemetry.test.sh`

## Implementation notes
- `session-start-brief.sh`: the offer line sits right after the map line (it is for before the first
  task). `<fill in` is looked for only between the `VULYK:PROFILE` markers, so a `<fill in` elsewhere in
  the constitution never offers; the `Bootstrap | declined` row is grepped across the whole file, like the
  litopys `Chronicle` row. CRLF constitutions work (the marker and row patterns are substrings/prefixes).
- `tests/maintenance.test.sh`: 11 cases - unfilled, CRLF unfilled, filled, `<fill in` outside the block,
  `telemetry/inbox/`, declined row, `CLAUDE.vulyk.md` over `CLAUDE.md` both ways, no constitution (the
  quiet hive, whose size check still holds), and this repo. With the old hook 4 fail; now 65 checks, 0 failed.
- `docs/hooks-reference.md` and `/vulyk-bootstrap` describe the offer and the decline row.

## Findings
