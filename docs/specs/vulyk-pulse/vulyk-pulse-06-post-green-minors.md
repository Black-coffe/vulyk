---
story: vulyk-pulse-06
status: done
worker: worker-code
model: sonnet
wave: 5
blocked_by: []
returned: DONE
---

# Post-GREEN minors from council round 4

## Goal
Council round 4 was GREEN; the owner chose to fix its minor notes before the release («Сначала поправить мелочи»,
2026-10-16). Fix the three below and change nothing else. Narrow fix: no new council round.

1. **Terminal only, as docs/pulse.md:57 says.** `AbovePrompt` and `TurnDuration` in register.tsx never check
   `e.surface`; the opus seat mounted `TurnDuration` on surface `desktop` and it drew the pulse line. Both sites
   return `next(e)` when `e.surface !== 'terminal'`, the way the `Spinner` site already does.
2. **Idle gaps do not count.** `elapsedOf` runs from `task.start`, so a main turn that joins inside the 60 s settle
   window counts the quiet gap before it (agents ended at 5m02s, a notice 40 s later closed at 5m45s). The timer
   counts only time when something runs: when activity joins a task that was quiet (nothing running), the gap
   `now - last` is added to the task's idle total, and elapsed subtracts it. Add the field to `Task` in core.ts
   and to `PulseTask` in types/index.d.ts; a state value from before the change (no field) reads as 0. A joined
   task while busy adds nothing. `touched`'s existing tests keep their meaning; extend them for the new field.
3. **Docs.** docs/pulse.md: say where `motion` is set as the host really names it. Check `claude plugin configure
   --help` (or the d.ts/`reference.md` text on `userConfig`) and write the command it names; keep `/config` only if
   it is confirmed. Add one sentence that a resumed session, like a reload, starts with no frozen closing lines, so
   an older "Baked for" line redrawn after it shows the figures of that moment.

## Requirements
> 2. A timer: how long the task has run, from the owner's message until the last agent ends.
> 6. Only in VULYK hives; other projects keep the native line.

## Files
- .claude/mods/vulyk-pulse/hooks/core.ts
- .claude/mods/vulyk-pulse/hooks/core.test.ts
- .claude/mods/vulyk-pulse/hooks/register.tsx
- .claude/mods/vulyk-pulse/types/index.d.ts
- docs/pulse.md
- tests/watcher.test.sh

## Non-goals
- The token padding (`trimStart`) and the `weigh()` fallback rate: left as they are.
- No new state atom, no file writes, no change to the settle window or the frozen-lines Map.

## Acceptance criteria
- [ ] A `claude plugin test` case: `TurnDuration` and `AbovePrompt` on surface `desktop` inside a hive return the
      engine's own drawing.
- [ ] A core test: agents end at t, a main turn joins at t + 40 s and ends at t + 42 s; elapsed is the busy time
      only (the 40 s gap is not in it). Removing the subtraction turns it red.
- [ ] `bash tests/watcher.test.sh` passes.

## Verification
`bash tests/watcher.test.sh`

## Implementation notes
- core.ts/index.d.ts: optional `idle` on Task/PulseTask; touched adds now-last when joining while quiet; elapsedOf subtracts it.
- register.tsx: AbovePrompt and TurnDuration pass through off-terminal. Docs: configure command, resume sentence.
- core.test.ts: new idle and desktop tests; the notification test now expects 0m 05s (its 30 s gap no longer counts).

## Findings
