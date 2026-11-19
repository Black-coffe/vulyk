# Close the known gaps in VULYK's guard hooks (plan)

**Tier:** 3 · **Spec slug:** `guards-1115` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** ADR-032 (story trust from git, the run state), ADR-025 (red receipt), ADR-021 (cards), ADR-039
(`human-check.sh --commit`), ADR-015 (families); Law 6; cards `safeguard-bypassable-or-late`,
`owner-words-by-builder`, `work-discarded-by-git-verb`, `host-internals-in-public-repo`; `docs/cycle.md` "Run state".
**Depends on:** `main` at 479ba709 (0.53.0 published, ADR sweep done). Sibling specs `tails-1115` and `docs-1115`
follow; one release 0.54.0 after all three.

## Goal
Carry the eight asks in four stories and three waves, one story per file set. Wave 1 closes what a subagent can do
to the cycle's records and the owner's records: git-guard refuses a subagent's shell call on the run state, every
history-changing git verb during a build, and three forms the owner chose to close, reads the git verb through the
forms that hid it, and keeps its subagent rules without Python; owner-guard refuses a subagent's tool write to the
run state and the owner-only commands and records under any spelling. Wave 2 makes the cycle read its own record at
the red gate and stop leaving raw test output in the temp folder. Wave 3 keeps a blind seat inside its own court:
git by an allowlist, paths judged by their resolved form, no path hidden behind a glued option, no other round's
court, no main-session scratch folder. Each closed gap gets a test with the original form and a neighbour form, each
hook header ends with what it still leaves open, and the exact forms stay in the private inventory.

## Assumptions
<!-- Law 1: every assumption the plan rests on, stated so the owner can veto it at the approval stop. -->
Taken from the private `decisions.md` (section FINAL):
- **A1.** The run state is protected by a deny in the existing hooks (owner-guard for Write/Edit, git-guard for the
  shell), not by moving the records into git refs.
- **A2.** For a subagent both hooks run their Python half on every shell call instead of a text prefilter. Cost: one
  interpreter start per hook per call. Loops such as `for t in tests/*.test.sh; do bash "$t"; done` must keep
  passing (contract L1).
- **A3.** A blind seat's git commands are judged by an allowlist of verbs, not by a list of forbidden ones.
- **A4.** Per the owner's answer («Только безопасные»): closed are another round's court, the main session's scratch
  folder under temp, `tag -f`, `push --force`, `iex`; code handed to an interpreter stays open for seats and the
  header says so. The other header-named forms stay open and named.

This plan's own readings, for veto at approval:
- **Privacy.** Stories name item numbers (S<n>, T14) and classes of behaviour; each worker reads the forms from
  `~/.vulyk/audits/known-defects-2026-11-15/`. A form enters the repo only as a test input for a gap that story
  closes. An item left half done goes back to the private folder; no repo text describes it.
- **Main session.** The main session keeps today's fast text prefilter in both hooks; the quote rule still judges
  every spelled form. Disguised spellings in the main session are named as open in the owner-guard header. Say so
  if the main session should also pay an interpreter start on every shell call.
- **Unreadable script word.** A subagent's shell call whose script word cannot be read from the command text is
  refused with "spell the script path", unless the shell only checks syntax. A loop over a literal list or a glob is
  read.
- **Shell reads of the run state** are refused to a subagent too (reading shell text for write-or-read did not
  converge in `owner-guard-commit-fp`); the Read tool passes and the refusal names it.
- **Tools the owner guard is not wired on.** The matcher stays `Bash|PowerShell|Edit|Write|MultiEdit`; no
  `settings.json` or `install.sh` change. A write through any other tool (a notebook editor, an MCP file tool) is
  named as open in the header. Recon question 10 decides whether a wiring story is needed.
- **Own court.** A seat's court is the court directory its call stands in; a call that stands in no court may read a
  court path only when one court exists. If seats do not work from inside their court, story 04 returns
  `NEEDS_CONTEXT` (recon questions 4, 5).
- **Seat git allowlist** holds the git forms the seat prompts name, plus tree state and repository location; `diff`
  and `log` stay allowed only with pathspecs outside `docs/specs/`.
- **No Python.** git-guard's fallback keeps the subagent rules by text; owner-guard judges a subagent's shell call by
  a wider text filter; court-guard keeps denying a seat's every call.
- **Upgrade effect of the red gate (story 03).** No transition rule: a receipt with no `stamp-red` record is refused.
  A hive upgraded in the middle of a build, holding a stamped story that is not closed yet, is refused once at that
  close; the way out is the Queen's `stamp-red --baseline`. The rollout upgrades a hive between builds, or names
  this step. Say so if a dated transition rule is wanted instead (it would let an old-dated receipt pass).
