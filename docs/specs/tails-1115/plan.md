# Fix the known code defects and tails (plan) - part 2 of 3 for 0.54.0

**Tier:** 3 · **Spec slug:** `tails-1115` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** ADR-032 (story trust from git), ADR-025 (red receipt), ADR-029 (gate split), ADR-015 (families and
the model floor), ADR-005 (upgrade keeps host edits), ADR-021 (rules tree); Law 6; cards
`upgrade-overwrites-host-edits`, `host-internals-in-public-repo`, `public-release-per-change`,
`shell-needs-gnu-or-bash4`, `safeguard-bypassable-or-late`, `handoff-offered-too-early`, `test-gate-one-long-limit`.
**Depends on:** `main` at 479ba709 (0.53.0 published, 15 ADRs accepted). Sibling `guards-1115` shares files with
this spec (see Assumptions, Sequencing); `docs-1115` follows both.

## Goal
Close every open item of the private inventory that touches code, in thirteen stories and five waves cut by file (stories 12 and 13 added 2026-11-16 on the owner's choices, brief `## Answers`).
Wave 1 fixes `close-story` and the driver's clerk line first, alone, because every later story closes through that
code. Wave 2 lands the installer's upgrade base, the masking and leak rules, and the model floor with its cost
tables. Wave 3 lands the check scripts, the installer's side effects and hook wiring, and the handoff and card
hooks. Wave 4 lands the prompt fixes, CI and the release-safety checks, and the session brief with the retired
learnings chain. Wave 5 writes the doc lines and the CHANGELOG from the notes the earlier stories left. Every fix
that code can check carries a test that fails on HEAD for the original case and a neighbour form. A fix that
rests on a claim about Claude Code is built only after the claim is checked against the official docs; an
unconfirmed claim closes its item as not-a-defect with the source named.

## Assumptions
- **Stories 12 and 13 (2026-11-16)** carry asks 11-13 from the owner's choices in brief `## Answers`. `symbol-map.sh --fill-tests` (new in narrow-repair-1115) is not run over the stories approved before it (owner, 2026-11-16: «Не применять, только отчёт (Рекомендую)»; after story 12 it runs once as a report only): it would add every test that sources `lib.sh` to stories 01 and 04 and break the wave cut; the full suite before merge covers the rest. Story 13 runs `tests/cycle.test.sh --part bsd` (it calls `reopen`) without owning that file.
<!-- Law 1: every assumption the plan rests on, stated so the owner can veto it at the approval stop. -->
- **Privacy.** Stories name private items by number (T<n>, S<n>) and class. The exact shapes are read by the
  worker from `~/.vulyk/audits/known-defects-2026-11-15/`; nothing from it enters the repo except synthetic test
  inputs. Fixtures use stand-in hive names.
- **Decisions taken from the private `decisions.md` (section FINAL), not asked again:**
  - A5 (T52): the installer installs the user-scope mod and pins a model only on a flag; otherwise it offers.
  - A6 (T57): maintainer scripts keep shipping to hives (cards' `check:` lines call them). Not built.
  - A7 (T63): the model-switch setting key is used only if the official docs confirm it (fact F1). If not, ask
    5's last clause has no mechanism in this spec and the Queen brings the owner the choice before wave 3.
  - A8 (T71): only `/vulyk-update` gets the no-model-invocation key; pause, resume and ship stay.
  - A9 (T29): the wall-clock check becomes a step-count bound.
  - T96, T97: both mechanisms are retired; no file already in a hive is deleted, moved or listed for deletion.
  - T64-T66, T72, T74-T76: verified against the official docs first, dropped if unconfirmed. This plan adds
    T55, T62, T67, T69, T70, T71, T77 to that list (ask 9).
- **Claude Code facts are checked once, by the Queen, before wave 1** (contract F0): `cc-facts.md` in this folder,
  facts F1-F16, each `confirmed` or `not confirmed` with two dated sources (fact-check protocol). F6 also needs
  one probe run of a capped Workflow agent. Stories are written conditionally on these lines; a worker never
  guesses a fact. A story whose fact line is missing returns `NEEDS_CONTEXT`.
- **T4 is built here** (story 08): ask 1 names it. `decisions.md` put it in `docs-1115`; if it should stay there,
  the last clause of ask 1 must be struck from the brief first.
- **Ask 3, "the red-receipt staleness"** is read as T23 (a receipt accepted on a reason found only in a passing
  line), the one open red-receipt item. The inventory lists the sealed-test deadlock as fixed at HEAD
  (`stamp-red --baseline`).
- **Ask 2, "glob loops safe"**: the inventory lists it as fixed since 0.50.3; story 02 only makes sure a test
  pins it.
- **Ask 8, "known flaky tests"**: the inventory holds no other open flake. T9 is UNCLEAR with two green CI runs
  since; its debug line stays until a recurrence is read (it sits in the block `guards-1115` edits).
- **T6** is built for `portability-check.sh`, the check the finding named. Printing each card's How-to line under
  any block hit at `close-story` is not built; say so if every block check should do it.
- **T7** stamps the source commit in a new one-line file, `.claude/vulyk-commit`; `.claude/vulyk-version` keeps
  its shape. A hive installed before this release has no stamp and keeps today's rule.
- **T26**: the push check is a git hook in the VULYK clone, copied by `/vulyk-ship` step 2a where the local dev
  tag is made. It is a guard in the maintainer's clone, not a feature switched on in hives.
- **T100**: `ship-check.sh` says NOT READY on a red defect gate in every hive, not only here. A hive with card
  debt will be stopped at ship until the debt is paid. Say so if this should be CI-only.
- **T51**: the Windows `install-smoke` job first runs at the owner's publish push (no branch CI by rule). A red
  there is fixed before the tag.
- **T74**: tool names stay in every matcher and hook; a guard matcher that names a tool an older Claude Code
  still has costs nothing. Only the handoff's task-list read changes, if F10 confirms.
- **T98**: the five unread interview questions are dropped, not wired to anything.
- **Not built, with the reason:** T28 (UNCLEAR, needs a real scout run); T94's `set -u` half (37 sourcing files
  shared with every other story and `guards-1115`; the header names it); T92's `.stale` half (the brief's
  age-based map line is the signal that needs no hook; the post-merge hook stays optional by the owner's
  offer-never-enable rule); T57 (A6).
