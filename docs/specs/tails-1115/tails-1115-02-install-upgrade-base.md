---
story: tails-1115-02
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 2
blocked_by: [tails-1115-01]
red: required
red_reason: an untagged install upgrades against its stamped commit
red_verified_at: 2026-11-17T10:49:21Z 66f6ad4f64e6485c95a9fe2371428550c596831ac66ae95dd0f947a01f9f295f
---

# install.sh: the upgrade base survives an untagged build, only tracked files ship, the LF step is real, AGENTS.md hives

## Goal
Five installer tails (private `~/.vulyk/audits/known-defects-2026-11-15/tails.md`, items T7, T15, T51, T53, T55).
1. T7: every install and upgrade stamps the source commit (plan.md `## Contracts` B1). When the installed
   version's tag is missing from the source, `--upgrade` takes that commit as the base; with neither, today's rule
   stands (nothing is a release copy, one NOTE line). The card's check learns the same rule.
2. T15: when the source is a git checkout, the installer copies only tracked files; a ZIP source keeps today's
   walk.
3. T51: the line-ending step really removes CR bytes on Git Bash and logs the true count.
4. T53: the installer ends with one line naming the tools it did not find (Python 3, jq, git and what is limited
   without each).
5. T55: a project with `AGENTS.md` and no `CLAUDE.md` gets the sidecar constitution and a two-line `CLAUDE.md`
   that imports both, as `cc-facts.md` F14 records the import syntax.

`model: opus`: long-horizon in a 2100-line installer, with data-write branches. Marked red: the branch that decides
whether a hive's file is replaced.

## Requirements
> 2. The installer defects are fixed: release copies not counted as hive edits, untracked source files not copied, area-only cards named on upgrade, glob loops safe, side effects (user-scope mod, model pin) offered or flagged, never done silently (T7, T15, T22, T51-T55 and the rest of tails.md that touch install.sh).
> 9. A claim about Claude Code behaviour that a fix rests on is checked against the official docs first; an item whose premise does not hold is closed as not-a-defect with the source named.
> 10. Every fix that code can check gets a failing test with the original case and a neighbour form; all suites green.

## Files
<!-- Functions: prev_tag, release_copy, copy_tree, the LF step, the version stamp, the constitution write, the end
report. Not touched: wire_hook, wire_guard, wire_permissions, install_mod, the model pin (story 06, guards-1115). -->
- install.sh
- scripts/upgrade-base-check.sh
- docs/defects/upgrade-overwrites-host-edits.*
- docs/defects/INDEX.md
- tests/telemetry.test.sh

## Non-goals
- `.claude/vulyk-version` keeps its one-line shape: its readers are not edited.
- Do not touch hook wiring, the allow list, the mod install or the model pin: story 06 (wave 3).
- No other tag, branch or commit counts as a base: only the installed tag, else the stamped commit.
- Do not overwrite or merge an existing `CLAUDE.md` or `AGENTS.md`; a plain upgrade never writes the constitution.
- No Windows CI job here (story 09) and no doc edit (story 11): leave `DOCS:` lines.
- CR-byte trap: edit `install.sh` with Edit, never through a Python text-mode rewrite; awk values go through
  `ENVIRON`. Run `bash scripts/portability-check.sh install.sh scripts/upgrade-base-check.sh` after every edit.
- Edit `tests/telemetry.test.sh` only in parts `edits`, `install`, `install-xp`, `install-xp2`.
- Run `bash scripts/defects-index.sh` after a card edit; never edit `INDEX.md` by hand.

## Map slice
`memory/map/scripts-install.md` → install.sh - the upgrade contract, Gotchas; `memory/map/scripts.md` → Gotchas
(bash 3.2 / BSD); `docs/defects/README.md` (Fixtures).

## Acceptance criteria
- [ ] Part `edits`: a hive installed from an untagged source commit, then upgraded from a source where that
  version has no tag: a file equal to the stamped commit's blob is replaced, a file the hive edited is merged or
  kept with `.vulyk-new`. The label contains `an untagged install upgrades against its stamped commit`.
  Neighbours: a tagged install behaves as today and reads no commit; a stamp naming a commit absent from the
  source falls back to the NOTE path; a hive with no stamp (installed before this release) too.
- [ ] `bash scripts/upgrade-base-check.sh install.sh` exits 0 in seconds and fails on a fixture that takes any
  other commit as the base; the card says what the base is now.
- [ ] Part `install`: with a git source holding an untracked file and an ignored file under a shipped folder,
  neither reaches the hive; a ZIP-shaped source (no `.git`) ships as today.
- [ ] A hive file with CRLF endings is LF after the step, checked by bytes, and the log names the real count; a
  tree with no CR logs no normalisation. The case runs on Git Bash and on BSD userland.
