# VULYK pulse: a live swarm row with timer and all-agent tokens (plan)

**Tier:** 3 · **Spec slug:** `vulyk-pulse` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-005 (installer upgrade contract), ADR-015 (Sonnet builds), ADR-016 (constitution size cap: no new
`## Commands` row), cards `upgrade-overwrites-host-edits`, `framework-fix-skips-live-hives`,
`host-internals-in-public-repo`
**Depends on:** `vulyk-watcher` (0.27.2, e4f5052): mod layout, `isHive`, root marketplace, `install_watcher`,
`tests/watcher.test.sh`; Claude Code 2.1.300 mod API ([study.md](study.md) "Probe results")

## Goal
Ship a second VULYK mod, `vulyk-pulse`, in `.claude/mods/vulyk-pulse/`. It is a gauge: it never calls the model.
In a VULYK hive it draws one row:

`✻ VULYK · build · wave 2 · ●●●· · 12m 04s · ≈1.8M tok`

- The `✻` cycles the engine's own spinner glyphs in theme colour.
- There is one dot per agent of the task: `●` live, `·` finished.
- The phase word comes from the live agent types; wave or round comes from `cycle.sh status --json`.
- The timer runs from the owner's message until the last agent ends.
- Tokens are weighted the same way as in `token-report.py`, summed live from every loop's `turn.step` usage: the
  Queen, subagents and workflow agents.

Where the row shows:

- It replaces the `Spinner` line while a main turn runs.
- It fills the `AbovePrompt` band while the main turn is idle and agents are live. During a Tier 3-4 build this is
  the main site, because the Queen's turn ended at the Workflow launch.
- The `Baked for ...` line gets the task's agent count and tokens appended.

Motion is set in `/config` (`on | slow | off`). Outside a hive every hook passes through and the native line stays.

The installer installs the mod beside the watcher, once per machine, from the root marketplace. Releasing it and
taking it to live hives are the Queen's work after GREEN, not a story's.

## Assumptions
- **The task (Ask 2).** A task opens at the owner's prompt on the main loop. That is a `prompt.submit`-style hook if
  the API has one, else the main loop's `turn.start` while no task is open.
  - It closes when two things have both held for 60 s: the main loop is idle and no agent is live.
  - A main turn or a spawn inside those 60 s joins the open task. So the Workflow's completion notification, and
    any short gap between driver agents, stay inside one build's task, and the closing line carries the build's
    total.
  - The timer and the token sum both cover the task.
  - The 60 s figure is a guess that the first real build confirms.
- **Tokens (Ask 3).** Weighted = input + 1.25 × every cache write + r × cache read + output. The read rate r is
  `token-report.py`'s per-model rate.
  - `ModelUsage` does not split 5-minute from 1-hour writes, so every write is weighted 1.25. The weekly report has
    the finer figure.
  - Not counted, and the docs say so: a plugin's own `$.model.fork` (the watcher keeps its own ledger), a response
    with no usage (interrupt, API error), and anything before the mod loaded.
  - The figure is the live `turn.step` sum alone. `turn.complete.usage` only repeats it (probe 2), so there is no
    reconciliation.
- **Workflow agents: confirmed live (2026-10-16, one-agent probe Workflow `wf_de08007c-5ba`).** A workflow agent raises
  `agent.spawn` with `workflow: {runId, agentIndex}`, `background: false`, and then `turn.start`, a `turn.step` with
  usage per response and `turn.complete`, all under its own `agentId`. With no `agentType` in the script,
  `subagentType` is `workflow-subagent`. The VULYK driver passes `agentType` (`worker-code`, `lead-review`,
  `cycle-clerk`...), which is expected to arrive as `subagentType`; `workflow-subagent` maps to the generic `agents`
  phase word. The Workflow `tool.call`'s arguments sit flat on the event (`e.args.spec`, `e.scriptPath`), not under
  `e.input`. Its result is `{status: 'async_launched', taskId, runId, ...}`.