- **Placed in `docs-1115`** (docs or map only): T18, T19, T21, T60, T66 (its fact F5 is checked here), T79, T81,
  T82, T83, T84, T86, T88, T89, T91 (one decision on the `memory/memory.md` contract, taken once; two command
  lines ride with it), T99 (README only); the doc halves of T65, T80 (`pipeline.md`), T90 (`CONTRIBUTING.md`).
- **Out by the brief:** FEATURE items T11, T46-T50, T58, T68, T73; T95 (own spec); T14 and S1-S14
  (`guards-1115`); S19 (waits for the owner's input). Done before this plan: T10/T87, T12, T13.
- **Sequencing with `guards-1115`.** The two specs never build in one tree at once; the second branches from the
  first's merge. Shared files: `scripts/cycle.sh` (here: `cmd_close_story`, `cmd_stamp_red` path and reason match,
  `short_line`), `scripts/lib.sh` (here: `commands_lint`, `model_floor`, `model_version`), `install.sh` and
  `.claude/settings.json` (here: no guard entry, no matcher), `tests/cycle.test.sh`, `tests/defects.test.sh`,
  `tests/maintenance.test.sh`, `tests/telemetry.test.sh`. Line numbers in the inventory are of 3e145fb6.
- **Queen's steps outside the stories:** (1) before wave 1, `cc-facts.md`; (2) before wave 4, wrap every
  `memory/map/*.md` line over the width cap (the inventory names one in `memory/map/cycle.md`), since story 10
  widens the test and workers never edit `memory/`; (3) after wave 4, check the two new scripts of story 09 are
  executable in the index.
- **Self-hosting.** Stories close with the scripts being edited. Story 01 runs alone (invariant of
  audit-fixes-1113, plan delta 2026-11-14). In waves 3 and 4 a wave-mate's close can meet a script or
  `tests/maintenance.test.sh` mid-edit: that red is a rerun, not a repair.
- **Shared files, one owner per wave.** `tests/maintenance.test.sh`: 03, 05, 10, 11. `tests/telemetry.test.sh`:
  02, 06. `tests/cycle.test.sh`: 01, 05, 09. `install.sh`: 02, 06. `docs/defects/INDEX.md`: 02, 05, 09.
  `CHANGELOG.md` and the docs pages: story 11 alone, from `CHANGELOG:` and `DOCS:` lines (contract N1).
