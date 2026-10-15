---
story: vulyk-watcher-01
spec: vulyk-watcher
status: todo
returned:
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

## Findings
