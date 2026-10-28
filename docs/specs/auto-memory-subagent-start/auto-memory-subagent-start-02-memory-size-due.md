---
story: auto-memory-subagent-start-02-memory-size-due
spec: auto-memory-subagent-start
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: ::error::memory triage due at 160 lines
red_verified_at: 2026-10-28T15:30:15Z 251e81f6af1c25954db8418b25c50deacf6bf9283d91b73502cf922078a80f98
---

# Native MEMORY.md size makes memory triage due

## Goal
`scripts/memory-triage.sh --dir` prints the private auto memory dir it would list (same derivation, no
listing). `session-start-brief.sh` reads `MEMORY.md` there and, at 160 lines or 20480 bytes or more, adds
`memory triage (MEMORY.md <n> lines, <k> KB of 200 lines / 25 KB)` to the `maintenance due` line with the
skill `vulyk-gc memory`; below that, or with no file, nothing changes. `docs/memory-system.md` gains a short
section: Claude Code's auto memory, its load limit, the new signal, and how to turn it off
(`autoMemoryEnabled: false` in a project's settings, or `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`) with what is
then lost (the owner's personal lessons stop loading); VULYK never sets it. `/vulyk-gc` names the new trigger.

## Requirements
> 2. Старт сессии пишет «memory triage due» с размером, когда нативный MEMORY.md проекта достиг 160 строк или 20 КБ.
> 3. В доке описано, как выключить автопамять и что при этом пропадёт; сам VULYK ничего не выключает.
> А в session-start-brief.sh добавить проверку размера нативного MEMORY.md: если Claude Code накопил там мусор в обход «Вулика», сразу сигнализировать memory triage due.
> Либо жёстко контролируют autoMemoryEnabled: false в проектных настройках, делегируя всю память git-системе проекта (как у тебя в memory/ и docs/defects/), чтобы не платить дважды за контекст и не ловить теневые галлюцинации.

## Files
- .claude/hooks/session-start-brief.sh
- scripts/memory-triage.sh
- tests/maintenance.test.sh
- docs/memory-system.md
- .claude/commands/vulyk-gc.md

## Non-goals
- No `autoMemoryEnabled` in any settings file, the installer or a hive.
- Do not read or judge the memory files' content at session start; the triage does that with the owner.
- Do not follow a custom `autoMemoryDirectory`.

## Map slice
memory/map/scripts.md: `memory-triage.sh`, the SessionStart brief.

## Acceptance criteria
- [x] A fixture `MEMORY.md` of 159 lines and 20479 bytes: no `memory triage`; 160 lines: due; 20480 bytes in fewer lines: due, with the size in the line.
- [x] No auto memory dir, or no `MEMORY.md`: the brief prints what it printed before.
- [x] `memory-triage.sh --dir` prints the same dir the listing reads, and the listing output is unchanged.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes
- `memory-triage.sh --dir`: the same derivation, printed and exit 0; the brief calls it beside the hook (`../../scripts/`) from `$ROOT`, so a hive without the script or outside git stays silent.
- Size: `wc -l` lines, `wc -c` bytes, KB floored (20480 B -> 20 KB). On this repo's own index (47 lines, 9.8 KB) nothing is due.
- Docs: `docs/memory-system.md` § Claude Code's own auto memory (signal, off switch, what is lost); `/vulyk-gc` names the trigger.

## Findings

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 251e81f6af1c25954db8418b25c50deacf6bf9283d91b73502cf922078a80f98 (tests/maintenance.test.sh)
- impl: a4fca4b346afa7c8866aa52ba6d834feefde84e0e854922e0e5b402dab27c954
- stamped: 2026-10-28T15:30:15Z

```
  ok    memory-triage: a file without frontmatter lists with type -
  ok    memory-triage: MEMORY.md is not a row
  ok    memory-triage: exactly two rows
  ok    memory-triage: an absent dir says so
  ok    memory-triage: an absent dir exits 0
  ok    memory-triage --index-lines: names the moved file's line
  ok    memory-triage --index-lines: takes a bare file name
  ok    memory-triage --index-lines: leaves other lines out
  ok    memory-triage: writes nothing
maintenance.test.sh: 160 checks, 4 failed
```
