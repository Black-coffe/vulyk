# Recon: vulyk-watcher (2026-10-15)

## Claude Code mod API (build 2.1.300, bundled plugin-authoring reference.md + types/claude-code.d.ts)
- A third-party mod is a folder: `.claude-plugin/plugin.json`, `hooks/hooks.json` (`{"modules": ["./register.tsx"]}`),
  `hooks/register.tsx` exporting `register: Register`. No build step: the engine loads TSX itself, no DOM, no Node.
- `on('turn.complete', ...)` fires once per turn; `turn.step` per model request (what the built-in mod hooks).
- `$.model.fork({ prompt })`: one tool-less question over the session's own transcript, same model and system prompt,
  prefix served from the prompt cache. Reasons on no answer: `nothing-to-fork`, `api-error`, `empty-reply`, `aborted`.
- `$.session.messages()` + `$.model.complete({ model: "haiku", prompt })`: the cheaper path, no history of its own.
- `ui.render` on `{ component: 'AbovePrompt' }` draws a band above the prompt (`Box`, `Text`, `Button` from
  `$.ui.resolve(e)`); `$.state` per session, `$.store` across sessions; `$.fs.read/write`; `$.ui.toast/status`.
- Distribution: a marketplace (`.claude-plugin/marketplace.json`, `"source": "./mods/<name>"`); a folder marketplace is read
  from the folder itself, no reinstall on edit. Settings carry `extraKnownMarketplaces` (`"source": "directory"` or
  `"github"`, the owner's user settings use both) and `enabledPlugins` (`<name>@<marketplace>`).
- Checks: `claude plugin validate <folder>`, `claude plugin test <folder>` (`*.test.ts`), `tsc -p <folder>`.
- Not verified: whether a project-scope `extraKnownMarketplaces` directory source loads without an interactive trust
  question in a fresh hive. A first story must measure it.

## VULYK side (drone-scout, file:line in install.sh unless named)
- Ship: tree loop :1092 copies `.claude` whole, so `.claude/mods/vulyk-watcher/` ships on fresh install with no edit.
  Upgrade replaces only `OWNED` trees (:52): add `.claude/mods/vulyk-watcher` there. `shippable()` :67-91 is a deny list
  (add `node_modules` if any). CRLF strip :1080-1086 and `.gitattributes` :1061 cover `*.sh`, `*.py`, `workflows/*.js` only.
- `wire_plugin` :951-1012 is hardcoded to `cc-plugin-you-should-know@builtin`; rc 0 wired / 3 already true / 6 owner
  value kept / 4 unparseable. A second id needs a parameter. VULYK's `.claude/settings.json:3-5` carries the key.
- Install wiring is tested inline in `.github/workflows/ci.yml` `install-smoke` (:190-540, plugin key :247-248). Node 22
  only in the `driver` job (:142-144); no tsc/bun anywhere. CI does not run defects/intake/inject suites.
- Defect library: `docs/defects/README.md` :7-83 (frontmatter id/title/status/check/fixtures/keys/paths; owner quotes
  verbatim; gate: undeliverable text card, key overlap, debt). VULYK's own cards never ship (`shippable()` :75): a hive's
  library is its own. No inbox/queue exists; `defect-intake.sh` (UserPromptSubmit) only tells the model to write a card.
  Card parsing exists three times already (defects-check.sh, intake, inject).
- `defects-inject.sh` (PreToolUse) matches by path/cmd only, injects `## Never` lines of `text` cards.
- Laws a transcript reader can judge: CLAUDE.md :8-13 (1, 3, 5, 6 concretely; 2 and 4 softly).
- `scripts/telemetry.sh scan --transcript` reads transcripts at SessionEnd, 10 quantitative codes, nothing per defect class.
