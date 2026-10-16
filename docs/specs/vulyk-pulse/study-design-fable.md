# VULYK pulse: design and architecture (Fable, 2026-10-16)

Read-only study. API claims below were checked in `claude-code.d.ts` (2.1.300) and `reference.md`; the line numbers
are the d.ts's. Facts marked **(verify)** are ones I could not settle from the declarations: they are sonnet-recon's.

## 0. Facts the design stands on

| Fact | Where |
|---|---|
| `Spinner` is raised only while a turn runs (terminal, desktop, vscode). A hook rewrites `word`/`message`/`suffix` and the engine keeps its own elapsed/tokens/effort tail; or the hook draws a tree *in place of all of it* (then the tail is gone and the hook owns the animation). `message !== null` means an engine state overrides the word (compacting etc.). | d.ts 10496-10535 |
| `TurnDuration` (`Baked for 3s`) is the turn's closing line, terminal only; props `word`, `durationMs`; a tree replaces it. | 10537-10560 |
| `AbovePrompt`: one band, terminal + desktop; props `isWorking` (main turn running), `hasSurvey`, `bodyColumns`, `maxRows`; the person can collapse it (`[-]`); the watcher already draws here. | 10640-10700 |
| `$.ui.status(text)`: one pinned text line per plugin under the prompt; text only, no tree, no colour. | 2500-2510 |
| `$.ui.invalidate('ui.render')` redraws this plugin's instances, capped at 10/s (30/s for a shown pane or expanded band); sooner calls fold. A `$.state` read while drawing subscribes the instance; `$.state.set` redraws exactly the readers. | 2378-2386, reference.md "State" |
| `Raster` + `$.ui.blit`: cell grid with explicit `0x00RRGGBB` colours (or terminal default), repainted at up to 60 fps without a render pass. Terminal only. Colours do **not** follow the theme except "default". | 9599-9680, 2395-2414 |
| `Text` takes theme keys as `color` (`claude`, `subtle`, `success`, `warning`, `error`, `inactive`…) so a tree follows the person's light/dark theme; `dimColor`; `weight`. | 13128-13210 |
| `turn.start` / `turn.complete` carry `agentId` for every loop but main; "every hook hears an agent's end, the spawner's too"; `turn.complete.usage` = the four `ModelUsage` counts summed over the turn's responses + `model`. A subagent's or workflow agent's whole run is **one turn**, so its usage lands only when it finishes. | 13915-13960, 14017-14040 |
| `turn.step` streams every response; the stop chunk states the response's usage ("adds nothing unless its stop states usage"). A plugin that spawns nothing hears every loop's steps. | 13951, 12700-12730 **(chunk field names: verify)** |
| `agent.spawn` fires for the Agent tool and for a workflow script's `agent()` (`e.workflow.runId`, `agentIndex`); input carries `subagentType`, `description`, `model`, `background`, `parentAgentId`. The driver's `phase:`/`label:` opts are **not** in the event. `$.agent.list()` does **not** list a workflow's agents. | 254-370, 3268, 4178 |
| `$.session.usage()` (free without `breakdown`): `startedAt`, `context.{tokens,window,percent}`, `cost.usd` "summed over every priced API response this session". Whether that sum includes subagents **(verify)**. | 12166-12200, 11382 |
| `$.process.run(argv)`: a host command, no shell, 30 s default timeout. Usable for `bash scripts/cycle.sh status <spec>` (JSON with `stage`, `wave`, `round`, `seats`). | 3581-3600; cycle.sh 681 |
| In VULYK the build **is a running main turn**: `/vulyk-build` calls the Workflow tool in the foreground and "nothing else while it runs"; Tier 1-2 reviewer dispatches are awaited Agent calls. The Queen is idle with agents live only when a run was handed to the background (ctrl+b on the Workflow task, `run_in_background` agents). | vulyk-build.md 43-45; d.ts 360-368 |
| Timers (`$.clock.every`) and module variables die on a hot reload; `$.state` survives it. `userConfig` fields become rows of the `/config` menu, a `string` with `options` a picker. | reference.md 74, 143, 185 |
| Marketplace `vulyk` lives at the repo root `.claude-plugin/marketplace.json` and lists plugins by path (`./.claude/mods/vulyk-watcher`); install.sh installs the mod once per machine at user scope, idempotent, and a hive opts out with `enabledPlugins["<id>@vulyk"]: false`. | install.sh 1024-1080 |
| VULYK's house unit of spend is **weighted tokens** = input + 1.25×cache-write(5m) + 2×write(1h) + r×cache-read + output, r = the model's read discount (0.1 Sonnet, 0.05 Opus, 0.025 Fable); `token-report.py`, `/vulyk-status`, `/vulyk-evolve` all print it. The Workflow's printed `totalTokens` "is not spend". | token-economy.md 24-26, 118; token-report.py 18, 57; vulyk-build.md 48 |
| No "reduced motion" signal exists anywhere in the API (grep: none). | d.ts |

