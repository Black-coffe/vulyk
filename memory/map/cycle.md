# Scout report: the cycle (build -> council -> repair state contract)

## Purpose
Truth lives in committed files under `docs/specs/<slug>/`, written only by `scripts/cycle.sh` (3217
lines at 0.36.0). One verb, `advance` (ADR-013), steps the loop to the next agent boundary; the Queen (Tier 1-2
solo, or Tier 3-4 without Workflow) or `.claude/workflows/vulyk-cycle.js` (Tier 3-4) calls it and
dispatches the agent `next` names. Contract: ADR-001 (D2, D3 superseded) + ADR-013.

## Files, one writer each
`brief.md ## Asks` ← `/vulyk-plan` · `plan.md **Briefed:**/**Approved:**` ← `briefed` / the owner ·
`**Branch:**` ← `branch` · `**Council:**` line per round, `## Needs a human` ← `judge`/`escalate` ·
`**Checked:**` ← `human-check.sh` · `council/round-N/ROUND` (`head= pack= opened= court= ceiling=
tier= seats= since=`) ← `build_round` :2317 · `council/REOPEN`, `CEILING` ← `reopen` ·
`council/round-N/<seat>.md` (+`.attempt-K.md`) ← `record-seat` · `<slug>-NN-repair-round-<n>.md` ←
`repair` · `memory/stats/council.jsonl` (1 row/round) ← `judge`/`escalate` · `journal.md` ←
`journal.sh`. Gitignored: `PAUSE`, `DRIVER` (stamp), `.vulyk/court/`, `.vulyk/reports/`.

## Verbs (exit 0 ok · 1 usage · 2 precondition · 3 paused · 4 malformed report / red verify · 5 stale · 6 escalate)
Dispatch `case "$VERB"` `cycle.sh:3101`. Last stdout line is one JSON object (`emit` :69); mutating
verbs on exit 0 carry the post-verb `status` (`emit_status` :86).
- **Branch guard (ship-safety, 0.31):** `branch_guard <spec> <verb>` :205 - when plan.md has a
  `**Branch:**` and `git rev-parse --abbrev-ref HEAD` differs, exit 2 (`on X, spec branch is Y`), never
  switches; no `**Branch:**` yet = pass. Called by `claim` (:2731), `close-story` (:1942), `open-round`
  (:2427). `default_branch` :219 = origin/HEAD, else `main`, else `master`, else empty.
- `status [--json]` `cmd_status` :559 (read-only) · `briefed` :1407 · `branch` :1458 · `escalate` :1336
  · `judge` :1052 · `record-seat` :1795 · `manual-done` :2796.
- `branch` also refuses (exit 2) an existing `vulyk/<slug>` that is already merged into the default
  branch and strictly behind its tip (:1495; a branch at the default tip is fresh, reused).
- `close-story <file> [--commit] [--stamp]` :1932 - scope-check (:1999); with `--commit`, a path scope-check
  counts out of scope (`  ! ` lines) that is still dirty and not `is_paperwork_path` → exit 4 `edited
  outside ## Files: <paths>` (:2030). A `## Verification` segment matching a `## Commands` row marked
  `round-only` → exit 2 `verification is round-only` (:2058-2077; fast-verification-04). Only the wave's last open story refuses; with a wave-mate still
  open (same `wave:`, not done) it prints a note and goes on (0.28). Each `## Verification` segment must be a
  `## Commands` cell of `constitution_file` or `none — reviewed by lead-review`; runs under `timeout
  ${VULYK_VERIFY_TIMEOUT:-540}` when a working `timeout` exists (124 → exit 4); commits. Done + clean
  tree → `ok:true` "already done"; self-marked done with a diff → closes it.
- `open-round` :2418 - refuses a tree dirty outside paperwork (`dirty_outside_paperwork` :455);
  `build_round` freezes `seats=`/`since=`, builds the court (`build_court` :2215) only when a blind seat
  is required, carries round n-1's GREEN/N/A blind seats (`carry_seats` :2294; `review` never carried).
