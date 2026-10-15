# VULYK's own watcher mod beside "You should know" (plan)

**Tier:** 3 · **Spec slug:** `vulyk-watcher` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-005 (installer upgrade contract: host settings.json appended in place, owner values kept), ADR-015
(Sonnet builds, Opus judges: the fork runs on the session model), Law 6 + `docs/defects/README.md` (cards are written by
the Queen only), cards `upgrade-overwrites-host-edits`, `framework-fix-skips-live-hives`, `host-internals-in-public-repo`
**Depends on:** `you-should-know` (0.25.0, `wire_plugin`, 6be3476), `top-model-pin` (0.26.2), Claude Code 2.1.300 mod API
([recon.md](recon.md))

## Goal
Ship VULYK's first mod, `vulyk-watcher`, in `.claude/mods/vulyk-watcher/`. Once per turn, on `turn.complete`, it asks
the session's own model, through `$.model.fork` over the cached transcript, whether the turn just finished breaks one
of the hive's constitution Laws or repeats a class in the hive's own `docs/defects/` cards. The bar is high and the
default answer is nothing. When there is something to say, it draws an `AbovePrompt` band in the user's language. The
band's «В defects» button hands the note to the main chat, and the Queen files the card through the existing intake
path. The installer ships the mod with a fresh install and with `--upgrade`, and enables it in every hive beside the
built-in `cc-plugin-you-should-know@builtin`. It keeps an owner's `false`; the per-machine off switch is
`.claude/settings.local.json`. Releasing it and taking it to live hives is the Queen's work after GREEN, not a story's.

## Assumptions
- **Id and layout.** Marketplace `vulyk`, plugin `vulyk-watcher`, id `vulyk-watcher@vulyk`. The marketplace root is the
  mod folder itself (`.claude-plugin/marketplace.json` beside `plugin.json`, `"source": "./"`), so everything the mod
  needs sits in the one `OWNED` tree `.claude/mods/vulyk-watcher`. If `"./"` is refused, -01 takes the nearest layout
  that stays inside that tree and records it as a delta.
- **Enabling a non-builtin mod.** Project `.claude/settings.json` gets `extraKnownMarketplaces.vulyk` (`"source":
  "directory"`, path relative to the project) plus `enabledPlugins["vulyk-watcher@vulyk"]: true`. This is not yet
  verified: -01 measures it with `claude -p --debug` in a fresh temp hive, and the result goes into `## Plan deltas`
  before wave 2.
  - **Fallback** if the project-scope directory marketplace does not load, or needs an absolute path: the
    `CLAUDE_CODE_PLUGIN_DIRS` env var, first through the settings `env` block (also measured by -01).
  - If neither loads without a machine path or a question, the Queen stops and asks the owner (Law 1: the work would
    differ materially).
- **The probe cannot see the trust dialog.** `claude -p` skips the interactive workspace trust dialog, so a clean `-p`
  load does not prove that an interactive fresh hive asks nothing. The Queen checks one interactive start in a fresh
  temp hive at rollout. If a trust question appears, she tells the owner it costs one approval per hive.
- **Cost guard (simplest).** No fork when:
  - the finished turn made no tool call;
  - a note is still on screen;
  - the session already showed 3 notes.

  A fork that returns `nothing-to-fork`, `api-error`, `empty-reply` or `aborted` stays silent: no retry, no toast.
  `turn.step` is never subscribed.
- **Anti-noise (simplest).** The reply carries a `tag:`.
  - A shown tag goes into `$.store` under the project root (the store is per mod, not per project), keeping the last
    200 tags. Stored tags are never shown again and are passed into the prompt so that the model skips them.
  - The band has two buttons: «В defects» and «Закрыть».
  - There is no separate known-list and no typed-past counters like the built-in's.