- [ ] With a tool stubbed away, the last lines of an install name it once; with all present, no such line.
- [ ] `AGENTS.md` and no `CLAUDE.md`: the hive gets the sidecar and a `CLAUDE.md` of two import lines;
  `AGENTS.md` is untouched. Neighbours: both files present (today's behaviour), neither present (full
  constitution). F14 `not confirmed`: no change, one notes line with the source.
- [ ] The 0.50.3 glob-loop fix stays pinned: a `.gitignore` pattern with `*` is written literally while a matching
  file exists. If no case pins it, add one.
- [ ] Every new case fails on HEAD; the notes list them.

## Verification
`bash tests/telemetry.test.sh --part edits`
`bash tests/telemetry.test.sh --part install`
`bash tests/telemetry.test.sh --part install-xp`
`bash tests/telemetry.test.sh --part install-xp2`
`bash scripts/defects-check.sh`
`bash tests/telemetry.test.sh --part install-xp3`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per item and a `DOCS: <file> - <sentence>` line for each doc sentence story 11 must change (T53: the requirements
lines of docs/getting-started.md). -->
- install.sh: `SRC_HEAD`/`SRC_GIT` (a source with `.git` and a HEAD); `prev_tag` sets `BASE` = `v$PREV`, else the 40-hex
  commit in the hive's `.claude/vulyk-commit` when the source has it, else empty with a NOTE naming which is missing;
  `release_copy` and `upgrade_edited` read `$BASE` instead of `v$PREV`. Other `v$PREV` readers (wiring, retired_edited,
  report_backup_only) are untouched (story 06 / not named).
- install.sh: the stamp writes `.claude/vulyk-commit` (git source); a ZIP source writes none and removes an older stamp,
  which would name a commit the hive's files no longer come from (my call; B1 says only "writes none").
  `shippable` refuses `.claude/vulyk-commit` like `.claude/vulyk-version`.
- install.sh `copy_tree`: a git source lists `git ls-files -- <tree>` (regular files that exist, `.gitkeep` skipped);
  a ZIP source keeps the `find` walk.
- install.sh LF step: the literal CR bytes are gone; CRs are counted with `tr -cd '\r' | wc -c` and stripped with `tr`
  into a `cp -p` copy renamed over the file. Surprise: on Git Bash `grep -q $'\r'` never matches a CRLF file (measured:
  `grep -c` = 0), and HEAD logged "normalized 2" for a tree with one CRLF script (every script counted).
- install.sh constitution: AGENTS.md and no CLAUDE.md -> the sidecar (kept when it exists) plus `CLAUDE.md` =
  `@AGENTS.md` / `@CLAUDE.vulyk.md`; AGENTS.md never written. F14 is `confirmed` for both claims (imports, AGENTS.md read
  only without a CLAUDE.md), so no not-confirmed note; the unconfirmed import depth limit is not relied on.
- install.sh end: one last line `Tools not found on this machine: ...` for Python 3 (vulyk_python), jq, git, each run
  (`--version`), not looked up.
- scripts/upgrade-base-check.sh: a second hive at untagged commit C (VERSION 0.2.5) stamped in `.claude/vulyk-commit`;
  u2-old (= v0.2.0's blob, changed in C) must stay, u2-copy (= C's blob) must be replaced. 12 s here.
  HEAD's install.sh fails it; both old fixtures still fail; new fixture `upgrade-overwrites-host-edits.untagged.fixture`
  (nearest tag below the stamp as the base) fails only the two B1 lines. Card: fixtures list + one Cause paragraph;
  INDEX.md regenerated (content unchanged).
- Tests, new cases red on HEAD (stamp-red receipt): edits - the untagged upgrade (label = red_reason), the merge, the
  base line, both stamps, the stamp-absent and no-stamp NOTEs, the tagged-install stamp; install - tracked-only, its
  manifest, the HEAD stamp, the ZIP case (stamps no commit), the AGENTS.md two-line CLAUDE.md and sidecar; install-xp -
  the real count, the no-CR tree, the jq line.
