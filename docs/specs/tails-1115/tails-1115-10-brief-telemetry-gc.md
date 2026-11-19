---
story: tails-1115-10
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 4
blocked_by: [tails-1115-05]
red: required
red_reason: the consent line is read from the sidecar constitution
red_verified_at: 2026-11-17T14:43:30Z 003b562ed03f57a9634097b237be6561b272344b7742605e829e2c44e0d9b838
---

# The session brief and telemetry read the right constitution, the learnings chain is retired, the map test covers every slice

## Goal
Eight tails in the SessionStart brief, `telemetry.sh` and the gc chain (private
`~/.vulyk/audits/known-defects-2026-11-15/tails.md`, items T56, T27, T54, T59, T96, T93, T70, T92).
1. T56: telemetry consent and the brief's declined-offer lookup read the constitution through
   `lib.sh` `constitution_file`, so a sidecar hive is read correctly.
2. T27: `telemetry.sh` drops every control byte from `--spec`, `--story`, `--ref`, so a local line stays JSON.
3. T54: the brief says in one line when a sidecar hive's `CLAUDE.md` does not import the sidecar.
4. T59: "no map yet" fires when no map slice exists (a README in the folder is no slice); an offer the owner
   declined is not repeated every session.
5. T96: the learnings chain is retired. Nothing writes `memory/learnings/` since 0.18, so the brief, `/vulyk-gc`,
   `/vulyk-evolve` and `librarian` stop reading and serving it. Files already in a hive stay where they are.
6. T93: `librarian` has no shell; whatever it was told to compare by file time now arrives as a list from its
   caller.
7. T70: `/vulyk-evolve` reads the meta-skills by path, so they are used wherever skills are discovered.
8. T92: the map width and line test covers every `memory/map/*.md`.

Marked red: new branches in a hook every session runs and in the consent read.

## Requirements
> 5. The hook, telemetry, token-report, prompt-check and model-floor tails in tails.md are fixed; a fallback never runs a model below the floor (pause instead).
> 6. Dead mechanisms are retired: the unwritten learnings chain and the never-read pre-compact snapshots, without deleting any data already in a hive.
> 10. Every fix that code can check gets a failing test with the original case and a neighbour form; all suites green.

## Files
- .claude/hooks/session-start-brief.sh
- scripts/telemetry.sh
- .claude/agents/librarian.md
- .claude/commands/vulyk-gc.md
- .claude/commands/vulyk-evolve.md
- tests/maintenance.test.sh
- CLAUDE.md

## Non-goals
- Never delete, move or rewrite a file under a hive's `memory/learnings/`, and list none under `Delete:`.
  `is_paperwork_path` keeps its `memory/learnings/*.md` entry (`lib.sh` is not yours).
- `librarian` keeps its other jobs (the memory index, the ADR harvest at ship); `/vulyk-gc memory` is untouched.
- Do not move `.claude/skills/_meta/`: the installer's file list and every hive depend on the paths.
- `telemetry.sh`: `ENUM` and `AGENTS` stay append-only; consent stays off unless the constitution says on.
- The brief stays silent for a subagent and keeps its other lines.
- Do not edit `memory/`: if the widened map test is red on a slice at HEAD, return `NEEDS_CONTEXT` naming file
  and line (the Queen wraps it, plan.md `## Assumptions`).
- No doc edit (story 11) and no installer or settings edit (story 06 did the installer half of T54).
- Run `bash scripts/portability-check.sh .claude/hooks/session-start-brief.sh scripts/telemetry.sh` after each
  edit.

## Map slice
`memory/map/scripts-hooks.md` → Entry points (`session-start-brief.sh`, `telemetry.sh`), Gotchas;
`memory/map/scripts.md` → Entry points (`lib.sh` `constitution_file`); `memory/map/agents-and-commands.md` →
librarian; `memory/map/commands-ship.md` → `/vulyk-gc`, `/vulyk-evolve`.

## Acceptance criteria
- [ ] In a scratch sidecar hive whose sidecar constitution says telemetry is on and whose `CLAUDE.md` holds only
  the import, `telemetry.sh consent` reads on. The label contains `the consent line is read from the sidecar
  constitution`. Neighbours: the brief's declined-offer row in the sidecar is honoured; a plain hive behaves as
  today; no constitution at all reads off.
- [ ] `telemetry.sh record` with a control byte (one below 0x20 other than tab, CR, LF) in each of the three
  arguments writes a line `jq -e .` accepts. Neighbour: tab, CR and LF are still dropped; ordinary text is
  unchanged.
- [ ] The brief prints one line for a sidecar hive without the import and none with it.
- [ ] A hive whose `memory/map/` holds only a README gets the "no map yet" line; one slice silences it. A declined
  offer recorded in the constitution is not printed again.
- [ ] With a `memory/learnings/` folder holding files, the brief prints no line about it, and `vulyk-gc.md`,
  `vulyk-evolve.md` and `librarian.md` name no step that reads, consolidates or deletes those files. The folder's
  files are byte-identical after a brief run. `librarian.md` asks for nothing that needs a shell.
