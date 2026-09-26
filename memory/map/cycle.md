# Scout report: the cycle (build -> council -> repair state contract)

## Purpose
Truth lives in committed files under `docs/specs/<slug>/`, written only by `scripts/cycle.sh`
(2838 lines). Since 0.18 (ADR-013) one verb, `advance`, steps the loop to the next agent
boundary; the Queen (Tier 1-2 solo, or Tier 3-4 without Workflow) or `.claude/workflows/
vulyk-cycle.js` (Tier 3-4) calls it and dispatches the agent `next` names. Contract: ADR-001
(D2 clerk-per-verb and D3 roster superseded) + ADR-013. Header summary: `scripts/cycle.sh:25-32`.

## Files, one writer each
`brief.md ## Asks` ← `/vulyk-plan` · `plan.md **Briefed:**/**Approved:**` ← `briefed` / the owner ·
`**Branch:**` ← `branch` · `**Council:**` line per round, `## Needs a human` ← `judge`/`escalate` ·
`**Checked:**` ← `human-check.sh` · `council/round-N/ROUND` (`head= pack= opened= court= ceiling=
tier= seats= since=`) ← `build_round` `cycle.sh:2015` · `council/REOPEN`, `CEILING` ← `reopen` ·
`council/round-N/<seat>.md` (+`.attempt-K.md`) ← `record-seat` (committed at judge) ·
`<slug>-NN-repair-round-<n>.md` ← `repair` · `memory/stats/council.jsonl` (1 row/round) ←
`judge`/`escalate` · `journal.md` ← `journal.sh`. Gitignored: `PAUSE`, `DRIVER` (stamp),
`.vulyk/court/<slug>/round-N/`, `.vulyk/reports/<slug>/round-N/<seat>.attempt-K.md`.

## Verbs (exit 0 ok · 1 usage · 2 precondition · 3 paused · 4 malformed report / red verify · 5 stale · 6 escalate)
Dispatch table `cycle.sh:2725-2838`. Last stdout line is always one JSON object (`emit` :64);
mutating verbs on exit 0 carry the post-verb `status` (`emit_status` :81).
- `status [--json]` `cmd_status` :461 - read-only.
- `briefed` :1262 · `branch` :1313 · `escalate` :1191 · `judge` :937 · `record-seat` :1601.
- `close-story <file> [--commit] [--stamp]` :1737 - scope-check, each `## Verification` segment must be
  a `## Commands` cell of `constitution_file` (lib.sh:94) or `none — reviewed by lead-review`; runs
  each under `timeout ${VULYK_VERIFY_TIMEOUT:-540}` when a working `timeout` exists (:1843-1857;
  exit 124 → exit 4 `verification timed out`); commits. Done + clean tree → `ok:true` "already
  done" (:1768); self-marked done with a diff → closes it (`SELFMARKED`).
- `open-round` :2116 - refuses a tree dirty outside paperwork (`dirty_outside_paperwork` :370);
  `build_round` freezes `seats=` and `since=`, builds the court (`build_court` :1947) only when a
  blind seat is required, and carries round n-1's GREEN/N/A blind seats (`carry_seats` :1992; header
  gets ` · carried: round <n-1>`; `review` never carried).
- `claim <spec> <stamp>` :2398 - refuses a dirty tree (`working tree not clean`); a re-claim by
  the holder skips it. `release` :2448 and `pause`/`resume`/`status` are not PAUSE-guarded.
- `reopen "<decision>"` :2280 - appends to `## Answers`, raises `CEILING`; emits `next:"repair"`
  (`open-round` for an `env` escalation).
- `repair [--commit] [--stamp]` :2493 - see Repair below.
- `advance [--stamp] [--claim] [--ingest]` :2641 - see below.

## `advance` (ADR-013 D2)
1. `--claim` (needs `--stamp`): runs `claim`; a refusal is the stop line.
2. `--ingest`: for the open, non-stale round, each missing required seat is recorded from
   `.vulyk/reports/<slug>/round-<n>/<seat>.attempt-<k>.md` (k = 2 if attempt-1 exists); no file →
   an empty report (spends the attempt). Tier 4 `review` = `fold_reviews` :2613 over `review-top`
   and `review-second` (both `VERDICT: PASS|BLOCK` → BLOCK if either; else `NO VERDICT`). Each
   exit 4 goes into `rejected:[{seat,attempt,error}]`.
3. Loop ≤ 12 steps: while `next` ∈ `branch|open-round|judge|repair`, run that verb with `--commit`
   (+`--stamp`) as a subprocess (`run_verb` :2632). Exit 6 is ok. A verb that leaves `next` equal to
   itself stops (`no progress`, exit 2).
4. Last line `{"ok":true,"verb":"advance","exit":0,"next",..,"steps":[..],"rejected":[..],"status":{..}}`;
   a stop: `ok:false`, the failing verb's `exit/next/error`, `"failed":"<verb>"`, `steps`,
   `rejected`, no `status` (`advance_stop`). After `--ingest` a RED round reads
   `steps:["judge","repair"]`, `next:"build:<W>"`.

