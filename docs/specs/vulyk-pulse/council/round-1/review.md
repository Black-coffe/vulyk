<!-- seat: review · model: claude-opus-5-5 · round: 1 · head: fef62c4 · pack: 1f2f744b6f2b · attempt: 1 · recorded: 2026-10-16T08:33:37Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-opus-5-5

## Critical
None.
## Major
1. .claude/mods/vulyk-pulse/hooks/register.tsx:245 [ask 5] each "Baked for ..." line must keep the figures of its own turn's task as they stood when that turn closed, yet the TurnDuration hook draws the current task's live view (viewOf reads taskA/agentsA/tallyA), and the engine re-runs a ui.render hook on every $.state write it read, on every $.ui.invalidate("ui.render") (the 125 ms timer) and on an onScreen change (claude-code.d.ts 2.1.300 lines 4070-4078, 10549-10556), so a line drawn at the Workflow launch ticks live and every earlier closing line is redrawn with a later task's reset tally and timer - repro: read register.tsx:245-250 against the d.ts lines, then in a hive run two tasks more than 60 s apart and scroll back to the first "Baked for" line
## Minor
- .claude/mods/vulyk-pulse/hooks/register.tsx:234 the AbovePrompt site has no `e.surface !== 'terminal'` pass-through although the d.ts raises AbovePrompt on desktop too, so docs/pulse.md "Terminal only" and the plan's Surface rule are not met there
- tests/telemetry.test.sh hit `timeout 540` (rc=124) after 387 ok and 0 failures, the pulse install checks among the passed ones; the remaining cases were not observed this round
- docs/specs/vulyk-pulse/vulyk-pulse-01.md implementation note says no prompt hook exists, but the watcher uses `prompt.submit` (.claude/mods/vulyk-watcher/hooks/register.tsx:89); turn.start also opens tasks on task-notification turns
- install.sh:1069 on a machine whose marketplace is added but whose watcher is not installed, the pulse install never refreshes the stale marketplace clone (only the watcher's update branch does), so `plugin install vulyk-pulse@vulyk` fails into the NOTE
- .claude/mods/vulyk-pulse/hooks/register.tsx:212 an agent is marked finished only by its turn.complete; one that ends without it keeps the task busy and the timer running until the session ends