- Cases that pass on HEAD by design (pins of today's behaviour): both AGENTS.md and CLAUDE.md, neither file, all tools
  present, the "names no tool that is there" check, and "a CRLF script is LF by bytes" (HEAD's sed strips CRs on Git
  Bash in text mode; its count was wrong).
- Glob-loop (0.50.3) is pinned already: part `crlf`, the `glob-cwd` case (a cwd holding `docs/specs/x/DRIVER`,
  `a.vulyk-new`); no case added. Part `crlf` green after this change.
- tests/telemetry.test.sh part `install-xp3` (Queen-approved, 2026-11-17): one edit, `rm -f "$UH2/.claude/vulyk-commit"`
  after the copy, so the "tag absent" case still meets no base; part green, 21 checks.
- Part `edits` runs about 150-185 s alone here (a clone of the release tree + three installs/upgrades of it).
CHANGELOG: install.sh stamps the source commit in `.claude/vulyk-commit`; when the installed version has no tag, `--upgrade` judges release copies against that commit (T7).
CHANGELOG: install.sh ships only the tracked files of a git source; an untracked or ignored file in the source no longer reaches a hive (T15).
CHANGELOG: install.sh's line-ending step counts and strips real CR bytes on Git Bash, and logs the true count (T51).
CHANGELOG: install.sh ends with one line naming Python 3, jq or git when the machine lacks it, and what is limited without it (T53).
CHANGELOG: a project with AGENTS.md and no CLAUDE.md gets CLAUDE.vulyk.md and a two-line CLAUDE.md importing both; AGENTS.md is left alone (T55).
DOCS: docs/getting-started.md - the Prerequisites line "`git`. Optional but recommended: `jq`" must also name Python 3 (hook wiring into an existing settings.json, the defect hooks) and say the installer's last line names any of the three it did not find.
DOCS: docs/getting-started.md - the install section should say a project with AGENTS.md and no CLAUDE.md gets CLAUDE.vulyk.md plus a two-line CLAUDE.md (`@AGENTS.md`, `@CLAUDE.vulyk.md`).
DOCS: memory/map/scripts-install.md - (librarian/drone-docs, not story 11) the upgrade contract: base = `v$PREV`, else `.claude/vulyk-commit`; a git source ships tracked files only.

## Findings
- NEEDS_CONTEXT (T7): `tests/telemetry.test.sh` part `install-xp3` (outside the parts this story may edit) goes red
  with B1, 4 checks: the case "tag v0.2.0 absent: each of the four differing files is kept with .vulyk-new" (about
  lines 1844-1854; `git -C "$UREL" tag -d v0.2.0`, then upgrade `$UH2`). `$UH2` was installed from a git source, so it
  now carries `.claude/vulyk-commit` = v0.2.0's commit, which `tag -d` leaves in the source: by contract B1 that commit
  is the base and the files are judged as with the tag (u1-copy updated, the edits merged), not the NOTE path the case
  pins. Proposed fix, one line in part `install-xp3`: `rm -f "$UH2/.claude/vulyk-commit"` right after `cp -a "$UH"
  "$UH2"` (the case stays "tag absent, no stamp"; the stamped-commit path is covered in part `edits`), plus
  `bash tests/telemetry.test.sh --part install-xp3` in `## Verification`. Question: may this story make that one edit
  in part `install-xp3`? It changes the sealed test after the red receipt, and the implementation is already green, so
  a re-stamp from base is needed (as for tails-1115-01). Nothing is committed.
  Other parts checked green with this change: crlf, crlf2, upgrade, constitution, constitution2, constitution3,
  library, wiring, wiring2, install2, install-xp4, edits2, mods, watcher, terminal; tests/intake.test.sh;
  tests/cycle.test.sh --part bsd. The four `## Verification` parts and `scripts/defects-check.sh` are green.

## Red receipt
- command: bash tests/telemetry.test.sh --part edits
- exit: 1
- tests: 66f6ad4f64e6485c95a9fe2371428550c596831ac66ae95dd0f947a01f9f295f (tests/telemetry.test.sh)
- impl: 4ef046e407a472a2806424c1c689107d4c7188251b02bd33ab23e8735a13ce5e
- stamped: 2026-11-17T10:49:21Z

```
--- upgrade: an untagged install upgrades against its stamped commit
::error::an untagged install upgrades against its stamped commit: a file equal to its blob is replaced
::error::... and the upgrade stamps the new commit - expected [0123d8a0930fa61abb9124b95d7bdbb141312747], got []
::error::a stamp naming a commit the source lacks:
  NOTE: v9.0.2 is not a tag in /tmp/tmp.YSvjsc5MjJ/rel-untagged - no file counts as a release copy; each differing framework file is kept, the new release beside it (.vulyk-new)
  would keep + new .claude/agents/drone-docs.md -> .claude/agents/drone-docs.md.vulyk-new
  NOTE: claude is not on PATH, so the VULYK mods (pulse) are not installed on this machine.
::error::a hive with no stamp:
  NOTE: v9.0.2 is not a tag in /tmp/tmp.YSvjsc5MjJ/rel-untagged - no file counts as a release copy; each differing framework file is kept, the new release beside it (.vulyk-new)
  would keep + new .claude/agents/drone-docs.md -> .claude/agents/drone-docs.md.vulyk-new
  NOTE: claude is not on PATH, so the VULYK mods (pulse) are not installed on this machine.
telemetry.test.sh: 27 checks, 8 failed
```
