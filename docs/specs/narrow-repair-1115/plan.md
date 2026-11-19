# A repair re-checks what it repaired, not the whole spec (plan)

**Tier:** 3 · **Spec slug:** `narrow-repair-1115` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** ADR-001 (cycle state contract), ADR-013 (D3 carry, D4 repair, the 2026-11-08 amendment C4/C5: this
plan amends them, see [adr-draft.md](adr-draft.md)), ADR-023 / ADR-029 (one full suite per round: amended), ADR-015
(repair on `opus`), ADR-025 (red receipt), ADR-032 (approved version), ADR-021 (cards); Law 6; cards
`full-round-for-a-narrow-fix`, `test-gate-one-long-limit`, `safeguard-bypassable-or-late`, `owner-words-by-builder`,
`host-internals-in-public-repo`, `shell-needs-gnu-or-bash4`; `docs/cycle.md`.
**Depends on:** `main` at 479ba709 (0.53.0). `guards-1115` and `tails-1115` build after this one is on local main.

## Goal
After a RED round the loop stops paying for the whole spec again. `cycle.sh repair` writes a story that holds the
files its findings name and only the rows that cover them. The round after it is narrow whatever the number of files
or red items: one reviewer reads the repair's diff, the blind seat is dispatched only when there is an ask to
re-judge (an ask that was red, or one whose files the repair touched) and judges only those, and the gate re-runs
only the steps that were red. A full round follows a repair only after a design fault. Before a local merge every
suite step runs once, green, on the branch head, with no agent. The full check of the whole project (every seat over
every ask, every step) runs on the owner's word: a major version, about once a month, bugs or feedback; a minor
release does not trigger it. At plan time the tests that mention a story's files join its lists. Five stories in
three waves; `scripts/cycle.sh` is touched by one story per wave.

## Assumptions
<!-- Law 1: every assumption the plan rests on, stated so the owner can veto it at the approval stop. -->
- **Ask 1, "design fault" has a mechanical reading.** The repaired round escalated as `half` (red on half the asks
  or more) or `no-progress` (the same ask red twice) and the owner reopened it. Those reasons already mean "the plan
  is wrong" in `docs/cycle.md`. A reopened `ceiling` is not a design fault: its repair gets a narrow round. Say so if
  a reviewer's own label should count instead.
- **Ask 1, "the suite parts covering the files it touched"** is two things: the repair story's own rows, run at
  `close-story` (the rows of the stories that named the touched files), and, in the round, the gate steps that were
  red before. No other step runs in a narrow round; the merge gate (ask 4) runs them all once.
- **Ask 1, "the owner's acceptance"** is the existing question at `green` («Выпускаем?»); nothing new is built.
- **Ask 1 replaces two earlier rules:** the one-file limit of 0.49 (C5) and the 0.52 rule that a repair whose findings
  name no real file gets a full round with its suite. What the 0.52 rule guarded (a repair that skipped every test)
  is now held by the merge gate.
- **Ask 2 applies to every repair,** also the one before a full round. A red ask whose findings name no path takes
  the rows of the stories that quote that ask. Nothing tied: the story carries `none — reviewed by lead-review`.
- **Ask 3, a dispatched seat judges only the listed asks** and writes `N/A - why: not re-judged this round` for the
  others (an `N/A` already counts as agreement in `judge`). When the blind seat has no report in any earlier round
  (as in audit-fixes-1113 round 1), every ask is listed. A narrow round has no second reviewer at Tier 4, as today.
- **Ask 3, a story serves an ask** when one of its `## Requirements` lines is found inside that ask's text. A story
  that quotes only the request adds no ask when the repair touches it; stderr names it. The reviewer still reads the
  whole diff.
- **Ask 4, the merge gate is in `ship-check.sh`,** so it holds for a GREEN council and for `**Checked:** ACCEPTED`
  alike; the owner's override of a NOT READY stays as `/vulyk-ship` describes it. A round that ran every step green
  on the head already satisfies it, so the suite runs once, not twice. A red merge gate is cured by fixing what failed
  and running the whole suite once more without agents (owner 2026-11-15: «Весь набор ещё раз (Рекомендую)»);
  never by a council round, which stays the owner's explicit `open-round --full`.
- **Ask 4, the full check is offered, never opened by code.** No rule ties it to a release, public or not. "Major"
  is the owner's reading (0.5x to 0.6x); `/vulyk-ship` asks at such a bump. "About once a month" and "bugs or
  feedback" stay the owner's call through `/vulyk-review <slug> --full`: no timer and no reminder is built. "The
  whole project" is read as every seat over every ask of the spec being shipped, plus every suite step.
- **This spec's own rounds.** Round 1 is a full round by nature (no repair before it): that is the one full council
  round the owner chose. A RED round 1 is then repaired and re-checked by the new code, which this build wrote.