- **What the fork reads.**
  - The `## Laws` section of the constitution file: `CLAUDE.vulyk.md` if it exists, else `CLAUDE.md`, the same rule as
    `lib.sh` `constitution_file`.
  - The full text of every `docs/defects/*.md` card whose `status:` is not `revoked`, `README.md` excluded, capped at
    about 16 KB. Past the cap, each card is cut to its title and `## Never` lines.
  - Reading the `status:` line is the only parsing; nothing else in the card is read. A hive with no `docs/defects/` is
    judged on its Laws alone.
  - VULYK's own cards are not shipped (`install.sh` `shippable()`, `docs/defects/*` bar the README) and stay so: all
    four are about developing VULYK, their `paths:` name VULYK's own `install.sh`, `vulyk-ship.md`, `CHANGELOG.md`. A hive
    is judged on its own cards plus the Laws, which ship in its constitution; inside VULYK the watcher reads VULYK's cards.
    No shared feed of VULYK cards to hives (raised by the built-in side agent, 2026-10-15; the owner can veto here).
- **Language.** It is detected from the user's own messages only. Tool output and code are excluded: they are what
  sent the built-in mod into English before 2.1.290.
  - A Cyrillic majority with `і ї є ґ` gives `uk`, any other Cyrillic majority gives `ru`, and everything else gives
    `en`.
  - The labels are fixed strings for those three languages. The model is told to write the note in the language of
    the user's messages and is given the detected one as a hint.
