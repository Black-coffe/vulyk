---
story: vulyk-watcher-01
spec: vulyk-watcher
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# Package the watcher mod and measure how a hive loads it

## Goal
`.claude/mods/vulyk-watcher/` exists as a valid mod. It holds `plugin.json`, `marketplace.json` (marketplace `vulyk`,
root = this folder, `"source": "./"`), `hooks/hooks.json` and a stub `hooks/register.tsx` that subscribes to
`turn.complete` and does nothing else. `claude plugin validate` passes on it. The story's real output is five measured
answers, written under `## Implementation notes` with the exact debug lines and commands. The Queen copies them into
plan `## Plan deltas` before wave 2 starts.

- **M1:** in a fresh temp hive (outside this repo), set project `.claude/settings.json` to `extraKnownMarketplaces.vulyk`
  with `"source": "directory"` and a project-relative path, plus `enabledPlugins["vulyk-watcher@vulyk"]: true`. Does
  `claude -p --debug` log the hooks module of `vulyk-watcher@vulyk` as loaded, with no trust or approval error? Run the
  controls too: with `.claude/settings.local.json` set to `false` it does not load; with no key it does not load; the
  built-in `cc-plugin-you-should-know@builtin` still loads beside it. Which path forms work: relative to the project,
  `${CLAUDE_PROJECT_DIR}`, absolute only?
- **M2:** only if M1 fails or needs an absolute path, does `CLAUDE_CODE_PLUGIN_DIRS` load the mod, set in the shell
  and then in the settings `env` block?
