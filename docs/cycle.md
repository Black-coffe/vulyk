# The cycle

Six stages, six confirmations, one loop. This page names the shape the whole framework is
in service of; [architecture.md](architecture.md) draws the machinery inside it and
[pipeline.md](pipeline.md) says what each gate cannot see.

```text
   01 Spec ───► 02 Plan ───► 03 Code
    ▲                           │
    │ next circle               ▼
   06 Ship ◄─── 05 Council ◄─── 04 Tests
                    ▲
        Human ------┘   (override, any stage: /vulyk-pause, human-check.sh)
```

A stage is not finished when the work is done. It is finished when its **confirmation
artifact exists on disk**, because a confirmation that lives in a chat turn is gone at the
next `/clear`, and the stage after it then rests on memory. Every artifact below is a file
or a line in one, every one is checked by a script that costs no tokens, and the command
that opens the next stage refuses when the previous stage's artifact is missing.

| # | Stage | Who | Confirmation artifact | Where it lives | Opened by |
|---|---|---|---|---|---|
| 01 | **Spec** — what and why: the message, the error report, the user's ask | human writes, Queen records | the spec text, verbatim | `docs/specs/<slug>/brief.md` (+ `## Answers`) | `/vulyk-plan` |
| 02 | **Plan** — who does what in which files; the plan can be handed to an agent whole | Queen / `queen-planner` | the list of steps, committed before the stop, and the brief's `## Asks` with it, approved by the owner in one word (default; at Tier 3-4 the approval starts `/vulyk-build`) or briefed straight through (`--go`, Tier 1) | `plan.md` + story files; `**Approved:**` or `**Briefed:**` line | `/vulyk-plan`, stop for approval |
| 03 | **Code** — changes live in their own branch | the Queen at Tier 1-2; workers in waves at Tier 3-4 | the branch, one commit per story | `**Branch:**` line in plan.md; git | `/vulyk-build` |
| 04 | **Tests** — automatic: each story's own `## Verification` command, run once inside `cycle.sh close-story` (each line under a 300 s cap, inside a 540 s call that pauses with exit 7 and resumes when the run is longer) and repeated as the story asks; a `red: required` story first proves its test red with `cycle.sh stamp-red` (receipt in the story file, its hashes in the run state), then closes as today | whoever built the story closes it: the Queen, or the worker itself | every story's verification green; on a `red: required` story, a red receipt | story `## Verification` greens; `## Red receipt` section | `/vulyk-build` |
| 05 | **Council** — `lead-review` judges the diff against the brief's `## Asks`; at Tier 3-4 one blind seat judges the same asks from a court that cannot see the hive's stories; the round after a repair is narrow: a review of the repair's diff, the blind seat only over the asks it lists, only the gate steps that were red | `lead-review` (+ at Tier 3-4 one blind seat: `council-haiku` when the Client path is filled, else `council-opus`; at Tier 4 a second reviewer, `review2`, on a risk path or after a BLOCK) | every required seat GREEN or N/A and the review PASS | `**Council:**` line in plan.md; `memory/stats/council.jsonl` | `/vulyk-build` or `/vulyk-review` (one round) |
| 06 | **Ship** — history fixed, every suite step run once green on the branch head with no agent (`cycle.sh suite <spec> --merge` unless the newest round already ran them all), branch merged locally, publish command printed and never pressed, next circle opened | a green build or review asks «Выпускаем?» once and a yes runs `/vulyk-ship`; Queen merges and prints; human presses when ready | the local merge, recorded; `ship-check.sh` `suite:` ready | `**Shipped:**` line in plan.md; git (local merge) | `/vulyk-ship` |

## Why 05 is red

Every gate before it is answerable to the brief, and the brief can ask for the wrong
thing — that is still true, and it is still what makes 05 the one stage that cannot be
skipped. What changed is who does the asking. `memory/stats/human.jsonl` across three hives
over one week (10 rows) recorded zero `REJECTED` verdicts, two of them stamped the same
second as the commit they were meant to be reading — evidence a mandatory human look had
drifted into ceremony, not substance. Over the same period `memory/stats/acceptance.jsonl`
across five hives (42 rows) recorded five `REJECTED` verdicts, every one substantive: an
interactive session dying after the first search, a brief requirement delivered nowhere, a
central ask left empty twice including after a repair round. The gate actually catching
things was the blind agent, not the human standing beside it.

