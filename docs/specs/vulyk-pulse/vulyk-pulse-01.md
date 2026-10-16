---
story: vulyk-pulse-01
spec: vulyk-pulse
status: todo
returned:
tier: 3
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# The pulse mod: swarm row, task timer, all-agent tokens

## Goal
`.claude/mods/vulyk-pulse/` exists as a valid mod that passes `claude plugin test`. The plan's `## Assumptions` and
`## Contracts` fix every rule below. Cite d.ts names for every API call you use; never guess one.

- **Manifest.** `.claude-plugin/plugin.json` follows the shape in plan `## Contracts`: `version` = `VERSION`,
  `userConfig.motion`, and `"types"` naming `types/index.d.ts`. `hooks/hooks.json` is
  `{ "modules": ["./register.tsx"] }`.
- **State.** `$.state` atoms, declared in `types/index.d.ts`, survive a hot reload. They hold:
  - the task: start, last activity, open or closed;
  - the tally: weighted tokens;
  - agents by `agentId`: type, live or finished;
  - the spec path;
  - `{wave, round}`.
- **`core.ts`** holds pure functions only:
  - `weigh(usage)`: the weights, with a comment naming `scripts/token-report.py` lines 18-19 and 57;
  - `fmtTokens`: `812`, `48.2k`, `1.8M`, padded to 5;
  - `fmtElapsed`: `0m 07s`, `12m 04s`, `1h 12m 04s`; narrow form `12m`;
  - `frameAt(now, motion)`;
  - `phaseOf(liveTypes)`: `build` > `council` > `design` > `plan` > `docs` > `clerk`. Any other type gives `agents`;
    no live agent gives `thinking`. The type map is in recon.md "VULYK data the row can read";
  - `dots(live, finished, now, motion)`: the live dots breathe, with one live dot `dimColor` per 500 ms step,
    walking left to right; none dim under `motion: off`;
  - `row(width, view)`: the full form, or the narrow form below 60 columns;
  - `closing(word, view)`;
  - the task open/close rule, with the 60 s settle;
  - `isHive`: the watcher's one-liner, copied, not imported.
- **`register.tsx`.**
  - **Hive gate.** On `session.start`, test `isHive` (`CLAUDE.vulyk.md` or `scripts/cycle.sh` at the root). Outside
    a hive every hook passes through.
  - **Redraw timer.** On `session.start`, re-arm it if the state shows an open task.
  - **Task lifecycle.** A main `turn.start` or prompt hook opens or joins the task. `turn.step` is a pass-through
    generator (`yield* next(e)`) that adds `r.usage` for every loop. `agent.spawn` records type and `agentId`.
    `turn.complete` with an `agentId` marks that agent finished.
    Probed live (study.md): a workflow agent's `agent.spawn` carries `workflow: {runId, agentIndex}`, and its
    `subagentType` is the script's `agentType`, or `workflow-subagent` when none was given (`phaseOf` maps it to
    `agents`).
  - **Spec, wave and round.** A `tool.call` on `Workflow` stores `args.spec`; the tool's arguments sit flat on the
    event (`e.args`, `e.scriptPath`), not under `e.input`. Then
    `$.process.run(['bash','scripts/cycle.sh','status',spec,'--json'])` runs at that call and on each spawn while a
    spec is known; a failure leaves wave/round blank.
  - **The redraw timer itself.** `$.clock.every(period)` calls `$.ui.invalidate('ui.render')`. It runs only while a
    task is open: 125, 500 or 1000 ms by `motion`.
  - **`ui.render` sites:**
    - `Spinner`: our row. It returns `next(e)` when `message !== null`, off the terminal, or outside a hive.
    - `AbovePrompt`: our row only when `!isWorking`, `!hasSurvey`, agents are live, and the chain drew nothing.
    - `TurnDuration`: the closing line.
  - **Colour.** The `✻` uses theme key `claude`, the separators `dimColor`; there is no bold and no RGB.