- [ ] `vulyk-evolve.md` names each meta-skill file by path with an instruction to read it.
- [ ] The map test fails on a fixture slice with an over-long line or too many lines, whatever its name.
- [ ] `bash scripts/prompt-check.sh --touched <the three prompt files>` reports no error; every new case fails on
  HEAD and the notes list them.

## Verification
`bash tests/maintenance.test.sh --part upkeep`
`bash tests/maintenance.test.sh --part redact`
`bash tests/maintenance.test.sh --part guards`
`bash tests/telemetry.test.sh --part scan`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per item and a `DOCS: <file> - <sentence>` line for each doc sentence story 11 must change (the learnings lines of
docs/memory-system.md, docs/self-evolution.md and README.md). -->
- session-start-brief.sh: sources lib.sh (relative to the hook, as memory-triage.sh is found) and reads `const` via
  `constitution_file`, CLAUDE.md fallback when lib.sh is absent; the litopys decline greps the constitution and CLAUDE.md.
- session-start-brief.sh: one line when CLAUDE.vulyk.md exists and CLAUDE.md (missing or not) lacks the import; the
  regex is install.sh's own (story 06). README.md in memory/map/ is no slice. The learnings gc block is gone.
- telemetry.sh: consent reads `constitution_file "$ROOT"`; sanitize is `tr -d '"\\\000-\037'` (all of 0x00-0x1f).
- librarian.md: no learnings step, no mtime comparison, no `Delete:` list; the map list (slice, last commit date,
  commits since outside memory/) arrives in the dispatch; vulyk-gc.md computes it with one git line.
- vulyk-gc.md: the guarded CONSOLIDATED.md commit line is replaced by an index-only commit line; the "gc due" paragraph
  went with the brief's gc line (gc is no longer offered by the brief; it runs on demand).