- **Docs.** `docs/hooks-reference.md` and `CHANGELOG.md` are not written here: no ask names them, and `docs-1115`
  writes them from the `CHANGELOG:` lines each story leaves. Until then the reference describes 0.53. Story 03
  touches only the run-state sentences of `docs/cycle.md`; cards follow their hook's header (stories 01, 02).
- **Self-hosting.** The three hooks judge the workers that edit them, and hook edits take effect at once (seen in
  `audit-fixes-1113` story 10's notes). Each hook story prototypes on a scratch copy and applies edits that leave
  the file runnable. Story 03's own close meets the gate it builds, so its order of work is fixed in the story. A
  red caused by a wave-mate's file mid-edit (`tests/maintenance.test.sh` reads the whole tree,
  `tests/defects.test.sh` runs card checks through git-guard) is a rerun, not a repair.
- **Three waves.** Story 03 runs alone: a story editing `close-story`'s gates in `cycle.sh` shares no wave (plan
  delta of `audit-fixes-1113`, 2026-11-14). Story 04 does not share a wave with story 02: both verify with the
  defect-hooks row, and a wave-mate's sealed red tests would fail the other's close. Recon question 1 can move
  story 04 into wave 1.
- **Story 01 is large** (seven items, one file). Its items are ordered so that a miss at the turn cap is cut after
  item 4: items 5-6 (ask 4) become a second story in wave 2. S6's three forms ride in story 01, not in the last
  wave: no worker uses them.
- **Models.** Stories 01-03 carry `model: opus` with the reason under `## Goal`; no story is routine enough for
  `model: haiku` (each carries a parser or a security branch).
- **Queen's steps outside the stories.** After wave 3: re-run the private probe set against the built hooks and have
  one reviewer of the judging family read the three hook diffs with the private inventory in hand (decisions.md:
  "a security-focused review"); results stay in the private folder.
- **S19** (the cut-off fifth finding of the commit review) is not in this spec: it needs the owner's full text.
- **Verification of several lines pauses and resumes** (540 s call budget, exit 7); accepted for story 03.
- **No scout ran.** Test homes come from the closed stories of `audit-fixes-1113` and `owner-guard-commit-fp`:
  git-guard in `tests/maintenance.test.sh`, owner-guard in `tests/defects.test.sh`, court-guard in
  `tests/inject.test.sh`, the red receipt in cycle parts `red`/`red2`.

### Recon questions for `drone-scout` (each may widen a `## Files` or move a line)
1. Does `wave-check.sh` / `close-story` accept one `&&` segment of the defect-hooks cell (`bash tests/inject.test.sh`,
   `bash tests/defects.test.sh`) as a cell? Yes: story 02 verifies with the second, story 04 with the first and
   moves to wave 1 (`blocked_by: []`).
2. The symbol map shows `tests: textual 2 not shown` for each hook. Which two test files name each hook, and which
   block holds its cases? A home other than the one assumed joins that story's `## Files` and `## Verification`.
3. Measured run time of `bash tests/maintenance.test.sh` and of the defect-hooks row against the 300 s line cap.
4. Which directory do a blind seat's calls start in (hook-input `cwd`), how is a round's court directory named, and
   can two courts exist at once (a leftover of an escalated round)?
5. Which git commands and which paths do `council-opus.md`, `council-haiku.md` and the `/vulyk-build` dispatch text
   tell a seat to run or read?
6. Does any agent prompt, command or doc tell a subagent to run a shell command naming the run-state folder, a loop
   whose script word is a variable, or a shell write naming a spec's `plan.md`? How do `lead-review` and the seats
   write their report files? Each such form joins contract L1.
7. Does the `stamp-red` verify record survive a finished `stamp-red`, and which receipt values does it hold? Which
   fixtures (cycle parts, council parts, `solo`, `e2e`, `driver`) close a marked story with a receipt no `stamp-red`
   run wrote? Each joins story 03; a suite with none leaves its `## Verification`.
8. Does any test pin the list or count of `tests/cycle.test.sh` parts? A pin outside that file joins story 03.
9. Does any test pin the hook rows of `docs/hooks-reference.md`, or a card's `## Check` list, against a hook header?
   A pin outside the story's own test file moves that file or that pin.
10. Which agents' `tools:` hold a notebook editor or an MCP tool that writes files?
11. The importers the symbol map counts for the three hooks (3, 2, 1): does any read more than the hook's stdin
    contract and its `--check` exit codes, which do not change?

