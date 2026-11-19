---
story: tails-1115-06
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 3
blocked_by: [tails-1115-02]
red: required
red_reason: the installer installs no mod unasked
red_verified_at: 2026-11-17T13:13:01Z 756d6d8d3cf2f100bf93d4d597bbab116299004fcacec984dfa814ec70b9a72e
---

# install.sh: side effects are offered, the upgrade names blind cards and a missing import, the snapshot hook is retired

## Goal
Six changes in the installer and the settings it writes (private
`~/.vulyk/audits/known-defects-2026-11-15/tails.md`, items T52, T22, T54, T63, T72, T97; plan.md `## Contracts`
I1 and W1).
1. T52: the installer no longer installs the pulse mod at user scope or pins a model on its own. Each is done
   only on its flag; without it the installer prints one offer line with the exact command.
2. T22: `--upgrade` and `--check` print one line per card in the hive's library that has an `area:` label and no
   `paths:` glob, naming the card: such a card reaches no worker.
3. T54: `--upgrade` and `--check` say when a sidecar hive's `CLAUDE.md` does not import the sidecar constitution.
4. T97: the PreCompact snapshot is retired. Its entry leaves `.claude/settings.json`, an upgrade unwires it in a
   hive and removes the script when it is a release copy; the snapshot folders already in a hive are not deleted,
   moved or listed for deletion.
5. T72: typed `vulyk-*` commands are counted, through the hook event `cc-facts.md` F9 records.
6. T63: the settings key F1 records stops a flagged request from being moved to another model.

T72 and T63 follow their facts: `not confirmed` means no wiring, no key, and one notes line with the source.
`model: opus`: long-horizon in the installer, with side effects outside the hive. Marked red: the branch that
decides whether something is installed at user scope.

## Requirements
> 2. The installer defects are fixed: release copies not counted as hive edits, untracked source files not copied, area-only cards named on upgrade, glob loops safe, side effects (user-scope mod, model pin) offered or flagged, never done silently (T7, T15, T22, T51-T55 and the rest of tails.md that touch install.sh).
> 6. Dead mechanisms are retired: the unwritten learnings chain and the never-read pre-compact snapshots, without deleting any data already in a hive.
> 5. The hook, telemetry, token-report, prompt-check and model-floor tails in tails.md are fixed; a fallback never runs a model below the floor (pause instead).
> 9. A claim about Claude Code behaviour that a fix rests on is checked against the official docs first; an item whose premise does not hold is closed as not-a-defect with the source named.

## Files
<!-- Functions: install_mod, the model pin (top-model --apply call), the shipped-hook list and unwire_hook call
for the retired entry, the retired-path list, the upgrade report lines. Not touched: wire_guard, the GUARDS
list, wire_permissions, the guard entries and matchers of settings.json (guards-1115); release_copy, copy_tree
(story 02). -->
- install.sh
- .claude/settings.json
- .claude/hooks/context-guard.sh
- .claude/hooks/skill-usage-counter.sh
- .claude/commands/vulyk-update.md
- tests/telemetry.test.sh
- tests/maintenance.test.sh

## Non-goals
- `retire_mod` of the retired watcher mod stays as it is. A mod the owner already has at user scope is kept
  current by an upgrade and the output says so; a model pin already in the hive's settings is kept.
- Do not remove `MultiEdit` from any matcher: a guard matcher keeps every tool name an older Claude Code has.
- If `context-guard.sh` does more than the PreCompact snapshot and its note, only the snapshot leaves and the
  script stays: say so in the notes. `handoff.py` on PreCompact is story 07's.
- Do not wire a hook the hive's owner removed; keep the "wired once" rule.
- No test edit outside `tests/telemetry.test.sh` parts `install`, `install-xp`, `install-xp2`, `wiring`; the
  counter's new case goes into `wiring`. A pin of the retired hook in another suite is `NEEDS_CONTEXT`, naming
  file and line.
