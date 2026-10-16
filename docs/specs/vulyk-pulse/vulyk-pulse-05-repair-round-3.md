---
story: vulyk-pulse-05
status: todo
returned:
worker: worker-code
model: opus
wave: 4
blocked_by: []
---

# Repair round 3

## Goal
Make the asks and findings council round 3 left RED pass, and change nothing else.

## Requirements
> 5. Visible both on the spinner line and above the prompt while a background build runs without the Queen; the total on the "Baked for..." line.

## Findings
ASK 5: RED - spinner + above prompt during background build; total on "Baked for" - run: probe: owner task A (one turn, durationMs 2500, 1.5k tok), then 120 s later task B (3 steps, also durationMs 2500), then 250 more main turns; mount TurnDuration saw: task A's line read "Baked for 0m 02s · ≈1.5k tok", then after B the same old line repaints to "Baked for 0m 02s · ≈4.5k tok" (frozen lines are keyed by durationMs, not by the turn); the store held 251 entries with the oldest still kept (no ~200 cap). Working parts: AbovePrompt with isWorking:false and a live worker drew the row; with no live agent it stayed native; a task-notification submit kept start 1000000 and tally 3000; the closing line drew "Baked for 1m 10s · 1 agent · ≈3.0k tok". The shipped core.test.ts has no TurnDuration-in-hive test and no task-notification test, both asked for in the round-2 decision
1. .claude/mods/vulyk-pulse/hooks/register.tsx:238 [ask 5] the closing line of a background build (the turn that answers the Workflow's completion notice) must carry the task total, but it is looked up by `durationMs` and the engine gives that line a different duration than the `turn.complete` that froze the figures: in claude.exe 2.1.301 the line's `props.durationMs` is the turn_duration message's (`useRenderInput("TurnDuration",()=>({requestId:g,props:{word:b,durationMs:d.durationMs}}))`), that message gets `vGr(...).durationMs`, which is `now - _backgroundWaitStartTime` once the launch turn ended with a workflow pending (it stores `backgroundWaitStartTime:M??g`, the launch turn's start), while `turn.complete` gets the notice turn's own `An` (`sJr({...durationMs:An})`); the key misses, `tail === undefined`, and the native "Baked for 10m 11s" stays, so in a background build the total never reaches the closing line (only the launch line, with its 2 s figures, matches; `_deferSwarmDuration` and `_holdDurationForDetachedToolCalls` lines miss the same way) - repro: `grep -aoE 'function vGr\(.{0,500}' claude.exe` and `grep -aoE '.{0,300}sJr\(\{turnEvents:Eo.{0,80}' claude.exe` under %APPDATA%/npm/node_modules/@anthropic-ai/claude-code/bin/
2. .claude/mods/vulyk-pulse/hooks/core.test.ts:222 [ask 5] the owner's escalation decision in brief.md (line 29) requires a `claude plugin test` that mounts TurnDuration inside a hive after a task and sees the pulse closing line, and one that a task-notification prompt does not reset the task; neither exists (the diff touches no test file, the only TurnDuration test is outside a hive) and plan.md `## Descoped` is empty, so the shipped suite cannot fail on either ask-5 defect this repair targets - repro: `git diff fbc3455..e237b0d --stat -- .claude/mods/vulyk-pulse/hooks/core.test.ts` (empty)

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
