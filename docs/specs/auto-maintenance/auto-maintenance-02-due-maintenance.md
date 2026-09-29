---
story: auto-maintenance-02
spec: auto-maintenance
status: done
returned: DONE
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
- .claude/agents/librarian.md
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
- `session-start-brief.sh`: the "learnings awaiting GC" count is gone. A second line prints only when something is due (plan A1); an unmerged `vulyk/evolve-*` branch prints "waits for the owner's review" instead. The evolve clock reads `"kind":"run"` rows of `memory/stats/evolve.jsonl` (a proposal row is not a run), so the plan contract gains the `run` row; story 03 writes it. The hook reads the ledger and git itself (bash, 0.27 s) instead of calling `evolve-ledger.py`, so it does not depend on story 03. Portable dates: GNU `date -d`, BSD `date -v` fallback, ISO strings compared lexicographically.
- Quiet brief: 384 B against v0.20.0's 412 B on the same fixture (checked in the test).
- The real gc run exposed a root defect: `librarian` (Read, Write, Edit, Glob) was told to delete files it cannot delete, so `/vulyk-gc` could never have finished. Its `Delete:` list now goes to the main session, which runs `git rm` and prunes snapshots (`vulyk-gc.md`, `librarian.md`). `librarian.md` joins `## Files` - recorded in plan.md `## Plan deltas`.
- The gc run: CONSOLIDATED.md written (15 entries from the 4 real learnings; ADR-015-superseded ladder claims dropped), 36 stubs and the 4 merged raw files removed, `memory/memory.md` pointer re-aimed at CONSOLIDATED.md. Librarian's open points for the owner: ADR-015 has no index pointer (index at 59/60 lines); `memory/map/agents-and-commands.md` predates ADR-015 (drone-docs work); whether frontmatter `effort:` is honoured on the current Claude Code.

## Findings