Stage 05 is now the **council**, sized by the tier (changed in 0.18.0, ADR-013). At Tier 1-2 it
is one fresh-context reviewer, `lead-review`, judging the diff against the asks and for
correctness. At Tier 3-4 one blind seat joins it (ab-run-fixes C1): `council-haiku` (the black-box
walk) when the Profile's *Client path* is filled, else `council-opus` (intent and edge cases). It
works in a worktree with `docs/specs/<slug>/` reduced to `brief.md`, so it cannot see the hive's own
account of what it built — the same blindness stage 05 used to buy from a human who had not
read the stories either. Green requires unanimity: every required seat `GREEN` or `N/A`, and
`lead-review` `PASS`. When the hive has `.claude/vulyk-setup` (its own script; the installer
never ships it), `open-round` runs it inside the fresh court with `VULYK_ROOT` and
`VULYK_COURT` set, capped at 300 s (`VULYK_SETUP_TIMEOUT`), logging to
`.vulyk/reports/<slug>/round-<n>/setup.log`; a failure or a timeout removes the court and opens
no round (exit 2, log tail on stderr), since a seat on a broken court writes `N/A` and `N/A`
counts as agreement.

At Tier 4 a second reviewer, `review2` (one `lead-review` on `second_model`), joins only when there
is a reason for it (C2). `open-round` freezes `second=risk|none` into `ROUND`: `risk` when a path in
the range the reviewer reads (round 1: the branch against its base; later rounds: `since..head`)
is in the fixed risk set; a range git cannot name counts as `risk`. The risk set (C3), matched
case-insensitively on the diff's `--name-only --no-renames` paths, so a moved file counts on both
sides (its old path and its new one), with no Profile row or env to change it:
- security: a path segment or file stem equal to, or starting with, `auth`, `security`, `secret`,
  `crypt`, `permission`, `password` or `credential`, or a file named `.env` or `.env.*`;
- data: a segment `migrations` or `migrate`, a file stem `schema`, or a `*.sql` file.

With `second=risk` the first dispatch is `review`, `review2` and the blind seat at once. With
`second=none` it is `review` and the blind seat; a recorded `review` BLOCK makes `next`
`dispatch:review2` once. `judge` folds `review` and `review2` when both exist (BLOCK if either,
both bodies kept, so the second reviewer's findings join the one repair story) and judges
`review` alone otherwise. The driver dispatches exactly the seats `next` names.

The council converges rather than starting over each round. In a round that is not a narrow repair
round (a full round, or the round after a hand fix on a GREEN spec), a blind seat that was `GREEN` or
`N/A` in round n-1 is carried into round n, unless round n-1's repair story touched an ask the
seat's report judged with an `ASK <n>:` line (a `> N. ` line under its `## Requirements`, or
`[ask N]` under its `## Findings`; C4). From round 2 `lead-review` reads only `since..head` against the previous round's findings. A `BLOCK` needs a finding anchored to an
ask (`[ask N]`) or a `[regression]`. A RED round becomes a repair story written by
`cycle.sh repair`: the RED asks quoted, the anchored findings verbatim, no planner in between. Its
`## Files` are the paths the findings name, their `exact` tests (`symbol-map.sh --exact`) and
`docs/defects/*`; its `## Verification` is the rows of the done stories that named one of those
paths, never the union of every story's rows. A RED ask whose findings name no path takes the files
and rows of the stories that serve it (a story's `## Requirements` line found inside the ask's text);
nothing tied is `none — reviewed by lead-review`. A worker builds it on `opus`.