- `vulyk-update.md` changes only where it reads the dry-run lines to the owner; its frontmatter is story 08's.
- CR-byte trap: edit `install.sh` with Edit; awk values through `ENVIRON`. Run
  `bash scripts/portability-check.sh install.sh .claude/hooks/skill-usage-counter.sh` after every edit.

## Map slice
`memory/map/scripts-install.md` → install.sh - the upgrade contract; `memory/map/scripts-hooks.md` → Purpose,
Entry points (`skill-usage-counter.sh`); `memory/map/commands-ship.md` → `/vulyk-update` bullets.

## Acceptance criteria
- [ ] Part `install`: a fresh install with no flag makes no `claude plugin` call (counting stub) and writes no
  model pin; its output holds one offer line for each, with the command. The label contains `the installer
  installs no mod unasked`. With the flags, both are done as today. Neighbours: `--upgrade` with the mod absent
  offers and installs nothing; with the mod present it updates it and says so; an existing pin is kept.
- [ ] `--check` on a hive whose library has a card with `area:` and no `paths:` prints one line naming it; a card
  with both, or with `paths:` only, prints none.
- [ ] A sidecar hive whose `CLAUDE.md` lacks the import line gets one line saying so on `--upgrade` and `--check`;
  with the import present, and in a hive with no sidecar, none. Nothing is written to the constitution.
- [ ] Part `wiring`: a fresh install has no snapshot entry on PreCompact; an upgraded hive loses the entry it had
  from the release and keeps one its owner changed, named. A scratch hive's existing snapshot folders are
  byte-identical after the upgrade.
- [ ] F9 `confirmed`: the event is wired on install and once on upgrade; the counter, fed that event for a
  `vulyk-*` command, counts it, and for any other typed command writes nothing.
- [ ] F1 `confirmed`: a fresh install's settings hold the key; an upgrade adds it when absent and keeps an
  owner's own value, named.
- [ ] `vulyk-update.md` reads the new lines to the owner and offers the two commands, never runs them unasked.
- [ ] Every new case fails on HEAD; the notes list them.

## Verification
`bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part wiring`
`bash tests/telemetry.test.sh --part install-xp`
`bash tests/telemetry.test.sh --part install-xp2`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
`bash tests/telemetry.test.sh --part mods`
`bash tests/telemetry.test.sh --part install-xp3`
`bash tests/telemetry.test.sh --part install-xp4`
`bash tests/maintenance.test.sh --part upkeep`
`bash tests/telemetry.test.sh --part mods2`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per item and a `DOCS: <file> - <sentence>` line for each doc sentence story 11 must change (README install
paragraph, docs/hooks-reference.md rows, the flag names). -->
- install.sh: `--pulse on|off` and `--model-pin on|off` (default off). Off: `install_mod` prints one `offer:` line with
  `claude plugin marketplace add ... && claude plugin install ...`; on --upgrade it still asks `plugin list` and keeps a
  mod already on the machine current. The pin block prints `offer: ... cd <hive> && bash scripts/top-model.sh --apply`.
- install.sh: `retire_mod vulyk-watcher@vulyk` now runs on --upgrade only (the function is unchanged): the AC's "a fresh
  install makes no `claude plugin` call" counts its `plugin list` too. The retired watcher leaves a machine on any upgrade.
- install.sh: `report_blind_cards` (T22) runs on --upgrade or --check over `docs/defects/**/*.md` (README, INDEX,
  `fixtures/` skipped); a card whose frontmatter has `area:` and no `paths:` (or `paths: []`) is named.
- install.sh: the sidecar branch (T54) prints `not imported:` when CLAUDE.md has no `@CLAUDE.vulyk.md` line; read only.
- install.sh (T97): the SHIPPED_HOOKS row and the `wire_shipped PreCompact context-guard.sh` call are gone; on --upgrade
  `unwire_hook PreCompact context-guard.sh` runs with `UNWIRE_EXACT` (new, read by `py_unwire`): only the two release
  command forms go, any other entry running the script is kept and printed `kept (yours)`. The script leaves through the
  manifest (release copy only, `retired_edited` as for any retired file); `memory/snapshots/` is never touched.