## Stories
<!-- One line per story, grouped by wave; the story files are the truth, this is their index. -->

**Wave 1**
- `guards-1115-01-git-guard` — asks 1, 2, 3, 4, 6: a subagent's shell call on the run state, the script word, history
  verbs under a DRIVER, the three forms closed on the owner's answer, the parser, the no-Python fallback (`model: opus`)
- `guards-1115-02-owner-guard` — asks 1, 2, 6: a subagent's tool write to the run state; the owner-only commands and
  records under any spelling (`model: opus`)

**Wave 2**
- `guards-1115-03-cycle-run-state` — asks 1, 8: the red gate reads the cycle's own stamp-red record; a record names
  only its own temp directory; stored test output is removed (`model: opus`)

**Wave 3**
- `guards-1115-04-court-guard` — asks 5, 6: git by allowlist, resolved paths, glued options, the seat's own court,
  the main session's scratch folder

Ask 7 (a test with the original and a neighbour form; no legitimate flow denied) is carried by every story.

## Contracts
<!-- Interfaces that cross a story boundary, agreed here at plan time. -->
- **H1, callers (existing; stories 01, 02, 04).** A hook call is a subagent's when its stdin JSON has a non-empty
  top-level `agent_id`. A blind seat is `agent_type` `council-opus` or `council-haiku`. Hook stdin and the `--check
  <file>` exit codes (1 deny, 0 otherwise) do not change.
- **L1, flows that keep passing (stories 01, 02, 04).** For a subagent: every backticked command of the
  constitution's `## Commands`; the six `cycle.sh` verbs as the clerk and the workers call them; the report-only
  checks (`wave-check.sh`, `trace-check.sh`, `scope-check.sh`, `symbol-map.sh`, `prompt-check.sh`,
  `portability-check.sh`, `defects-check.sh`); a loop over a literal list or a glob that runs each test script
  (`for t in tests/*.test.sh; do bash "$t"; done`); a shell that only checks syntax, behind `xargs` too; git reads
  and `git update-index --chmod`; reading a spec's `plan.md` with no writer in the command; writing a report or a
  note outside the guarded paths whose text (a heredoc body fed to a file, an `echo` or `printf` word) names the run
  state, `plan.md`, a verdict word or a guarded script; the planner's Write of a `plan.md` whose marker lines hold
  the template placeholder. For the main session: everything that passes today.
- **R1, run state (stories 01, 02, 03).** The guarded place is `<project>/.vulyk/state/`, by resolved path (`..`,
  links, letter case on a case-insensitive disk). Story 02: a subagent's Write, Edit or MultiEdit into it is denied.
  Story 01: a subagent's shell command is denied when a path word or a redirect target names it, when the command
  stands in it after a `cd`, or when text handed to a shell or an interpreter names it; a `cycle.sh` call with one of
  the six verbs passes; the reason names the Read tool. Story 03: a record's stored-output directory is honoured
  only as a real directory directly under the temp root with `stamp-red`'s own prefix, owned by the caller; else the
  record is dropped with a stderr reason and nothing is read or removed.