The round after a repair is **narrow**, whatever the number of files or RED items (narrow-repair-1115,
ADR-040). `open-round` computes its scope from committed records only (`round_scope`: HEAD's
`memory/stats/council.jsonl` and `council/REOPEN`) and freezes it into `ROUND`: `repair=<story>`,
`narrow=1`, `asks=` (the asks RED in the repaired round, the asks served by a done story whose
`## Files` the repair's diff `since..head` touched, and every ask when no earlier round holds the
blind seat's report), `rerun=` (the gate steps `FAIL` in the repaired round's `suite.log`; `all` when
the step count changed) and `second=none`. With `asks=` empty the round is `seats=review`: no court,
no dispatch, no empty report. Otherwise the tier's blind seat is dispatched without a carry, reads
`<court>/docs/specs/<slug>/round-asks`, judges only those asks and writes `N/A - why: not re-judged
this round` for the others. A narrow round has no second reviewer, and `cycle.sh suite` runs only the
`rerun=` steps (`SUITE: ok|FAIL <N>s - narrow repair round, steps <list> of <S>`; with none,
`SUITE: none - narrow repair round`). The files the repair touched are covered by its own rows at
`close-story`. A `ROUND` opened before 0.54 with `narrow=1` and no `asks=` or `rerun=` reads as
review-only with no step. A narrow round counts against the ceiling like any RED round.