## 1. WHERE

**Recommendation: replace the native Spinner line with our own one-row tree (terminal surface), and reuse the same
row in the AbovePrompt band only while the main turn is idle but agent loops are still live. Leave `$.ui.status`,
`Pane` and `Raster` alone.**

Visibility matrix:

| State | What shows | Site |
|---|---|---|
| Main turn running (every VULYK build, council, Tier 1-2 dispatch; also plain chat) | the pulse row, animated | `Spinner` (ours in place of the engine's) |
| Main turn idle, agents live (backgrounded Workflow / `run_in_background` agents) | the same row, dim, `in background` | `AbovePrompt`, 1 row |
| Engine state override (`message !== null`: compacting, retrying) | the engine's own line | we `next(e)` |
| Turn ended | `Baked for 1h 12m · 9 agents · ≈4.2M tok` | `TurnDuration` (ours) |
| Idle, nothing live | nothing | - |

Why the Spinner line:
- It is already *the* native "working" affordance: the eye rests there, and it already carries an animation, a timer
  and a token count. The owner's three asks are exactly its three parts. Making it say the truth about the hive is
  more native than adding chrome next to it.
- One line, no box, nothing to collapse, no `[-]`, no competition with surveys or the watcher's notes (the band is
  "one instance" shared by every plugin: the watcher draws when it has a note, we would have to chain behind it).
- Zero layout shift: the row exists only while a turn runs, which is also when the engine's own line would be there.

Why the band as secondary and not primary: it is the only site drawn while the main turn is idle, which is the one
case the Spinner cannot cover. The same render function draws both; the band hook returns `next(e)` whenever
`e.props.isWorking` is true, so the two never show together.

Rejected:
- **Band as the primary** (two-row dashboard above the prompt): duplicates the spinner one row above it; takes 1-2
  rows of a slot capped at half the terminal; collapsible by the person, so the animation can silently vanish;
  shares the band with the watcher's notes and surveys.
- **`$.ui.status`**: text only, dim, one of several pinned notices; no colour, no control of position; fine as a
  fallback where a tree is refused (vscode) but not "beautiful".
- **`Raster` + `blit` at 60 fps**: colours are hard RGB and do not follow the theme; a 1-row micro-animation at
  8 fps needs no blit path; `invalidate` at ≤10/s is the documented way for a redraw.