- **Court setup (0.34):** `build_court` ends by calling `run_court_setup` :2264. If the hive has
  `$ROOT/.claude/vulyk-setup` (working copy, never shipped), it runs `bash` of it with cwd = the court,
  env `VULYK_ROOT`, `VULYK_COURT`, stdin /dev/null, under `timeout ${VULYK_SETUP_TIMEOUT:-300}` (non-numeric
  or 0 → 300; no working `timeout` → runs uncapped with a stderr note). Log:
  `.vulyk/reports/<slug>/round-<n>/setup.log`. Non-zero (124 = timeout) → tail 20 lines of the log to stderr,
  court removed, empty round dir removed, `open-round` exit 2 `court setup failed (exit N)`/`timed out`.
  No file = no-op. Runs only when a court is built (blind seat required).
- `claim <spec> <stamp>` :2723 refuses a dirty tree (a holder's re-claim skips it); `release` :2774,
  `pause`/`resume`/`status` are not PAUSE-guarded. `reopen "<decision>"` :2593 appends to `## Answers`,
  raises `CEILING`, emits `next:"repair"`; `open-round` when `escalate_reruns_round` :526 (an `env`
  escalation, or `suite-timeout` with nothing else red: the suite re-runs) or the round is stale.
- **Full-suite line (0.36, fast-verification):** the `review` seat's line 3 is `SUITE: ok|FAIL|TIMEOUT <N>s
  [budget <B>s]|none`. `record-seat` (:1652-1661) refuses (exit 4) a missing/malformed line when the
  constitution has a `round-only` row whose Purpose names the full suite (:1608-1618); no such row =
  `SUITE: none` accepted. `judge` (:1151-1172, :1230): `SUITE: FAIL` = BLOCK as `[regression]` (a PASS
  verdict gets note `review PASS with SUITE: FAIL`); `SUITE: TIMEOUT` → ESCALATE `suite-timeout`
  (`## Needs a human` says seconds + budget; `VULYK_SUITE_TIMEOUT` default 590); `escalate --reason`
  accepts `suite-timeout`. `reopen` of it re-runs the round unless the row also has a RED ask/BLOCK.
- `repair` :2848 - below. `advance [--stamp] [--claim] [--ingest]` :3009 - below.

## `advance` (ADR-013 D2)
1. `--claim` (needs `--stamp`): runs `claim`; a refusal is the stop line.
2. `--ingest`: each missing required seat of the open, non-stale round is recorded from
   `.vulyk/reports/<slug>/round-<n>/<seat>.attempt-<k>.md` (k=2 if attempt-1 exists); no file → empty
   report (spends the attempt). Tier 4 `review` = `fold_reviews` :2981 over `review-top`/`review-second`
   (BLOCK if either). Each exit 4 goes into `rejected:[{seat,attempt,error}]`.
3. Loop ≤ 12 steps: while `next` ∈ `branch|open-round|judge|repair`, run it with `--commit` (+`--stamp`)
   via `run_verb` :3000. Exit 6 is ok. A verb leaving `next` unchanged stops (`no progress`, exit 2).
4. Last line `{"ok":true,"verb":"advance",..,"next","steps","rejected","status"}`; a stop is `ok:false`
   with `failed`, no `status`. After `--ingest` a RED round reads `steps:["judge","repair"]`.

## `status --json` `next`
First match in `cmd_status`: `shipped` → `paused` → `briefed` → `branch` → `build:<wave>` →
`close-story:<file>` → open round: stale → `open-round`, missing seat → `dispatch:<csv>`, else `judge` →
`escalated` → `green` (GREEN, pack matches, not stale) → `repair` (RED not stale; or reopened non-`env`
ESCALATE) → `open-round`. Keys end with `seat_attempt{} seats[]` (0.18). `green` is what
`/vulyk-build` and `/vulyk-review` turn into the «Выпускаем?» question (0.22); `cycle.sh` is unchanged.

## Seats by tier and the verdict (`cmd_judge`)
`required_seats_for_tier` :386: Tier 1-2 → `review`; 3-4 → `opus review`, plus `haiku` when
`client_path_filled`. `round_required_seats` :401 reads `seats=` (pre-0.18 rounds: tier roster).
`tier_ceiling` :376 is 1/2/3/3; `CEILING` wins. Verdict, first match: human REJECTED newer than the
round → RED; required seat ABSENT with no RED/BLOCK → ESCALATE `env`; `SUITE: TIMEOUT` with nothing
RED → ESCALATE `suite-timeout` (:1230); evidenced RED ≥ max(2, ceil(A/2))
→ `half`; anchored review BLOCK or any RED → `no-progress` if the same ask was RED in round n-1,
`ceiling` if `red_rounds`+1 ≥ ceiling, else RED; else GREEN. A BLOCK with no in-range `[ask N]`/
`[regression]` is recorded PASS, note `review BLOCK unanchored`.

## Staleness, PAUSE, seat reports
Stale iff `ROUND.head` != HEAD and the commits between are not `paperwork_only` (lib.sh:87; the list
is in scripts.md). Stale with
no seat file → re-stamp; with one → STALE row, open N+1. `PAUSE` → every mutating verb exits 3.
Blind seat report: `COUNCIL/MODEL/COURT/VERDICT/ASSUMED CONFIG/RAN/PATH`, one `ASK <n>:` per ask with
`run:`+`saw:` / `url:`+`saw:` / `why:`, `UNASKED:`, `BREACH:`; malformed → exit 4, re-asked once, then
ABSENT. Taint = a path to a story file, `plan.md`, `journal.md` or `council/` (`taint_reason` :1558).
`lead-review`: line 1 `VERDICT: PASS|BLOCK`, then `## Critical/Major/Minor`, blocking lines tagged
`[ask N]`/`[regression]`/`[unanchored]`. Court = `git worktree add --detach` at the pack commit,
`docs/specs/<slug>/` reduced to `brief.md`, removed by `judge`.

## Repair (ADR-013 D4)
`cmd_repair` :2848 runs only when `next == repair`; idempotent. Writes `<slug>-NN-repair-round-<n>.md`:
`status: todo`, `worker: worker-code`, **`model: opus` on purpose** (ADR-015: cycle.sh:2917; first
attempts run on Sonnet, a repair follows a RED), `wave: <max+1>`; `## Requirements` = the row's `red` +
`review_asks` + seat-file RED asks as `> N. text` (`ask_item` :2829); `## Findings` = RED `ASK` lines +
anchored review lines; `## Files`/`## Verification` = union over done stories.

## The Workflow driver (`.claude/workflows/vulyk-cycle.js`)
Args `{spec, stamp, top_model, second_model}` plus `worker_model`, `review_model`, `seat_model` (only off
`sonnet-builds`). Shell only via `cycle-clerk`. `advance --claim`; `build:W` → workers in parallel, a
story still listed is a miss, the second stops the run; `dispatch:` → seats in parallel (Tier 4 review =
two `lead-review`), then `advance --ingest`. `CAPS` :28 mirrors `maxTurns`; `release` in `finally`.

## Tests
`cycle.test.sh` (7 parts), `council.test.sh` (11), `telemetry.test.sh` (17) take `--part <topic>` /
`--list-parts` (unknown part: exit 1 + names). A story's `## Verification` names a part; the full set
runs once per round via `tests/full-suite.sh` (scripts.md). CI runs that in one uncapped `full-suite`
job (`.github/workflows/ci.yml:107-121`), replacing the per-suite jobs. `driver.test.sh` covers the
profile args.

Telemetry consumers (`telemetry.sh`, `scope-check.sh` ledger): see `memory/map/scripts.md`.

last-verified: 2026-10-26 (v0.36.0, ADR-001, ADR-013, ADR-015, ADR-020)