- **Ask 5, "mention" means an `exact` hit only** (owner 2026-11-15: «Утверждаю все три, тесты exact (Рекомендую)»):
  `textual` hits are not added, so a `scripts/cycle.sh` story does not pull a dozen suites; indirect coupling is caught
  by the full suite before a local merge (ask 4). A parted suite (`--part <topic>`) is not guessed: the command prints
  a `pick` line and the Queen settles it before the plan commit.
- **Ask 6, the card.** The `## Allowed` line is rewritten; the owner's dated words on the global check and the merge
  gate go beside it. The quote, the new check and two fixtures land in one commit (story 05), so the gate sees no
  ESCAPE. That same-commit reading comes from the header comment of `scripts/defects-check.sh` ("a quote after its
  `check:` line and no fixture or check change since"), which does not say whether an equal commit time is clean:
  recon question 6.
- **Ask 7.** Each rule's original case is a fixture shaped like the audit-fixes-1113 repair (round 1: four asks red
  from the review, three red suite parts, no blind-seat report; the round after it was full). The neighbour is its
  round-3 repair (no ask red, one slow part). Rule 5's original is a pin in a suite the story did not name.
- **Not changed, on purpose:** a round after a hand fix on a GREEN spec (carried seats, review of the new diff, the
  round's own full gate); `judge`, the ceiling, `half`, `no-progress`; the driver (`vulyk-cycle.js` dispatches the
  seats `next` names; recon question 3); the dispatch prompts. How often the merge gate catches what a narrow round
  missed is not recorded anywhere: not asked.
- **Migration.** Story 01 adds the new repair scope beside the old one-file path; story 03 switches `open-round` and
  removes `narrow_file`, `narrow_round_holds` and the local `narrow.round-<n>` record. An already open round keeps
  its `ROUND`; `narrow=1` without `asks=` / `rerun=` reads as review-only, no step.
- **ADR.** The policy changes ADR-013 D4 and its C5/C4 amendment, and the once-per-round suite of ADR-023 / ADR-029.
  The draft is [adr-draft.md](adr-draft.md); story 05 files it as ADR-040 and amends ADR-013. ADR-001 is not
  changed. ADR-036 could not be located (recon question 7).
- **Models.** Stories 01, 03 and 04 carry `model: opus` with the reason under `## Goal`. No story is routine enough
  for `model: haiku`: each holds a gate branch, a parser, or the owner's words on a card.
- **Self-hosting.** This repo closes its stories with the `cycle.sh` being edited; a wave-mate's close can meet a
  file mid-edit, and `tests/maintenance.test.sh` reads the whole tree: that red is a rerun, not a repair.
- **CHANGELOG.md** is paperwork and named by no story: each story ends its notes with one `CHANGELOG:` line and the
  Queen pastes them under `## [Unreleased]`.
- **Hives get this through the ship rollout** (`/vulyk-ship` step 2a), not through a story; a hive in the middle of
  a build keeps its open round's frozen `ROUND`.
- **Sibling specs.** All `cycle.sh` changes sit in the named functions of `## Contracts`.
- **Where the facts come from.** No scout ran. The planner opened no script, test or driver source except the
  header comment of `scripts/defects-check.sh`: function names, part names and file shapes come from the map slices
  of 2026-11-14/15, earlier specs' plans, the two audit-fixes-1113 repair stories and the card's fixtures, and are
  hints until a worker or a scout checks them. New test cases go into new parts the stories create (`repair-scope`,
  `round-scope`, `merge-gate`).
- **`wave-check.sh` and `trace-check.sh` were not run** (the planner has no shell); the Queen runs them in step 7.
  `verify-gap` on prose paths is expected noise.

### Recon questions for `drone-scout` (each may widen a `## Files` or add a row; answer before approval)
1. `scripts/cycle.sh` has 12 `textual` tests beside `tests/council.test.sh`. Which suites and parts pin the rules
   this plan replaces: the union `## Verification` of a repair story, the one-file narrow rule, the
   `narrow.round-<n>` record, `SUITE: none - narrow repair round`, the carry of a blind seat (council `verbs*`,
   `seats`, `roster`, `advance`; cycle parts; `tests/e2e.test.sh`, `tests/solo.test.sh`, `tests/driver.test.sh`)? A
   hit outside `tests/council.test.sh` joins story 01 or 03; a hit in it adds that part's row.
2. Which tests end in `ship-check.sh` READY after a round (cycle `ship`, `gates`; e2e; solo; driver), and does their
   fixture constitution have a `round-only` row? Each joins story 04, which adds the `suite:` line.
3. Does `.claude/workflows/vulyk-cycle.js` derive a seat, the court or the review prompt from anything but `next`
   and `status` (a blind seat by tier, `since` in round > 1)? A yes adds the driver and `tests/driver.test.sh` to
   story 03 or 04.