- **Wave and round (Ask 1).** The spec path is the Workflow call's `args.spec`, read by a `tool.call` hook on
  `Workflow`. `bash scripts/cycle.sh status <spec> --json` runs at that call and at each `agent.spawn` while a spec
  is known.
  - The row shows `wave N` while the phase is `build` and `round N` while it is `council`.
  - Nothing is shown when no spec is known, as in Tier 1-2 dispatches and plain chat, or when the command fails.
- **The band.** The watcher's note wins when both mods have something to draw. Pulse asks the chain first and draws
  its row only when nothing else drew. It passes through on `isWorking`, on `hasSurvey` and when nothing is live.
- **Motion.** `userConfig.motion` defaults to `on`: 125 ms per frame, ping-pong over `· ✢ ✳ ✶ ✻ ✽`. `slow` is
  500 ms. `off` draws a static `✻` and redraws once a second, so the numbers stay live.
- **Surface.** Terminal only. On desktop and vscode, `Spinner`, `AbovePrompt` and `TurnDuration` all return `next(e)`.
- **Dots.** There is one dot per agent of the task: `●` live first, then `·` finished.
  - At most 10 dot cells. Finished dots are dropped first.
  - Past 10 live agents, the row shows `●×N`.
  - The live dots breathe: every 500 ms one live dot is drawn `dimColor`, walking left to right, so each running
    agent visibly moves. The owner chose the swarm row as presented with this (2026-10-16); `motion: off` stops it.
- **The closing line.** `TurnDuration` becomes `<engine word> for <task elapsed> · N agents · ≈X tok`. The agents part
  is dropped at 0. For a plain chat turn, the task elapsed equals the turn time.
- **Row text is English** (`VULYK`, `build`, `wave`, `tok`), as in the approved mockup.
- **No new `## Commands` row.** `tests/watcher.test.sh` (row `Watcher mod`) is extended to validate and test both mods.
  The constitution sits at its ADR-016 cap, and one wrapper for one marketplace is simpler than two.
- **Release and rollout (Ask 7 after GREEN), the Queen's:**
  - `/vulyk-ship` bumps `VERSION` and both mods' `plugin.json` versions (the watcher test pins both to `VERSION`).
  - The Queen runs `install.sh` on this machine. The mod is installed at user scope, so every hive on the machine
    gets it after a `claude` restart.
  - Live hives get the `OWNED` tree at their audited `--upgrade` (cards `framework-fix-skips-live-hives`,
    `upgrade-overwrites-host-edits`).

## Stories

**Wave 1** (parallel, disjoint files)
- `vulyk-pulse-01` — the mod. It covers:
  - `plugin.json` (with `userConfig.motion` and the types contract), `hooks.json`, `types/index.d.ts`;
  - `core.ts`: weights pinned to `token-report.py`, formats, frames, phase, dots, row and narrow row, task rules;
  - `register.tsx`: hive gate, task tally, `cycle.sh status`, the `Spinner`, `AbovePrompt` and `TurnDuration` sites;
  - `core.test.ts`, and `tests/watcher.test.sh` extended to both mods.
- `vulyk-pulse-02` — shipping and docs. It covers:
  - the root marketplace entry;
  - `install.sh`: `install_watcher` becomes `install_mod <id>`, called twice, and `OWNED` gets the pulse tree;
  - `tests/telemetry.test.sh` pins and CI `install-smoke` lines;
  - `docs/pulse.md` and a `docs/token-economy.md` paragraph.

Wave and round are folded into -01, not given a story of their own (see `## Rejected alternative`).

## Contracts
- **Identity.** Marketplace `vulyk`, plugin `vulyk-pulse`, id `vulyk-pulse@vulyk`, tree `.claude/mods/vulyk-pulse/`.
  The root `.claude-plugin/marketplace.json` entry is `{ "name": "vulyk-pulse", "source": "./.claude/mods/vulyk-pulse",
  "description": ... }`, the same shape as the watcher's.
