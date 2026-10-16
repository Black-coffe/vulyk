---
story: vulyk-pulse-04
status: todo
returned:
worker: worker-code
model: opus
wave: 3
blocked_by: []
---

# Repair round 2

## Goal
Make the asks and findings council round 2 left RED pass, and change nothing else.

## Requirements
> 5. Visible both on the spinner line and above the prompt while a background build runs without the Queen; the total on the "Baked for..." line.

## Findings
ASK 5: RED - spinner + above prompt during background build; total on the "Baked for..." line - run: scratch host (hive forced), mount TurnDuration {word:'Baked'} after a task with 2 live agents saw: Spinner and AbovePrompt draw the row, but TurnDuration draws nothing of the pulse; host reports "vulyk-pulse's ui.render hook was skipped: state.set: denied: it was made while ui.render is being dispatched, and drawing is pure (host check)". register.tsx TurnDuration hook writes linesA inside the render, so the hook is skipped and the native "Baked for 3s" line stays: the task total never reaches the closing line
1. .claude/mods/vulyk-pulse/hooks/register.tsx:156 [ask 5] the owner-message reset must fire only for the person's own message (e.origin.kind 'composer' or 'bridge'), never for a background task's notification, so that a Workflow's completion notice, which arrives after its last agent ended with the main loop idle (busy=false), joins the build's task and the closing line carries the build's total; today only `isMeta` is filtered, but task notifications reach prompt.submit with origin.kind 'task-notification' and no isMeta (d.ts 2.1.300 lines 9199-9232: origin.kind is how a hook tells the user's Enter from a notification; the claude.exe background-task enqueue sites `{value:...,mode:"task-notification",skipAttachments:!0,priority:"next",taskId:e}` set no isMeta), so begin($, true) zeroes tally/agents/spec/place and restarts the clock at the notice, where on the base f483469 (`git show f483469:.claude/mods/vulyk-pulse/hooks/register.tsx`, no prompt.submit hook; turn.start joins within the 60 s settle window) the notice joined - repro: `grep -n "isMeta" .claude/mods/vulyk-pulse/hooks/register.tsx` against `sed -n 9199,9232p <bundled-skills>/2.1.300/.../plugin-authoring/types/claude-code.d.ts`

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
