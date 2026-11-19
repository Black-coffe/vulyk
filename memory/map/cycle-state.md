# Scout report: the cycle - run state, claim, advance, verdict, repair (split from cycle.md)

Other slices: `cycle.md` (files, verbs, gates), `cycle-repair.md` (repair), `cycle-suite.md` (suite, Workflow driver).

## Cycle-owned run state
- **Run state (0.51; docs/cycle.md "Run state"):** `.vulyk/state/<slug>/` (local; `cycle.sh` writes its own `*`
  `.gitignore`), plain `key=value`, written only by `cycle.sh` (`lib.sh state_get`). Records:
  `approved` (story id → approved sha, 0.53), `claim` (`wave.<W>` → the head `claim` saw when that wave's build began,
  0.53), `verify.<story-id>.<verb>` (`verify_rec`, `verify_rec_new`): `head`, `stamp` (`-` none), `files`, `verify`
  hashes, `next=<k>`, `line=<k> <rc> <hash>` per line run (stamp-red adds the stored-output hash and `outd=`, its
  `mktemp -d` dir). `verify.<story-id>.stamp-red.receipt` (`red_rec`, guards-1115) holds `tests=`/`impl=`/`stamped=` of
  the last finished stamp-red; `red_gate` needs it. Subagents cannot write this folder (git-guard/owner-guard
  deny shell and Edit/Write paths under `.vulyk/state/`). `verify_resume_start` honours `next` only if every key
  matches (head = HEAD or only paperwork since) and each skipped line has its entry (close-story: exit 0; stamp-red:
  dir is real, not a symlink, owned, output hash equal); else line 1, record dropped, a stderr reason.
  A `verify_resume:` story line is never read or written. No narrow record is kept (0.54: `narrow_file`,
  `narrow_round_holds`, `narrow.round-<n>` are gone). A story's `narrow:` line is information only; it still joins the blocks
  compared with the approved version (`... differ ...: narrow:`, `story_blocks_guard`).
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
(ROUND `narrow=1`, `asks=`, `rerun=`): `second=none`; `seats=review` and no court when `asks=` is empty, else the
tier's blind seat with no carry (see Repair).
`tier_ceiling` 1/2/3/3; `CEILING` wins. Verdict, first match: human REJECTED newer than the round → RED; required
seat ABSENT with no RED/BLOCK → ESCALATE `env`; (`suite-timeout` only on old rows); evidenced
RED ≥ max(2, ceil(A/2)) → `half`; anchored review BLOCK or any RED → `no-progress` (same ask RED in n-1),
`ceiling`, else RED; else GREEN. A BLOCK with no in-range `[ask N]`/`[regression]` is PASS, note `unanchored`.

## Staleness, PAUSE, seat reports
Stale iff `ROUND.head` != HEAD and the commits between are not `paperwork_only`. `PAUSE` → every mutating verb
exits 3. Blind seat report: `COUNCIL/MODEL/COURT/VERDICT/ASSUMED CONFIG/RAN/PATH`, `ASK <n>:`, `UNASKED:`,
`BREACH:`; malformed → exit 4, re-asked once, then ABSENT. Court = `git worktree add --detach`, removed by `judge`;
`court-guard.sh` keeps the blind seat inside it (`scripts-hooks.md`).

Repair (`cmd_repair`, repair scope, next-round scope) is in `cycle-repair.md`.

last-verified: 2026-11-17 (guards-1115 red_rec; ADR-001, 013, 015, 032, 040)
