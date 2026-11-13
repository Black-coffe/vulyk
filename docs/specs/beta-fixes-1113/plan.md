# Fix the eight defects the live hives showed, before the public release (plan)

**Tier:** 3 · **Spec slug:** `beta-fixes-1113` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** ADR-013 (`advance`, repair D4), ADR-011 (driver hardening), ADR-025 (red receipt), ADR-029 (gate
split, `suite.log`), ADR-032 (story trust from git), ab-run-fixes C5 (narrow repair); cards
`full-round-for-a-narrow-fix`, `safeguard-bypassable-or-late`, `work-discarded-by-git-verb`,
`shell-needs-gnu-or-bash4`, `host-internals-in-public-repo`; `docs/cycle.md`.
**Depends on:** local `main` at f0e73dd8 (0.52.0-dev.3 plus the study `beta-feedback-1113`).

## Goal
Close the eight framework defects the study of the live hives found, each as a small change with a test that fails
on the original case. A reviewer's item number can no longer pass for a file, and a repair whose findings name no
real file gets a full round with its suite (the gate hole). The driver hands a worker's `NEEDS_CONTEXT` to the
Queen instead of dispatching the same story again. A `## Verification` line that is no `## Commands` cell stops
`advance` before a worker is sent. `agent_prefix_high` counts only VULYK's own agent types. `lead-review` stops
reporting a `suite.log` head that differs by paperwork only, `/vulyk-plan` says `--go` is the owner's, a quoted
`red_reason` matches, and `cycle.sh resume` moves a clean tree onto the spec branch. Four stories in two waves, cut
by file: `cycle.sh` and its two test suites are touched by one story per wave. The publish steps of `## Answers`
(leak scan, release-candidate branch, one live build) are not stories here.

