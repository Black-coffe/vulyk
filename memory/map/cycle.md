# Scout report: the cycle (build -> council -> repair state contract)

## Purpose
Truth lives in committed files under `docs/specs/<slug>/`, written only by `scripts/cycle.sh`. One verb,
`advance` (ADR-013), steps the loop to the next agent boundary; the Queen (Tier 1-2, or Tier 3-4 without
Workflow) or `.claude/workflows/vulyk-cycle.js` (Tier 3-4) calls it and dispatches the agent `next` names.
Contract: ADR-001 (D2, D3 superseded) + ADR-013 + ADR-029 (gate split). No line numbers: `grep -n '^cmd_name()'`.

## Files, one writer each
`brief.md ## Asks` ← `/vulyk-plan` · `plan.md **Briefed:**/**Approved:**` ← `briefed` / the owner ·
`**Branch:**` ← `branch` · `**Council:**`, `## Needs a human` ← `judge`/`escalate` · `**Checked:**` ←
`human-check.sh` · `council/round-N/ROUND` ← `build_round` · `council/round-N/suite.log` ← `suite` ·
`council/REOPEN`, `CEILING` ← `reopen` · `council/round-N/<seat>.md` ← `record-seat` ·
`<slug>-NN-repair-round-<n>.md` ← `repair` · `council.jsonl` ← `judge`/`escalate` · `journal.md` ← `journal.sh`.
Gitignored: `PAUSE`, `DRIVER`, `.vulyk/court/`, `.vulyk/reports/`.

## Verbs (exit 0 ok · 1 usage · 2 precondition · 3 paused · 4 malformed report / red verify · 5 stale · 6 escalate · 7 verification paused)
Last stdout line is one JSON object (`emit`); mutating verbs on exit 0 carry the post-verb `status`.
- **Branch guard (0.31):** `branch_guard <spec> <verb>`: plan.md has a `**Branch:**` and HEAD differs → exit 2,
  never switches; none yet = pass. Called by `claim`, `close-story`, `open-round`, `stamp-red`, `suite`.
- `status [--json]` (read-only) · `briefed` · `branch` (refuses a `vulyk/<slug>` already merged and behind the
  default) · `escalate` · `judge` · `record-seat` · `manual-done`.
- **Red receipt (ADR-025):** frontmatter `red: required` (planner-marked; `fm_red` reads frontmatter only)
  closes only on a receipt. `stamp-red <story> [--stamp S]` runs `## Verification` once and writes
  `red_verified_at: <ts> <test-hash>` + a `## Red receipt` section (0.47: its fenced tail leads with up to 3
  lines of the failing output carrying `red_reason`, then the last 10 lines, redacted). Exit 4, nothing written: not required, empty
  `red_reason`, no sealed test, only tests in `## Files`, every line exits 0, 126/127, timeout, or `red_reason`
  (`grep -F`) in no failing line; exit 2 no sha256 tool. `close-story` calls `red_gate` after scope-check: exit 4
  `no red receipt` / `test changed after red receipt` / `no implementation change since red receipt`.
- **Story trust from git (0.50, ADR-032):** `approved_rev <story>` = newest commit touching it with a paperwork
  subject (`vulyk(<slug>): ...`, incl. `revised <story-id>`). `close-story`/`stamp-red` compare `## Verification`,
  `## Files`, `red:` with that version: differ → exit 4 `story blocks differ from the approved version (<sha7>)`;
  none at Tier 3-4 → exit 2 `no approved version in git`. A close is a commit `story(<id>): ...`
  (`has_close_commit`); `status` counts a `done` story with no such commit as `in-progress`; `close-story` on it
  re-runs the gates (`--allow-empty`). After `red_gate`, `defects-check.sh --files <## Files>` runs when a
  `status: block` card exists: red → exit 4 `defect card <ref> fails on <file>`, gate error → exit 2.
  `stamp-red --baseline` restores `RED_IMPL` files to HEAD, stamps, restores (no stash; Queen only).
  `briefed`/`branch` at Tier 2-4 need `**Approved:**` or `--go` (exit 2 `Tier <N> plan needs ...`; `--go` goes
  on the Briefed line and re-stamps an old one).
