# Recon: Claude Code 2.1.300 mod API for a live VULYK indicator (Sonnet)
Source: DTS = .../bundled-skills/2.1.300/6d3e1afc.../plugin-authoring/types/claude-code.d.ts (22296 lines); REF = reference.md (255 lines).
Facts only; "not confirmed" where the declaration is silent.

## 1. Token accounting across all loops

### Events that carry usage
- `turn.complete` input has `usage?: TurnUsage` (DTS 13954), `agentId?: string` (DTS 13946, doc 13938-13945: "the loop the turn ran in: a subagent's id ... absent on the main loop"), `turnId`, `durationMs` (DTS 13911+). Registration doc DTS 4571-4581: "Every hook hears an agent's end (`e.agentId`), the spawner's too". So ONE hook `on('turn.complete')` sees main-loop and every subagent turn end, each with the turn's summed token counts.
- `TurnUsage = ModelUsage & { model }` (DTS 14312). `ModelUsage` = {input_tokens, output_tokens, cache_read_input_tokens, cache_creation_input_tokens}, all four always present, zero when absent (DTS 6550-6580). A turn's counts are its responses' summed (DTS 14308-14310). Absent when nothing counted (interrupt, API error) (DTS 13949-13954).
- `turn.step` (streaming event) result carries `usage: TurnUsage | null` per API response (DTS 14184-14186, result type 14138+) and stop chunk `usage` (DTS 14232). Input has `agentId?` (DTS 14100-14118: "a subagent's id, the id $.agent.list() gives it; absent on main"). Caveat DTS 14114-14116: a subagent a hook spawned via `$.agent.spawn` steps PAST that hook (its own turn.steps are not seen by the spawning hook).
- `turn.start` (DTS 4560-4568, input 14017-14040): fires for main turn and subagent turns (`agentId`). Caveat: "An agent's start skips the hooks its spawn was nested in".
- `session.measure` (DTS 4518-4525, input 11550-11590): fires after each MAIN-THREAD turn and when a rate-limit window moves a whole point; carries `cost?: SessionCost` ({usd}) and `context`, `rateLimits`, `changed: UsageUnit[]` ('context'|'rateLimits'|'cost', DTS 15276). Dollars only, no tokens.
- `session.compact` result has `usage?: ModelUsage` of the summarizer request (DTS 11179-11189); doc says "the session's cost ledger already holds it".
- `$.model.complete` / `$.model.fork` results carry `usage: ModelUsage` on every arm (DTS 6385-6454).

### $.session.usage()
- `usage(args?) => Promise<SessionUsage>` (DTS 2902). SessionUsage = {startedAt, context, rateLimits, cost?} (DTS 12166-12193). `cost` = `SessionCost { usd }`: "US dollars, summed over every priced API response this session" (DTS 11382-11387), "as /cost totals it" (DTS 12189). NO token counts in SessionUsage; `context` is the live window fill (main thread), not cumulative.
- Does `cost.usd` include subagents/workflow agents/forks? DTS says "every priced API response this session" and compaction note says the ledger holds the summarizer cost (DTS 11184), which implies engine-side requests are in it. NOT CONFIRMED explicitly for subagents, workflow agents, or a mod's own $.model.fork. Needs a live probe (diff cost.usd around a known subagent call).
- Dollars only; to show tokens a mod must sum the events itself.

### Subagent loops
- agentId distinguishes loops. AgentLoop type (DTS 194-204): "A workflow's agents and the engine's own forks (compaction, memory) carry ids no list names." => Workflow-tool agents DO run as agent loops in this process and carry an agentId on turn.start/turn.step/turn.complete, but `$.agent.list()` does NOT list them (DTS 3263-3270: "a workflow's are not"). `agent.spawn` input has `workflow?: { runId, agentIndex }` for a workflow script's agent() (DTS 331-348), so a mod can tell workflow agents apart and group by runId.
- Exception DTS 340-345: with `isolation: 'remote'` (internal builds only) no turn.complete/loop event carries the id. Not relevant to external build.
- Engine's own forks (compaction, memory extraction) carry agentIds no list names (same AgentLoop doc); whether turn.complete is raised for them: not confirmed.