- **Spinner `word` rewrite only** (keep the engine's tail): 30 lines, but the tail's token figure is the engine's,
  whose scope is undeclared **(verify: sonnet-recon)**; if it is main-loop-only it contradicts "all agents" on the
  same line. If recon shows the engine's figure already sums every agent, this becomes a credible v0: rewrite `word`
  to `VULYK · build · 3 workers`, `suffix` to `""`, done. I still recommend the tree, because we need the row on the
  band and on `TurnDuration` anyway and one renderer should own the format.
- **`Pane`**: a framed region for a one-line gauge is the wrong weight.

## 2. WHAT it shows

Content, left to right, one row, ≤ 80 cols, one animated cell:

```
glyph  VULYK · <phase> · <agents> · <elapsed> · <tokens>
```

- **glyph**: the engine's own six spinner dingbats (`·` `✢` `✳` `✶` `✻` `✽`, U+00B7 2722 2733 2736 273B 273D),
  cycling forward then back at 125 ms, coloured with theme key `claude` (Claude's amber: reads as honey on both
  themes). These glyphs are proven on the owner's Windows Terminal every day (the engine draws them), so no tofu
  risk; copy the exact frames from the engine at build time rather than from this note.
- **phase**: one word from the live agent types: `build` (worker-code/-test), `council` (lead-review, council-*),
  `design` (lead-architect), `plan` (queen-planner, drone-scout, drone-coverage), `docs` (drone-docs, librarian),
  `clerk` shown only when nothing else is live; `thinking` when the Queen alone works. Wave/round numbers: see Q3.
- **agents**: `3 workers`, `2 seats`, `1 clerk` — the live loops count by phase word; absent when none.
- **elapsed**: since this turn's `turn.start` (main loop), fixed width: `12m 04s`, `1h 12m 04s`.
- **tokens**: `≈1.8M tok`, weighted, this turn, all loops (section 3). Fixed width 5 chars + unit.

### Mockup A (recommended): the Spinner row

```
✻ VULYK · build · wave 2 · 3 workers · 12m 04s · ≈1.8M tok
```
(colours: `✻` claude/amber · `VULYK` plain · `·` separators dimColor · phase plain · numbers plain)

Frames of the one animated cell, 125 ms each, then reverse:
```
·  ✢  ✳  ✶  ✻  ✽  ✻  ✶  ✳  ✢  ·
```
The owner's earlier two states, for the eye:
```
✢ VULYK · council · 2 seats · 4m 10s · ≈310k tok
✽ VULYK · thinking · 0m 07s · ≈12k tok
```
Motion `slow` (2 fps) shows the same frames at 500 ms; `off` pins `●` (U+25CF) and still updates the numbers.

### Mockup B: the swarm (one dot per live agent)

```
✻ VULYK · build · ●●●· · 12m 04s · ≈1.8M tok
```
`●` a loop that is running, `·` one that finished this phase (U+25CF / U+00B7, both in Cascadia). The lit dots
"breathe": one of them is drawn `dimColor` each 500 ms, walking left to right, so every running process visibly
moves. Nicer for a 4-wave build, one more thing to look at. I would ship A first and A/B as a `style` picker only if
the owner asks: Law 2.

### Mockup C (rejected): two-row band

```
┃ ✻ VULYK  build · wave 2/4                              12m 04s   ≈1.8M tok
┃   ● worker-code 01   ● worker-code 02   ● worker-test 03
```
Rejected for the reasons in section 1 (duplicates the spinner, collapsible, shares the band).

### Narrow fallback (`viewport.columns` < 60, or `bodyColumns` on the band)

```
✻ build 3 · 12m · 1.8M
```
Drop, in order: `VULYK`, the `wave N` word, the `tok` unit, seconds.

### The idle band row (main turn idle, agents live)

```
· 2 workers in background · 48m 12s · ≈2.4M tok
```
Whole row `dimColor`; same frames, `slow` rate, so the band does not shout while the person types.

### The closing line (`TurnDuration`)

```
Baked for 1h 12m · 9 agents · ≈4.2M tok
```
Keeps the engine's `word` and its formatted duration; appends what the turn cost with everyone counted. This is where
the figure survives after the spinner is gone, and it stays in the transcript view.

### No flicker, themes, fonts
- One `Text` run per row with fixed-width fields (elapsed and tokens padded), so a digit change never shifts a
  cell; only the one glyph cell changes between frames. Redraws ride `invalidate` at the engine's cap; the render
  hook reads `$.clock.now()` to pick the frame (`floor(now / 125) % 10`), so nothing is written per tick.
- Colour only through theme keys (`claude`, `subtle`/`dimColor`); no RGB; no background colours; nothing bold
  (bold over `dimColor` kills the dim on the terminal, d.ts 13140).
- Glyph set = the engine's own; `●`/`·` for the swarm; nothing from Geometric Shapes Extended (`⬡ ⬢` honeycomb
  is tempting and renders as tofu in older Cascadia builds), no emoji (`🐝` is 2 cells wide and width-ambiguous
  across terminals: a guaranteed jitter).
