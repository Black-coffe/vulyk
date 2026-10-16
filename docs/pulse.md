# The VULYK pulse

A small gauge mod for Claude Code. It shows how long the current task has run, how many agents are working and roughly
how many tokens they used. It never calls the model, so it costs nothing to leave on.

## What the row shows, and where

`✻ VULYK · build · wave 2 · ●●●· · 12m 04s · ≈1.8M tok`

- `✻` is the spinner glyph, drawn in the theme colour.
- The phase word (`build`, `council`, `agents`...) comes from the kinds of agents that are live.
- `wave N` shows while the phase is `build`, `round N` while it is `council`. It comes from `cycle.sh status --json`
  for the spec the Workflow was launched with. With no known spec (Tier 1-2 work, plain chat) nothing is shown.
- One dot per agent of the task: `●` live, `·` finished. At most 10 dot cells; finished dots go first, and past 10 live
  agents the row reads `●×N`. Every 500 ms one live dot dims, walking left to right, so each running agent visibly moves.
- Then the task timer and the token figure.

It appears in three places:

- It replaces the `Spinner` line while the main turn runs.
- It fills the band above the prompt while the main turn is idle and agents are still live. In a Tier 3-4 build this is
  the main place: the Queen's turn ended when the Workflow launched. If the watcher has a note to draw, the note wins.
- The `Baked for ...` closing line becomes `<word> for <task time> · N agents · ≈X tok`. The agents part is dropped at 0.

## What a task is

A task opens at your message. It closes when two things have both held for 60 seconds: the main loop is idle and no
agent is live. A turn or a spawn inside those 60 seconds joins the open task, so a build's pauses between agents and the
Workflow's completion notice stay in one task, and the closing line carries the build's total. Timer and tokens both
cover the task. The 60 seconds is a first guess.

## Motion

Set `motion` in `/config`: `on` (125 ms per frame, the glyph ping-pongs over `· ✢ ✳ ✶ ✻ ✽`), `slow` (500 ms) or `off`
(a static `✻`, redrawn once a second so the numbers stay live; the dots stop breathing).

## What `≈tok` counts, and what it misses

Weighted tokens of every agent together (the Queen, subagents, workflow agents), summed live from each response's usage:
input + 1.25 x every cache write + the per-model rate x cache read + output. The cache-read rate is the one in
`scripts/token-report.py`.

It misses:

- A plugin's own forked model calls (the watcher keeps its own ledger).
- A response with no usage (an interrupt, an API error).
- Anything before the mod loaded.

The mod cannot tell 5-minute cache writes from 1-hour ones, so every write is weighted 1.25. The weekly token report has
the finer figure. The row is a gauge, not the ledger.

## Where it runs

- Hive only. Outside a VULYK hive every hook passes through and the native line stays.
- Terminal only. On desktop and vscode the three sites return the native line.

## Install and off switch

`install.sh` installs `vulyk-pulse@vulyk` beside the watcher, once per machine, at user scope, from the root marketplace;
`--upgrade` refreshes it. Restart `claude` to apply it.

To turn it off in one hive, set `"vulyk-pulse@vulyk": false` under `enabledPlugins` in that hive's
`.claude/settings.json` or `.claude/settings.local.json`. The installer respects it and never writes it.
