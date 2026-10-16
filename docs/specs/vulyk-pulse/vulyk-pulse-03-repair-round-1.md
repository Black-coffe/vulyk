---
story: vulyk-pulse-03
status: done
returned: DONE
worker: worker-code
model: opus
wave: 2
blocked_by: []
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 2. A timer: how long the task has run, from the owner's message until the last agent ends.
> 5. Visible both on the spinner line and above the prompt while a background build runs without the Queen; the total on the "Baked for..." line.

## Findings
ASK 2: RED - timer from the owner's message to the last agent's end - run: bun p.ts: touched(task{start:0,last:600000}, 630000, busy=false), then elapsedOf at +5s saw: {"start":0,"last":630000,"open":true} and "10m 35s": a new owner message 30 s after the last agent ended inherits the old task's clock (and its token tally, since begin() resets only on a new task). register.tsx opens tasks on main turn.start and says "There is no separate prompt hook", but the harness lists prompt.submit (the watcher uses it), so an owner message could start a fresh task
1. .claude/mods/vulyk-pulse/hooks/register.tsx:245 [ask 5] each "Baked for ..." line must keep the figures of its own turn's task as they stood when that turn closed, yet the TurnDuration hook draws the current task's live view (viewOf reads taskA/agentsA/tallyA), and the engine re-runs a ui.render hook on every $.state write it read, on every $.ui.invalidate("ui.render") (the 125 ms timer) and on an onScreen change (claude-code.d.ts 2.1.300 lines 4070-4078, 10549-10556), so a line drawn at the Workflow launch ticks live and every earlier closing line is redrawn with a later task's reset tally and timer - repro: read register.tsx:245-250 against the d.ts lines, then in a hive run two tasks more than 60 s apart and scroll back to the first "Baked for" line

## Files
- .claude/mods/vulyk-pulse/.claude-plugin/plugin.json
- .claude/mods/vulyk-pulse/types/index.d.ts
- .claude/mods/vulyk-pulse/hooks/hooks.json
- .claude/mods/vulyk-pulse/hooks/core.ts
- .claude/mods/vulyk-pulse/hooks/core.test.ts
- .claude/mods/vulyk-pulse/hooks/register.tsx
- tests/watcher.test.sh
- .claude-plugin/marketplace.json
- install.sh
- tests/telemetry.test.sh
- .github/workflows/ci.yml
- docs/pulse.md
- docs/token-economy.md

## Verification
`bash tests/watcher.test.sh`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- core.ts: `joinable`/`touched` take `owner` (default false); the owner's message joins only while busy, so with all quiet it opens a new task (fresh clock, tally reset by `begin`).
- core.test.ts: the ASK 2 repro (task{0,600000}, owner at 630000 idle -> new task, elapsed 0 at +5 s; busy -> joins).
- register.tsx: `prompt.submit` hook (d.ts 4189-4200, skips `isMeta`) calls `begin($, true)`; the misleading "no separate prompt hook" comment replaced.
- register.tsx: TurnDuration line text frozen at first draw under `e.requestId` (RenderInputOf, d.ts ~10125) in a new `$.state` atom `lines`; redraws return the kept text.
- types/index.d.ts: `lines: Record<string, string>` added to the state contract.
- docs/pulse.md: two sentences on the owner-message rule and the frozen closing line.
- Decision: prompt reset happens before `next(e)`, so a prompt dropped by another hook still opens a task (rare; accepted). `lines` is not capped: one short string per closing line per session.