- **File ownership.**
  - -01 owns everything under `.claude/mods/vulyk-pulse/` and `tests/watcher.test.sh`.
  - -02 owns `.claude-plugin/marketplace.json`, `install.sh`, `tests/telemetry.test.sh`, `.github/workflows/ci.yml`,
    `docs/pulse.md` and `docs/token-economy.md`.
  - Neither edits the other's paths; a needed change goes back as an INTERFACES line.
- **`plugin.json` shape.**
  - It carries `name`, `version` (= `VERSION`), `description` and `author`, as the watcher's does.
  - It adds `userConfig.motion`: a string with `options` `on`, `slow`, `off`, default `on`.
  - It adds `"types"`, naming the `$.state` contract file.
- **Off switch.** As for the watcher: `enabledPlugins["vulyk-pulse@vulyk"]: false` in a hive's `.claude/settings.json`
  or `.claude/settings.local.json`.
- **Test entry point.** `bash tests/watcher.test.sh` covers both mods:
  - it runs `claude plugin validate` on `.claude/mods/vulyk-watcher`, on `.claude/mods/vulyk-pulse` and on the root
    marketplace;
  - it runs `claude plugin test` on both mods;
  - it checks the version pin to `VERSION` for both mods, and the weights pin;
  - it exits 2 with one line when `claude` is absent.
- **Order inside wave 1.**
  - -02's local tests must not need -01's files. Those files are untracked until -01 commits, so
    `tests/telemetry.test.sh` stubs `claude` and asserts install calls and output lines, never the pulse tree.
  - The pulse tree's presence after a fresh install and after an upgrade is asserted in CI only, which runs after
    both commits.
  - If `OWNED` listing a tree that is not yet committed breaks a local install test, -02 returns NEEDS_CONTEXT naming
    it. It does not work around it.
- **`install_mod <id>` output.** It prints, per id, exactly the lines `install_watcher` prints today for the watcher:
  - `would install` and `would update` under `--check`;
  - the refresh on `--upgrade`;
  - the NOTE without `claude`;
  - an owner's `enabledPlugins[id]: false` is respected.

  The watcher's existing pins stay green unchanged.
- **Behaviour that `docs/pulse.md` describes,** as fixed by `## Assumptions` above:
  - the sites and when each shows;
  - the row and narrow forms (`✻ build ●●●· · 12m · 1.8M`) and the closing line;
  - motion;
  - the token unit and what it misses;
  - the task definition;
  - hive-only and terminal-only;
  - the off switch.

## Integration gate
`bash tests/watcher.test.sh` · `bash tests/telemetry.test.sh` · `git ls-files '*.sh' | xargs -n1 bash -n` · `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Rejected alternative
A separate story -03 for the wave and round numbers, wave 2, blocked by -01. It would edit `register.tsx` and `core.ts`
again: the same files as -01, so it could never run in parallel. Its diff is small: one `tool.call` hook, one
`$.process.run` and one JSON field read. Paying a second worker's orientation and a second close for that fails the
merge test. -01 holds it at little extra cost, and Ask 1 needs it in v1 anyway.

## Open questions
- **The 60 s settle window** in `## Assumptions` is a guess. If the first real build shows the band dropping and the
  timer restarting between driver agents, the Queen records the measured gap as a delta.
- **The d.ts answers -01 settles:**
  - whether a `prompt.submit` hook exists;
  - what `next(e)` returns for an `AbovePrompt` nobody draws;
  - the exact `userConfig` and `"types"` keys.

  -01 cites the names in its notes and never guesses.
- **`install.sh` and missing trees.** Does `install.sh` copy `OWNED` trees from `git ls-files` or from the working
  tree? A scout question if -02 hits the order problem in `## Contracts`.

## Descoped

*(empty)*

## Plan deltas

**Approved:** Andrei, 2026-10-16
**Briefed:**
**Branch:** vulyk/vulyk-pulse
**Checked:**
**Council:**
**Council:** RED round 1, 2026-10-16, at f483469, pack 1f2f744b6f2b - red: 2
**Shipped:**