- `.claude/hooks/context-guard.sh` did only the snapshot and its echo, so the whole script is deleted.
- install.sh (T72, F9 confirmed): UserPromptExpansion -> skill-usage-counter.sh, a SHIPPED_HOOKS row; wired when v$PREV's
  settings.json has no UserPromptExpansion, else `report_unwired` (an owner's removal stays removed).
- `skill-usage-counter.sh`: on UserPromptExpansion it counts `command_name` only when it starts with `vulyk-` (and passes
  `ours`); a typed skill, another command or a plugin command writes nothing.
- install.sh (T63, F1 confirmed): `wire_flag_switch` adds `switchModelsOnFlag: false` when absent (`set` line), keeps an
  owner's other value (`kept (yours)`); `.claude/settings.json` ships the key, the UserPromptExpansion entry and no
  context-guard entry. No guard entry or matcher touched.
- `vulyk-update.md` step 2: reads the `offer:`, `card reaches no worker:` and `not imported:` lines; offers the commands.
- Surprise: the sealed install-xp2 case "which is PreCompact: handoff.sh" grepped `handoff.sh precompact`, but py_wire
  follows the hive's `bash -c` template (`.../handoff.sh" precompact'`). Fixed the assertion to a regex before any
  implementation was on disk (implementation reverted to HEAD, test edited, stamp-red re-run, implementation re-applied).
- New cases red on HEAD (both receipts): install T52 offer/no-call/no-pin, T22 cards on --check/--upgrade, T54 import
  line; install-xp3 no pin without the flag + `--model-pin on`; install-xp2/xp4 handoff in place of context-guard and the
  retired hook not named; mods no-flag offer, `--pulse on` install/check, upgrade with the mod absent; mods2 `--pulse on`;
  wiring snapshot retired/unwired/kept (yours)/script removed/folders identical, UserPromptExpansion wired once + counter,
  switchModelsOnFlag set/kept; maintenance H1 no context-guard PreCompact command.
- CHANGELOG: T52 - the installer no longer installs the pulse mod or pins the Queen model unasked: `--pulse on` and `--model-pin on` do it; otherwise one `offer:` line with the command.
- CHANGELOG: T22 - `--upgrade` and `--check` name each defect card with `area:` and no `paths:` glob (it reaches no worker).
- CHANGELOG: T54 - `--upgrade` and `--check` say when a sidecar hive's CLAUDE.md does not import CLAUDE.vulyk.md.
- CHANGELOG: T97 - the PreCompact snapshot hook (context-guard.sh) is retired; an upgrade unwires the shipped entry and removes the release copy; existing snapshot folders stay.
- CHANGELOG: T72 - typed `/vulyk-*` commands are counted through the UserPromptExpansion hook.
- CHANGELOG: T63 - settings ship `switchModelsOnFlag: false`: a flagged request pauses instead of moving to another model; an owner's value is kept.
- DOCS: README.md - the install paragraph names `--pulse on|off` and `--model-pin on|off` (default off: offered, not done) and drops "installs the pulse mod".
- DOCS: README.md - the hooks table row for `context-guard.sh` (PreCompact) goes.
- DOCS: docs/hooks-reference.md - the `context-guard.sh` row goes; the `skill-usage-counter.sh` row adds UserPromptExpansion (typed vulyk-* commands).
- DOCS: docs/hooks-reference.md - `memory/snapshots/` is no longer written; the librarian pruning sentence goes with it.

## Findings
- NEEDS_CONTEXT (builder, before any edit): the retired snapshot hook and the two side effects are pinned by tests
  this story may not edit (Non-goals: "A pin of the retired hook in another suite is `NEEDS_CONTEXT`, naming file and
  line"; test edits only in parts `install`, `install-xp`, `install-xp2`, `wiring`).
  - `tests/maintenance.test.sh:395` asserts at least 2 PreCompact commands in `.claude/settings.json` (only
    `handoff.sh precompact` stays after T97), and `:440-441` runs the `context-guard.sh` PreCompact entry and expects
    `context-guard: snapshot saved` (H1 case).
  - `tests/telemetry.test.sh` part `mods` `:2777-2779` expects the no-flag fresh install's `NOTE: claude is not on
    PATH` with both plugin commands; `:2786-2790` expects a no-flag fresh install to run `plugin marketplace add` and
    `plugin install` at user scope. T52 makes both false.
  - part `install-xp3` `:1767-1771` expects `--upgrade` with no flag to pin `model = opus` in a hive with no pin
    (`pinned: model = opus`). T52 ("no longer pins a model on its own") makes it false.
  - part `install-xp4` `:1956-1967` expects `PreCompact: context-guard.sh` named as unwired on a no-tag upgrade. After
    T97 the hook is no longer shipped, so it is not named.
  Question: may this story edit those cases (maintenance H1 PreCompact lines; telemetry parts `mods`, `install-xp3`,
  `install-xp4`, and their Verification lines added), or do they move to another story?
- Queen (2026-11-17): yes, this story owns them: change those cases to the behaviour T97 and T52 ask for (no PreCompact
  snapshot; no mod install or model pin without its flag, an offer instead), each with the original and a neighbour
  form; nothing else in those parts. `tests/maintenance.test.sh` joins `## Files` for the H1 PreCompact lines only
  (story 05, its wave-mate, is closed); their parts join `## Verification`.
- NEEDS_CONTEXT (builder, round 2, after the tests and before any implementation edit): `cycle.sh stamp-red ... --stamp
  e652567f08f4cc2c` exits 3: `paused: Andrei · owner to answer the Queen decisions on stories 07 and 12 before they
  close · 2026-11-17T12:03:41Z` (`docs/specs/tails-1115/PAUSE`). Not fixable from here. State left in the tree, uncommitted:
  the new and changed cases in `tests/telemetry.test.sh` (parts `install`, `mods`, `mods2`, `install-xp2`, `install-xp3`,
  `install-xp4`, `wiring`) and `tests/maintenance.test.sh` (H1 PreCompact lines); no implementation file is touched, so
  the next run starts at stamp-red. One more case outside the listed parts: `mods2` line "a marketplace already added is
  not added again; the mod tries its install" pins the old T52 behaviour (an upgrade with no flag installs the mod); its
  upgrade now passes `--pulse on`. `mods2` is not in `## Verification`: the Queen may add it or move the edit.
- Queen (2026-11-17): the `mods2` edit stays with this story (it pinned the old no-flag install); `--part mods2`
  joins `## Verification`. The pause is lifted.

## Red receipt
- command: bash tests/telemetry.test.sh --part install
- exit: 1
- tests: 756d6d8d3cf2f100bf93d4d597bbab116299004fcacec984dfa814ec70b9a72e (tests/maintenance.test.sh, tests/telemetry.test.sh)
- impl: 27ba0fb57725cc1ada578c1fbb3471fa18f9a5584c7ee12d10fbd5cbdbf431ed
- stamped: 2026-11-17T13:13:01Z

```
::error::a fresh install with no flag: the installer installs no mod unasked (claude plugin calls, counting stub) - expected [0], got [5]
        
        Done. Upgraded framework files only; your CLAUDE.md, memory/, specs, ADRs and wiki were not touched.
        If the constitution changed this release, the note above says by how much and how to migrate.
  ok    ... a card with both area: and paths: is not named
  ok    ... nor one with paths: only
--- install.sh --upgrade: a CLAUDE.md that does not import the sidecar constitution (T54)
::error::a sidecar hive whose CLAUDE.md lacks the import: one line on --upgrade and on --check - expected [1 1], got [0 0]
  ok    ... and CLAUDE.md is not written
  ok    with the import present, and in a hive with no sidecar: no such line
telemetry.test.sh: 77 checks, 8 failed
```