- Reduced motion: no signal exists, so it is a `userConfig` picker `motion: on | slow | off` (default `on`), a
  row of `/config` by itself. `off` keeps the numbers live.
- Surfaces: draw the tree on `e.surface === 'terminal'` only; `next(e)` on desktop/vscode (the Spinner site exists
  there too and an untested tree would be refused or drawn oddly; the engine's own line is a fine fallback).

## 3. TOKENS, honestly

**Recommendation: show one number, `≈<n> tok` = weighted tokens of this turn across every loop (main, Agent-tool
subagents, workflow agents), computed from each API response's usage with the same weights `token-report.py` uses.**

What "all agents" means here: every `turn.step` stop (or `turn.complete.usage`) heard by a plugin that spawns
nothing, i.e. the Queen's loop, every Agent-tool subagent, every workflow agent the driver dispatches, teammates.
Not counted and said so in the docs: `$.model.fork`/`$.model.complete` calls made by plugins (the watcher's own
forks: they are not turns; the watcher writes those to `memory/stats/watcher.jsonl` already), remote-isolated
agents (no events, d.ts 349-357), and the engine's compaction/memory forks **(verify whether their loops raise
`turn.complete`)**.

Why weighted and not the alternatives:
- **Raw sum of the four counts**: dominated by cache reads (the watcher ledger's first row: 47,032 read vs 71
  output). It would read "2M tokens" for a 70-token answer: misleading in the direction the owner cares about.
- **Output only**: honest and pricing-free, but hides the 90% of cost that is input; says "work done", not "burned".
- **`$.session.usage().cost.usd`**: the engine's own ledger, includes everything it priced, no drift; but on a Max
  subscription it is notional (`/cost` says so), it is session-scoped not turn-scoped, and the owner asked for
  tokens. Keep it out of the row; `/cost` already shows it.
- **Weighted**: VULYK's established unit; `/vulyk-status`, `token-report.py` and `/vulyk-evolve` print the same
  number, so the live gauge and the weekly report agree. It is "≈cost in token units", which is what "burned" means.
  The `≈` on the row is the honesty mark: a derived figure.

Live source: `turn.step` pass-through generator reading each response's stop usage (per API call, every few
seconds during a build) rather than `turn.complete` (a worker's whole 40-minute run is one turn; the tally would
freeze between agents, which defeats "movement"). `turn.complete.usage` is read too, as the reconciliation for a
loop whose steps were missed. The weights table (four read discounts + 1.25/2 write) is duplicated from
`token-report.py` into `core.ts` with a comment naming it, and `core.test.ts` pins one fixture to the python
script's result so the two cannot drift silently (Law 6 shape: a check, not a warning). 1h-TTL writes cannot be
told from 5m ones in `ModelUsage`; weight every write at 1.25 and say so (the report has the finer figure).

Scope: **per turn**, like the elapsed timer beside it. In VULYK a build is one turn, so "this turn" is "this
build". A session total is one atom more if the owner wants it (Q2).

Format: `812` under 1k, `48.2k`, `1.8M`; pad to 5 characters so the row holds still.

## 4. ARCHITECTURE in VULYK

**A new mod, `vulyk-pulse`, at `.claude/mods/vulyk-pulse/`, not a fold into `vulyk-watcher`.**

