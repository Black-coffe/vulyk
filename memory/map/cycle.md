# Scout report: the cycle (build -> council -> repair state contract)

## Purpose
Truth lives in committed files under `docs/specs/<slug>/`, written only by `scripts/cycle.sh` (~2940
lines). One verb, `advance` (ADR-013), steps the loop to the next agent boundary; the Queen (Tier 1-2
solo, or Tier 3-4 without Workflow) or `.claude/workflows/vulyk-cycle.js` (Tier 3-4) calls it and
dispatches the agent `next` names. Contract: ADR-001 (D2, D3 superseded) + ADR-013.

## Files, one writer each
`brief.md ## Asks` ← `/vulyk-plan` · `plan.md **Briefed:**/**Approved:**` ← `briefed` / the owner ·
`**Branch:**` ← `branch` · `**Council:**` line per round, `## Needs a human` ← `judge`/`escalate` ·
`**Checked:**` ← `human-check.sh` · `council/round-N/ROUND` (`head= pack= opened= court= ceiling=
tier= seats= since=`) ← `build_round` :2065 · `council/REOPEN`, `CEILING` ← `reopen` ·
`council/round-N/<seat>.md` (+`.attempt-K.md`) ← `record-seat` · `<slug>-NN-repair-round-<n>.md` ←
`repair` · `memory/stats/council.jsonl` (1 row/round) ← `judge`/`escalate` · `journal.md` ←
`journal.sh`. Gitignored: `PAUSE`, `DRIVER` (stamp), `.vulyk/court/`, `.vulyk/reports/`.

## Verbs (exit 0 ok · 1 usage · 2 precondition · 3 paused · 4 malformed report / red verify · 5 stale · 6 escalate)
Dispatch `case` `cycle.sh:2826-2941`. Last stdout line is one JSON object (`emit` :69); mutating
verbs on exit 0 carry the post-verb `status` (`emit_status` :86).
- `status [--json]` `cmd_status` :487 (read-only) · `briefed` :1307 · `branch` :1358 · `escalate` :1236
  · `judge` :978 · `record-seat` :1646 · `manual-done` :2520.
- `close-story <file> [--commit] [--stamp]` :1782 - scope-check; each `## Verification` segment must be a
  `## Commands` cell of `constitution_file` or `none — reviewed by lead-review`; runs under `timeout
  ${VULYK_VERIFY_TIMEOUT:-540}` when a working `timeout` exists (124 → exit 4); commits. Done + clean
  tree → `ok:true` "already done"; self-marked done with a diff → closes it.
- `open-round` :2166 - refuses a tree dirty outside paperwork (`dirty_outside_paperwork` :396);
  `build_round` freezes `seats=`/`since=`, builds the court (`build_court` :1997) only when a blind seat
  is required, carries round n-1's GREEN/N/A blind seats (`carry_seats` :2042; `review` never carried).
