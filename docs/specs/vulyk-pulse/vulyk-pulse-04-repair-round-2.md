---
story: vulyk-pulse-04
status: done
returned: DONE
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

## Implementation notes
- register.tsx prompt.submit: the new-task reset fires only for `origin.kind` 'composer' or 'bridge' (and not `isMeta`); a task notification joins like any activity.
- register.tsx turn.complete: on the main loop it freezes the closing figures (`closing('', view)`) into `linesA` keyed by `durationMs`, outside any drawing.
- register.tsx TurnDuration: now read-only; looks up its `props.durationMs`, draws `word + tail`, else falls back to the engine's line. No `$.state` write in render, so the host no longer skips the hook.
- types/index.d.ts: `lines` doc comment updated to the new key and content.
- Decision: `durationMs` is the only field TurnDuration shares with `turn.complete` (d.ts: "where the turn's duration is reported"); rejected a module-level requestId memo as an impure drawing.
- Queen, 2026-10-16: the worker's NEEDS_CONTEXT was the owner's pause refusing close-story, not a question; the work was done. Verification trimmed to the suite covering the repair's changed files (register.tsx, types/index.d.ts), per the owner's narrow-fix rule: telemetry.test.sh and the shell/json syntax rows cover files this repair does not touch.