- **N1, script word (stories 01, 02).** For a subagent the Python half runs on every Bash and PowerShell call. The
  script a shell runs is read after quote removal; a glob is matched against the guarded names; a variable is
  resolved from an assignment or a `for` list in the same command; a word still unreadable is denied ("spell the
  script path") unless the shell only checks syntax. Guarded names: story 01, `cycle.sh` with a verb outside
  `advance`, `status`, `release`, `suite`, `stamp-red` (never `--baseline`), `close-story`; story 02,
  `human-check.sh` with a verdict and `cycle.sh briefed ... --go`. An argument of a guarded script (verb, verdict,
  flag) that is not literal is denied. Each hook denies in its own domain and relies on the other for nothing.
- **G2, history verbs (story 01).** While a `docs/specs/*/DRIVER` exists in the repository the git command acts on
  (each `cd` and `-C` followed; an option or environment word that points git elsewhere is judged by the place it
  names, unreadable counts as held), a subagent is denied every git verb that stages, makes a commit, or moves a
  branch or HEAD. Reads and `git update-index --chmod` pass.
- **F1, no Python (stories 01, 02).** git-guard's bash fallback denies, for a subagent, the G2 verbs under a DRIVER,
  a `cycle.sh` verb outside the six and a command naming the run state, beside today's verb list for any caller.
  owner-guard judges a subagent's shell call by a wider text filter and denies a spelled guarded call naming the
  missing Python. court-guard: unchanged, a seat's every call is denied.
- **C2, court (story 04).** For a blind seat. Git: a fixed allowlist of verbs, each with its argument rule; any other
  verb, an alias, and a revision naming a path under `docs/specs/` are denied. Paths: judged by their resolved form;
  allowed are the seat's own court, `<project>/.vulyk/reports/`, and system locations that cannot point back into
  the project; the main session's working folder under temp is denied. A script or pattern glued to its option is
  the script. Own court: the court directory the call stands in (hook-input `cwd`, then each `cd`); standing in no
  court, a court path passes only when exactly one court exists.
- **D1, receipt record (story 03).** `stamp-red` writes the receipt's test hash and implementation hash into the
  story's `stamp-red` record in the run state and keeps it after a finished run. `close-story`'s red gate compares
  the story's `red_verified_at` and `## Red receipt` with it: no record or different hashes is exit 4 with a message
  naming `stamp-red`. The existing three refusals keep their messages.
- **O2, open-forms list (stories 01, 02, 04).** Each hook header ends with one block listing every form the hook
  leaves open, in general words; a form closed in this spec is not on it. Cards `work-discarded-by-git-verb` and
  `owner-words-by-builder` carry the same list in `## Check`.
- **Red labels.** Each `red_reason` is text the story's first new failing case prints: 01 `a subagent shell call on
  the run state is denied`; 02 `a subagent cannot write a run-state record`; 03 `a receipt with no stamp-red record
  is refused`; 04 `a seat git read outside the allowlist is denied`. Every other new case fails on HEAD too.
- **Rejected alternative.** Keeping the run-state records as git refs written by `cycle.sh` (`git update-ref`, which
  git-guard already denies a subagent). Rejected: it rewrites the state reader and writer and the approved-record
  code, the verify records hold directories and would stay files anyway, and refs travel with clones and mirrors;
  by the inventory's estimate the hook deny is well under half of that change, and it closes the tool path exactly.
  Also rejected: a first story carrying S1 and S2 across both hooks and a second story per hook for the rest (two
  serial waves on each hook file, six stories), and a signature over the records (same user, the agent can read the
  key).

## Integration gate
`bash tests/full-suite.sh`

## Descoped
<!-- Mid-build narrowing, appended as it happens - never silent. Each line: what was dropped, why,
and the owner's line authorizing it, quoted. Only the owner removes a requirement. The same commit
strikes or narrows the ask in brief.md's ## Asks: the blind seats read only the brief, and
`cycle.sh open-round` refuses a descope the brief has not taken in. -->

- Ask 1 (2026-11-16): "by any tool" narrowed to the named form classes (a write tool by any resolved spelling of
  the path; a shell writer, redirect or in-place editor; a copy, move, rename, unpack or delete of the records or a
  folder holding them; an interpreter naming the path; an unresolvable target next to the state folder refused);
  every other form is named open in the header. Why: the hooks judge shell text, so a neighbour spelling always
  exists and "any tool" cannot be met. Owner, 2026-11-16, after round 1 ESCALATE: «Ремонт классами + сузить вопросы (Рекомендую)».
- Ask 3 (2026-11-16): "cannot change history by any verb" re-cut as "runs only the verbs on the hook's read list"
  (an allowlist in place of a deny list; not weaker). Same reason. Owner, 2026-11-16, after round 1 ESCALATE: «Ремонт классами + сузить вопросы (Рекомендую)».
- Ask 4 (2026-11-16): "whatever is written between or in front" narrowed to the named command positions and every
  global option with its value; a git call the hook cannot resolve is refused for a subagent; wrappers it does not
  know are named open in the header. Same reason. Owner, 2026-11-16, after round 1 ESCALATE: «Ремонт классами + сузить вопросы (Рекомендую)».
- Ask 5 (2026-11-16): "the court cannot be left" narrowed to the named form classes (git allowlist wherever git is a
  command; resolved paths, links made in the same call, glued options, a variable set in the same call, a quoted
  substitution, a file URL; no system-path escape); every other form is named open in the header. Same reason. Owner, 2026-11-16, after round 1 ESCALATE: «Ремонт классами + сузить вопросы (Рекомендую)».
- git-guard part of asks 1, 3, 4 (2026-11-16): moved to 0.55.0 (a guard design not built on shell text): shell
  writes of the run state through a glued redirect, an unresolved target or a folder-level move; a read list of git
  verbs under a build lock in place of the deny list; git found in every command position. Each is named open in
  git-guard's header by class; the exact forms stay in the private audit. Why: the model's safety classifier stopped
  the repair worker three times on the list of forms. Owner, 2026-11-16, during the repair: «Минимум для git-guard (Рекомендую)».

## Plan deltas
<!--
One entry per change to the plan after approval - a new story, expanded story files, a changed
contract - written from a return report, never from a diff: date, trigger, decision, what was
rejected. Tell the owner in one line when it happens. trace-check.sh accepts these entries as a quote
source for stories cut after approval. /vulyk-ship hands them to librarian for an ADR harvest.
-->
- 2026-11-16 · repair split: the round-2 repair (05) split by hook into 05 git-guard, 06 owner-guard, 07 court-guard
  (wave 5), after its worker stopped on the size of one story; rejected: one story for three hooks.
- 2026-11-16 · story 08 (wave 6): an automated review of the 05/06 commits found, and a probe confirmed, a defaulted
  variable naming git let through by 05 (refused before it) and an owner-guard alias chain longer than its walk;
  both are inside the owner's chosen scope (the over-deny fix, the alias class). Rejected: leaving them to round 3.
- 2026-11-16 · story 10 (wave 8): the Queen had moved git-guard's `cycle.sh` verb spellings (ask 2) to 0.55.0
  under the owner's «Минимум для git-guard», whose text named asks 1, 3, 4 only; a side agent caught it, and the
  owner chose «Чинить сейчас (Рекомендую)». The narrowing is undone; story 10 closes the class. Round 4 was open
  with no seat dispatched.

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
**Branch:** vulyk/guards-1115
**Council:** ESCALATE round 1, 2026-11-16, at 4cda5d6f, pack 72574cf5ee95 - red: 1,3,4,5,6,7
**Council:** ESCALATE round 2, 2026-11-16, at b5b1466e, pack 72574cf5ee95 - red: 1,3,4,5,6,7
**Council:** RED round 3, 2026-11-16, at af4665d6, pack 83cb58389a3f - red: 2,6,7
**Council:** ESCALATE round 4, 2026-11-16, at 941d06c4, pack 502e211a5247 - red: 2
**Council:** RED round 5, 2026-11-16, at b32347d7, pack 1d79e1a6be10 - red: 4,7
**Council:** ESCALATE round 6, 2026-11-17, at 5cd993e4, pack 6b4519ee4bea - red: 2

## Needs a human
- reason: half · round 1 · 2026-11-16
- ask 1: RED - see docs/specs/guards-1115/council/round-1/*.md for evidence
- ask 3: RED - see docs/specs/guards-1115/council/round-1/*.md for evidence
- ask 4: RED - see docs/specs/guards-1115/council/round-1/*.md for evidence
- ask 5: RED - see docs/specs/guards-1115/council/round-1/*.md for evidence
- ask 6: RED - see docs/specs/guards-1115/council/round-1/*.md for evidence
- ask 7: RED - see docs/specs/guards-1115/council/round-1/*.md for evidence
- ask 2: BLOCK by the reviewer - see docs/specs/guards-1115/council/round-1/review.md
- seats: docs/specs/guards-1115/council/round-1/
- reason: half · round 2 · 2026-11-16
- ask 1: RED - see docs/specs/guards-1115/council/round-2/*.md for evidence
- ask 3: RED - see docs/specs/guards-1115/council/round-2/*.md for evidence
- ask 4: RED - see docs/specs/guards-1115/council/round-2/*.md for evidence
- ask 5: RED - see docs/specs/guards-1115/council/round-2/*.md for evidence
- ask 6: RED - see docs/specs/guards-1115/council/round-2/*.md for evidence
- ask 7: RED - see docs/specs/guards-1115/council/round-2/*.md for evidence
- ask 2: BLOCK by the reviewer - see docs/specs/guards-1115/council/round-2/review.md
- seats: docs/specs/guards-1115/council/round-2/
- reason: no-progress · round 4 · 2026-11-16
- ask 2: RED - see docs/specs/guards-1115/council/round-4/*.md for evidence
- no progress: ask 2 RED in rounds 3 and 4
- seats: docs/specs/guards-1115/council/round-4/
- reason: no-progress · round 6 · 2026-11-17
- ask 2: RED - see docs/specs/guards-1115/council/round-6/*.md for evidence
- no progress: ask 2 RED in rounds 5 and 6
- seats: docs/specs/guards-1115/council/round-6/
**Checked:** ACCEPTED by Andrei, 2026-11-17, at 6fb2b7da - «Принимаю (Рекомендую)»
**Shipped:** 0.54.0-dev.2, 2026-11-17, at ab5311c1 - merged to main (local), dev build rolled to 7 hives; branch CI skipped on the owner's earlier override for these specs (origin public, local merge without branch CI); public 0.54.0 pending tails-1115, docs-1115, outward review and the owner's word