### Per-agent token figure elsewhere
- `AgentInfo` (DTS 125-200): id, teammateId, description, type, status, parentId, spawnedBy, name. NO usage/token field.
- `AgentCallRecord` (DTS 110-120): { agentId, resolvedModel? }. NO usage.
- `AgentSpawnResult` (DTS 422-445): { model, agentId?, teammateId? } or { deny }. NO usage.
- So per-agent tokens are obtainable ONLY by summing turn.complete (or turn.step) `usage` keyed by `e.agentId`.

### Gaps (spend a mod would MISS)
1. Anything before the mod loaded (no backfill; `turn.complete` is not replayed). Hot reload mid-session also loses module-var counters.
2. A subagent turn whose `turn.complete` carries no `usage` (interrupt, API error: DTS 13949-13954) is counted as zero even if tokens were billed.
3. `$.model.fork` / `$.model.complete` calls made by THIS mod: the mod's own return value has usage, so it can add them itself, but they are NOT a turn and fire no turn.complete. Calls by OTHER plugins: they are op events `model.complete`/`model.fork` (OpEventOf DTS 6970/6982, "every one is hookable by name and by on('*')", DTS 6940-6950); `next(e)` resolves to the result with usage, and the calling hook alone is skipped. So a mod CAN observe other plugins' completions via `on('model.fork', ...)` (and its own via the return value). Not confirmed: whether engine-internal requests (memory, compaction, classifier, title) fire `model.complete`; compaction has its own `usage` on session.compact result.
4. A hook that spawned a subagent via `$.agent.spawn` does not see that child's turn.start/turn.step (DTS 14114-14118, 14034-14037) but DOES hear its turn.complete (DTS 13943-13946).
5. `agentId`-less turns are only main; engine-internal forks with unlisted ids may or may not raise turn.complete (not confirmed).
6. Remote-isolated workflow agents (internal builds): invisible. Not applicable to external 2.1.300 build.
7. Teammates in a separate terminal pane run no loop here (DTS 131-132): invisible.
8. `session.measure` cost only moves after a main-thread turn; `$.session.usage()` can be polled by clock for current dollars.