- `claim <spec> <stamp>` :2448 refuses a dirty tree (a holder's re-claim skips it); `release` :2498,
  `pause`/`resume`/`status` are not PAUSE-guarded. `reopen "<decision>"` :2330 appends to `## Answers`,
  raises `CEILING`, emits `next:"repair"` (`open-round` for an `env` escalation).
- `repair` :2572 - below. `advance [--stamp] [--claim] [--ingest]` :2733 - below.

## `advance` (ADR-013 D2)
1. `--claim` (needs `--stamp`): runs `claim`; a refusal is the stop line.
2. `--ingest`: each missing required seat of the open, non-stale round is recorded from
   `.vulyk/reports/<slug>/round-<n>/<seat>.attempt-<k>.md` (k=2 if attempt-1 exists); no file → empty
   report (spends the attempt). Tier 4 `review` = `fold_reviews` :2705 over `review-top`/`review-second`
   (BLOCK if either). Each exit 4 goes into `rejected:[{seat,attempt,error}]`.
3. Loop ≤ 12 steps: while `next` ∈ `branch|open-round|judge|repair`, run it with `--commit` (+`--stamp`)
   via `run_verb` :2724. Exit 6 is ok. A verb leaving `next` unchanged stops (`no progress`, exit 2).
4. Last line `{"ok":true,"verb":"advance",..,"next","steps","rejected","status"}`; a stop is `ok:false`
   with `failed`, no `status`. After `--ingest` a RED round reads `steps:["judge","repair"]`.

## `status --json` `next`
First match in `cmd_status`: `shipped` → `paused` → `briefed` → `branch` → `build:<wave>` →
`close-story:<file>` → open round: stale → `open-round`, missing seat → `dispatch:<csv>`, else `judge` →
`escalated` → `green` (GREEN, pack matches, not stale) → `repair` (RED not stale; or reopened non-`env`
ESCALATE) → `open-round`. Keys end with `seat_attempt{} seats[]` (0.18). `green` is what
`/vulyk-build` and `/vulyk-review` turn into the «Выпускаем?» question (0.22); `cycle.sh` is unchanged.

## Seats by tier and the verdict (`cmd_judge`)
`required_seats_for_tier` :327: Tier 1-2 → `review`; 3-4 → `opus review`, plus `haiku` when
`client_path_filled`. `round_required_seats` :342 reads `seats=` (pre-0.18 rounds: tier roster).
`tier_ceiling` :317 is 1/2/3/3; `CEILING` wins. Verdict, first match: human REJECTED newer than the
round → RED; required seat ABSENT with no RED/BLOCK → ESCALATE `env`; evidenced RED ≥ max(2, ceil(A/2))
→ `half`; anchored review BLOCK or any RED → `no-progress` if the same ask was RED in round n-1,
`ceiling` if `red_rounds`+1 ≥ ceiling, else RED; else GREEN. A BLOCK with no in-range `[ask N]`/
`[regression]` is recorded PASS, note `review BLOCK unanchored`.

## Staleness, PAUSE, seat reports
Stale iff `ROUND.head` != HEAD and the commits between are not `paperwork_only` (lib.sh:68). Stale with
no seat file → re-stamp; with one → STALE row, open N+1. `PAUSE` → every mutating verb exits 3.
Blind seat report: `COUNCIL/MODEL/COURT/VERDICT/ASSUMED CONFIG/RAN/PATH`, one `ASK <n>:` per ask with
`run:`+`saw:` / `url:`+`saw:` / `why:`, `UNASKED:`, `BREACH:`; malformed → exit 4, re-asked once, then
ABSENT. Taint = a path to a story file, `plan.md`, `journal.md` or `council/` (`taint_reason` :1448).
`lead-review`: line 1 `VERDICT: PASS|BLOCK`, then `## Critical/Major/Minor`, blocking lines tagged
`[ask N]`/`[regression]`/`[unanchored]`. Court = `git worktree add --detach` at the pack commit,
`docs/specs/<slug>/` reduced to `brief.md`, removed by `judge`.

## Repair (ADR-013 D4)
`cmd_repair` :2572 runs only when `next == repair`; idempotent. Writes `<slug>-NN-repair-round-<n>.md`:
`status: todo`, `worker: worker-code`, **`model: opus` on purpose** (ADR-015: cycle.sh:2641; first
attempts run on Sonnet, a repair follows a RED), `wave: <max+1>`; `## Requirements` = the row's `red` +
`review_asks` + seat-file RED asks as `> N. text` (`ask_item` :2553); `## Findings` = RED `ASK` lines +
anchored review lines; `## Files`/`## Verification` = union over done stories.

## The Workflow driver (`.claude/workflows/vulyk-cycle.js`)
Args `{spec, stamp, top_model, second_model}` (`TOP` :43). Shell only via `cycle-clerk`. Starts
`advance --claim`; `build:W` → workers in parallel (model = the story's, `TOP` on a retry), then `advance`;
a story still listed is a miss, the second stops the run. `dispatch:` → seats in parallel, each told its
report path; Tier 4 review = two `lead-review`; then `advance --ingest`. `CAPS` :28 mirrors `maxTurns`;
`release` in `finally`.

## Tests
`tests/cycle.test.sh`, `council.test.sh` (`--quick`), `driver.test.sh`, `e2e.test.sh`, `solo.test.sh`,
`telemetry.test.sh` run in `.github/workflows/ci.yml`; `maintenance.test.sh` (budget, due brief, evolve
ledger) is NOT in ci.yml (run by hand / the spec's integration gate).

## Telemetry consumers
`scripts/telemetry.sh` reads `council.jsonl`, `journal.md`, `scope.jsonl` without writing them. See
`memory/map/scripts.md`.

last-verified: 2026-09-29 (v0.22.0, ADR-013, ADR-015)