- **A watcher note is never an owner quote (Law 6).** «В defects» fills the owner's prompt draft
  (`$.prompt.fill`, mode `replace`); the owner may type their own words above it and sends it. The note sits inside a
  fenced block headed «заметка наблюдателя - не цитата владельца» (in the user's language): `defect-intake.sh` strips
  code fences, so the note's words never trip intake keys. The request line asks the Queen to show the note and ask
  whether it is a defect; only the owner's own words (typed above the fence, or their reply) go under the card's owner
  quotes; the note's text may go to `## Cause`, never under quotes. A bare send with no own words gives the Queen a
  hint, not a quote: she asks. The mod writes nothing under `docs/defects/`. (Raised by the built-in side agent and
  relayed by the owner, 2026-10-15: a model's text submitted through the owner's prompt would have become «their» quote,
  and a second such quote would have demanded a `check:`.)
- **Language beyond three (coverage, Ask 6).** The note itself is written by the session model in whatever language
  the user writes, any language. Only the two button labels are fixed strings for `ru`/`uk`/`en`; any other language
  gets English buttons. Coverage flagged it; kept, because the owner writes in those three.
- **Tests: CI versus local.**
  - The mod's tests (`*.test.ts`, the Russian-conversation fixture among them) need the `claude` binary, which CI does
    not have. They are two local `## Commands` rows (`claude plugin validate|test .claude/mods/vulyk-watcher`), and
    `close-story` runs them on this machine.
  - CI covers the install wiring: `tests/telemetry.test.sh` locally, and `jq -e` on both keys plus a check that the
    mod tree exists in `install-smoke` after a fresh install and after an upgrade. It also covers the mod's JSON
    files, through the JSON-validity row.
- **Ask 7 is the Queen's, not a story's.** After GREEN:
  - `/vulyk-ship` cuts minor 0.27.0. Its release commit writes `CHANGELOG.md` and `VERSION`, and the Queen pushes and
    tags herself (owner rule "run it yourself").
  - The rollout is one audited upgrade per live hive. Before each `--upgrade`, compare the hive's framework files
    with the release it was installed from and carry its own edits and deletions over by hand (card
    `upgrade-overwrites-host-edits`). Check each hive's remote before any push. Bring every live hive along, a
    mid-build one included, or name why one is left (card `framework-fix-skips-live-hives`).
  - No hive name, folder, transcript slug or debug log from a hive is written into this repository: the rollout
    report stays in chat, and `scripts/leak-check.sh` runs before push (card `host-internals-in-public-repo`).
- **Token report.** Answer 4 says the weekly token report will show the cost. Whether fork requests appear in the
  session transcript with usage is unverified; -01 records it. If they do not, that becomes a next-circle note, not
  work in this spec.

## Stories

**Wave 1**
- `vulyk-watcher-01` — mod packaging (`plugin.json`, `marketplace.json`, `hooks.json`, a loading stub
  `register.tsx`), the `claude plugin validate` row, and the measured answers M1-M5 for `## Plan deltas`

**Wave 2** (parallel, disjoint files; both blocked by -01)
- `vulyk-watcher-02` — the watcher itself (opus): `turn.complete` + fork, Laws + cards prompt, high bar, band,
  «В defects», anti-noise, cost guard, language detection, `*.test.ts` with the Russian fixture, the `claude plugin
  test` row
- `vulyk-watcher-03` — the installer: `OWNED` tree, `wire_plugin` parameterised for a second id + the marketplace
  key, VULYK's own settings.json, tests, CI smoke, ADR-005 line, `docs/watcher.md`

## Contracts
- **Identity:** marketplace `vulyk`, plugin `vulyk-watcher`, id `vulyk-watcher@vulyk`; mod tree
  `.claude/mods/vulyk-watcher/` (marketplace root unless -01's delta says otherwise).
- **Settings (project `.claude/settings.json`):** `extraKnownMarketplaces.vulyk = {"source": {"source": "directory",
  "path": "<as measured by -01>"}}` and `enabledPlugins["vulyk-watcher@vulyk"] = true`. Off switch:
  `.claude/settings.local.json` `enabledPlugins["vulyk-watcher@vulyk"] = false`. If -01 lands on the fallback, this
  line is replaced by a delta before wave 2.
- **File ownership in the mod tree:** -01 owns `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` and
  `hooks/hooks.json` (`{"modules": ["./register.tsx"]}`). -02 rewrites `hooks/register.tsx` and adds `hooks/core.ts`,
  `hooks/core.test.ts` and `hooks/fixtures/*`. -02 does not edit -01's files; a needed change goes back as an
  INTERFACES line.
- **Mod behaviour that -03's docs page describes:**
  - It fires once per turn on `turn.complete`, never on `turn.step`. `turn.step` handling is the built-in mod's,
    which keeps its own key.
  - Skip rules: no tool call, a note already on screen, 3 notes this session.
  - Seen tags are kept per project in `$.store` (last 200).
  - Two buttons, «В defects» and «Закрыть», with labels in `ru`/`uk`/`en`.
  - The off switch is as above.
- **The «В defects» hand-off text,** in the user's language, filled into the prompt draft: one request line ("this is
  a watcher note, not my words: show it to me and ask whether it is a defect; only my own words go under owner quotes")
  then a fenced block headed «заметка наблюдателя - не цитата владельца» holding the note line, the explanation and the
  class it names (a card id, `law <n>` or `new`). Nothing is written to disk.
- **Verification wrapper:** `tests/watcher.test.sh` (from -01) runs `claude plugin validate` and, once tests exist,
  `claude plugin test` on `.claude/mods/vulyk-watcher`; exit 2 without `claude`. One `## Commands` row (`| Watcher
  mod |`), added at plan time; the constitution sat 11 bytes under its ADR-016 cap, so three of VULYK's own row labels
  were shortened to make room.

## Integration gate
`bash tests/telemetry.test.sh` · `git ls-files '*.sh' | xargs -n1 bash -n` · `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null` · `claude plugin validate .claude/mods/vulyk-watcher` · `claude plugin test .claude/mods/vulyk-watcher`

## Rejected alternative
Running the mod's logic tests in CI under Node 22's type stripping (the `driver` job): `register.tsx` is JSX and
depends on the engine's `$`. CI would need a second harness that mocks what `claude plugin test` already provides,
with nothing to keep the two in step (Law 2). The cost of choosing local-only: CI does not run the language test, and
`close-story` and the review run it on this machine instead.

## Open questions
- **Settled by the Queen, 2026-10-15** (Claude Code 2.1.300 bundled `types/claude-code.d.ts`): the chat hand-off is
  `$.prompt.fill({ text, mode })` (modes `replace` | `append` | `insert`: fills the owner's prompt draft, the owner sends
  it), and `$.fs.list(path?)` lists a folder (`FsEntry[]`). -01's M3 confirms both on the real engine.
- **wave-check `verify-gap` on -01 is a known false positive:** the shared JSON row's `/dev/null` is the only
  path token that exists at plan time (`tests/watcher.test.sh` does not exist yet).
- **The trust question.** It needs the interactive check at rollout (see `## Assumptions`).

## Descoped

*(empty)*

## Plan deltas

*(empty - vulyk-watcher-01's measurements M1-M5 are recorded here by the Queen before wave 2 starts)*

**Approved:** Andrei, 2026-10-15
**Briefed:**
**Branch:** vulyk/vulyk-watcher
**Checked:**
**Council:**
**Shipped:**