- **prompt-check gate (0.43):** after the defect gate, when `## Files` has a path under `scripts/`, `.claude/agents/`,
  `.claude/commands/` or `templates/`, `close-story` runs `prompt-check.sh --touched <## Files>`: exit 1 with an
  `error` line → exit 4 (first `error` line); exit 1 with none → exit 4 `prompt-check crashed`; 2 = stderr note.
- `close-story <file> [--commit] [--stamp]` - scope-check; `--commit` with a dirty out-of-scope, non-paperwork
  path → exit 4 `edited outside ## Files`. A `## Verification` segment matching a `round-only` row → exit 2.
  Each segment must be a `## Commands` cell or `none — reviewed by lead-review`. **Verify runner (gate-split-02,
  `verify_run`, shared with `stamp-red`):** each line under its own cap `VULYK_VERIFY_TIMEOUT` (default 300; a
  value above 300, or junk/0, acts as 300; 124 → exit 4, naming the line); the call has a budget
  `VULYK_VERIFY_CALL` (default 540): a line starts only if its cap fits what is left (the first line of a call
  always runs), else `verify_pause` writes a resume mark and exits 7 `verification paused`; rerun the same verb
  to resume at that line. No timeout/gtimeout/Python cap = uncapped; a command's own 124 is then not a timeout.
  Only the wave's last open story refuses; with a wave-mate open it notes and goes on. Done + clean tree →
  `ok:true` "already done".
- `open-round` refuses a tree dirty outside paperwork; `build_round` freezes `seats=`/`since=`, builds the court
  only for a blind seat, carries round n-1's GREEN/N/A blind seats (`review` never). Court setup: `build_court`
  runs `$ROOT/.claude/vulyk-setup` if present (`${VULYK_SETUP_TIMEOUT:-300}`); failure → `open-round` exit 2.
- `claim` refuses a dirty tree, except (0.49, `claim_leftover`) edits inside a todo wave story's `## Files`: ok,
  `next:"claimed"`, `"leftover":[files]`. Every `emit` line and `status` carry `now` (epoch s). `verify_run` lines
  read `< /dev/null`. `suite` commits once, on the call that finishes it.
- `claim` otherwise as above; `release`, `pause`/`resume`/`status` are not PAUSE-guarded. `reopen "<decision>"`
  appends to `## Answers`, raises `CEILING`, emits `next:"repair"` (or re-runs on `env`, or an old `suite-timeout`).
