# Scout report: the cycle - run state, claim, advance, verdict, repair (split from cycle.md)

Other slices: `cycle.md` (files, verbs, gates), `cycle-suite.md` (suite gate, Workflow driver).

## Cycle-owned run state
- **Run state (0.51; docs/cycle.md "Run state"):** `.vulyk/state/<slug>/` (local; `cycle.sh` writes its own `*`
  `.gitignore`), plain `key=value`, written only by `cycle.sh` (`lib.sh state_get`). Records:
  `approved` (story id → approved sha, 0.53), `claim` (`wave.<W>` → the head `claim` saw when that wave's build began,
  0.53), `verify.<story-id>.<verb>` (`verify_rec`, `verify_rec_new`): `head`, `stamp` (`-` none), `files`, `verify`
  hashes, `next=<k>`, `line=<k> <rc> <hash>` per line run (stamp-red adds the stored-output hash and `outd=`, its
  `mktemp -d` dir). `verify_resume_start` honours `next` only if every key matches (head = HEAD or only paperwork
  since) and each skipped line has its entry (close-story: exit 0; stamp-red: dir is real, not a symlink, owned,
  output hash equal); else line 1, record dropped, a stderr reason. A `verify_resume:` story line is never read
  or written. Narrow record `narrow.round-<n>` (`story=`, `file=`, `from=`) written by `repair`; `open-round` freezes
  `narrow=1` only via `narrow_round_holds` (record names round n-1's repair story and `narrow_file` recomputed from
  its committed records still gives that file); else a full round with a stderr reason. The story's `narrow:` line
  is information and joins the blocks compared with the approved version (`... differ ...: narrow:`).
- **`## Commands` cells (0.51):** a cell runs its backticked span, the rest is a note (`lib.sh` cell helpers,
  scripts.md); `suite` marks a `several`-span full-suite row a red part. Tier 4 risk check (`round_second`) diffs with
  `--no-renames`, so both sides of a rename count.
- `open-round` refuses a tree dirty outside paperwork; `build_round` freezes `seats=`/`since=`, builds the court
  only for a blind seat, carries round n-1's GREEN/N/A blind seats (`review` never). Court setup: `build_court`
  runs `$ROOT/.claude/vulyk-setup` if present (`${VULYK_SETUP_TIMEOUT:-300}`); failure → `open-round` exit 2.
- `claim` refuses a dirty tree, except (0.49, `claim_leftover`) edits inside a todo wave story's `## Files`: ok,
  `next:"claimed"`, `"leftover":[files]`. It records the wave's claim head. Every `emit` line and `status` carry `now`
  (epoch s). `verify_run` lines read `< /dev/null`. `suite` commits once, on the call that finishes it.
- `release`, `pause`/`resume`/`status` are not PAUSE-guarded. `reopen "<decision>"` appends to `## Answers`, raises
  `CEILING`, emits `next:"repair"` (or re-runs on `env`, or an old `suite-timeout`). `resume` (0.52) switches a clean
  tree to the plan's `**Branch:**` (JSON gains `"switched"`); a dirty tree is only reported.

## `advance` (ADR-013 D2)
1. `--claim` (needs `--stamp`): runs `claim`. 2. `--ingest`: each missing seat of the open round is recorded from
`.vulyk/reports/<slug>/round-<n>/<seat>.attempt-<k>.md`; none → empty report (spends the attempt). Tier 4 `review`
= `fold_reviews` (BLOCK if either). Exit 4s go into `rejected[]`. 3. Loop ≤ 12 steps: while `next` ∈
`branch|open-round|judge|repair`, run it with `--commit`; exit 6 is ok; unchanged `next` = `no progress`. `suite`
is not in the loop: the Queen or the driver calls it before the seats. 4 (0.52): at `build:<wave>` each listed
story's `## Verification` goes through `verify_cells_check` (close-story's segment check) before the line is
emitted; a segment not a `## Commands` cell → exit 2 naming the story, no worker sent; empty passes. Last line
`{"ok":true,"verb":"advance",..}`.

## `status --json` `next`
First match: `shipped` → `paused` → `briefed` → `branch` → `build:<wave>` → `close-story:<file>` → open round:
stale → `open-round`, missing seat → `dispatch:<csv>`, else `judge` → `escalated` → `green` → `repair` → `open-round`.

## Seats and the verdict (`cmd_judge`)
`required_seats_for_tier` (0.49): Tier 1-2 → `review`; 3-4 → `review` plus ONE blind seat: `haiku` when
`client_path_filled`, else `opus` (`sonnet` in no roster; `record-seat` still accepts it). Tier 4 `review2` is not frozen:
`review2_called` = Tier 4, not a narrow round, and ROUND `second=risk` or the recorded `review` is BLOCK;
`record-seat review2` otherwise exits 2. With review2 recorded, judge folds both (BLOCK if either). A narrow round
(ROUND `narrow=1`): `seats=review`, `second=none`, no court, `suite` writes `SUITE: none - narrow repair round`.
`tier_ceiling` 1/2/3/3; `CEILING` wins. Verdict, first match: human REJECTED newer than the round → RED; required
seat ABSENT with no RED/BLOCK → ESCALATE `env`; (`suite-timeout` only on old rows); evidenced
RED ≥ max(2, ceil(A/2)) → `half`; anchored review BLOCK or any RED → `no-progress` (same ask RED in n-1),
`ceiling`, else RED; else GREEN. A BLOCK with no in-range `[ask N]`/`[regression]` is PASS, note `unanchored`.

## Staleness, PAUSE, seat reports
Stale iff `ROUND.head` != HEAD and the commits between are not `paperwork_only`. `PAUSE` → every mutating verb
exits 3. Blind seat report: `COUNCIL/MODEL/COURT/VERDICT/ASSUMED CONFIG/RAN/PATH`, `ASK <n>:`, `UNASKED:`,
`BREACH:`; malformed → exit 4, re-asked once, then ABSENT. Court = `git worktree add --detach`, removed by `judge`;
`court-guard.sh` keeps the blind seat inside it (`scripts-hooks.md`).

## Repair (ADR-013 D4)
`cmd_repair` runs only when `next == repair`. Narrow (`narrow_file`, 0.52): exactly one RED item whose findings
name exactly one non-test path that exists in the tree (`finding_paths` drops `- `, a leading `N. `, `[tag]`s;
no path, a glob, a dir or a missing file = full round; `## Files` no longer a fallback) → the story
has `narrow: true` (information only) and `## Files` = that file, its tests, `docs/defects/*`; `repair` also writes
the `narrow.round-<n+1>` record, and the next `open-round` is review-only only when it re-checks.
Writes `<slug>-NN-repair-round-<n>.md` and records its commit as the story's approved version:
`worker: worker-code`, **`model: opus` on purpose** (ADR-015), `wave: <max+1>`, `red: required` kept unless
`repair_unmarks`. `## Requirements`/`## Findings` = RED asks, anchored review lines, red suite PART lines; `## Files` = union.

last-verified: 2026-11-14 (0.53.0-dev.1 audit-fixes-1113; split from cycle.md; ADR-001, 013, 015, 032)