4. Does `record-seat` require one `ASK` line per ask, and does it accept `N/A` for all but a few? Which tests pin
   the text of `council-opus.md` / `council-haiku.md` (inject, maintenance, prompt-check fixtures)? Story 03.
5. Which test pins `CLAUDE.md`'s byte and line caps and the caps of `docs/cycle.md`, if any; which other docs state
   the one-file narrow rule or "one full suite per round" (`docs/pipeline.md`, `docs/architecture.md`,
   `docs/token-economy.md`, `docs/command-reference.md`, `docs/hooks-reference.md`)? Each joins story 05.
6. `defects-check.sh` ESCAPE: is a quote committed in the same commit as a fixture or `check:` change clean? If the
   comparison is strict, story 05's fixtures must land in a later commit than the quote, and the Queen splits it.
7. What does ADR-036 decide and under which file name; the file names of ADR-023 and ADR-029; is 040 the next free
   ADR number?
8. How does a `ROUND` after a `reopen` tell its escalation reason (`council.jsonl` row, `council/REOPEN`), and are
   both committed? Story 01's `round_scope` reads committed records only.
9. Duration against the 210 s line of council `seats` and cycle `ship`, which stories 03 and 04 run at close.

## Stories
<!-- One line per story, grouped by wave; the story files are the truth, this is their index. -->

**Wave 1**
- `narrow-repair-1115-01-repair-story-scope` — asks 1, 2, 7: a repair story holds its findings' files and rows, any number of files; `round_scope` decides narrow or full (`cycle.sh`; `red: required`; `model: opus`)
- `narrow-repair-1115-02-plan-time-tests` — asks 5, 7: `symbol-map.sh --fill-tests` adds mentioning tests and their rows to each story; `/vulyk-plan` step 7 runs it (`red: required`)

**Wave 2**
- `narrow-repair-1115-03-round-scope` — asks 1, 3, 7: the round after a repair freezes `asks=`, the blind seat only when it has an ask, `rerun=` red steps only; seat prompts read `round-asks`; the one-file path removed (`cycle.sh`; `red: required`; `model: opus`)

**Wave 3**
- `narrow-repair-1115-04-merge-gate-and-full-check` — asks 4, 6, 7: `suite --merge` and the `suite:` line of `ship-check.sh`; `open-round --full`; `/vulyk-build`, `/vulyk-review`, `/vulyk-ship` text (`cycle.sh`; `red: required`; `model: opus`)
- `narrow-repair-1115-05-card-docs-adr` — asks 6, 4, 7: the card with the owner's words, its check and two fixtures; `CLAUDE.md`, `docs/cycle.md`, ADR-040 and the ADR-013 amendment

## Contracts
<!-- Interfaces that cross a story boundary, agreed here at plan time. -->
- **S1, repair scope (story 01 writes; story 03 calls `round_scope`).**
  - `round_scope <spec> <n>` prints the scope of the round that follows the repair of round n: `narrow`,
    `full design` (round n's record is an ESCALATE for `half` or `no-progress`, reopened) or `full norecord` (the
    record cannot be read). Committed records only; no story frontmatter, no run state.
  - `repair_scope_paths`: each existing path the round's findings name (`finding_paths`), each path's `exact` tests,
    `docs/defects/*`; for a red ask with no path, the `## Files` of the done stories that serve it; no path at all:
    the union of today.
  - `repair_scope_rows`: the `## Verification` lines of the done stories whose `## Files` match one of those paths;
    for a pathless red ask, of the stories that serve it; none: `none — reviewed by lead-review`.
  - A story serves ask N when one of its `## Requirements` lines, whitespace-normalised and with a leading `N. `
    dropped, is found inside ask N's text. The story's `narrow: true` line is information, as today.
- **R1, `ROUND` of a round that follows a repair (story 03 writes; story 05's check reads).** Added lines:
  `repair=<repair story id>`; then either `narrow=1` with `asks=<comma list, ascending, may be empty>`,
  `rerun=<comma list of step numbers | empty | all>` and `second=none`, or `full=<design|asked|norecord>`. `seats=`
  is `review` when `asks=` is empty, else the tier's roster. `asks` = the asks RED in the repaired round (seat or
  review) + the asks served by a done story whose `## Files` match a path of the repair's diff (`since..head`) +
  every ask when no earlier round holds the blind seat's report. Functions `round_asks`, `round_rerun`.
- **R2, the court's ask list (story 03).** In a narrow round with a blind seat, `court_round_asks` writes
  `<court>/docs/specs/<slug>/round-asks`, one ask number per line. Absent file: the seat judges every ask. The
  dispatch prompt and the driver are unchanged.