- vulyk-evolve.md: reads both meta-skills by path; the skills' learnings inputs are named as retired, to skip.
- maintenance.test.sh: the gc-due cases and the CONSOLIDATED refusal cases are replaced (they asserted the retired
  chain); map test is a `map_over` over every memory/map/*.md, all 15 slices pass at HEAD.
- New cases red on HEAD (18): no learnings line/nothing due, the three prompt files x memory/learnings, librarian mtime,
  librarian delete, librarian dispatch list, gc git line, evolve x2 meta-skill paths, sidecar consent, sidecar litopys
  decline, import line x2 (missing import, no CLAUDE.md), map README-only, control-byte JSON, control-byte fields.
  The map fixture cases pass on HEAD by construction (the check lives in the test); the old `scripts*.md` glob would
  have missed both fixtures (cycle.md, agents.md).
- Surprise: `bash tests/telemetry.test.sh --part scan` is red on one case of wave-mate tails-1115-07 (T69 Fable
  family window), red before any edit of mine; not in my files.
- maintenance.test.sh (retry): the gc cases redirected output to `$T/gc-lower`, the repo dir the case creates;
  outputs now go to `$T/gc-<case>.out` (redact part 420/420).
- CLAUDE.md (Queen's note): the `| Defect hooks |` row label is now `| Defects |`, 7167 -> 7162 B (CR removed).
- CHANGELOG: telemetry consent and the session brief's litopys decline read the sidecar constitution (CLAUDE.vulyk.md).
- CHANGELOG: telemetry record drops every control byte below 0x20 from --spec, --story and --ref.
- CHANGELOG: the session brief names a sidecar CLAUDE.vulyk.md that CLAUDE.md does not import.
- CHANGELOG: "no map yet" fires when memory/map/ holds only a README; a recorded litopys decline is honoured in a sidecar hive.
- CHANGELOG: the memory/learnings chain is retired from the brief, /vulyk-gc, /vulyk-evolve and librarian; files stay.
- CHANGELOG: librarian gets the map-slice dates from its caller instead of comparing file times without a shell.
- CHANGELOG: /vulyk-evolve reads insight-harvester and skill-gardener by path.
- CHANGELOG: the map width and line test covers every memory/map/*.md.
- DOCS: docs/memory-system.md - the Learnings row (line 12) and the single-consolidator bullet: retired, nothing reads them.
- DOCS: docs/self-evolution.md - the "gc - stub learnings exist, or 10+ raw ones wait" due line, the Learnings input
  line and Harvest step 1: learnings no longer feed evolve or gc.
- DOCS: README.md - the /vulyk-evolve and /vulyk-gc rows (lines 177-178), the memory/learnings/ tree line (195) and
  Harvest (206): no learnings.

## Findings
- close-story exit 4: `edited outside ## Files: memory/map/agents-and-commands.md, memory/map/cycle-close.md,
  memory/map/cycle-repair.md, memory/map/cycle-state.md, memory/map/cycle.md, memory/memory.md - committed since the
  claim head 8bdd6ac0`. None of them is mine: they are commit 4658299b (Queen step before wave 4, map slices within
  80 lines and 130 chars). The claim head needs moving past 4658299b (or the paths accepted) before close-story can pass.
  My work is complete and uncommitted: upkeep part 166/166 green; telemetry scan part is red on one wave-mate case
  (tails-1115-07, T69), red before any edit of mine.
- Retry (stamp c331ac18833c1053): the claim-head refusal is gone (scope-check 6/6, 0 out of scope). close-story then
  failed `bash tests/maintenance.test.sh --part redact` (5 cases): my gc test cases redirected output to
  `$T/gc-lower`/`$T/gc-upper`, the very dirs `gc_case` creates, so mkdir failed. Fixed in tests/maintenance.test.sh
  lines 1050-1056 (outputs to `$T/gc-<case>.out`); redact part now 420/420. close-story now refuses with
  `test changed after red receipt: re-run stamp-red`, and the implementation is already green, so by protocol I do not
  re-stamp. The Queen decides: re-stamp from base (revert impl, stamp-red, re-apply) or accept the test-only edit.
- Retry (stamp 328899d5e53f8699, after the Queen's re-stamp from base): close-story exit 4 on
  `bash tests/maintenance.test.sh --part guards` (912 checks, 2 failed: "portability-check: the tree exits 0" and
  "the tree prints its ok line"). The tree check's 2 hits are both in `tests/inject.test.sh` (lines 246 and 273,
  `sed -i` without a suffix), a wave-mate's uncommitted edit (tails-1115-07), not in my `## Files`. My own files pass
  portability-check. Needs the wave-mate's fix (sed_inplace or `sed -i.bak`) or its close before 10 can close.
- Retry (stamp 94fbfe302879088e): the guards refusal is gone (portability-check ok; upkeep, redact, guards green,
  maintenance 912/912). close-story exit 4 on line 4 `bash tests/telemetry.test.sh --part scan` (175 checks, 1 failed):
  `no context_high row for a Fable session at 150k with no report: the family table gives 1M - expected [0], got [1]`,
  tests/telemetry.test.sh line 882. That is tails-1115-07's sealed T69 case (uncommitted in the tree, its handoff.py
  family table not built yet), not in my `## Files` and not my code. 10 can close once 07 closes (or that line leaves
  my `## Verification`).
- Retry (stamp c32ee87d7fa14371): tails-1115-07 is still `status: todo`, so per the Queen's note nothing was run;
  close-story waits for 07 to close.
- Retry (stamp 3e9b2ad667cc30d8): tails-1115-07 is still `status: todo`; per the Queen's note nothing was run.
- Retry (stamp 04f5272d9440a700): 07 is done; close-story exit 4 on `bash tests/maintenance.test.sh --part upkeep`
  (166 checks, 1 failed): `CLAUDE.md grew past its baa5219 size` (tests/maintenance.test.sh line 117, not my edit).
  CLAUDE.md is 7167 B against 7162 B at baa5219; commit 6c79b69b (tails-1115-07) grew it (Commands intro line and the
  new Inject row). CLAUDE.md is not in my `## Files` and the check is not mine to loosen: CLAUDE.md needs 5 B trimmed
  by the Queen or a story naming it. The other 165 upkeep checks are green.

## Red receipt
- command: bash tests/maintenance.test.sh --part upkeep
- exit: 1
- tests: 003b562ed03f57a9634097b237be6561b272344b7742605e829e2c44e0d9b838 (tests/maintenance.test.sh)
- impl: eb22b804adc32ec31316f9f597e0cc55f59f66f1b6f7f2bea5d98503912f2d21
- stamped: 2026-11-17T14:43:30Z

```
::error::telemetry consent: the consent line is read from the sidecar constitution - got 'off'
--- green terminal asks «Выпускаем?» and ships on yes
  ok    vulyk-build green asks through AskUserQuestion
  ok    vulyk-build green asks «Выпускаем?»
  ok    vulyk-build green runs vulyk-ship with the Skill tool on yes
  ok    vulyk-build green keeps the one-line fallback
  ok    vulyk-review green asks through AskUserQuestion
  ok    vulyk-review green asks «Выпускаем?»
  ok    vulyk-review green runs vulyk-ship with the Skill tool on yes
  ok    vulyk-review green keeps the one-line fallback
maintenance.test.sh: 166 checks, 18 failed
```
- Queen (2026-11-17): your work is done; `--part scan` waits for story 07's T69 table. Until 07 is `status: done`,
  return NEEDS_CONTEXT at once without running anything; then close-story.
- Queen (2026-11-17): `tests/maintenance.test.sh` holds CLAUDE.md at its baa5219 size (7162 B with CR removed);
  story 07 left it at 7167. `CLAUDE.md` joins `## Files` for one change only: the row label `| Defect hooks |`
  becomes `| Defects |` (5 bytes; no test or script keys on that label); nothing else in CLAUDE.md changes. The
  Queen shows the owner this diff before the close. Then close-story.