### Persistence
- Module variables: lost on hot reload (existing watcher says the same, register.tsx top comment). `$.state` (DTS 3467-3490): plain data, versioned, "survives a hot reload of the plugin's code"; requires a typed contract (PluginState via declaration merging in the plugin's types) and its keys literal in source; the `get` inside a ui.render hook subscribes and a later `set` redraws. Refused while a ui.render hook draws. Does it survive /clear? Not stated; the process lives on under a new session id (DTS 11456-11463), so process-held state likely survives but is NOT CONFIRMED.
- `$.store` (DTS 3434-3465): JSON file under the user's Claude config dir, "kept between sessions and hot reloads", 4 MiB cap. Survives /clear, resume, restart. Write is async (one fs write per set): do not call per token.
- /clear: `session.end` fires with reason `clear`, no `session.start` fires (DTS 11456-11458, 4436); `$.session.usage().startedAt` restarts at /clear (DTS 12172). `$.model.fork` returns `nothing-to-fork` after /clear (DTS 6497). So a "session total" must be chosen: reset on session.end/id change, or keep a process-lifetime counter in $.state and a per-sessionId bucket in $.store.
- Compaction: the usage ledger is unaffected (it is event sums); `session.compact` raises own event with the summarizer usage.

### Hot-reload / worker-loss hazard (REF)
- REF line 147: "State a drawing draws from belongs in `$.state`, not a module variable (a hot reload loses those)". REF "Work that outlives a dispatch" (~lines 178-186): if the engine replaces the plugin's copy mid-session (hooks worker lost), "its timers and state gone"; `$.clock.every` timers run until cancelled or the module reloads; start long-lived timers from `session.start` (awaited before the first prompt, DTS 4436-4442).
- Hook budget: 10 s own time per dispatch, 1 s `.catch` grace, 5 s linger (DTS 5221-5256, HookBudget). A turn.complete accumulator is far inside it; `$` waits do not count against it.
- The existing watcher keeps `onScreen/shownCount/forkCount` in module vars (register.tsx lines 21-26) and writes its own fork spend to a file ledger: a mod does not hear its OWN `$.model.fork` as an event (the calling hook alone is skipped, DTS 6940-6950); it reads `reply.usage` from the return value.

## 2. Animation mechanics

### Common limits
- `$.ui.invalidate('ui.render')` (DTS 2383-2393): "A redraw: ten a second at most, thirty in the terminal for a shown pane, expanded band and prompt hint (sooner calls fold)". So a Spinner tree is capped at 10 redraws/s; an expanded AbovePrompt band or a shown Pane at 30/s.
- `$.state.set` redraws the reading sites "at the redraw rate" (DTS 3482-3487); a `$.state.get` made while a ui.render hook draws subscribes that instance (DTS 3472-3474); `$.state.set` is refused while a ui.render hook draws.
- `$.clock.every(ms, fn)`: ms at least 1; one hookable dispatch per period; callback lives in the plugin environment, cancelled by hot reload (DTS 3503-3507, 3540-3547).
- Terminal element table: Box, Text, Button, Input, Select, Link, Code, Markdown, Client, Raster, Image (DTS 3893-3917). The terminal is the only surface with Raster/Image and has no Svg (DTS 3895).
- Text props (DTS 13128-13193): color/backgroundColor (theme key or raw string: named color or hex; `Color` DTS 1716), dimColor, weight/bold, italic, underline, strikethrough, inverse, wrap; `tabular` exists for timers (no-op on terminal, digits already one cell). NO gradient prop anywhere in the DTS (grep "gradient": 0 hits). A gradient = one Text per character with hex colors, or a Raster. Theme keys (DTS 13201): text, inverseText, inactive, subtle, suggestion, remember, success, error, warning, merged, claude, permission, planMode, autoAccept, promptBorder, bashBorder, ide, diff*.
- Box props (DTS 928-1030): flexDirection/Grow/Shrink/Wrap, alignItems/Self, justifyContent, gap/columnGap/rowGap, width/height/minWidth/minHeight (number or string), margin*, padding*, borderStyle (single, double, round, bold, singleDouble, doubleSingle, classic, arrow, dashed, quote), borderColor, backgroundColor, overflow, display, position relative|absolute with top/left/right/bottom.
- Width: a tree wider than the room wraps/truncates per Text `wrap`; a width change re-runs every hooked site once the resize settles; a height change alone re-draws nothing (RenderViewport DTS 10787-10810; REF 140-142). AbovePrompt/Pane hooks must size to `e.props.bodyColumns`, not `viewport.columns` (REF 142). `viewport.isFullscreen` = alt-screen layout (DTS 10804, CommandPresentation 1794-1802: false on the main screen, `CLAUDE_CODE_NO_FLICKER=0`, tmux by default).

### Raster (terminal only)
- `RasterProps` DTS 9632-9668. Leaf: no children, no hover, no onPress. Props: `key` (unique among Rasters of one tree), `columns` 1..512, `rows` 1..256, `cells`.
- Cell format: `cells` is standard padded base64 of `columns*rows` little-endian u32 TRIPLETS `[codePoint, foreground, background]`, row-major. Code point: one printable width-1 BMP character (blocks, box drawing, braille too) or the whole tree is refused naming the cell index. Color: `0x00RRGGBB`, or `0x01000000` (bit 24 alone) for the terminal's default. DTS example: `Uint32Array.of(0x2588, 0xff8800, 0x01000000)` then `new Uint8Array(words.buffer).toBase64()` (DTS 9655-9664). Palette: 1024 distinct color pairs at once, others snapped to nearest (DTS 9637-9638). Whether `Uint8Array.prototype.toBase64` exists in the mod runtime: NOT CONFIRMED.
- `$.ui.blit({ requestId, key, cells, columns?, rows? })` (DTS 2395-2414; args 9599-9630): repaints a mounted Raster THIS plugin's own render hook drew; "no redraw"; "up to 120 a second taken, some sixty shown"; blits between frames fold into one. `columns`/`rows` must equal the mounted size; a resize is a redraw, not a blit. Resolves `{}` or `{ deny }` (not mounted, not this plugin's, other size, undecodable cells). `requestId` = "one of its panes' ids, a tool row's tool_use_id, the band's" (DTS 9606-9608); in practice the `e.requestId` of the hook that drew the Raster (RenderInputOf.requestId, DTS ~10120-10125). The literal requestId string of the band: NOT CONFIRMED, read it from `e`.
- DTS example: `$.clock.every(33, () => $.ui.blit({ requestId, key, cells: frame() }))` (DTS 2410).