## Requirements
> 1. While VULYK works, a live micro-animation at the prompt: an animated ✻ and one dot per live agent, plus the phase, wave and round.
> 2. A timer: how long the task has run, from the owner's message until the last agent ends.
> 3. Tokens of all agents together (the Queen, subagents, workers), live, weighted as in the weekly token report.
> 4. Beautiful and native: theme colours, no flicker, the animation can be slowed or turned off in /config.
> 5. Visible both on the spinner line and above the prompt while a background build runs without the Queen; the total on the "Baked for..." line.
> 6. Only in VULYK hives; other projects keep the native line.

## Files
- .claude/mods/vulyk-pulse/.claude-plugin/plugin.json
- .claude/mods/vulyk-pulse/types/index.d.ts
- .claude/mods/vulyk-pulse/hooks/hooks.json
- .claude/mods/vulyk-pulse/hooks/core.ts
- .claude/mods/vulyk-pulse/hooks/core.test.ts
- .claude/mods/vulyk-pulse/hooks/register.tsx
- tests/watcher.test.sh

## Non-goals
- **The model.** Never call it: no `$.model.fork`, no `$.model.complete`.
- **No new files outside the mod tree:**
  - no new ledger under `memory/stats/`;
  - no file writes at all.
- **No extras (Law 2):**
  - no `turn.complete.usage` reconciliation;
  - no `$.session.usage().cost.usd`;
  - no style picker;
  - no session total;
  - no `$.ui.status`, `Pane` or `Raster`.
- **Other files.**
  - Do not touch `.claude/mods/vulyk-watcher/`, the root marketplace, `install.sh`, CI or the docs: those are -02's,
    or not this spec's.
  - Do not add a `## Commands` row.
- **Fixtures** are synthetic numbers and `Acme`-style stand-ins, never a real transcript (card
  `host-internals-in-public-repo`).

## Map slice
- Plan: `## Assumptions` and `## Contracts`.
- [study.md](study.md): "Probe results".
- [recon.md](recon.md): all of it.
- [study-design-fable.md](study-design-fable.md): sections 2 and 3, for mockups and format only. Its claim in
  section 1 that "the build is a running main turn" is wrong.
- `docs/specs/vulyk-watcher/vulyk-watcher-01.md` and `-02.md` `## Implementation notes`: the `Register` signature,
  `$.state` needing `"types"`, and the test env having no fs.

## Acceptance criteria
- [ ] `claude plugin validate` and `claude plugin test` pass on `.claude/mods/vulyk-pulse`.
- [ ] **Weights pin.** A fixture usage set gives the same weighted figure through `weigh()` and through
      `token-report.py`'s own function, with one Opus row, one Sonnet row and one Fable row. Changing a weight in
      either file alone makes `bash tests/watcher.test.sh` fail.
- [ ] **Row tests** cover:
  - the mockup row: `✻ VULYK · build · wave 2 · ●●●· · 12m 04s · ≈1.8M tok`;
  - `council · round 2`;
  - the narrow form at width 50;
  - no spec gives no wave word;
  - more than 10 dots;
  - `thinking` with no agents;
  - the closing line with and without agents;
  - fixed width: two rows that differ only in a digit have equal length.
- [ ] **Task tests** cover:
  - a spawn 30 s after the last agent ends joins the task;
  - a spawn at 61 s opens a new one;
  - a main turn while agents are live joins.
- [ ] `frameAt` covers the ping-pong sequence at 125 ms and 500 ms, and a static `✻` for `off`.
- [ ] **Pass-through.** Outside a hive (fixture: neither file present), every site returns `next(e)`.
- [ ] `tests/watcher.test.sh` validates and tests both mods and the root marketplace, and pins both `plugin.json`
      versions to `VERSION`. It exits 2 with one line when `claude` is absent. Every watcher check it ran before
      still runs.
- [ ] `## Implementation notes` names, with d.ts names:
  - the prompt hook used, or "none, main `turn.start`";
  - what `next(e)` returns for an empty band;
  - the `userConfig` and `"types"` keys.

## Verification
`bash tests/watcher.test.sh`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Implementation notes

## Findings