## `status --json` keys and `next`
Keys in order: `spec slug stage next briefed approved branch head pack stories{todo,in-progress,
done,blocked} wave wave_stories[{file,story,worker,model,repeat}] round ceiling tier open court
missing[] stale verdict review red[] round_dir paused shipped since seat_attempt{} seats[]`
(the last three new in 0.18, appended). `next` first match (:610-637): `shipped` → `paused` →
`briefed` → `branch` → `build:<wave>` → `close-story:<file>` → open round: stale → `open-round`,
missing seat → `dispatch:<csv>`, else `judge` → `escalated` (ESCALATE not reopen-cleared) →
`green` (GREEN, pack matches, not stale) → `repair` (RED not stale; or a reopened non-`env`
ESCALATE not stale) → `open-round`.

## Seats by tier and the verdict (`cmd_judge`)
`required_seats_for_tier` :301: Tier 1-2 → `review`; 3-4 → `opus review`, `haiku opus review` when
`client_path_filled` (lib.sh:142: non-empty, not `<fill…`, not `none…`). Read back through
`round_required_seats` :316 (`seats=` first; pre-0.18 rounds fall back to the tier roster).
`sonnet` is in no roster; `record-seat` still accepts it. Ceiling `tier_ceiling` :291 1/2/3/3;
`CEILING` wins. Verdict, first match: human REJECTED newer than the round → RED; a required seat
ABSENT with no RED and no BLOCK → ESCALATE `env`; evidenced RED ≥ max(2, ceil(A/2)) → `half`;
anchored review BLOCK or any RED → `no-progress` if the same ask was RED in round n-1, `ceiling`
if `red_rounds`+1 ≥ ceiling, else RED; else GREEN. `red_rounds` counts RED and ESCALATE
`ceiling`/`no-progress` rows only. A BLOCK with no in-range `[ask N]`/`[regression]` is recorded
PASS, note `review BLOCK unanchored`; row field `review_asks`.

## Staleness, PAUSE
Stale iff `ROUND.head` != HEAD and the commits between are not `paperwork_only` (lib.sh:68;
`is_paperwork_path` :54 includes `VERSION` and `CHANGELOG.md` since 0.18). Stale with no seat file →
re-stamp; with one → STALE row, open N+1 (never counts). `PAUSE` → every mutating verb exits 3.

## Seat report contract and the court
Blind seat: `COUNCIL/MODEL/COURT/VERDICT/ASSUMED CONFIG/RAN/PATH`, one `ASK <n>:` line per ask with
`run:`+`saw:` / `url:`+`saw:` / `why:`, `UNASKED:`, `BREACH:`; malformed → exit 4, re-asked once,
attempt 2 malformed → ABSENT. Taint = a path to a story file, `plan.md`, `journal.md` or `council/`
(`taint_reason` :1403). `lead-review`: line 1 `VERDICT: PASS|BLOCK`, then `## Critical`/`## Major`/
`## Minor` list lines, blocking lines tagged `[ask N]`/`[regression]`/`[unanchored]`. Court =
`git worktree add --detach` at the pack commit, `docs/specs/<slug>/` reduced to `brief.md`,
removed by `judge`.

## Repair (ADR-013 D4)
`cmd_repair` :2493 runs only when `next == repair`; idempotent (a not-done `*-repair-round-<n>.md`
→ nothing written). Writes `<slug>-NN-repair-round-<n>.md`: frontmatter `status: todo`,
`worker: worker-code`, `model: opus`, `wave: <max+1>`; `## Requirements` = the row's `red` +
`review_asks` + seat-file RED asks, each `> N. text` (`ask_item` :2474); `## Findings` = RED `ASK`
lines + anchored review lines (never `[unanchored]`); `## Files`/`## Verification` = union over
done stories (`repeat:` dropped). `trace-check.sh:52-56` accepts `## Asks` quotes.

## The Workflow driver (`.claude/workflows/vulyk-cycle.js`, 213 lines)
Args `{spec, stamp, top_model, second_model}`. Shell only via `cycle-clerk` (`ask` :67). Start
`advance --claim` (:186); `build:W` → workers in parallel (`build` :106; model = story's, `TOP` on a
retry), then `advance`; a story still listed is a miss, the second stops the run with `file`.
`dispatch:` → seats in parallel (`council` :148), each told its report path; Tier 4 review = two
`lead-review` (TOP, SECOND); then `advance --ingest`; a seat dispatched twice in a round stops.
An unreadable clerk line costs one `status --json` (`advance` :87). `MAX_ITERATIONS` 40 (:29);
`CAPS` :28 mirrors `maxTurns`; `release` in `finally` (:212). No queen-planner, no JS fold.

## Tests
`tests/cycle.test.sh` (63), `tests/council.test.sh` (513; `--quick` 252 in ~3 min),
`tests/driver.test.sh` (66, stubbed agents), `tests/e2e.test.sh` (19, real driver + real
`cycle.sh`), all in `.github/workflows/ci.yml`.

## Telemetry consumers
`scripts/telemetry.sh` detectors read `council.jsonl` (`council_rounds_high`), `journal.md`
(`stage_long`) and `scope.jsonl` (`scope_breach`) without writing them; `anomalies.jsonl` is
paperwork. See `memory/map/scripts.md`.

last-verified: 2026-09-27 (v0.18.0, ADR-013)