The round after a repair is **full** (`full=<why>`: the tier's whole roster, every gate step) only
when the repaired round escalated as `half` and the owner reopened it, or the owner reopened it with `--full` (`full=design`:
the plan was wrong, not the patch), when the owner asked for it (`cycle.sh open-round <spec> --full`,
`full=asked`: no carried seat, `since=` the branch base, no `round-asks`), or when the committed
records cannot be read (`full=norecord`, one stderr line: a missing input is never a pass). `full=asked`
is the **full check of the whole project**: every seat over every ask plus every suite step. It
runs on the owner's word only - a major version (0.5x to 0.6x; 0.51 to 0.52 is minor), about once a
month, bugs or feedback; a minor release, public or not, never opens it, and `/vulyk-ship` only
offers it at a major bump.

Before a local merge every suite step runs once, green, on the branch head, with no agent (ADR-040
D5). `ship-check.sh` is ready on its `suite:` line only with a finished `SUITE: ok` over every step
keyed to the branch head, or to a commit with only paperwork after it: the newest round's `suite.log`
when that round was not narrow, else `council/merge-suite.log`, which `cycle.sh suite <spec> --merge`
writes one step per call, with the round's caps and resume, and never while a round is open. A red
merge run is cured by fixing what failed and running the whole suite once more with `--merge`, never
by a council round. A constitution with no `round-only` row reads `suite: none`, ready.
Both logs sit in the spec's `council/`, which a subagent can write, so a `SUITE: ok` line proves
nothing alone: each write `cycle.sh` makes to a suite log re-seals it in the run state
(`.vulyk/state/<slug>/suite-seal`, the log's sha256), which the guards deny to subagents. `ship-check.sh`
counts only a log whose seal matches; a log resumed or reused without a matching seal (a forged
step or verdict, an edit after the seal) runs from step 1.

A round with an evidenced RED on
half the asks or more escalates immediately rather than burning further rounds on a plan
that is wrong; a round that finds the same ask RED as the round before escalates at once
(`no-progress`) instead of opening another repair; RED rounds without unanimity escalate on the tier's ceiling (1 RED round at Tier 1,
2 at Tier 2, 3 at Tier 3–4; a GREEN or `STALE` round never counts). Either way
`cycle.sh escalate` writes `## Needs a human` into `plan.md` and stops — this is the
emergency exit, not the routine path.

The owner is never locked out: `/vulyk-pause` hands the tree back at any stage, and
`scripts/human-check.sh` still writes `**Checked:** ACCEPTED` or `REJECTED`, which outranks
the council's verdict whichever way it points — `scripts/human-check.sh docs/specs/<slug>
ACCEPTED "<where you looked>" --commit` writes one line in two places and commits those two paths only (an
agent's own commit of the record beside a verdict word is refused by owner-guard). `/vulyk-ship` refuses without
either a GREEN `**Council:**` row or a `**Checked:**` line, exactly as it refused without a
human look before.

## What invalidates a confirmation

Each artifact is about the pack **at a commit**. Move the pack and the artifact is about
something else — same rule as every gate in [pipeline.md](pipeline.md).

| Event | Stage(s) it reopens | Artifact that goes stale |
|---|---|---|
| The brief gains an `## Answers` line that changes an ask after the grill closed | 02 onward | `**Approved:**` (or `**Briefed:**` on the `--go` / Tier 1 path) — re-present the plan |
| A code commit lands on the branch while a council round is open | 05 | the open round: `cycle.sh open-round` re-stamps it in place if no seat has reported yet, or writes a `STALE` row and opens round N+1 if one already has — neither counts against the ceiling, which counts only rounds that ended RED |
| A code commit lands after a round already judged GREEN | that `**Council:**` row | `ship-check.sh` reads it as `STALE (commit)` unless only paperwork landed since (`paperwork_only`; `VERSION` and `CHANGELOG.md` count as paperwork, and so does any path matching a glob in the hive's own `.claude/vulyk-paperwork` - one per line, `#` comments, `*` crosses `/`, a trailing `dir/` covers everything beneath it; such a path also passes `ship-check` stage 03 uncommitted; the installer never ships or touches it); a fresh round opens, carries the green blind seats and re-reviews only the new diff; a GREEN round never counts against the ceiling |
| A round is RED for half the asks or more, holds an ask RED that round N-1 also held RED (`no-progress`), or the tier's ceiling (1 / 2 / 3 rounds that ended RED for Tier 1 / 2 / 3–4, `+` the same per `reopen`; a GREEN or `STALE` round never counts) is reached | 05 | `ESCALATE` — `cycle.sh escalate` writes `## Needs a human` into `plan.md`; the loop stops instead of opening a round nobody asked for |
| The owner pauses, at any stage | any | `PAUSE` semaphore — the loop stops at its next safe point; `/vulyk-resume` clears it and relaunches fresh, never resuming a cached run |
| An `ESCALATE` is on the record | 05 | three exits, all on the record: `human-check.sh ACCEPTED` (ship over the council), `cycle.sh reopen "<decision>"` [`--full`] (another tier's worth of rounds, starting with a repair story whose round is `full=design` after a `half` escalation or with `--full`, and narrow after a `no-progress` or `ceiling` one; with a fresh round instead when the escalation was `env` or the round is stale), or leaving the spec open |
| A round ends RED and its repair story closes | 05 | the RED verdict — the next round is narrow (`repair=`, `narrow=1`, `asks=`, `rerun=`, `second=none`): review of the repair's diff, the blind seat only over `asks=`, only the `rerun=` steps; it is full only with `full=design`, `full=asked` (the owner's `open-round --full`) or `full=norecord` (ADR-040 D1-D4) |
| A code commit lands after the last full suite run on the branch (a narrow round's partial gate never counts as one) | 06 | `ship-check.sh` `suite:` — NOT READY, `suite: no full run at <sha7> - run bash scripts/cycle.sh suite <spec> --merge`; paperwork after the run keeps it; cure: the merge run, every step once, no agent (ADR-040 D5) |
| The merge run ends with a red part | 06 | `ship-check.sh` `suite:` — NOT READY, naming the red parts; cure: fix them and run the whole suite once more with `cycle.sh suite <spec> --merge` on the new head; never a council round |
| The owner records `**Checked:** REJECTED` after a GREEN council row | 05, then 03–04 via repair | the council verdict — treated as RED regardless of what the seats said; the repair story goes through `/vulyk-build`, then a fresh round |
| A sealed test of a `red: required` story is edited after its red receipt | 04 | `red_verified_at` — close-story refuses (`test changed after red receipt`); cure: re-run `cycle.sh stamp-red`; with the implementation already written, the Queen runs `cycle.sh stamp-red <story> --baseline` after `/vulyk-pause` (it stamps against HEAD's implementation and puts the working copy back itself; ADR-032 D5) |
| A story's `## Verification`, `## Files` or `red:` differs from its approved version (the story file in the commit `cycle.sh` itself made and recorded for it in `.vulyk/state/<slug>/approved`: `branch`, `revise`, `repair`; no commit subject is read) | 04 | the story's gate blocks — `close-story` and `stamp-red` refuse, exit 4 (`story blocks differ from the approved version (<sha7>): <blocks>`); at Tier 3-4 a story with no record refuses, exit 2 (`no approved record for <story>: run bash scripts/cycle.sh revise <story>`); cure: the Queen runs `cycle.sh revise <story>`, or the worker puts the blocks back (ADR-032 D1, amended 2026-11-14) |
| A spec's `brief.md` or `plan.md` changes outside the lines a cycle script writes there (in `plan.md` the `**Briefed:**`, `**Branch:**`, `**Council:**`, `**Checked:**` and `**Shipped:**` markers and the `## Needs a human` block; in `brief.md` what `reopen` appends under `## Answers`: the `**After escalation (round N, <date>).**` line and its `> ` lines) | 04–05 | nothing is paperwork but those lines (`paperwork_change`, `lib.sh`; audit-fixes-1113 P1): any other change is a hand edit. Dirty at a close, it refuses, exit 4 (`edited outside ## Files: <file>`), and `open-round` and `claim` read it as dirt; committed after a round's `ROUND.head`, it stales the round, and `cycle.sh status` names the file and the commit on stderr (`<file> hand-edited in <sha7>`). A `cycle.sh revise` commit is the way to change either during a build: the wave's closes measure the file from it, and `status` never calls it a hand edit. Every `--commit` verb stages the spec files it writes by name, never the spec folder, so a stray file there stays out of the commit |
| A story reads `status: done` but no `story(<id>):` commit closed it | 03–04 | the `done` mark — `status` counts it as in progress, so its wave keeps it; `close-story` runs the whole gate over it and, green, writes the close commit (journal `closed over a hand-committed tree`; ADR-032 D2) |
| A `block` defect card's `check:` is red on a file the story's `## Files` expand to | 04 | the close — `close-story` refuses, exit 4 (`defect card <ref> fails on <file>`), after the red gate and before prompt-check; a gate that cannot run is exit 2 (`defect gate could not run`); cure: fix the file (ADR-032 D3) |
| A Tier 2-4 plan has neither `**Approved:**` nor a `**Briefed:**` line that records `--go` | 02 | `**Briefed:**` — `cycle.sh briefed` and `cycle.sh branch` refuse, exit 2 (`Tier <N> plan needs **Approved:** or an explicit --go`); ship-check stage 02 fails (`plan: Tier <N> was briefed without approval or --go`) unless `**Shipped:**` is set; cure: the owner's `**Approved:**`, or, when the owner opted out, `cycle.sh briefed <spec> --go --commit` (journal `briefed --go recorded`; ADR-032 D4) |

`scripts/ship-check.sh docs/specs/<slug>` reads all of it at once and says which stage is
open. It is what `/vulyk-ship` runs first, and it is free. Its defect line is the repo-wide defect gate: a red gate, or one that cannot run (no Python), is NOT READY.

**Run state in `.vulyk/state/`.** When `close-story` or `stamp-red` pauses at exit 7, the point
to resume from is kept in a record under `.vulyk/state/<slug>/` (`verify.<story-id>.<verb>`),
not in the story file. Only `cycle.sh` writes it. It holds the HEAD, the `--stamp`, the
`## Files` and `## Verification` hashes, and the exit of each line run since line 1. For
`stamp-red` it also names the results directory, which `mktemp -d` made. A rerun resumes only
when every key still matches: paperwork-only commits since the pause are allowed. `close-story`
also needs a recorded exit 0 for every line it skips. `stamp-red` uses a results directory only
when it is a real directory directly under the temp root, named `vulyk-sr.*`, owned by the
caller; any other recorded path is neither read nor removed. Otherwise the run starts again at
line 1 and stderr says why. The verb that finishes removes its record. `stamp-red` removes its
results directory on every way out except a pause, and the next `stamp-red` or `open-round`
removes `vulyk-sr.*` directories older than a day. A finished `stamp-red` keeps one record,
`verify.<story-id>.stamp-red.receipt`, with the receipt's tests and impl hashes: `close-story`'s
red gate reads it and refuses a receipt it does not match, or one with no record. The
directory is local to the checkout and ignored: it writes its own `.gitignore`. A missing or
unreadable record always means the strict path, line 1. A `verify_resume:` line in a story,
from an older release, is not read.

## Tiers and the cycle

The cycle is the shape of every Tier 1+ spec. Tier 0 work skips it entirely by design —
there is no brief, so there is nothing to judge. Past that, the tier the Queen already
assigned before any work started is the cycle's one scaling decision: `cycle.sh` reads it
from plan.md's `**Tier:**` line and freezes the seats that tier requires into the round's
`ROUND` file when the round opens (ADR-013 D1).

| Tier | Who builds | Required seats | Round ceiling | Agents per round |
|---|---|---|---|---|
| 1 | the Queen, solo | `review` | 1 | 1 `lead-review` |
| 2 | the Queen, solo, in a fresh session after approval | `review` | 2 | 1 `lead-review` |
| 3 | workers in waves (Workflow driver) | `review` plus one blind seat: `haiku` when *Client path* is filled, else `opus` | 3 | 2 seats + 1 clerk call to record them |
| 4 | workers in waves + `lead-architect` | as Tier 3, plus `review2` on a risk path or after a `review` BLOCK, folded with `review` | 3 | as Tier 3; one reviewer more only when `review2` is called |

The round after a repair is narrow at any tier: one `lead-review` over the repair's diff, the blind seat
only when `asks=` lists an ask (judging only those), no `review2`, and only the `rerun=` gate steps.
Only `full=design`, `full=asked` or `full=norecord` opens the whole row above.

Solo means no driver, no clerk and no court: the Queen runs `cycle.sh advance` from her own
Bash. It performs every mechanical step (branch, open-round, judge, repair) and stops at the
next thing only an agent can do. Before it ends on `build:<W>`, every story that wave lists goes
through the segment check `close-story` uses on `## Verification` (each `&&` segment a `## Commands`
cell, or `none — reviewed by lead-review`; a `round-only` row refused): the first story that fails
stops `advance` with exit 2, `"error":"<story file>: <close-story's refusal>"` and the `try:` hints
on stderr, so no worker is sent to a story it could never close.

`resume` reads the plan's `**Branch:**`; when the checked-out plan names none (`branch --commit` writes
the line on `vulyk/<slug>` only), it takes `vulyk/<slug>` if that branch's own plan copy names it. With HEAD on another branch and a clean tree it switches to
that branch before it writes anything, and its last line gains `"switched":"<branch>"`; with a dirty
tree it exits 2 naming the uncommitted paths, keeps `PAUSE` and touches nothing (no stash, no forced
switch, no reset). Every other verb still only refuses off the spec branch.

At Tier 3-4 the Workflow driver (`.claude/workflows/vulyk-cycle.js`) runs the same loop through the
clerk. A worker that returns with its story still `todo` is a miss: the driver dispatches it once
more, on the gate model, and a second miss stops the run. A worker whose report's `STATUS:` line says
`NEEDS_CONTEXT` is no miss: the driver dispatches nothing more and returns `{"status":"needs_context",
"stories":[{story,report}],...}`, releasing its claim; the Queen reads the story's `## Findings`, revises
it and commits it with `cycle.sh revise <story>`, journals it and relaunches with a fresh stamp.

**The approved record (audit-fixes-1113 A1).** A story's approved version is the story file in a commit
`cycle.sh` itself made and recorded, one `<story-id>=<sha>` line per record in the run state
`.vulyk/state/<slug>/approved` (never committed): `branch` records every story at its own commit and refuses,
exit 2 `commit the plan first`, while a story is untracked or differs from HEAD; `revise <story-file>` commits
the story with `plan.md`, `brief.md` and a journal line (`vulyk(<slug>): revised <story-id>`) and records that
commit; `repair --commit` records the repair story. A commit made by hand approves nothing, whatever its
subject. A spec branched before this release is seeded once, by `claim` or `branch`, from the old subject rule,
with a journal line `approved records seeded from commit subjects`; after that line, or after `branch` wrote
the records, an open Tier 3-4 story with no record makes `claim` exit 2 naming `cycle.sh revise`.
`reanchor <spec> --reason <text> [--commit]` moves the claim head of the wave the build is on to HEAD and
journals the move (`claim head of wave <W> moved from <old> to <new> by reanchor: <reason>`): a main-session
commit made between two claims then no longer counts as the next worker's out-of-scope edit. Both verbs are
the main session's.
A miss's edits stay in the tree, and since
ab-run-fixes a relaunch is not refused for them: `claim` accepts dirty paths in the `## Files` (or the
story file) of a `todo` story of the current wave, names those stories under `leftover`, and the
driver tells each one's worker to read `git diff` and finish. Any other dirty path is refused as before.
The driver also returns `{"status":"checkpoint",...}` at the first wave, gate-step or seat boundary
past `checkpoint_min` minutes (default 50) since launch, releasing its claim; `/vulyk-build` journals
it and relaunches with a fresh stamp, so the Queen's turn comes back before her 1 h cache lapses.

A story can also wait on a hand step: `blocked_by: [manual:<id>]` (0.19). When the earliest wave with
todo stories has none ready and one waits on an unrecorded step, `next` is `manual:<id,...>` (the ids
also under `status.manual`); no later wave is built past it, and the driver stops without dispatching.
`bash scripts/cycle.sh manual-done docs/specs/<slug> <id> [note]` writes and commits
`docs/specs/<slug>/manual/<id>`, and the wave becomes ready. A wave with a ready story beside the
waiting one is built first: `next` is `build:<W>` with only the ready stories listed, and the `manual:`
stop comes once they are done (ab-run-fixes ask 18 repro, both test suites).

Study work - a request whose deliverable is a document - never enters the loop at all: it ends
at `report.md` (ADR-008). And since v0.13 stage 02 closes on the owner's `**Approved:**` by
default; `**Briefed:**` is the straight-through opt-in (`--go`) and Tier 1's mini-brief. At Tier 2-4
the opt-in is `cycle.sh briefed <spec> --go`, which writes `--go` into the line; a Briefed line
without it does not open the build there (ADR-032 D4).

The round's test gate keeps its step barrier on purpose: each `cycle.sh suite --step K` is one
capped call, so a step waits for its slowest part. That cost is measured and accepted
([hooks-reference.md](hooks-reference.md#accepted-costs)). Opt-in, for a repo whose default branch holds
`.vulyk-solo-gate` = `merge-only` (VULYK's own repo; the installer never ships it): a Tier 1-2 round's gate runs no step
and writes `SUITE: none - Tier 1-2: ...`, the narrow round after its repair re-runs none either, and the merge run is
the one full run; Tier 3-4 and the owner's `--full` round run the gate as above.

What still shrinks below that floor is the size of the record — a one-line `## Asks` instead
of a grill's 3-7, one story instead of many — never whether the reviewer runs.

## The next circle

Stage 06 does not end at the tag. Three things carry over, and `/vulyk-ship` writes them
down before recommending `/clear`:

- `UNASKED` lines from the blind seats' reports (`docs/specs/<slug>/council/round-N/{haiku,opus}.md`)
  — behaviour nobody asked for that is now on the record, and either a bug or the seed of
  the next brief;
- `lead-review`'s minors and every `[unanchored]` critical or major finding: they never block
  a round, so they wait here;
- `## Descoped` lines from plan.md — requirements the human agreed to drop *for now*;
- `CONCERNS` from worker returns that review ranked minor and nobody fixed.

Together they are the draft of the next `brief.md`. The human decides which of them
becomes one; the framework only refuses to forget them.
