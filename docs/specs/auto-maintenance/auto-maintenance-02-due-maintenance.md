---
story: auto-maintenance-02
spec: auto-maintenance
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 2
blocked_by: [auto-maintenance-01]
---

# Due maintenance runs itself; the real gc run (asks 1, 5, 6)

## Goal
The SessionStart brief drops the false "learnings awaiting GC" count. It computes what is due (plan A1):
gc, evolve (never run / 7+ days with a council round since / a changeset pending review / overdue
28+ days), map refresh. Nothing due: the brief is no longer than today's. Something due: one extra
line that tells the Queen to run each due command through the Skill tool after the owner's current
task, on the default branch with a clean tree, without asking, and to tell the owner in one line what
changed. `/vulyk-gc` commits its own result. The real gc pass runs once here: the stubs go, the real
learnings are consolidated.

## Requirements
> (1) один раз запустить gc и починить ложный счётчик

> 1. Запустить /vulyk-gc и починить ложный счётчик.

> можем ли мы автоматизировать команду Vultr GC?

> Их нужно максимально автоматизировать.

> (5) gc, evolve и обновление карты запускаются сами, и никому не нужно знать эти команды

> Хук старта сессии уже есть. Он сам вычисляет, что пора делать (накопились learnings, неделя без evolve, устарела карта), и велит главной сессии выполнить это после твоей текущей задачи.

## Files
- .claude/hooks/session-start-brief.sh
- .claude/commands/vulyk-gc.md
- tests/maintenance.test.sh
- docs/hooks-reference.md
- README.md
- memory/learnings/*
- memory/memory.md

## Non-goals
- No new hook, no Stop hook, no state file: the brief computes from files and git on every start.
- Do not make the hook modify files; it only reads and prints.
- Do not change `/vulyk-status` or `/vulyk-map`.

## Map slice
`memory/map/scripts.md` - hooks.

## Acceptance criteria
- [ ] Fixture hives in the test: stubs present → gc due; 9 real → not due; 10 real → due; no evolve ledger + a council row → evolve due; a ledger row 2 days old → not due; 8 days old + a newer council row → due; 8 days old, no newer council row → not due; an unmerged `vulyk/evolve-*` branch → "waiting for review", not due; last run 30 days old → overdue with the sunset pointer; `memory/map/.stale` → map due.
- [ ] Nothing due: brief output ≤ today's byte count and carries no maintenance line.
- [ ] The litopys offer test in `tests/telemetry.test.sh` still passes.
- [ ] After the gc run: no file in `memory/learnings/` carries the stub marker; `CONSOLIDATED.md` holds the four real learnings' entries.

## Verification
`bash tests/maintenance.test.sh`
`bash tests/telemetry.test.sh`

## Implementation notes

## Findings