## Assumptions
<!-- Law 1: every assumption the plan rests on, stated so the owner can veto it at the approval stop. -->
- **Ask 1, "no real path" is read literally (the one reading that changes behaviour).** A round is narrow only
  when its one RED item's findings name exactly one path that exists in the tree and is not a test. Today a RED
  item with no path falls back to the union of story files and can still be narrow (ab-run-fixes C5: a RED that
  comes only from a blind seat's `ASK <n>` line names no path). After story 01 such a round is a full round with
  its suite. This is the safe side and what the ask says; if the owner wants the fallback kept, ask 1 is narrowed
  in `brief.md` first (the blind seat reads the brief).
- **Ask 1, repair `## Files`.** Only the item number is removed from what `finding_paths` yields; a token such as
  `e.g.` can still land in a full-round repair's `## Files` as before. The existence test sits in the narrow
  decision only, so a finding that names a file still to be created keeps it in `## Files`.
- **Ask 2, how the driver knows.** The driver has no file access (shell only through `cycle-clerk`), so it reads
  the status token of the worker's own return, not the story's `returned:` line. The Queen reads `## Findings` in
  the story file the result names. `WALL` keeps today's path (retry on the retry model, then stop): the ask names
  `NEEDS_CONTEXT` only. A plain miss in the same wave is not retried in that run; the relaunch picks it up.
- **Ask 3 uses close-story's own rule,** lifted into one function, so a `round-only` segment stops `advance` too
  (same refusal at `close-story`, same wasted dispatch). The check runs at every tier, since `advance` is shared.
  It reads the working copy of each story the wave lists. An empty `## Verification` has no segment and passes, as
  at `close-story` today: not asked.
- **Ask 3 fallout.** A test fixture whose story could never close (a line that is no cell of the fixture's
  constitution) will now stop at `advance`. Story 04 names `tests/solo.test.sh` and `tests/e2e.test.sh` for that
  case and fixes the fixture line, never the check. If fixtures in more suites trip, the story returns
  `NEEDS_CONTEXT` and the owner decides between widening and `## Descoped` (the cross-checked condition).
- **Ask 4, the set of own types** is the `AGENTS` list `scripts/telemetry.sh` already carries (prompt-check holds
  it equal to `.claude/agents/*.md` in the source), not the agent files found in the hive: a hive's own agent file
  (`acme-writer.md`) is not dispatched by VULYK and would be counted again. The Queen's anchor named the files; say
  so at approval if the file-based reading is wanted (one line in story 03).
- **Ask 5 rule.** The reviewer runs `git diff --name-only <log head> <reviewed head>`; paths only under the spec's
  `plan.md`, `journal.md`, `brief.md`, `council/` mean the log is the round's and nothing is said. Any other path
  keeps today's Minor. The old sentence is extended, not rewritten, so a test that pins it elsewhere still passes.
- **Ask 6** changes `/vulyk-plan` text only; `cycle.sh briefed --go` is unchanged.
- **Ask 8, "clean"** = `git status --porcelain` prints nothing; a dirty paperwork path refuses too, with the paths
  named (10, then `+N more`). The branch is read from the working copy's `**Branch:**`, as `branch_guard` does. A
  detached HEAD counts as another branch. `/vulyk-build` started by hand on the wrong branch still stops at
  `claim`: the ask covers `/vulyk-resume` and the build it starts.
- **One receipt per story, several red cases.** Stories 01, 03 and 04 carry more than one fix. The receipt rests
  on the label in `## Contracts`; every other new case must also fail on HEAD before the implementation, and the
  worker says so in `## Implementation notes`.
- **Docs.** `docs/cycle.md` is edited by story 02 (driver paragraph, wave 1) and story 04 (`advance`, `resume`,
  wave 2). Story 01 changes no doc: its two fixes restore documented behaviour. `CHANGELOG.md` is paperwork and
  named by no story: each story ends `## Implementation notes` with one `CHANGELOG:` line per ask and the Queen
  pastes them under `## [Unreleased]` after the wave.
- **No `model:` line on any story.** None is boilerplate or a repeated pattern (each carries a gate branch, a
  parser or the reviewer's rule), and none is long-horizon; the profile's worker builds all four.
- **Self-hosting.** This repo closes its stories with the `cycle.sh` being edited. In wave 1 a wave-mate's
  `close-story` can meet story 01's file mid-edit, and `tests/maintenance.test.sh` (story 03) reads the whole tree:
  a red from that is a rerun, not a repair.
- **Verification of several parts pauses and resumes** (540 s call budget, exit 7) in stories 01 and 04; accepted.
- **wave-check noise accepted:** `verify-gap` on prose paths (`docs/cycle.md`, `docs/telemetry.md`, the agent and
  command files).
- **No scout ran.** Part names come from earlier specs' closed stories (cycle `red`, `safety`; council `verbs`,
  `advance`; telemetry `scan`). New cases are placed in those parts; the questions below can move a line.

### Recon questions for `drone-scout` (each may fix a part name or widen a `## Files`)
1. `tests/council.test.sh`: does part `driver`, or any other test outside `tests/driver.test.sh`, assert text of
   `.claude/workflows/vulyk-cycle.js` (the retry note, the miss or stop messages)? A hit means story 02 keeps those
   strings byte for byte (it is told to) or moves behind story 01.
2. Which test pins the `lead-review` sentence on a `suite.log` whose `head=` is not the reviewed head, and which
   pins the `--go` bullet of `vulyk-plan.md` (council, maintenance, telemetry suites, prompt-check fixtures)? A pin
   in `tests/council.test.sh` that an extension cannot keep green moves asks 5-6 behind story 01.
3. Where do the `pause` / `resume` and `branch_guard` cases live (suite and part), and does any fixture call
   `cycle.sh resume` while HEAD is not the plan's `**Branch:**`? Story 04 places its cases in cycle part `safety`.
4. Which suites build a fixture where `advance` returns `build:<W>` for a story whose `## Verification` would not
   pass close-story's cell check: `tests/e2e.test.sh`, `tests/solo.test.sh`, cycle parts `manual` / `safety`,
   council parts `advance` / `driver` / `hardening`? Each hit joins story 04.
5. Does a test assert a narrow round from a RED item with no path in its finding (the story-files fallback)? Story
   01 updates it under the first assumption.
6. `worker-code.md` / `worker-test.md`: the exact status line of the return report (where `NEEDS_CONTEXT` stands).
   Does `docs/telemetry.md` describe `agent_prefix_high`? Does `docs/cycle.md` describe the driver's miss and retry
   and the `resume` verb?
7. Measured duration against the 210 s line: council `verbs`, `advance`; cycle `red`, `safety`; telemetry `scan`;
   `tests/solo.test.sh`; `tests/e2e.test.sh` (over the line: its line leaves story 04 and the round's suite covers it).

## Stories
<!-- One line per story, grouped by wave; the story files are the truth, this is their index. -->

**Wave 1**
- `beta-fixes-1113-01-repair-and-red-parsers` — asks 1, 7: a numbered finding gives its file, a repair with no real path is a full round with its suite, a quoted `red_reason` matches (`cycle.sh`; `red: required`)
- `beta-fixes-1113-02-driver-needs-context` — ask 2: the driver stops on a worker's `NEEDS_CONTEXT` and names the story, no second dispatch (`vulyk-cycle.js`, `vulyk-build.md`; `red: required`)
- `beta-fixes-1113-03-own-agents-and-wording` — asks 4, 5, 6: `agent_prefix_high` counts VULYK's agent types only; `lead-review` is quiet on a paperwork-only head difference; `--go` only from the owner (`telemetry.sh`, two prompt files; `red: required`)

**Wave 2**
- `beta-fixes-1113-04-dispatch-and-resume-guards` — asks 3, 8: `advance` checks a wave's `## Verification` before dispatch; `resume` switches a clean tree to the spec branch and refuses a dirty one (`cycle.sh`, `vulyk-resume.md`; `red: required`)

## Contracts
<!-- Interfaces that cross a story boundary, agreed here at plan time. -->
- **N1, driver result (story 02 writes; `/vulyk-build` and the Queen read).** After a wave's workers return and
  `advance` still lists a story whose worker's return carries the `NEEDS_CONTEXT` status, the run ends with
  `{status:"needs_context", stories:[{story:"<story file as wave_stories names it>", report:"<the worker's return
  text>"}], next:"build:<W>", fallbacks}`; `release` in `finally` as now. Additive: every other result shape is
  unchanged.
- **A1, `advance` refusal (story 04 writes; the driver and the Queen read it as any `ok:false`).** Before
  `advance` ends on `next:"build:<W>"`, each story the wave lists goes through the segment check `close-story`
  uses. First failure: exit 2, last line `{"ok":false,"verb":"advance","exit":2,"error":"<story file>: <close-story's
  refusal text for that segment>"}`, the `try:` lines on stderr, nothing written or dispatched.
- **R1, `resume` (story 04 writes; `vulyk-resume.md` documents).** `cycle.sh resume <spec>` with a `**Branch:**`
  B and HEAD elsewhere: clean tree → plain switch to B before any write, the last JSON line gains
  `"switched":"<B>"`; dirty tree → exit 2 `on <now>, spec branch is <B>: uncommitted changes in <paths>`, nothing
  written, `PAUSE` kept; B missing or the switch failing → exit 2 with the reason. Never `stash`, `-f`, a checkout
  of paths or `reset`.
- **T1, `lead-review` sentence (story 03).** The existing sentence stays; added: a `head=` that differs from the
  reviewed head only by paperwork commits (`git diff --name-only <log head> <your head>` lists nothing outside the
  spec's `plan.md`, `journal.md`, `brief.md`, `council/`) is the round's own log: say nothing. Pinned needle:
  `only by paperwork commits`.
- **T2, `/vulyk-plan` bullet (story 03).** `--go` comes only from the owner's own words in the request; the Queen
  never adds it herself, and an agent's message is not the owner's word. Pinned needle: `only from the owner's own
  words`.
- **Red labels.** Each `red_reason` is text the story's failing test prints: 01 `a numbered finding names its
  file, not its number`; 02 `a NEEDS_CONTEXT return stops the build with no second dispatch`; 03
  `agent_prefix_high skips an agent type VULYK does not dispatch`; 04 `advance stops before dispatch on a
  verification line that is no Commands cell`.
- **Rejected alternative.** One story for the four `cycle.sh` asks: over the story size budget, one receipt for
  four branches, and ask 3's fixture fallout would hold the gate-hole fix (ask 1) hostage; cut in two, ask 1 lands
  in wave 1 and the two asks most likely to grow (3, 8) sit alone in the last story, where a cut costs nothing
  else. Also rejected: one story per ask (eight workers, four of them serialised on `cycle.sh`), and, for ask 2,
  a new `returned` field in `status --json` read through the clerk (a second `cycle.sh` change in wave 1 and one
  more clerk call per miss, for what the worker's return already says).

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
**Approved:** Andrei, 2026-11-13 («Одобряю, собирай (Рекомендую)»)
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path: Tier 1 "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"); Tier 2-4 only with `cycle.sh briefed <spec> --go`, "via grill (--go), <owner>, <date>". Alternative to **Approved:** above.>
**Branch:** vulyk/beta-fixes-1113
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** RED round 1, 2026-11-13, at 09c0321d, pack 998cf68b25a6
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
