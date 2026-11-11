# Upgrade findings: gate state the cycle owns, the backticked command, an upgrade that measures and reports (plan)

**Tier:** 3 · **Spec slug:** `upgrade-findings` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** ADR-032 (story trust from git; this plan adds cycle-owned run state beside it), ADR-029 (gate
split, `verify_run`, `suite.log`), ADR-025 (red receipt), ADR-013 D4 + ab-run-fixes C2/C3/C5 (risk set, narrow
repair), ADR-005 (installer upgrade contract), ADR-023; cards `safeguard-bypassable-or-late`,
`upgrade-overwrites-host-edits`, `shell-needs-gnu-or-bash4`, `host-internals-in-public-repo`,
`test-gate-one-long-limit`, `full-round-for-a-narrow-fix`; `docs/cycle.md`.
**Depends on:** `main` at 881e3498 (0.50.3).

## Goal
One release that closes what a hive's 0.44 -> 0.50 upgrade surfaced. The three gate inputs an agent could write
into its own paperwork (the verification resume point, stamp-red's results directory, the `narrow` flag) move
into one store the cycle writes under `.vulyk/state/`, each with a re-check, so a line typed into a story file
decides nothing; the Tier 4 risk check sees both sides of a rename (issue #5, A1-A4). A `## Commands` cell runs
its backticked command and treats the rest as a note. The upgrade's dry run stops being generic: it names
command rows it reads differently, a full suite this hive already measured over the cap, and the hand-written
constitution lines a replace would leave in the backup; a frontmatter-only hive edit is merged by key instead
of parked, and `settings.json` keeps its indent. The update check is at most 6 hours old and says when it
looked. Six stories in three waves, cut by file: `cycle.sh` and `install.sh` are each touched by one story per
wave, and no two wave-mates share a test file.

## Assumptions
<!-- Law 1: every assumption the plan rests on, stated so the owner can veto it at the approval stop. -->
- **Ask 6, several spans (the one reading that changes work).** `templates/story.md` documents that a cell
  with several backticked commands offers each to a story's `## Verification`. The plan keeps that in the
  matching lookups (`command_cell_exists`, `command_cell_round_only`, wave-check `verify-cell`) and refuses
  several spans only where one cell becomes one command to run: the round's full-suite row (a red part with
  a clear message) and the ready-line `try:` hint (such a row is not offered). The literal reading (refuse
  everywhere) would break every hive whose rows read `` `a` or `b` `` at its next `close-story`. If the owner
  wants the literal rule, story 01 gains that refusal and the template sentence is reversed; if this reading
  stands, the Queen narrows ask 6 in `brief.md` (`asks revised`) so the blind seat reads the same rule.
- **A1 key.** "Driver stamp" = the `--stamp S` value the verb was called with, `-` when none. "HEAD" follows the
  cycle's own staleness rule: the recorded head equals HEAD, or `<head>..HEAD` is `paperwork_only`. A
  wave-mate's close commit between a pause and its rerun therefore restarts that story's verification at
  line 1 (bounded by the number of wave-mates; costs minutes, never a wrong green). A driver relaunched with a
  fresh stamp restarts a paused verification the same way.
- **Limit of cycle-owned state (Answers 1).** `.vulyk/state/` is a directory an agent with a shell can also
  write; the store removes the story file as an input and adds re-checks (recorded exit 0 per skipped line,
  directory ownership, the narrow rule recomputed from the committed round), nothing more. No signing.
- **State is local and ignored.** `.vulyk/state/.gitignore` (`*`) is written by `cycle.sh` itself, so no
  installer or `.gitignore` change is needed. A clone that never ran `repair` has no narrow record: its next
  round is a full round (safe side; the card `full-round-for-a-narrow-fix` loses only on a second machine).
  A pause from before this release (a frontmatter mark) restarts at line 1 once.
- **A2 on Windows.** `[ -O dir ]` is assumed true in Git Bash for a directory the call just made. Where it is
  false (unverified: an elevated shell), stamp-red restarts instead of resuming and says which check failed.
- **Ask 5.** `CHANGELOG.md` is paperwork and named by no story: stories 03 and 05 end `## Implementation
  notes` with one `CHANGELOG:` line per A item and the Queen pastes them under `## [Unreleased]` after the
  wave (ab-run-fixes precedent). Closing issue #5 is a ship step (`Closes #5` in the release), and the branch
  is pushed only with the fixes (Answers 2). Story and test texts stay at the level of issue #5.
- **Asks 7, 8, 15 live in `install.sh`,** in the report `--upgrade` and `--upgrade --check` print, because
  `vulyk-update.sh` hands off to the target release's installer: code in the hive's old `vulyk-update.sh`
  would run one upgrade late. `scripts/vulyk-update.sh` itself changes only if story 06's fresh-fetch test fails.
- **Ask 8, "newest N".** N = 5 measured rounds, newest by the last commit touching the log. Sources:
  `docs/specs/*/council/round-*/suite.log` and, for hives older than ADR-029, the `SUITE:` line in
  `review.md`. A round with `PART` lines is judged by part, one without by its `SUITE:` total. No measured
  round prints one line saying so (silence is not a pass).
- **Ask 12, "frontmatter-only" and conflicts.** Tried only after today's `git merge-file` conflicts, when the
  hive's body equals the body its installed release shipped (CR stripped). A key is a top-level `name:` line
  with its indented lines, compared as text (no YAML parser). A key both the hive and the release changed is a
  conflict: the file is parked as today and the key is named. Release-wins on such a key was rejected (card
  `upgrade-overwrites-host-edits`); "dropped" names a key the hive had not touched and the release removed.
- **Ask 14.** Kept: the indent unit (N spaces or a tab) read from the existing file. Not kept: inline arrays
  or other hand layout, which `json.dump` reflows; the `.vulyk-bak` copy stays. Applies to every installer
  writer that rewrites an existing JSON file (same helper).
- **Ask 15.** With the installed release's tag in the source, only lines the hive wrote (absent from that
  release's constitution and from the new one) are printed; without the tag, every line absent from the new
  one, with a note that old upstream wording is included.
- **Ask 10.** The line shows date and time in UTC; a cache without the timestamp field counts as expired.
- **Ask 11.** Expected not reproducible on 0.50.x (recon: the report came from a 0.44.0 hook). Story 06 pins
  the three scopes with tests and states the cause in the test header; its red receipt rests on ask 10's test.
- **Ask 13.** Expected green on HEAD; story 02's red receipt rests on ask 12's test.
- **No ADR story.** The state contract lives in `## Contracts` and `docs/cycle.md`; `librarian` harvests the
  ADR at ship (it narrows ADR-032's "no new state file" to gate blocks; run state is cycle-owned and local).
- **No `model: haiku` story:** every story carries a gate branch or a parser. Story 03 is `model: opus`.
- **Self-hosting.** This repo closes its stories with the `cycle.sh` being edited: after story 01 the
  constitution's own cells (one span each) parse as before; `tests/maintenance.test.sh` (story 06) reads the
  whole tree, so a wave-mate mid-edit can turn it red once: rerun, not a repair.
- **wave-check noise accepted:** `verify-gap` on prose paths (`templates/story.md`, `docs/cycle.md`,
  `.claude/commands/vulyk-update.md`, `docs/hooks-reference.md`, `README.md`).
- **No scout ran.** Part names come from earlier specs' stories; the open ones are below.

### Recon questions for `drone-scout` (each may fix a part name or widen a `## Files`)
1. `tests/council.test.sh`: which parts hold the narrow-round cases (`repair` narrow, `open-round`
   `narrow=1`, `SUITE: none - narrow repair round`) and the `second=risk` cases? Story 05 assumes `verbs`,
   `suite`, `roster`. Duration of each against the 210 s line.
2. `tests/telemetry.test.sh`: the exact `constitution*` part names and which holds `--constitution replace`
   (story 04 assumes `constitution`); durations of `edits`, `crlf`, `wiring`, `upgrade`, `install-xp`. Does
   `--upgrade --check --constitution replace` run today, and does `vulyk-update.sh` pass both flags through?
3. Does any test outside `tests/cycle.test.sh` parts `close` / `red` assert the frontmatter `verify_resume`
   line or exit 7 (`council`, `driver`, `e2e`, `solo`)? Does any agent or command file name `verify_resume`?
   A hit joins story 03.
4. `scripts/cycle.sh` has 11 textual tests and 17 importers not shown, `lib.sh` 14 more importers: does any
   suite beyond cycle `close` / `gates` and council `suite` assert cell matching, a several-span cell or the
   `try:` hint? Which functions hold the backtick stripping at `cycle.sh:2070` and `lib.sh:355`?
5. Does a test assert the update check's 24 h default or the two-field cache, and does anything but the hook
   read `.claude/.vulyk-update-cache`? Does a test assert `README.md`'s "once a day" or text of
   `.claude/commands/vulyk-update.md`?
- **Coverage (drone-coverage, 2026-11-10), readings kept for the owner to veto:** ask 1's HEAD key accepts paperwork-only commits since the
  pause (the cycle's own staleness rule) and a stamp-less call keys on `-`; stamp-red's skipped lines need a matching recorded result,
  not exit 0 (its red line is expected to fail). Ask 8 reads the newest 5 measured rounds, and says so in one line when none were measured.
  Ask 12: a key both the hive and the release changed parks the file as today. Ask 14's indent rule is one helper, so it
  covers every installer JSON rewrite, not only `.claude/settings.json`. Ask 15 prints the non-block lines only the hive wrote
  (old upstream wording is left out, since the new release replaces it anyway). Ask 16: no story touches a hive file, the
  A/B study or model profiles. Gaps on asks 2, 4, 6 and 9 were closed in stories 03, 05, 01 and 04.

## Stories
<!-- One line per story, grouped by wave; the story files are the truth, this is their index. -->

**Wave 1**
- `upgrade-findings-01-commands-span` — ask 6: one span is the command, the rest a note, in every lookup; `commands_lint` for story 04 (`lib.sh`, `cycle.sh`, `wave-check.sh`; `red: required`)
- `upgrade-findings-02-upgrade-writes` — asks 12, 13, 14: frontmatter merge by key, the CRLF classification test, `settings.json` indent kept (`install.sh`; `red: required`)

**Wave 2**
- `upgrade-findings-03-verify-state` — asks 1, 2, 5: resume point and stamp-red results in `.vulyk/state/`, a hand-written mark decides nothing (`cycle.sh`; `red: required`; `model: opus`)
- `upgrade-findings-04-check-reports` — asks 7, 8, 9, 15: the dry run names odd command rows, an over-cap measured suite and backup-only constitution lines; step 6 gets the cutting recipe (`install.sh`, `vulyk-update.md`; `red: required`)

**Wave 3**
- `upgrade-findings-05-round-state` — asks 3, 4, 5: narrow only from the cycle's record plus a re-check, `narrow:` in the compared blocks, renames seen from both sides (`cycle.sh`; `red: required`)
- `upgrade-findings-06-session-brief` — asks 10, 11: 6 h cache with a checked-at time, the litopys offer pinned at three scopes (hooks; `red: required`)

## Contracts
<!-- Interfaces that cross a story boundary, agreed here at plan time. -->
- **S1, the state directory (story 03 creates; story 05 uses).** `.vulyk/state/<slug>/` under the repo root,
  made on first write together with `.vulyk/state/.gitignore` holding `*`. Plain `key=value` lines, written
  only by `cycle.sh`. A record that is missing, unreadable or fails its key always means the strict path
  (line 1, a new directory, a full round), never a refusal loop without a reason on stderr.
- **S2, the verify record (story 03).** `.vulyk/state/<slug>/verify.<story-id>.<verb>` with `head=`,
  `stamp=`, `files=` (today's `verify_files_hash`), `verify=` (hash of the `## Verification` lines), `next=<k>`,
  one `line=<k> <rc> <hash of line k>` per line run in this chain, and for stamp-red `outd=<path>`. A resume at
  `k` needs every key equal to the current call (head per the assumption above) and a `line=<j> 0 <hash>` for
  each skipped `j` in `close-story`; stamp-red reads a stored result only when its `line=` record matches and
  `outd` is `-d`, not `-L`, `-O`. `outd` comes from `mktemp -d` (0700). The finishing call removes the record
  and the directory. The `verify_resume` frontmatter line is neither read nor written.
- **S3, the narrow record (story 05).** `cycle.sh repair` writes `.vulyk/state/<slug>/narrow.round-<n+1>` with
  `story=<repair story id>`, `file=<the one file>`, `from=<n>`. `open-round` freezes `narrow=1` only when that
  record names the newest repair story and the narrow rule, recomputed from round n's committed records by the
  function `repair` uses, still holds; otherwise the round is full and stderr says why. Not keyed by HEAD (the
  repair is built between the two verbs). The story's `narrow:` line is information for the worker and joins
  the blocks compared with the approved version: `story blocks differ from the approved version (<sha7>): narrow:`.
- **B1, cell helpers in `scripts/lib.sh` (story 01 provides; story 04 consumes).** `command_cell_shape <cell>`
  prints `none | one | noted | several` (no span; one span alone; one span plus other text; two or more).
  `command_cell_cmd <cell>` prints the command for `none` (the trimmed cell, as today), `one` and `noted` (the
  span's inside), exit 2 with nothing printed for `several`. `commands_lint <constitution file>` prints one
  line per row, exit 0: `commands: row '<Purpose>': text outside the backticked command is read as a note` or
  `commands: row '<Purpose>': <N> backticked commands in one cell (the round gate refuses it as a full-suite
  row; split it)`. A `several` round-only row is a red part: `several backticked commands in one cell`.
- **C1, measured suite lines (story 04).** `full suite measured <N>s in round <slug>/round-<n>: cut before
  taking this release`, for a part `full suite part <name> measured <N>s in round <slug>/round-<n>: cut before
  taking this release`, then once `check a log with: bash scripts/suite-parts-check.sh <log>`; none found:
  `gate split (ADR-029): no measured full suite in this hive's council logs`. Over = more than 210 s.
- **E1, frontmatter merge lines (story 02 writes; story 04 documents in `vulyk-update.md`).** `merge
  frontmatter <file>` (`would merge frontmatter <file>` under `--check`), then per key `kept <key> (yours)` or
  `dropped <key> (removed by the release)`. Per key, with P the installed release, H the hive, N the new
  release: H = P takes N; N = P takes H; H = N takes it; otherwise `frontmatter conflict on <key>` and the
  file is parked as `keep + new`. Key order is the release's, hive-added keys last.
- **E4, backup-only lines (story 04).** Under `--upgrade --check --constitution replace`: `constitution: <N>
  lines only in the backup (<name>.pre-<version>.md):` then each line as `  | <line>`; N = 0 prints the header
  with `0` and no list.
- **D1, cache and line (story 06).** `.claude/.vulyk-update-cache` holds `<epoch> <latest> <YYYY-MM-DDTHH:MMZ>`;
  `VULYK_UPDATE_INTERVAL_HOURS` defaults to 6. The line keeps `installed v<X>, latest v<Y>` and adds
  `(checked <YYYY-MM-DD HH:MM> UTC)`.
- **Red labels.** Each `red_reason` is text the story's failing test prints: 01 `runs only the backticked
  span`; 02 `a frontmatter-only edit lands the release body`; 03 `a hand-written resume mark is ignored`;
  04 `full suite measured 378s in round`; 05 `narrow: true in the story does not shrink the round`;
  06 `a cache older than 6 hours is refetched`.
- **Rejected alternative.** The brief's other routes for A1 and A3: have `story_blocks_guard` refuse a
  `verify_resume` line the verb did not write, and read `narrow` from `git show <approved_rev>:<story>` or from
  `ROUND`. Rejected: a line in a file the worker must edit cannot prove who wrote it, the approved version of
  a repair story is itself written from the same `repair` call, and two mechanisms would guard three inputs
  where the owner chose one store (Answers 1). Also rejected: one story per finding (13 workers on two files).

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

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
**Approved:** Andrei, 2026-11-10 («Утверждаю»)
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path: Tier 1 "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"); Tier 2-4 only with `cycle.sh briefed <spec> --go`, "via grill (--go), <owner>, <date>". Alternative to **Approved:** above.>
**Branch:** vulyk/upgrade-findings
**Council:** RED round 1, 2026-11-11, at d2dfc17c, pack df396030b3bb - red: 2,5
**Council:** ESCALATE round 2, 2026-11-11, at bf9863ca, pack 4513d384eef0
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>

## Needs a human
- reason: no-progress · round 2 · 2026-11-11
- ask 5: BLOCK by the reviewer - see docs/specs/upgrade-findings/council/round-2/review.md
- no progress: ask 5 RED in rounds 1 and 2
- seats: docs/specs/upgrade-findings/council/round-2/
**Checked:** ACCEPTED by Andrei, 2026-11-11, at a33426f5 - принимаю