### (a) Spinner component
- DTS 10495-10527 (props), 9754 (component list), 10124 (requestId = "the agent id for a spinner"). Raised on terminal, desktop, vscode only.
- Props: `word` (e.g. "Sauteing", sampled per turn), `message` (override or null), `suffix` (one ellipsis; "" draws bare, " ~" draws "Sauteing ~"), `mode` ('requesting'|'responding'|'thinking'|'tool-input'|'tool-use').
- Native line: `Sauteing... (12s, 300 tokens)` (DTS 10495). A hook "reads `word` (or `message`), `suffix`, then what the surface keeps and no prop carries: elapsed time, tokens, effort. A hook rewrites the first three, or draws a tree in place of all of it" (DTS 10499-10501). Consequence: rewriting word/message/suffix keeps the engine's native elapsed/tokens text and native animation; drawing a tree REPLACES the line including elapsed and tokens (not available as props), so the mod would draw its own timer and token total.
- Whether the native tokens/elapsed count only the main loop or all agents: NOT CONFIRMED by the DTS. `requestId` being an agent id hints at one Spinner instance per agent loop that has a spinner (e.g. a viewed agent), not an aggregate; not confirmed.
- Visible: "The line that animates while a turn runs" (DTS 10495): only during a turn, not idle. Whether it shows while only background agents/workflows run after the main turn ended: NOT CONFIRMED.
- Redraw: a tree is a normal redraw (10/s cap, DTS 2383). Whether Raster blit works inside a Spinner tree: NOT CONFIRMED (Spinner not in the requestId list at 9606-9608). A Client element does not need blit.
- A refused or throwing tree falls back to the engine's own Spinner; shown only in the debug log (and the transcript during hot-reload sessions) (REF 155).

