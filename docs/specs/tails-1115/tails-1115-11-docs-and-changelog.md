---
story: tails-1115-11
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
model: haiku
wave: 5
blocked_by: [tails-1115-01, tails-1115-02, tails-1115-03, tails-1115-04, tails-1115-05, tails-1115-06, tails-1115-07, tails-1115-08, tails-1115-09, tails-1115-10]
---

# The doc lines and the CHANGELOG for this spec

## Goal
The docs say what stories 01-10, 12 and 13 changed, and `CHANGELOG.md` lists it under `## [Unreleased]`. Each earlier story
ends its `## Implementation notes` with `CHANGELOG:` lines and `DOCS: <file> - <sentence>` lines (plan.md
`## Contracts` N1). This story applies them: every `DOCS:` line becomes the named change in the named file, every
`CHANGELOG:` line becomes one line under `## [Unreleased]`.

`model: haiku`: routine, it transcribes lines the earlier stories left and decides nothing.

## Requirements
> 2. The installer defects are fixed: release copies not counted as hive edits, untracked source files not copied, area-only cards named on upgrade, glob loops safe, side effects (user-scope mod, model pin) offered or flagged, never done silently (T7, T15, T22, T51-T55 and the rest of tails.md that touch install.sh).

## Files
- CHANGELOG.md
- README.md
- docs/getting-started.md
- docs/faq.md
- docs/hooks-reference.md
- docs/model-cascade.md
- docs/memory-system.md
- docs/self-evolution.md
- docs/cycle.md
- docs/telemetry.md
- tests/maintenance.test.sh
- docs/pulse.md
- docs/command-reference.md
- docs/pipeline.md
- .claude/agents/council-opus.md
- .claude/agents/council-haiku.md

## Non-goals
- Change only sentences a `DOCS:` line names. Every other contradiction in these pages belongs to the later spec
  `docs-1115`: leave it, even when it is on the same line.
- A `DOCS:` line naming a file outside `## Files`, or one you cannot place, is `NEEDS_CONTEXT`, quoting the line.
- No version bump and no release heading: the ship step does both.
- A `CHANGELOG:` line from story 03 is copied as written: it says what is masked or refused by class. Never add
  which form was open, an example value, or a host project's name to any line.
- Edit `tests/maintenance.test.sh` only where it pins a sentence this story changed.
- Do not edit `CLAUDE.md`, any file under `.claude/` (except the two council seat files, for their `DOCS:` lines
  only), `memory/` or `docs/adr/`.

## Map slice
None: the inputs are the `## Implementation notes` of `docs/specs/tails-1115/tails-1115-01-*.md` to
`tails-1115-10-*.md`.

## Acceptance criteria
- [ ] Every `DOCS:` line of stories 01-10, 12 and 13 is applied; the notes list each line and the file it went to.
- [ ] Every `CHANGELOG:` line of stories 01-10, 12 and 13 is under `## [Unreleased]`, one line each, grouped as the file
  already groups (Added / Changed / Fixed).
- [ ] `git diff --stat` shows only files under `## Files`, and no sentence changed that no `DOCS:` line names.
- [ ] `bash scripts/leak-check.sh <file>` exits 0 for each changed file.

## Verification
`bash tests/maintenance.test.sh --part upkeep`
`bash tests/maintenance.test.sh --part redact`
`bash tests/maintenance.test.sh --part guards`