Why separate:
- The watcher is a judge: it calls the model (`$.model.fork`), costs tokens, shows notes rarely, stays silent
  outside a hive. Pulse is a gauge: never calls the model, draws every 125 ms, useful in any session. Different
  cadence, different failure modes, different off switch (`enabledPlugins["vulyk-pulse@vulyk"]: false` per hive).
- A refused tree or a thrown hook is said "once per load and component" per plugin; a pulse bug must not silence
  the watcher's notes and vice versa. A hot reload of one does not drop the other's state.
- The repo-root marketplace already lists plugins by path; a second entry is three lines. `install.sh`'s
  `install_watcher` becomes `install_mod <id>` called twice (same idempotent shape, same `--check` lines).
  `OWNED` gains `.claude/mods/vulyk-pulse`. Cost: one more `claude plugin install` per machine, done by install.sh.
- Against: both mods hook `turn.complete` and `AbovePrompt`. Cheap: pulse's band hook passes whenever
  `isWorking` or when nothing is live, the watcher's passes without a note; they chain, no shared state.

Files (the story names them; Law 3):
```
.claude/mods/vulyk-pulse/.claude-plugin/plugin.json   name, version = VERSION, userConfig { motion: on|slow|off }
.claude/mods/vulyk-pulse/hooks/hooks.json             { "modules": ["./register.tsx"] }
.claude/mods/vulyk-pulse/hooks/core.ts                pure: tally(usage, model) -> weighted, format(n), elapsed(ms),
                                                      frameAt(now, motion), phaseOf(agentTypes), row(width, state)
.claude/mods/vulyk-pulse/hooks/core.test.ts           claude plugin test: fixtures incl. the token-report.py pin
.claude/mods/vulyk-pulse/hooks/register.tsx           hooks: turn.start, turn.step, turn.complete, agent.spawn,
                                                      ui.render {Spinner, TurnDuration, AbovePrompt}
.claude/mods/vulyk-pulse/types.d.ts                   PluginState contract (atoms below)
.claude-plugin/marketplace.json                       + vulyk-pulse entry
install.sh                                            install_watcher -> install_mod, OWNED
tests/watcher.test.sh                                 validate + plugin test for both mods (or a sibling pulse.test.sh)
docs/watcher.md (+ a pulse section) · docs/token-economy.md (one paragraph: what the row's ≈tok is)
CHANGELOG.md, VERSION                                 the Queen's, at ship
```

State: `$.state` atoms, declared in the types contract, nothing on disk.
```
pulse: {
  turn:       { startedAt: number; turnId: string } | null     // the main loop's current turn
  tally:      { weighted: number; out: number; calls: number } // this turn, all loops
  agents:     Record<agentId, { type: string; since: number }> // live loops (turn.start -> turn.complete)
  agentsSeen: number                                           // for the closing line
}
```
Why not module variables (the watcher's choice): a hot reload mid-build would zero a three-hour tally; `$.state`
survives it and is the subscription mechanism that redraws exactly the Spinner/band instance on `set`. Why not a
file under `memory/stats/`: the figure is a live gauge, not a ledger; `token-report.py` over the transcripts is the
ledger of record, and a second file would be a second source of truth that must agree with the first (the drift
class `lib.sh` guards with its one whitelist). The `TurnDuration` rewrite leaves the per-turn figure in the
transcript view, which is all the persistence a gauge needs.

Animation loop: `turn.start` (main) starts `$.clock.every(period, () => $.ui.invalidate('ui.render'))`;
`turn.complete` (main) cancels it unless agents are still live; the last agent's `turn.complete` cancels it. The
render hook computes the frame from `$.clock.now()`; `motion: off` means no timer at all and a redraw only when
state changes. Nothing is written per tick; the engine folds redraws to its 10/s cap.

Does it read VULYK's artifacts? v1: no. Phase and counts come from `agent.spawn`'s `subagentType` and the loop
events: zero I/O, works in every hive at every version. Wave/round numbers would come from one
`$.process.run(['bash', 'scripts/cycle.sh', 'status', spec])` per `agent.spawn` (the JSON already has `stage`,
`wave`, `round`; the spec path is the Workflow tool call's `args.spec`, readable from a `tool.call` hook matched on
`Workflow`): a documented contract, not a second parser over `journal.md`. That is story 03, behind Q3.

Hive detection: none needed. The row is useful in any session; the word `VULYK` and the phase vocabulary appear
only when VULYK agent types are seen (otherwise `· thinking ·` / `· 2 agents ·`). The watcher's `isHive` stays the
watcher's.

Tier and stories (CLAUDE.md table): **Tier 3**: the mod plus the installer and the root marketplace are
cross-cutting, exactly the watcher's precedent (Tier 3, three stories, Sonnet workers, council `opus` + `review`,
3 rounds). Two stories in one wave, disjoint files:
- `vulyk-pulse-01` (worker-code): the mod: `core.ts` + `core.test.ts` + `register.tsx` + manifest + types.
  Verification: `bash tests/watcher.test.sh` extended to both mods (validate + plugin test).
