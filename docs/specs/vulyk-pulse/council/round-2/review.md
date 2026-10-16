<!-- seat: review · model: claude-opus-5-5 · round: 2 · head: 6d05230 · pack: 1a4a725223e7 · attempt: 1 · recorded: 2026-10-16T09:16:20Z · verdict: BLOCK -->
VERDICT: BLOCK
MODEL: claude-opus-5-5

## Critical
None.
## Major
1. .claude/mods/vulyk-pulse/hooks/register.tsx:156 [ask 5] the owner-message reset must fire only for the person's own message (e.origin.kind 'composer' or 'bridge'), never for a background task's notification, so that a Workflow's completion notice, which arrives after its last agent ended with the main loop idle (busy=false), joins the build's task and the closing line carries the build's total; today only `isMeta` is filtered, but task notifications reach prompt.submit with origin.kind 'task-notification' and no isMeta (d.ts 2.1.300 lines 9199-9232: origin.kind is how a hook tells the user's Enter from a notification; the claude.exe background-task enqueue sites `{value:...,mode:"task-notification",skipAttachments:!0,priority:"next",taskId:e}` set no isMeta), so begin($, true) zeroes tally/agents/spec/place and restarts the clock at the notice, where on the base f483469 (`git show f483469:.claude/mods/vulyk-pulse/hooks/register.tsx`, no prompt.submit hook; turn.start joins within the 60 s settle window) the notice joined - repro: `grep -n "isMeta" .claude/mods/vulyk-pulse/hooks/register.tsx` against `sed -n 9199,9232p <bundled-skills>/2.1.300/.../plugin-authoring/types/claude-code.d.ts`
## Minor
- Round 1 major (register.tsx TurnDuration repaint) is fixed: the line is frozen under e.requestId, which the d.ts (line 10123-10128) defines as one instance per drawing, and the write converges (the second run finds the key)
- .claude/mods/vulyk-pulse/hooks/register.tsx:265 a TurnDuration line first drawn while no task exists (view null) is not stored, so once a task opens it is repainted with that later task's live figures; likewise transcript lines of a resumed session get first-drawn with the current task's figures
- .claude/mods/vulyk-pulse/hooks/core.test.ts:181 the new ask-2 test drives only joinable/touched with an explicit owner flag, so nothing exercises which prompts register.tsx counts as the owner's (the gap that hides the major above)
- docs/pulse.md:28 still says the Workflow's completion notice stays in one task and the closing line carries the build's total, which the head contradicts until the major is fixed