## Implementation notes
<!-- appended by the builder: one line per DOCS: line applied (story, file), one line per CHANGELOG: line. -->
- Files: CHANGELOG.md, README.md, docs/getting-started.md, docs/faq.md, docs/hooks-reference.md, docs/model-cascade.md, docs/memory-system.md, docs/self-evolution.md, docs/cycle.md, docs/pulse.md, docs/command-reference.md, docs/pipeline.md, .claude/agents/council-opus.md, .claude/agents/council-haiku.md. tests/maintenance.test.sh and docs/telemetry.md untouched (no pinned sentence changed; no DOCS line names telemetry.md). All five Queen-named files are in ## Files of the working copy.
- DOCS 01 council-opus.md, council-haiku.md: "Your dispatch names COURT (a path relative to the project root)".
- DOCS 02 docs/getting-started.md (Prerequisites): git line names Python 3 and the installer's last line for the three tools.
- DOCS 02 docs/getting-started.md (install): AGENTS.md with no CLAUDE.md gets CLAUDE.vulyk.md and the two-line CLAUDE.md.
- DOCS 04 README.md (lines 27, 133), docs/faq.md (line 20), docs/model-cascade.md (line 274): floor reads fable 5.2.
- DOCS 04 docs/getting-started.md (line 42): "free to change on Opus 5.5 and Fable 5.2" (a sentence about today's models). Other Fable 5.1 mentions (model-cascade 29, 128, 396) are not named, so untouched.
- DOCS 04 docs/pulse.md (cost line): cache reads weighed by family and version, with the three weights.
- DOCS 06 README.md (install paragraph): `--pulse on|off` and `--model-pin on|off`, default off, one offer line. No "installs the pulse mod" sentence exists in README, so nothing was dropped.
- DOCS 06 README.md and docs/hooks-reference.md (context-guard.sh rows): the PreCompact row is removed; the snapshots and librarian-pruning text went with it.
- DOCS 06 docs/hooks-reference.md (skill-usage-counter row): event adds UserPromptExpansion; a typed /vulyk-* command counts too.
- DOCS 07 docs/hooks-reference.md (handoff row): the window is read from the config pin (context_limit), then CLAUDE_CODE_AUTO_COMPACT_WINDOW (k/M suffixes) and CLAUDE_CODE_DISABLE_1M_CONTEXT, the statusLine copy, a same-model copy, the family table, the measured proof, else 200k; levels reset when the window changes.
- DOCS 07 docs/hooks-reference.md (auto-dump bullet): "last task list (TodoWrite or TaskCreate/TaskUpdate)".
- DOCS 07 docs/hooks-reference.md (defect-inject row): read-only Bash/PowerShell gets no card; a story's ## Files inside a fence is not read.
- DOCS 07 docs/command-reference.md (/vulyk-handoff entry): "last task list".
- DOCS 08 docs/command-reference.md (/vulyk-plan Client path): one blind seat at Tier 3-4, haiku instead of opus.
- DOCS 08 docs/pipeline.md (lead-review paragraph): the suite ran before dispatch; lead-review reads suite.log (T80).
- DOCS 09 docs/cycle.md (ship-check paragraph): the defect gate red or unable to run (no Python) is NOT READY.
- DOCS 09 docs/hooks-reference.md (git hook samples): post-merge and pre-push, the pre-push refusals, /vulyk-ship step 2a, --no-verify.
- DOCS 10 docs/memory-system.md: Learnings row marked retired; the single-consolidator bullet is deleted (the DOCS line says it is retired, and its only learnings clause went with it).
- DOCS 10 docs/self-evolution.md: the gc due bullet is deleted; the Learnings input line says retired; Harvest step 1 drops "learnings".
- DOCS 10 README.md: /vulyk-evolve row drops "mine learnings"; /vulyk-gc row drops "consolidate learnings"; the memory/learnings/ tree line is deleted; Harvest drops the learnings input.
- DOCS 13 docs/cycle.md (reopen): the repair round is full (full=design) after a reopened half or a reopen with --full; a reopened no-progress without --full is narrow; the reopen verb takes [--full] (the repair-round paragraph and the "An ESCALATE is on the record" row).
- Not applied, by the Queen's ruling: the memory/map/ DOCS lines (stories 01, 02, 05; workers never edit memory/, drone-docs at ship). Story 08's vulyk-bootstrap.md:23 note names no DOCS line in that story's notes, so no edit; drone-docs at ship if it still applies.
- Kept, not changed (docs-1115): the README "five layers" sentence, Learnings-is-a-buffer bullet, and every other contradiction in the same pages.
- CHANGELOG: 22 lines under Changed and 36 under Fixed (58 lines, one per CHANGELOG: line of stories 01-10, 12, 13), copied as written; story 03's three lines copied; each duplicated line appears once.
- Checks: maintenance.test.sh --part upkeep 166 checks 0 failed; --part redact 420 checks 0 failed; --part guards 912 checks 0 failed; prompt-check --touched on the two seat files ok; leak-check.sh exit 0 on each of the 14 changed files.

## Findings
NEEDS_CONTEXT: DOCS lines name files outside `## Files` (the story's Non-goals make these NEEDS_CONTEXT, so nothing was edited yet):
- story 01: `DOCS: .claude/agents/council-opus.md, council-haiku.md - "Your dispatch names COURT (an absolute path)" ...` (under `.claude/`, not editable here)
- story 01: `DOCS: memory/map/cycle.md (--short) - the court key is relative to the repo root, not absolute.`
- story 02: `DOCS: memory/map/scripts-install.md - (librarian/drone-docs, not story 11) the upgrade contract ...` (its own note excludes story 11; confirm it is dropped here)
- story 04: `DOCS: docs/pulse.md - the cost line: cache reads are weighed by family and version ...`
- story 05: `DOCS: memory/map/scripts-checks.md ...`, `DOCS: memory/map/scripts-hives.md ...`, `DOCS: memory/map/scripts.md ...`
- story 07: `DOCS: docs/command-reference.md - the /vulyk-handoff entry says "last TodoWrite": "last task list".`
- story 08: `DOCS: docs/command-reference.md - "(a filled *Client path* adds the black-box seat at Tier 3-4)" -> ...`
- story 08: `DOCS: docs/pipeline.md - lead-review runs the suite -> the suite ran before dispatch ...`
Question for the Queen: add these files to `## Files` (a later amendment of this story), or move these lines to the `docs-1115` spec. Every other DOCS line names a file under `## Files`; they are ready to apply once the question is settled.
Also: story 04's `docs/getting-started.md` line is conditional ("if the sentence is about today's models"); the sentence to change needs a check when applying.
- Queen (2026-11-17): every `DOCS:` line lands, none is dropped. `docs/pulse.md`, `docs/command-reference.md`,
  `docs/pipeline.md` and the two council seat files (story 01's relative COURT wording) join `## Files` for their
  `DOCS:` lines only. The `memory/map/` lines (stories 01, 02, 05) are not yours: workers never edit `memory/`;
  the Queen hands them to drone-docs at ship. `vulyk-bootstrap.md:23` (story 08's note) also goes to drone-docs
  at ship. Run `bash scripts/prompt-check.sh` on the two seat files before close.
- NEEDS_CONTEXT (builder, 2026-11-17, at close-story): every DOCS and CHANGELOG line is applied in the working tree (notes above); the three maintenance parts are green. `cycle.sh close-story --commit --stamp 4a14a7d5b933029e` exits 4 `edited outside ## Files: scripts/git-hooks/pre-push, scripts/tag-push-check.sh`. Neither file is mine: this story never edits them, and both were committed before this story (`aa31f98e`, the story-09 executable-bit chore, after the claim head 82adac76), so scope-check counts them as changed since the claim head. Question for the Queen: is the claim head to move past `aa31f98e` (or the story's scope to treat those two wave-mate paths as not this story's), so close-story can commit the story's own paths? Nothing was undone: those files are untouched by this story, and no commit was made.