- **R3, the gate of a narrow round (story 03).** `suite` runs only the steps listed in `rerun=` (the steps `FAIL` in
  the repaired round's `suite.log`), writes their `STEP` / `PART` lines and `SUITE: ok|FAIL <N>s - narrow repair
  round, steps <list> of <S>`; an empty list writes `SUITE: none - narrow repair round`; `rerun=all` (the step count
  changed) runs every step.
- **M1, merge run (story 04).** `cycle.sh suite <spec> --merge [--commit] [--stamp S]` (`suite_merge`): every step
  of the round gate's rows, one step per call, same caps and resume, into `council/merge-suite.log` (`head=<HEAD>
  steps=<S>`, the round log's line format, paperwork). Exit 2 while a round is open; a finished log for HEAD is a
  no-op; a log keyed to another head is replaced. Last line `{"verb":"suite","merge":true,"step","steps","done",
  "suite"}`.
- **M2, `ship-check.sh` line `suite:` (story 04).** Ready with a finished `SUITE: ok` over every step keyed to the
  branch head or to a commit with only paperwork after it: the newest round's `suite.log` when that round was not
  narrow, else `merge-suite.log`. Otherwise NOT READY: `suite: no full run at <sha7> - run bash scripts/cycle.sh
  suite <spec> --merge`, or `suite: FAIL at <sha7> - <parts>` naming `open-round --full`. No `round-only` row:
  `suite: none`, ready.
- **F1, the full check (story 04).** `cycle.sh open-round <spec> --full` (`open_round_full`): `full=asked`, no
  `narrow=1`, the tier's whole roster with no carried seat, `since=` the branch base (the reviewer reads the whole
  branch), no `round-asks`, every gate step. Run only on the owner's word.
- **T1, plan-time tests (story 02).** `bash scripts/symbol-map.sh --fill-tests <spec-dir>`: appends mentioning test
  files to `## Files` and a placeholder-free covering cell to `## Verification`; `symbol-map: <story>: pick a row for
  <test> (<cell>)` and exit 1 while a listed test has no row; idempotent. Every existing mode's output unchanged.
- **K1, the card's check (story 05).** Red on: a `narrow=1` round naming a blind seat with `asks=` empty or
  missing, with `second=risk`, or with a `STEP K/` line whose K is not in `rerun=`; a round with `repair=` and
  neither `narrow=1` nor `full=design|asked|norecord`.
- **Red labels.** Each `red_reason` is text the story's failing test prints: 01 `a repair story carries only its
  findings' rows`; 02 `a test that mentions a story file joins its lists`; 03 `a seat with no ask to judge is not
  dispatched`; 04 `a narrow green round is not merged without the full suite`. Every other new case of a story also
  fails on HEAD before the implementation.
- **Rejected alternative.** A `[design]` tag written by `lead-review` as the signal for a full round. Rejected: a new
  report field every reviewer must be taught, and the cost of a round would rest on a model's label, while `half`
  and `no-progress` are already computed by `judge`. Also rejected: passing the ask list to the seat through the
  dispatch prompt (a `status` field, the `--short` line, the driver and three command files change for what one file
  in the court does); one story for all of `cycle.sh` (audit-fixes-1113 story 09 missed twice at that size); a new
  `ROUND` key in place of `narrow=1` (every reader and both old fixtures would have to change for a rename).

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
**Approved:** Andrei, 2026-11-15 «Утверждаю все три, тесты exact (Рекомендую)»
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path: Tier 1 "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"); Tier 2-4 only with `cycle.sh briefed <spec> --go`, "via grill (--go), <owner>, <date>". Alternative to **Approved:** above.>
**Branch:** vulyk/narrow-repair-1115
**Council:** RED round 1, 2026-11-15, at 264201f4, pack 4f58805c826e - red: 1,5,8
**Council:** ESCALATE round 2, 2026-11-15, at 970c53f8, pack e76871907df7 - red: 5,8

## Needs a human
- reason: no-progress · round 2 · 2026-11-15
- ask 5: RED - see docs/specs/narrow-repair-1115/council/round-2/*.md for evidence
- ask 8: RED - see docs/specs/narrow-repair-1115/council/round-2/*.md for evidence
- no progress: ask 5, 8 RED in rounds 1 and 2
- seats: docs/specs/narrow-repair-1115/council/round-2/
**Checked:** ACCEPTED by Andrei, 2026-11-16, at b48d2b06 - «Принять, доделать в tails (Рекомендую)»
**Checked:** ACCEPTED by Andrei, 2026-11-16, at c73bebb2 - «Принимаю (Рекомендую)»
**Shipped:** 0.54.0-dev.1, 2026-11-16, at f00b490a - merged to main, publish pending (0.54.0 goes public after guards-1115 and tails-1115, on the owner's word); CI waived by the owner for the local merge: «Мерж без CI ветки (Рекомендую)»