- `vulyk-pulse-02` (worker-code): marketplace entry, `install.sh` `install_mod` loop + `OWNED`, docs.
  Verification: `bash install.sh --check` on a temp hive prints both `would install` lines; the existing install
  checks in `tests/telemetry.test.sh` that mention the watcher id.
- `vulyk-pulse-03` (optional, Q3): wave/round via `cycle.sh status`; worker-code; verification in `core.test.ts`.
Release and the 35-hive rollout are the Queen's after GREEN (install.sh does the machine-wide install; a restart of
`claude` applies it, as the watcher's note says). The pin to `token-report.py` is the one test that touches a file
outside the mod; it runs python on a fixture JSONL and compares one number, no new script.

What I rejected in the architecture: a `turn.step` hook was the one place I hesitated (the watcher plan says
"`turn.step` is never subscribed", but that was a fork-cost guard, not a streaming one). A pass-through generator
that reads one field per stop chunk is the cheapest live source there is; `turn.complete`-only would freeze the
tally for a worker's whole run. If sonnet-recon finds the stop chunk carries no usage on this build, fall back to
`turn.complete` plus `$.session.usage().cost.usd` polled each second as the live hint, and say in the docs that the
tally steps per finished agent.

## 5. Risks and open questions (recommended answer first)

1. **Does the engine's own spinner token figure already sum every agent?** *Recommended: assume no and build the
   tree; if sonnet-recon shows it does, keep the tree anyway* (the row is needed on the band and the closing line
   too, and one renderer should own the format) and use the engine's figure as the cross-check fixture in
   `core.test.ts`. Since the tree replaces the engine's tail, two different token numbers can never sit side by
   side on screen whichever way the fact falls.
2. **Scope of the two numbers: this turn (recommended) or the whole session?** Per turn matches the timer beside
   it and VULYK's unit of work (a build is one turn). A session figure is one more atom and a second dim number
   (`· 3.1M today`) if the owner wants it later; not in v1.
3. **Show wave/round numbers (`wave 2 of 4`, `council r2`) in v1?** *Recommended: yes, as story 03 in the same
   spec, via `cycle.sh status` once per agent spawn*: a three-hour wait is where "where are we" matters most and the
   JSON contract already exists. If the owner says no, v1 shows the phase word and the live count only, and nothing
   reads the spec folder.

Residual risks, no question needed: the Dingbat frames are proven on this machine, but a hive on another font could
show tofu; the `motion: off` glyph `●` is in every monospace font and is the escape. The Spinner tree is
terminal-only by design (desktop/vscode keep the engine's line). `invalidate` costs a render pass up to 10/s for the
session's length: one small tree, and the engine already animates that row at that rate.
