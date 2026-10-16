# Recon: vulyk-pulse (the Queen, 2026-10-16)

No scouts: the territory is the `vulyk-watcher` precedent, read directly. API facts are in [study.md](study.md) and
its two raw reports; this file gives the planner the repo pointers the stories will name.

## The precedent: `vulyk-watcher`

- Layout: `.claude/mods/vulyk-watcher/.claude-plugin/plugin.json` (`name`, `version` = VERSION `0.27.2`, `description`,
  `author`), `hooks/hooks.json` (`{ "modules": ["./register.tsx"] }`), `hooks/register.tsx` (hooks only),
  `hooks/core.ts` (pure functions), `hooks/core.test.ts` (`claude plugin test`), `hooks/fixtures/`.
- Hive test: `core.ts:83` `isHive({ vulyk, cycle }) = vulyk || cycle`, where `vulyk` = `CLAUDE.vulyk.md` exists at
  `$.session.root()` and `cycle` = `scripts/cycle.sh` exists (register.tsx reads both with `$.fs.read`).
- The watcher keeps session values in module variables (a hot reload clears them). A `$.state` value needs a types
  contract named in `plugin.json` `"types"` (plugin-authoring skill); pulse wants `$.state` so a reload mid-build does
  not zero the tally.
- Docs: `docs/watcher.md`; map: `memory/memory.md:14-15` points at it (no map slice for mods).

## Shipping

- Root marketplace `.claude-plugin/marketplace.json`: `plugins: [{ name: "vulyk-watcher", source:
  "./.claude/mods/vulyk-watcher", description }]`. A second entry is the whole change there.
- `install.sh:52` `OWNED` lists `.claude/mods/vulyk-watcher`; a pulse tree needs its own entry (or the parent
  `.claude/mods`).
- `install.sh:1024-1080` `install_watcher`: per machine, user scope, from the GitHub marketplace `Black-coffe/vulyk`;
  idempotent; `--check` prints `would install` / `would update`; respects `enabledPlugins["<id>"]: false`; prints a
  NOTE and never fails when `claude` is absent. `install.sh:1262` calls it. The pulse needs the same once more:
  generalise to `install_mod <id>` or call a twin; the story decides, the simplest that keeps both outputs.
- Tests that pin the watcher install: `tests/telemetry.test.sh:15-17, 1416-1430+` (stubbed `claude`, `WID=...`), and
  CI `.github/workflows/*.yml:249-256` (fresh install and upgrade: no settings key, mod tree present).
- `tests/watcher.test.sh`: `claude plugin validate` of the mod and of the root marketplace, then `claude plugin test`.
  The `## Commands` row "Watcher mod" names it; a pulse check can extend it to both mods or add a sibling script
  with its own `## Commands` row.

## VULYK data the row can read

- Phase from agent types (`agent.spawn.subagentType`): `worker-code`/`worker-test` build, `lead-review` and
  `council-*` council, `queen-planner`/`drone-scout`/`drone-coverage` plan, `lead-architect` design,
  `drone-docs`/`librarian` docs, `cycle-clerk` clerk (agent list: `.claude/agents/`).
- Wave and round: `bash scripts/cycle.sh status docs/specs/<slug> --json` prints one JSON object with `stage`,
  `wave`, `wave_stories`, `round`, `ceiling`, `tier`, `open` (checked on `vulyk-watcher`). The spec path is the
  Workflow call's `args.spec` (`.claude/commands/vulyk-build.md` step 3: `args: {spec: "docs/specs/<slug>", ...}`),
  readable from a `tool.call` hook on `Workflow`. `$.process.run(argv)` runs it (no shell, 30 s default).
- Weights: `scripts/token-report.py:18-19, 57, 154, 423` - weighted = input + 1.25 x write(5m) + 2 x write(1h) +
  r x read + output, r = 0.05 Opus 5.5, 0.025 Fable/Mythos 5.1, else 0.1. `ModelUsage` does not split 5m/1h
  writes: weight every write 1.25 and say so.

## Facts from the probe (study.md "Probe results")

- `turn.step` pass-through (`async function*`, `const r = yield* next(e)`): `r.usage` per API response, every loop,
  `e.agentId` set for subagents. Live sum = the row's figure. `turn.complete.usage` = the sum of that loop's steps.
- `agent.spawn` result `agentId`, input `subagentType`, `background`, `workflow` (null for the Agent tool; a
  workflow agent's `workflow.runId` confirmed by the probe Workflow, see study.md).
- The engine's spinner figure is the main loop's output only: the row must replace the Spinner line (tree), not
  rewrite its `word`.
- A Tier 3-4 build is a background Workflow: the Queen's turn ends at launch, so the `AbovePrompt` band is the site
  during a build; `e.props.isWorking` tells when the Spinner covers it instead.
- `$.clock.every(125)` -> `$.ui.invalidate('ui.render')` drew a steady 8 fps band; no flicker on the owner's terminal.
- The watcher already draws in `AbovePrompt` (its note, rarely). Both hooks chain: pulse returns `next(e)` whenever it
  has nothing to show or a survey is up; the planner decides who yields when both have something (the watcher's note
  is the rarer and more important one).