### (b) AbovePrompt band
- DTS 10641-10716. "The band directly above the prompt input, where the surveys draw; of its own the engine draws a `[-]` beside the tree, an `n more` row under it." One instance. Terminal and desktop only.
- Props: `hasSurvey` (yield to it), `isWorking`, `maxRows` (fullscreen: what the bottom slot has left above the prompt, the slot capped at half the terminal rows prompt included; else terminal height), `bodyColumns` (column width less the engine's five at the right end), `scroll`, `view` (main conversation or an opened agent transcript; switching re-runs the hook).
- Visibility: the hook runs whether or not a turn is running (`isWorking` is a read-only prop; the example band.tsx draws "Last turn: Ns" after the turn ends, and the existing watcher shows its note after turn.complete, i.e. idle). So it is visible idle, during turns and while only background agents run, as long as the mod returns a tree from its own state. The person can collapse it (ctrl+x ctrl+a or `[-]`) and focus it (ctrl+x tab, click) (DTS 10644-10648): a collapsed band hides the indicator.
- Redraw: 30/s for an expanded band (DTS 2383-2386). A keyed Raster inside it can be repainted with `$.ui.blit` with no redraw (120/s taken, ~60 shown). Taller trees than `maxRows` scroll; the band sits above the prompt so it costs layout rows.

### (c) $.ui.status
- DTS 2498-2510. `status(text|undefined)`: "Pins `text` as this plugin's status line under the prompt, beside the engine's own pinned notices, until the next call replaces it. One per plugin; `undefined` removes it." Plain string: first 2000 characters drawn on the terminal (10000 remote). Color/ANSI/styling: NOT CONFIRMED (signature is `string`, no style channel). Visible independent of turn state. Update-rate cap: not stated in the DTS. Width handling: not stated. DTS example `$.clock.every(1000, () => $.ui.status("polling"))`. One line per plugin, below the prompt.

### (d) Pane
- `$.ui.open({ id, title?, focus?, closeOnEscape?, holdToasts?, rows?, columns? })` (DTS 7532-7600; 2512-2533), component 'Pane' (DTS 10699-10751: title, isFocused, bodyColumns, placement 'dock'|'inline', scroll, view). Placement: 'dock' beside the transcript only in the fullscreen layout from 110 columns, else 'inline' above the prompt. A pane a plugin opens by itself (unasked) is not placed below 144 columns (110 once the person opened that id themselves); the call resolves `{ isPlaced: false, reason }`. An open answering the person's own input (command, prompt, press) is placed at any width (DTS 7520-7530). One pane per id; the person closes it (engine mark, ctrl+x x), a `ui.close` hook may refuse. Redraw 30/s when shown. Visible while open, any turn state. Framed, with a tab row if several; heavier than a one-line indicator.

### (e) Client element (surface module): an option the DTS offers beyond the four asked
- `ClientProps` DTS 1532-1565, `ClientSurface` DTS 1583-1660, `ClientModule` DTS 1473-1480. A region drawn by the plugin's own surface module: "The engine keeps the instance (its local state, its timers) across the plugin's redraws"; module gets `surface.elements`, `surface.state` / `setState`, `surface.every(ms, fn)` ("on the surface's frame clock"), `columns`/`rows`, `onPointer`, `onKey`, `post(data)` to the hooks module (one per frame). "Runs on the drawing thread, a second per call at most; a throw, an overrun or a tree past the bounds unmounts it" (DTS 1473-1480). `module` must be a string literal. Terminal and desktop have `Client`; vscode and mobile do not (REF 146-147).
- Value for the goal: a local animation loop (spinner glyph, shimmer) with no plugin round trip and no 10/s redraw cap; the hooks module passes `props` = { startedAt, tokens, agentsRunning } and the module animates between updates. Frame-clock rate, and whether `Date` is available on the drawing thread: NOT CONFIRMED.

## 3. Lifecycle: "VULYK is working"

| Signal | DTS | What it gives |
|---|---|---|
| `prompt.submit` | 4200 | the person's prompt; start timestamp for the "working since" clock (band.tsx example does exactly this) |
| `turn.start` | 4560-4568, input 14017-14040 | main turn and each subagent/teammate run (`e.agentId`); hooks that spawned the agent do not hear its start (nested-spawn skip) |
| `turn.complete` | 4571-4581, 13911-13990 | main turn end and every subagent run end; `reason` answer|aborted|refusal|error; `usage`, `durationMs`, `agentId` |
| `agent.spawn` | 4188, input 261-418, result 422-445 | fires for subagents, teammates, workflow agents (field `workflow:{runId, agentIndex}`, DTS 331-348), forks (`fork:true`); `parentAgentId`, `background`, `model` |
| `$.agent.list()` | 3270, `AgentInfo` 125-190, `AgentStatus` 566 | pending/running/waiting/idle/completed/failed/killed per subagent/teammate; NOT workflow agents ("a workflow's are not", DTS 3268); one row dropped seconds after end |
| `classic.SubagentStart` / `classic.SubagentStop` | 12804-12830; ClassicEventName 1271 | a mod can `on('classic.SubagentStop')` (fires "wherever the engine runs the classic hook, whether or not a settings hook is configured", DTS 1262-1270); `agent_id`, `agent_type`, `last_assistant_message`, `background_tasks`, `session_crons` |
| `classic.Stop` | 12676-12700 | fires when the main loop stops; carries `background_tasks?: BackgroundTaskSummary[]` = "in-flight background work (running/pending + backgrounded) ... lets hooks distinguish 'session is done' from 'session is paused waiting for background work'" ; task `type` 'shell'|'subagent'|'monitor'|'workflow' (DTS 820-850) |
| `classic.TaskCreated` / `TaskCompleted` | 12882-12900 | task_id, subject (team tasks; teammate-oriented) |
| `tool.call` with tool `Workflow` | Workflow input 17519-17535, result 22242-22262 | result `{status:'async_launched', taskId, taskType:'local_workflow', workflowName, runId, transcriptDir}`: a mod CAN know a Workflow started and its runId (in-process, `local_workflow`) |
| UserMessage `origin.kind: 'task-notification'` | RenderPropsOf.UserMessage ~10150-10200; REF 143 | a background task's completion notice (`e.props.task`: id, status, durationMs) is drawn as a transcript row and hookable at `ui.render`, a render-time signal not an event |
| `session.measure` | 4518-4525 | after each main-thread turn + whole-point rate-limit moves; has `cost.usd` |
| `session.end` / session.start | 4527-4537, 4436 | /clear = session.end(reason 'clear') with NO session.start |

- Is there an event when a background subagent finishes? Yes, three: its `turn.complete` (with `agentId`; "a hook that spawns at each end sees them", DTS 13943-13946), `classic.SubagentStop`, and the AgentStatus change visible by polling `$.agent.list()`. For a Workflow agent: `turn.complete` with its unlisted agentId (AgentLoop DTS 194-204), and `classic.SubagentStop` presumably (not confirmed for workflow agents).
- Can a mod know a Workflow is running? Start: `tool.call` Workflow result (runId, taskId) and `agent.spawn` with `workflow.runId`. Agent-level progress: spawns minus turn.completes per runId. End of the whole run: NO dedicated event in the DTS; options are `classic.Stop.background_tasks` (workflow entry gone) and the task-notification UserMessage; neither confirmed to fire at exact completion. Not confirmed: whether an `agent.spawn` is raised for a workflow retry ("a stalled agent's retry is not raised again", DTS 356-357; so a retry is invisible as a spawn).
- Background agents after the main turn ended: `isWorking` on AbovePrompt/PromptHint reads only "a model turn is running" (DTS 10657, 10619) - it does NOT cover background agents. A mod must compute "VULYK busy" itself = mainTurnRunning || (spawned - completed agents > 0) || a workflow runId open.
- Pitfall: spawn/complete counters in a module var are lost on worker loss/hot reload; reconcile on start from `$.agent.list()` (non-workflow agents only).

## 4. Engine status line (statusLine setting / `cs`) vs `$.ui.status`

- This box: `~/.claude/settings.json` lines 109-113: `"statusLine": { "type": "command", "command": "C:/Python3129/Scripts/cs.EXE", "refreshInterval": 300 }` (the installed claude-statusbar). Read via grep.
- DTS has no type for the `statusLine` setting beyond `Settings = Readonly<Record<string, unknown>>` (DTS 12256) and a mention of `StatusLineCommandInput.effort` (DTS 871). A mod can read it with `$.settings.read()` (DTS 3646-3670) but cannot write settings.
- Coexistence: `$.ui.status` is documented as "this plugin's status line under the prompt, beside the engine's own pinned notices" (DTS 2498-2503). The DTS does not say anything about the `statusLine` command output sharing the row. NOT CONFIRMED that they coexist on separate rows; strongly suggestive that they are different surfaces (the command statusLine is the engine footer fed by the cs process; the mod's line is a pinned notice), but a live probe is required.
- `SessionUsage` is explicitly "the status line's figures" (DTS 12159-12165): `context`, `rateLimits`, `cost`; so cs and a mod can show the same cost; both are dollars, not tokens. cs (skill description) has toggles for "running subagents", "session duration", "cost", so the existing status bar may already cover part of the goal; how cs counts subagents (transcript parsing?) is NOT CONFIRMED here.

## 5. Other limits

- Flicker on Windows Terminal: the DTS says nothing about flicker per terminal. Related facts: fullscreen (alternate-screen) vs main-screen layout is chosen by `CLAUDE_CODE_NO_FLICKER` (default fullscreen; `=0` and tmux use the main screen) (DTS 1794-1802); Raster blits fold to ~60 shown/s and "no redraw" (DTS 2395-2412) - the mechanism meant for animation; tree redraws are capped 10/s (Spinner) and 30/s (band). Real flicker on Windows Terminal: NOT CONFIRMED; needs a live visual test. This box's shell env reports TERM_PROGRAM=WarpTerminal (a different terminal than Windows Terminal; env of the agent shell, the owner's actual terminal may differ).
- NO_COLOR / reduced motion: no accessibility, reduced-motion or NO_COLOR field exists in the DTS (grep reduceMotion|prefersReduced|NO_COLOR|accessib: 1 unrelated hit, a close control's accessible name, DTS 1161). A mod can read `$.env.get("NO_COLOR")` (literal name; DTS 3671-3699) and `$.settings.read()` (any key, merged) but there is no first-class signal. Colors follow the person's theme only via theme keys (Color DTS 1716); raw hex ignores the theme. Raster cells are raw RGB.
- Terminal width: `e.props.bodyColumns` (band, pane), `e.viewport.columns/rows` (DTS 10787); width change re-runs hooks after resize settles; height change does not. Raster is limited to 512x256 and "the site clips what its body cannot show" (DTS 9647-9650) so it must be sized to bodyColumns on each render. Band and Pane are not drawn on vscode/mobile (AbovePrompt: terminal and desktop; Spinner: terminal, desktop, vscode).
- Colors: raw hex works on Text (any string; "what a surface draws for one it does not know is its own", DTS 1713-1715). Terminal color depth handling (truecolor vs 256): NOT CONFIRMED; Raster states the 1024-pair palette and nearest-color fallback.
- Authority/footgun: `ui.render` trees are validated; an invalid prop fails the whole tree and the engine draws its own (DTS 9759-9763). A `Raster` with a non-width-1 or non-BMP code point refuses the tree.
- Hot reload during use: a mod in `.claude/mods` hot-reloads when the mods folder is watched; changing options reloads and `register` runs again (DTS 15660s, Register doc). Module vars reset (see section 1).
- `Uint8Array.toBase64`, Date on drawing thread, frame-clock rate, blit inside Spinner, ANSI in `$.ui.status`, native spinner token scope, statusLine coexistence: all NOT CONFIRMED and listed again below as probes.

## Honest gap list: spend a mod would MISS, and unknowns to probe live

Misses (token accounting):
1. Everything before the mod loaded and everything between a worker loss/hot reload and recovery (module-var counters reset; `$.state`/`$.store` mitigate, but no backfill from the engine exists in the DTS).
2. Turns that end with no `usage` (interrupt, API error: DTS 13949-13954) even if billed.
3. Engine-internal requests with unlisted agentIds (compaction summarizer, memory extraction, classifiers, title generation): they are in the dollar ledger (`cost.usd`, DTS 11184) but a mod only sees them if they raise `turn.complete`/`model.complete`; compaction has `session.compact` result `usage` (DTS 11179-11189). Not confirmed for the others.
4. The mod's OWN `$.model.fork`/`complete` calls fire no hook for itself; it must read `reply.usage` (as the watcher does) and add it. Other plugins' calls are visible via `on('model.fork' | 'model.complete')` (DTS 6955-6985) only if the calling plugin is not the observer.
5. Teammates in their own terminal panes run no loop here (DTS 131-132): not visible. Remote-isolated workflow agents (internal builds only, DTS 340-345): not applicable.
6. A subagent's `turn.start` and `turn.step` are hidden from the hook that spawned it (DTS 14034-14037, 14114-14118); only its `turn.complete` reaches it. A watcher that itself spawns would miss per-step streaming for those children.
7. Dollar vs token: `$.session.usage().cost.usd` is dollars only; whether it includes subagents/workflow agents/mod forks is not stated (NOT CONFIRMED; "every priced API response this session").

Unknowns (probe before building): native Spinner token scope; blit inside Spinner; `$.ui.status` styling and refresh rate; statusLine vs `$.ui.status` coexistence; Workflow-run completion event; whether `classic.SubagentStop` fires for workflow agents; `toBase64` / `Date` in the module runtimes; actual flicker on the owner's terminal.

## Addendum
- `Image` (terminal) draws via the kitty graphics protocol only where the terminal has it (kitty, Ghostty), its `alt` elsewhere (REF 149-150); useless for Windows Terminal/Warp-unknown, so Raster is the cell-based animation primitive. Unicode block/braille glyphs in a Raster are width-1 BMP, fine.
- REF 148-149: "A grid of colored cells (sparkline, heat map, rendered frame) is one Raster ... never a Box per cell; $.ui.blit repaints a mounted one without a render pass."