- **Known wave-check noise, accepted:** `verify-gap` on story 08 (prose; `tests/maintenance.test.sh` reads the
  prompts and the constitution cap but is story 10's file that wave).
- **`tests/token-report.test.sh` has no `## Commands` row** (the constitution is at its byte cap): story 04's
  token-report case runs at the round gate only.
- **Size and models.** Eleven stories for ten asks and about fifty items; the owner chose three specs. Stories
  01, 02, 06 carry `model: opus` (long-horizon); story 11 `model: haiku` (routine, per the brief line).
- **No scout ran.** Test homes and part names come from closed stories of earlier specs; what each script does
  today comes from the map slices and the inventory, which are hints. `wave-check.sh` and `trace-check.sh` were
  not run by the planner (no shell): the Queen runs both.

### Recon questions for `drone-scout` (each may widen a `## Files` or move a line)
1. Which tests pin the `commands_lint` sentence about the round gate, and which pin `court` in the `--short` line
   outside `tests/driver.test.sh`? Does `record-seat` or a seat file need an absolute court? (01)
2. Which test fixtures run `journal.sh` or `ship-check.sh --record` in a scratch tree without `scripts/redact.sh`?
   (03; `journal.sh` has 5 textual tests and 4 textual importers)
3. Does the installer treat an unknown file under a hive's `.claude/` as a hive edit; which scripts read
   `.claude/vulyk-version`, and does any need more than one line of it? (02)
4. Which files outside story 04's hold a model version literal (the driver, `top-model-brief.sh`, tests)? (04)
5. Where do the existing `human-check.sh --show` cases and the `telemetry.sh record` / `consent` cases live? (05,
   10)
6. Does `context-guard.sh` do anything besides the PreCompact snapshot and its note; where are snapshots written;
   which tests name the hook (the subagent-silence block of `tests/maintenance.test.sh`, the entry count in
   telemetry part `wiring`)? (06)
7. How is `scripts/git-hooks/post-merge` put into a clone today? (09)
8. Where is the "haiku if Client path" wording copied outside `CLAUDE.md`, and which test pins it? (08)
9. Every mention of `memory/learnings` under `.claude/`, `scripts/`, `templates/`, `tests/`. (10)
10. `sort -V` sites in the tree besides `vulyk-evolve.md`. (05)
11. Measured duration against the 210 s line: `tests/maintenance.test.sh`, `tests/driver.test.sh`, cycle parts
    `close`, `close2`, `red`, `red2`, `gates`, `hooklog`, `ship`, telemetry parts `install`, `install-xp`,
    `install-xp2`, `edits`, `wiring`, `scan`.

## Stories
<!-- One line per story, grouped by wave; the story files are the truth, this is their index. -->

**Wave 1** (alone: edits `close-story`)
- `tails-1115-01-cycle-and-driver` — asks 3, 1: absolute story paths, the commit subject, the executable bit, the red reason match, a short clerk line, a cut-off reply, lint wording, headers (T2, T3, T17, T23, T8, T67, T25, T94; `model: opus`; `red: required`)

**Wave 2**
- `tails-1115-02-install-upgrade-base` — ask 2: the stamped source commit as upgrade base, only tracked files ship, a real LF step, a missing-tools line, AGENTS.md hives (T7, T15, T51, T53, T55; `model: opus`; `red: required`)
- `tails-1115-03-masking-and-leak` — ask 4: more masked shapes, journal and ship record refuse when masking fails, one more leak form (S15, S16, S17; `red: required`)
- `tails-1115-04-models-and-cost` — ask 5: the floor follows the newest version, cost tables by family, family and plan names (T61, T62, T64, T76; `red: required`)

**Wave 3**
- `tails-1115-05-check-scripts` — asks 1, 5: wave-check and new test paths, the busy check, portability hits print the fix, a `sort -V` rule, `--show` order, agent tools (T1, T5, T6, T90, T16, T65; `red: required`)
- `tails-1115-06-install-side-effects-and-wiring` — asks 2, 6, 5: mod and pin offered, blind cards and a missing import named, the snapshot hook retired, typed commands counted, the model-switch key (T52, T22, T54, T97, T72, T63; `model: opus`; `red: required`)
- `tails-1115-07-handoff-and-inject` — asks 5, 12: the handoff's window rules, its task list and PreCompact output, no card on a read-only command, no path from a fenced section (T20, T69, T74, T75, T78; `red: required`)
- `tails-1115-12-test-pickup-exact-forms` — ask 11: a direct call inside `"$(...)"` is an exact hit, a `lib.sh` source is not a call of every script it wraps (`red: required`)

**Wave 4**
- `tails-1115-08-prompts` — asks 1, 7: one blind seat in the constitution, worker instruction sources, seat wording, `/vulyk-update` not model-invoked, the rules promise, the interview (T4, T24, T80, T85, T92, T71, T77, T98; no red)
- `tails-1115-09-ci-and-release-safety` — asks 4, 8, 2: actions pinned, a Windows install smoke, the defect gate in CI and ship-check, no dev tag pushed, a clock-free bound (S18, T51, T100, T26, T29; `red: required`)
- `tails-1115-10-brief-telemetry-gc` — asks 5, 6: the sidecar constitution read, control bytes, brief lines, the learnings chain retired, librarian without a shell, meta-skills read, the map test (T56, T27, T54, T59, T96, T93, T70, T92; `red: required`)
- `tails-1115-13-reopen-narrow` — ask 13: a reopened `no-progress` gets a narrow round, a full one only with `reopen --full`; `half` stays full (`model: opus`; `red: required`)

**Wave 5**
- `tails-1115-11-docs-and-changelog` — the doc lines and the CHANGELOG, from the `DOCS:` and `CHANGELOG:` lines of stories 01-10, 12 and 13 (`model: haiku`; no red)

## Contracts
<!-- Interfaces that cross a story boundary, agreed here at plan time. -->
- **F0, Claude Code facts (the Queen; every story that names an F).** `docs/specs/tails-1115/cc-facts.md`, one
  line per fact: `F<n> · confirmed | not confirmed · <what the docs say, exact names> · <two sources, dated>`.
  F1 the setting that stops a flagged request moving to another model (T63). F2 model family names accepted
  today (T64). F3 the effort-level environment variable and its precedence (T64). F4 whether a subagent can spawn
  subagents and the tool's name, old and new (T65). F5 how Agent Teams is switched on (T66, for `docs-1115`).
  F6 what a Workflow `agent()` call returns when the agent stops at a cap (T67; docs plus one probe). F7 the
  compaction-window variable and the context window per family (T69). F8 the command frontmatter key that bars
  model invocation (T71). F9 the hook event for an expanded typed command and its input (T72). F10 whether
  `MultiEdit` and `TodoWrite` exist today and what replaced them (T74). F11 what Claude Code does with a
  PreCompact hook's stdout and `systemMessage` (T75). F12 the plan names and a documented way to read the plan
  (T76). F13 prices of the newest gate-family version, cache read included (T62). F14 `@file` imports in
  `CLAUDE.md` and whether `AGENTS.md` is read natively (T55). F15 what `omitClaudeMd` does to `.claude/rules/`
  (T77). F16 how deep skills are discovered (T70; story 10 reads by path either way).
- **K1, the short line (story 01).** In `--short` output the court is the path relative to the repo root; no field
  of the line grows with the root's length. The driver hands a seat that path with the rule to resolve it against
  the project root.
- **B1, upgrade base (story 02; story 06 builds on it).** Every install and upgrade writes the source's HEAD sha
  (40 hex) to `.claude/vulyk-commit` when the source is a git checkout; a ZIP source writes none. A hive file is a
  release copy when it equals the blob at its path in tag `v<installed version>`; when that tag is absent, the
  blob at the stamped commit, if the source has that commit; else nothing is a release copy (one NOTE line).
  `scripts/upgrade-base-check.sh` judges the same rule.
- **R1, masking failure (story 03).** `redact.sh` keeps its contract (`[VULYK:REDACT-FAILED]` on stdout, exit 1).
  A caller that writes to disk (`journal.sh`, `ship-check.sh --record`) exits non-zero and writes nothing when
  `redact.sh` is missing or fails. Every mask added to `redact.sh` is added to `_REDACT_FALLBACK` in the same
  story, with parity rows.
- **I1, installer side effects (story 06).** Two flags in the style of `--telemetry on|off|ask`, default off: one
  for the user-scope pulse mod, one for the model pin. Off: one `offer:` line with the exact command, nothing
  done. A mod already installed at user scope is kept current by an upgrade and named; an existing pin is kept.
  Story 06 leaves the flag names in a `DOCS:` line.
- **W1, settings (story 06 alone writes `.claude/settings.json`).** The PreCompact snapshot entry is removed and
  unwired on upgrade when it is the shipped one. If F9: one entry for the typed-command event calling
  `skill-usage-counter.sh`. If F1: the model-switch key. No guard entry or matcher changes.
- **J1, read-only commands (story 07).** A Bash or PowerShell command gets no card when every command word in it
  is on a short read list (search, print, list, count, compare) and it has no redirect to a file and no in-place
  flag. `git` is never on the list. Anything the hook cannot parse gets the cards.
- **P1, tag push check (story 09).** `scripts/tag-push-check.sh` reads git's pre-push lines on stdin (`<local ref>
  <local sha> <remote ref> <remote sha>`). Exit 1 with a reason when a pushed `refs/tags/` ref holds `-dev.`, or
  when more than one `refs/tags/v*` ref is pushed; a deletion and any branch ref pass; exit 0 otherwise.
  `scripts/git-hooks/pre-push` passes stdin through and returns its exit code.
- **N1, notes lines (stories 01-10, 12 and 13 write, story 11 reads).** Each story ends `## Implementation notes` with one
  `CHANGELOG: <line>` per item and one `DOCS: <file> - <sentence to change and what it must say>` per doc
  sentence. Story 03's lines name classes, never forms.
- **Red labels.** Each `red_reason` is text the story's failing test prints: 01 `an absolute story path closes
  like a relative one`; 02 `an untagged install upgrades against its stamped commit`; 03 `a journal line is
  refused when masking cannot run`; 04 `a model one version behind the newest is below the floor`; 05 `a test path
  the story itself creates counts as covered`; 06 `the installer installs no mod unasked`; 07 `a read-only command
  gets no card`; 09 `a dev tag is refused at push`; 10 `the consent line is read from the sidecar constitution`.
  A story with several fixes makes every other new case fail on HEAD too and says so in its notes.
- **Rejected alternative.** A second line in `.claude/vulyk-version` for the source commit (the inventory's first
  suggestion for T7). Rejected: the map slices name three readers that take the file as one version string (the
  update check, the telemetry version, the hive registry check), none of them in this spec's files; a new file
  changes no reader's contract (recon question 3 confirms the list). Also rejected: one story per item (about
  fifty workers, most of them serialised on `cycle.sh`, `install.sh` and three test suites), and letting each
  worker check its own Claude Code facts (one dated record serves this spec and `docs-1115`).

## Integration gate
`bash tests/full-suite.sh`

## Descoped

- Story 12 acceptance (2026-11-17): "the six scripts above each list at least one exact test" narrowed to the three
  run inside `"$(...)"`; the other three miss for other causes (a `;`-separated path assignment, a path passed to a
  test-local function, a name only in a grep pattern) and go to the next circle by name. Owner, 2026-11-17:
  «Сузить до трёх (Рекомендую)».

## Plan deltas

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all. Approved is the owner's
word, the stop at Tier 2-4; Briefed is written by `cycle.sh briefed` instead, at Tier 1 ("via
mini-brief"), with `--go`, or in no-question mode ("assumed"). Either closes stage 02. Council and
Checked close stages 04+05 together: a GREEN council row is enough on its own, and Checked is the
owner's override in either direction, newest timestamp wins. No line of this comment may start with
a marker: the scripts read the first line that does.

There is no default tier: `cycle.sh open-round` refuses to open a round while the `**Tier:**` line above
is missing or unparsable.
-->
**Approved:** Andrei, 2026-11-15 «Утверждаю все три, тесты exact (Рекомендую)»
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path: Tier 1 "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"); Tier 2-4 only with `cycle.sh briefed <spec> --go`, "via grill (--go), <owner>, <date>". Alternative to **Approved:** above.>
**Branch:** vulyk/tails-1115
**Council:** RED round 1, 2026-11-17, at 690d0ab9, pack 2d6f016f0a85 - red: 4,6
**Council:** RED round 2, 2026-11-17, at 5c1c3a01, pack 7ceba8b59898 - red: 10
**Checked:** ACCEPTED by Andrei, 2026-11-17, at db7bb811 - «Принимаю (Рекомендую)»
**Shipped:** 0.54.0-dev.3, 2026-11-18, at a089d89e - merged to main (local) after the owner's ACCEPTED; installer fixes found by the canaries in dev.4 and dev.5; branch CI skipped on the owner's earlier override (origin public); public 0.54.0 pending docs-1115, a real hive build, outward review and the owner's word