- **`suite <spec> [--commit] [--stamp S]` (ADR-029, `cmd_suite`):** the round's gate, one step per call, before
  the seats, into `council/round-N/suite.log` (paperwork, committed per step with `--commit`): line 1
  `head=<ROUND head> steps=<S>`, per step `STEP K/S: ok|FAIL <N>s` + its `PART <name> ok|FAIL|SKIP|CAP <N>s cap
  <C>s` lines, last `SUITE: ok <N>s | FAIL <N>s - <why> | none`. Guards: pause, driver, branch; no open round →
  exit 2; stale → exit 5. Last line `{"verb":"suite","step","steps","done","suite"}` (+ `status`), always exit 0
  for a red suite (data). A finished log keyed to the ROUND head is a no-op; a log keyed to another head is
  deleted. One `round-only` full-suite row whose Purpose has `steps` = stepped: `<cmd> --steps` gives S, each call
  runs `<cmd> --step K` under a 590 s cap. Otherwise each row (`full_suite_row`, table order) is one step and one
  part under `VULYK_PART_CAP` (default 300, never above), part name = Purpose slug. An empty command cell or a
  step past the rows is a red part, never ok. A step is FAIL on non-zero rc or when `suite-parts-check.sh` names
  a part (CAP, cap > 300, or > 70% of cap). No row = `SUITE: none`. A step killed at its cap notes
  `timed out after <C>s - no end from: <parts>` (from the runner's `PARTS K/S:` line); the SUITE line repeats it.
  **LOAD lines (0.47, `suite_load`):** each step samples the box in the background at its start; only a FAIL
  step appends `LOAD: start <cpu line>` and `LOAD: end ...` under its PART lines (end sample <= 10 s, none under
  2 s left of 580: `LOAD: unavailable - end: no time left in this call`). `suite_load` always exits 0; failure =
  `LOAD: unavailable - <when>: <why>`. `lib.sh load_sample` is the sampler; `VULYK_LOAD_SAMPLER` (a `bash -c`
  command) replaces it (tests' seam). Evidence, never a verdict.
- **Full-suite line (0.36; ADR-023, ADR-029):** a finished suite.log keyed to the round head overrides the
  `review` report: `record-seat` drops every reported `SUITE:` line and writes the log's under the VERDICT line.
  **0.46:** `record-seat` of a `review` with a `round-only` row and no finished log for the round head exits 2
  (`no suite.log for round N ... run cycle.sh suite`), nothing written, no attempt spent (not a re-ask; the
  same report records after the gate). `judge`: `SUITE: FAIL` and a legacy `SUITE: TIMEOUT` line are both a
  review BLOCK `[regression]` → repair, never `suite-timeout`. `VULYK_SUITE_TIMEOUT` is read nowhere;
  `escalate --reason suite-timeout` stays valid for old rows/reopen. `repair` also copies each red PART line of
  the finished log as a `- [regression]` finding.

## `advance` (ADR-013 D2)
1. `--claim` (needs `--stamp`): runs `claim`. 2. `--ingest`: each missing seat of the open round is recorded from
`.vulyk/reports/<slug>/round-<n>/<seat>.attempt-<k>.md`; none → empty report (spends the attempt). Tier 4 `review`
= `fold_reviews` (BLOCK if either). Exit 4s go into `rejected[]`. 3. Loop ≤ 12 steps: while `next` ∈
`branch|open-round|judge|repair`, run it with `--commit`; exit 6 is ok; unchanged `next` = `no progress`. `suite`
is not in the loop: the Queen or the driver calls it before the seats. Last line `{"ok":true,"verb":"advance",..}`.

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
`BREACH:`; malformed → exit 4, re-asked once, then ABSENT. Court = `git worktree add --detach`, removed by `judge`.

## Repair (ADR-013 D4)
`cmd_repair` runs only when `next == repair`. 0.49 narrow: exactly one RED item in one non-test file → the story
has `narrow: true` and `## Files` = that file, its tests, `docs/defects/*`; the next `open-round` is review-only.
Writes `<slug>-NN-repair-round-<n>.md`: `worker: worker-code`,
**`model: opus` on purpose** (ADR-015), `wave: <max+1>`, `red: required` kept unless `repair_unmarks`. `##
Requirements`/`## Findings` = RED asks, anchored review lines, red suite PART lines; `## Files` = union.

## The Workflow driver (`.claude/workflows/vulyk-cycle.js`)
Args `{spec, stamp, top_model, second_model}` (+ `worker_model`, `review_model`, `seat_model` off `sonnet-builds`;
`launched_at`, `checkpoint_min` default 50). **Checkpoint (0.49):** past `checkpoint_min` between `launched_at` and the
last verb's `now`, the next wave/gate step/seat is not started; returns `{status:"checkpoint",next,elapsed_min}`; either
time missing = no checkpoint; no clock read. A `leftover` story from `claim` is re-dispatched with a note; 2nd miss stops.
Shell only via `cycle-clerk`. `build:W` → workers in parallel, a still-listed story is a miss, the second stops
the run; `dispatch:` → `gate(st)` first, then the seats in parallel (Tier 4 review = two `lead-review`), then
`advance --ingest`. `release` in `finally`.
- **`gate`:** loops `suite <spec> --commit --stamp S` via the clerk until `done:true`; `exit 3` → Paused;
  `ok:false` stops the run; an unreadable clerk line (`BadLine`) is asked again, within `SUITE_CALLS` = 32 calls
  total, then fails `suite not done after 32 calls` (safe: steps resume, a finished log is a no-op).
- **Claim / retry (0.50):** an unreadable `advance --claim` line is proven by a short re-claim with the same stamp
  (no leftover list); unproven stops. A missed story's retry model = first of [TOP, opus] not judging the round;
  none left → opus, result carries `retry_same_family`.
- **Fable-limit fallback:** a `refused(r)` or empty-and-ping-empty result off `opus` is rerun once on `opus`;
  entries go in `fallbacks`; `/vulyk-build` journals them.
- Tests: `cycle|council|telemetry.test.sh --part <topic>` / `--list-parts`; full set once per round (scripts.md).

last-verified: 2026-11-09 (0.50.0 mass-audit-fixes; ADR-001, 013, 015, 023, 025, 029, 032). Over the ~80-line budget.
