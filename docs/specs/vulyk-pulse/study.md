# vulyk-pulse: study (2026-10-16)

Study work, no story yet. Owner's ask (2026-10-16, verbatim): «добавить анимацию, когда вуллык работает, чтобы мы
показывали, что процессы идут и движение какое-то есть ... И таймер, который будет показывать, сколько мы работаем и
сколько токенов мы спалили вместе со всеми агентами взятыми, то есть сабагенты, королева, все-все полностью. Я хочу
это красиво, нативно, современно сделать.»

Inputs: [study-recon-sonnet.md](study-recon-sonnet.md) (Sonnet 5.5, API facts with d.ts line numbers) and
[study-design-fable.md](study-design-fable.md) (Fable 5.1, design and architecture). Both read Claude Code 2.1.300's
mod API declarations; nothing was run live.

## The correction that changes the placement

Fable's design stands on "in VULYK the build is a running main turn, so the Spinner is on screen for the whole
build". It is not: the Workflow tool returns at once with `{status: 'async_launched', taskId, runId}` (the tool's
own description; d.ts 22242-22262 per recon) and the Queen waits for a task notification with her turn ended. So
during a Tier 3-4 build, the hours that matter most, no Spinner is drawn. The band above the prompt
(`AbovePrompt`, drawn idle or working) is the main stage; the Spinner rewrite covers foreground turns (Tier 1-2
council dispatches, plain chat).

## Synthesis

- **Sites.** The `AbovePrompt` band shows the indicator whenever anything is live and the main turn is idle
  (a Workflow run, background agents). The `Spinner` line is replaced by the same row while a main turn runs, so the
  two never show together. `TurnDuration` (`Baked for 3s`) gets the turn's total appended. Rejected: `$.ui.status`
  (plain text), a `Pane` (too heavy), `Raster` + blit (raw RGB ignores the theme; a one-cell glyph at 8 fps needs
  neither).
- **Motion.** One animated cell cycling the engine's own spinner dingbats `· ✢ ✳ ✶ ✻ ✽` in theme colour `claude`,
  frame derived from `$.clock.now()`, redraw via `$.clock.every` + `$.ui.invalidate` (capped at 10/s for the
  spinner, 30/s for an expanded band). Fixed-width numbers so nothing shifts. No emoji, no `⬡⬢`. `userConfig`
  `motion: on | slow | off`, since the API has no reduced-motion signal.
- **Tokens.** One figure, `≈1.8M tok`: weighted tokens by `token-report.py`'s formula, the same unit
  `/vulyk-status` and `/vulyk-evolve` print, summed over every loop (`turn.step` stop usage live,
  `turn.complete.usage` per agent as reconciliation, keyed by `agentId`). Workflow agents run in-process and carry an
  `agentId`, so they are counted. Missed, and said so in the docs: a plugin's own `$.model.fork` (the watcher keeps its
  own ledger), turns ending without usage (interrupt, API error), anything before the mod loaded.
- **State.** `$.state` atoms (survive a hot reload, drive the redraw); no file ledger, since the transcripts are the
  ledger of record.
- **Architecture.** A new mod `vulyk-pulse` beside `vulyk-watcher`: a gauge rather than a judge, never calls the
  model, has its own off switch and fails on its own. Second entry in the root `marketplace.json`; install.sh's
  `install_watcher` becomes `install_mod <id>`. Tier 3 (mod + installer + marketplace), two stories in one wave,
  plus an optional third for wave/round numbers via `cycle.sh status`.

## Probes before the plan (unconfirmed in the declarations)

1. Does the engine's own spinner token count already include subagents? (If it does, a `word`-only rewrite is a v0.)
2. Field names of `turn.step`'s stop-chunk usage, and whether workflow agents' steps reach a plugin's hook.
3. Does `$.session.usage().cost.usd` include subagents and workflow agents (a cross-check figure)?
4. Real flicker of a 10/s Spinner tree and a 30/s band on the owner's terminal.

## Probe results (2026-10-16, throwaway mod `pulse-probe`, two background Haiku agents)

1. **Native spinner token scope: main loop output only.** The owner's screenshot shows the engine's line
   `Ionizing… (1m 2s · ↓ 5.2k tokens)` beside the probe band `main ≈67.5k · all ≈241.1k · done ≈173.7k`; the log's
   main-loop output was 5,152, and with the two agents' output it would read about 9.3k. So the native figure cannot
   answer "all agents", and the tree that replaces the line is required. On the same screenshot all = main + done
   (67.5k + 173.7k): `done` adds an agent only when its run ends and the Queen's own turn was still open, so the row
   uses the live `turn.step` sum alone.
2. **Live per-agent usage: confirmed.** `turn.step` (pass-through generator, `yield* next(e)`) returns
   `TurnStepResult.usage` = `{input_tokens, output_tokens, cache_read_input_tokens, cache_creation_input_tokens,
   model}` for every API response of the main loop *and* of each subagent, with `e.agentId`. `turn.complete.usage`
   equals the exact sum of that agent's steps (agent 1: output 269 + 844 = 1113, write 45649 + 11695 = 57344), so
   `turn.complete` adds nothing but a cross-check. `agent.spawn` gives `subagentType`, `background`, `model`,
   `agentId`, `workflow: null` for the Agent tool. `classic.SubagentStop` fires just before the agent's
   `turn.complete`. A one-agent probe Workflow (`wf_de08007c-5ba`, Haiku) confirmed workflow agents too:
   `agent.spawn` with `workflow: {runId, agentIndex: 1}` and `subagentType: workflow-subagent` (no `agentType` was
   given), two `turn.step` rows with usage, then `turn.complete` (output 279 + 361 = 640). The Workflow `tool.call`
   result is `{status: 'async_launched', taskId, runId, ...}`; its arguments sit flat on the event, not under `e.input`.
3. **`cost.usd`** rises while subagents run (8.1996 -> 8.2032 between the two agents' ends); whether it holds every
   subagent's full price is not settled. Not used: the row shows weighted tokens.
4. **Flicker: none.** The owner saw the test band animate at 8 fps (`$.clock.every(125)` -> `$.ui.invalidate`)
   above the prompt, steady. The Spinner site re-rendered every 125 ms too, from the same invalidate.

Side fact: the Agent tool's printed `subagent_tokens` (58,190 for agent 1) is neither the raw (104,110) nor the
weighted spend, which is the same trap as the Workflow's `totalTokens`.

## Owner decisions (2026-10-16)

- Look: the swarm row, `✻ VULYK · build · wave 2 · ●●●· · 12m 04s · ≈1.8M tok`, one dot per agent.
- Scope of the timer and tokens: per task, from the owner's prompt until the last agent finishes.
- Where: VULYK hives only (the watcher's `isHive` test); other projects keep the native spinner line.
- Next: `/vulyk-plan`, Tier 3.