- **M3:** from the bundled plugin-authoring reference and `types/claude-code.d.ts` (cite the names, never guess), find:
  - the call that puts text into the main chat (the built-in's "Chat in main session");
  - whether `$.fs` can list a folder;
  - how a mod learns the project root;
  - what the `turn.complete` payload carries (tool calls of the turn?);
  - whether `.ts` sibling imports from `register.tsx` load.
- **M4:** does the mod load and does `turn.complete` fire with `DISABLE_TELEMETRY=1`?
- **M5:** does a `$.model.fork` request show up in the session transcript JSONL with `usage`? Answer it with a
  throwaway fork in the temp hive's copy only; the committed stub never forks.

## Requirements
> 1. Свой наблюдатель VULYK работает рядом со встроенным «You should know», а не вместо него.
> Наш мод в составе VULYK (ставится в каждый улей через install.sh) работает рядом со встроенным.

## Files
- tests/watcher.test.sh
- .claude/mods/vulyk-watcher/.claude-plugin/plugin.json
- .claude/mods/vulyk-watcher/.claude-plugin/marketplace.json
- .claude/mods/vulyk-watcher/hooks/hooks.json
- .claude/mods/vulyk-watcher/hooks/register.tsx

## Non-goals
- No watcher logic, prompt, band or fork in the committed `register.tsx`: that is -02's.
- No edit of `install.sh`, `.claude/settings.json` or CI: that is -03's, after the delta.
- Do not edit `plan.md`: the measurements go into this story's notes, and the Queen writes the delta.
- Never paste a debug log or a path from any other project into this repo (card `host-internals-in-public-repo`).
  The temp hive is a synthetic folder in your temp dir; quote only the lines that answer M1-M5.

## Map slice
`docs/specs/vulyk-watcher/recon.md` `## Claude Code mod API`; `docs/specs/you-should-know/plan.md` `## Facts this plan
rests on` (how the built-in key was measured).

## Acceptance criteria
- [ ] `claude plugin validate .claude/mods/vulyk-watcher` exits 0.
- [ ] `tests/watcher.test.sh` runs `claude plugin validate .claude/mods/vulyk-watcher`, and `claude plugin test` on it once a `*.test.ts` exists; with no `claude` on PATH it exits 2 with one line, never a vacuous green. Its `## Commands` row (`| Watcher mod |`) was added at plan time by the Queen.
      This story adds it because its Verification names it.
- [ ] `## Implementation notes` answers M1-M5 (M2 only if needed). Each answer gives yes/no/value, the command, and the
      debug line or d.ts name that shows it.
- [ ] If `"source": "./"` is refused, the layout used instead stays inside `.claude/mods/vulyk-watcher/` and is named
      in the notes.

## Verification
`bash tests/watcher.test.sh`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Implementation notes
Files: tests/watcher.test.sh, .claude/mods/vulyk-watcher/{.claude-plugin/plugin.json, .claude-plugin/marketplace.json, hooks/hooks.json, hooks/register.tsx}. `claude plugin validate` passes (build 2.1.300; `"source": "./"` accepted).
Stub API fact (changes -02): `import type { Register } from 'claude-code'`; `export const register: Register = on => { on('turn.complete', async ($, e, next) => next(e)) }`. The first draft `({ on }) =>` was refused by validate: "the parameter that receives on is not a plain name". Hooks take `($, e, next)` and must return `next(e)`.
Measured in a synthetic temp hive, `claude -p --debug-file dbg.txt "say ok" </dev/null` (`--debug` swallows the prompt; the file appends, rm it between runs).
- **M1: NO.** Project `.claude/settings.json` with `extraKnownMarketplaces.vulyk` (`source: directory`) + `enabledPlugins["vulyk-watcher@vulyk"]: true` does not load the mod in `-p`. Lines: `Skipping orphaned enabledPlugins entry vulyk-watcher@vulyk: marketplace not registered`, then `Skipped auto-recording vulyk-watcher@vulyk - enabled only by repo-authored settings`. Same for all four path forms: `./mods/x`, `mods/x`, absolute `C:/...`, `${CLAUDE_PROJECT_DIR}/mods/x`. No "hooks module vulyk-watcher@vulyk loaded" line. The interactive trust question was not measurable here (stays open, plan Open questions). The built-in `cc-plugin-you-should-know@builtin` still loaded beside it (a user-scope key was on, so the built-in's own no-key control was not run).
- **M2: partly.** `CLAUDE_CODE_PLUGIN_DIRS=<absolute path>` in the shell loads it: `hooks module vulyk-watcher@inline loaded (worker, environment 1, tier user); events: turn.complete`, with no `enabledPlugins` key. Id is `vulyk-watcher@inline`, not `@vulyk`; `{"enabledPlugins":{"vulyk-watcher@inline":false}}` in `.claude/settings.local.json` switches it off (no load line). Relative path refused: `CLAUDE_CODE_PLUGIN_DIRS: skipped ./mods/x: a plugin folder here is an absolute local path or starts with ~`. In the project settings `env` block (absolute or `${CLAUDE_PROJECT_DIR}`): `[WARN] CLAUDE_CODE_PLUGIN_DIRS in .claude/settings.json is ignored - project-scoped settings can't set this key. Set it in ~/.claude/settings.json or managed settings instead.` `claude --plugin-dir <path>` also exists. So a committed project file cannot load the mod by either route; a hive needs a user-scope setting or an interactive marketplace add.
- **M3** (probe mod on the real engine; names also found in the binary):
  - text into the main chat: `$.prompt.fill({ text, mode })`, mode `replace|append|insert` (binary: `prompt.fill`, `ui_prompt_fill`: places text as the person's draft, answers `{filled}`, false with no composer). Also present: `$.prompt.suggest`, `$.session.send`, `$.ui.toast`. Not exercised in `-p` (no composer). The built-in's "Chat in main session" is a menu option inside its own output text, not an API name.
  - `$.fs.list('.')`: yes, returns `[{name, kind: 'file'|'dir', size, mtimeMs, isLink}]`; relative paths resolve against the project dir.
  - project root: `await $.session.cwd()` returned the hive folder; debug `$.fs.write (vulyk-watcher): <hive>/probe.json`.
  - `turn.complete` payload keys: `answer, durationMs, isAborted, turnId, reason, usage` (usage: input_tokens, output_tokens, cache_read_input_tokens, cache_creation_input_tokens, model). NO tool calls of the turn: collect them with `tool.call` hooks per turn.
  - `.ts` sibling import from `register.tsx` (`import { marker } from './helper'`): loads, value seen.
- **M4: YES.** With `DISABLE_TELEMETRY=1`: `hooks module vulyk-watcher@inline loaded` and `vulyk-watcher@inline turn.complete settled in 2.0ms`; the built-in you-should-know is skipped in that run, ours is not.
- **M5: NO.** `$.model.fork({ prompt })` returned `{isAnswered: true, text: 'FORKED', usage: {input_tokens: 18, output_tokens: 6, cache_read_input_tokens: 21280, cache_creation_input_tokens: 17752}}` (debug: `Forked agent [plugin_model_fork] finished ... totalUsage`). The session transcript JSONL holds no `FORKED`, no fork prompt, no `plugin_model_fork`: fork cost is visible only in the returned `usage`; a cost ledger must write it itself.
- Temp hive and its transcript folder removed.

## Findings
