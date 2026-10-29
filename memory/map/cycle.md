# Scout report: the cycle (build -> council -> repair state contract)

## Purpose
Truth lives in committed files under `docs/specs/<slug>/`, written only by `scripts/cycle.sh`. One verb,
`advance` (ADR-013), steps the loop to the next agent boundary; the Queen (Tier 1-2 solo, or Tier 3-4 without
Workflow) or `.claude/workflows/vulyk-cycle.js` (Tier 3-4) calls it and dispatches the agent `next` names.
Contract: ADR-001 (D2, D3 superseded) + ADR-013. No line numbers: `grep -n '^cmd_name()'`.

## Files, one writer each
`brief.md ## Asks` ← `/vulyk-plan` · `plan.md **Briefed:**/**Approved:**` ← `briefed` / the owner ·
`**Branch:**` ← `branch` · `**Council:**`, `## Needs a human` ← `judge`/`escalate` · `**Checked:**` ←
`human-check.sh` · `council/round-N/ROUND` ← `build_round` · `council/REOPEN`, `CEILING` ← `reopen` ·
`council/round-N/<seat>.md` ← `record-seat` · `<slug>-NN-repair-round-<n>.md` ← `repair` · `council.jsonl` ←
`judge`/`escalate` · `journal.md` ← `journal.sh`. Gitignored: `PAUSE`, `DRIVER`, `.vulyk/court/`, `.vulyk/reports/`.

## Verbs (exit 0 ok · 1 usage · 2 precondition · 3 paused · 4 malformed report / red verify · 5 stale · 6 escalate)
Last stdout line is one JSON object (`emit`); mutating verbs on exit 0 carry the post-verb `status`.
- **Branch guard (0.31):** `branch_guard <spec> <verb>` - plan.md has a `**Branch:**` and HEAD differs: exit 2
  `on X, spec branch is Y`, never switches; no `**Branch:**` yet = pass. Called by `claim`, `close-story`,
  `open-round`, `stamp-red`. `default_branch` = origin/HEAD, else `main`, else `master`.
- `status [--json]` (read-only) · `briefed` · `branch` · `escalate` · `judge` · `record-seat` · `manual-done`.
  `branch` refuses (exit 2) an existing `vulyk/<slug>` already merged into the default and strictly behind it.
- **Red receipt (ADR-025):** frontmatter `red: required` (planner-marked; other `red:` value = unmarked) closes
  only on a receipt. `fm_red` reads the mark (frontmatter only, over `fm_raw`, cut at `#`); a body line marks
  nothing. `stamp-red <story> [--stamp S]` (pause/driver/branch guards; commits nothing) runs `## Verification`
  once and writes `red_verified_at: <ts> <test-hash>` plus a `## Red receipt` section (command/exit/tests/impl/
  stamped + 10 redacted tail lines; re-stamp replaces). Exit 4, nothing written: not `red: required`, empty
  `red_reason`, no sealed test, only tests in `## Files`, every line exits 0, 126/127, timeout, or `red_reason`
  (`grep -F`) absent from every failing line; exit 2 no sha256 tool. `red_sets`: `RED_SEALED` = `sealed_tests`,
  `RED_IMPL` = the other `## Files`. `close-story` calls `red_gate` after scope-check, before verification: exit 4
  `no red receipt` / `test changed after red receipt` / `no implementation change since red receipt`.
- **prompt-check gate (0.43.0/0.43.1):** after `red_gate`, before verification, when `## Files` has a path under
  `scripts/`, `.claude/agents/`, `.claude/commands/` or `templates/` and `prompt-check.sh` exists, `close-story`
  runs `prompt-check.sh --touched <## Files>`. Exit 0: `warn` lines to stderr; 1 with an `error` line: exit 4
  (reason = first `error` line); 1 with no `prompt-check: error` line: exit 4 `prompt-check crashed: <last output
  line>` (or `exit 1 with no output`); any other (2 no python/usage) is a stderr note, not a refusal.
- `close-story <file> [--commit] [--stamp]` - scope-check; with `--commit`, a dirty path counted out of scope
  and not `is_paperwork_path` → exit 4 `edited outside ## Files: <paths>`. A `## Verification` segment matching a
  `round-only` `## Commands` row → exit 2 `verification is round-only`. Each segment must be a `## Commands` cell
  of `constitution_file` or `none — reviewed by lead-review`; each line runs under lib.sh `run_capped_as` for
  `${VULYK_VERIFY_TIMEOUT:-540}` s total (124 → exit 4; no timeout/gtimeout/Python cap = uncapped, so a command's
  own 124 is not read as a timeout); commits. Only the wave's last open story refuses; with a wave-mate open it notes and goes on.
  Done + clean tree → `ok:true` "already done"; self-marked done with a diff → closes it.
- `open-round` refuses a tree dirty outside paperwork; `build_round` freezes `seats=`/`since=`, builds the court
  only for a blind seat, carries round n-1's GREEN/N/A blind seats (`review` never).
- **Court setup (0.34):** `build_court` runs `$ROOT/.claude/vulyk-setup` if present (cwd = court, `run_capped
  ${VULYK_SETUP_TIMEOUT:-300}`); non-zero → court removed, `open-round` exit 2 `court setup failed`/`timed out`.
- `claim` refuses a dirty tree; `release`, `pause`/`resume`/`status` are not PAUSE-guarded. `reopen "<decision>"`
  appends to `## Answers`, raises `CEILING`, emits `next:"repair"` (or re-runs on an `env`/`suite-timeout` escalation).
- **Full-suite line (0.36; ADR-023):** the `review` seat's line 3 is `SUITE: ok|FAIL|TIMEOUT <N>s [budget <B>s]|none`.
  `record-seat` refuses (exit 4) a missing/malformed line when the constitution has a `round-only` row whose
  Purpose names the full suite; no such row = `SUITE: none`. `judge`: `FAIL` = BLOCK `[regression]`; `TIMEOUT` →
  ESCALATE `suite-timeout` (`VULYK_SUITE_TIMEOUT` default 590).

## `advance` (ADR-013 D2)
1. `--claim` (needs `--stamp`): runs `claim`; a refusal is the stop line.
2. `--ingest`: each missing required seat of the open, non-stale round is recorded from
   `.vulyk/reports/<slug>/round-<n>/<seat>.attempt-<k>.md`; no file → empty report (spends the attempt). Tier 4
   `review` = `fold_reviews` over `review-top`/`review-second` (BLOCK if either). Exit 4s go into `rejected[]`.
3. Loop ≤ 12 steps: while `next` ∈ `branch|open-round|judge|repair`, run it with `--commit` (+`--stamp`). Exit 6
   is ok. A verb leaving `next` unchanged stops (`no progress`, exit 2).
4. Last line `{"ok":true,"verb":"advance",..,"next","steps","rejected","status"}`; a stop is `ok:false` with `failed`.

## `status --json` `next`
First match: `shipped` → `paused` → `briefed` → `branch` → `build:<wave>` → `close-story:<file>` → open round:
stale → `open-round`, missing seat → `dispatch:<csv>`, else `judge` → `escalated` → `green` (GREEN, pack matches,
not stale) → `repair` (RED not stale; or reopened non-`env` ESCALATE) → `open-round`. `green` becomes
«Выпускаем?» in `/vulyk-build` and `/vulyk-review`.

## Seats by tier and the verdict (`cmd_judge`)
`required_seats_for_tier`: Tier 1-2 → `review`; 3-4 → `opus review`, plus `haiku` when `client_path_filled`.
`round_required_seats` reads `seats=`. `tier_ceiling` 1/2/3/3; `CEILING` wins. Verdict, first match: human REJECTED
newer than the round → RED; required seat ABSENT with no RED/BLOCK → ESCALATE `env`; `SUITE: TIMEOUT` with nothing
RED → ESCALATE `suite-timeout`; evidenced RED ≥ max(2, ceil(A/2)) → `half`; anchored review BLOCK or any RED →
`no-progress` if the same ask was RED in round n-1, `ceiling` if `red_rounds`+1 ≥ ceiling, else RED; else GREEN.
A BLOCK with no in-range `[ask N]`/`[regression]` is recorded PASS, note `review BLOCK unanchored`.

## Staleness, PAUSE, seat reports
Stale iff `ROUND.head` != HEAD and the commits between are not `paperwork_only`. Stale with no seat file →
re-stamp; with one → STALE row, open N+1. `PAUSE` → every mutating verb exits 3. Blind seat report: `COUNCIL/
MODEL/COURT/VERDICT/ASSUMED CONFIG/RAN/PATH`, one `ASK <n>:` per ask, `UNASKED:`, `BREACH:`; malformed → exit 4,
re-asked once, then ABSENT. Taint = a path to a story file, `plan.md`, `journal.md` or `council/`. Court =
`git worktree add --detach` at the pack commit, spec dir reduced to `brief.md`, removed by `judge`.

## Repair (ADR-013 D4)
`cmd_repair` runs only when `next == repair`; idempotent. Writes `<slug>-NN-repair-round-<n>.md`: `status: todo`,
`worker: worker-code`, **`model: opus` on purpose** (ADR-015), `wave: <max+1>`. If a done story it unions is `red:
required`, the repair carries `red: required` + empty `red_reason:` unless `repair_unmarks` says every finding
line names a path of the union `## Files` and none names a marked story's path; no findings or a pathless finding
= mark kept (fail closed). `## Requirements` = the row's `red` + `review_asks` + seat RED asks as `> N. text`;
`## Findings` = RED `ASK` lines + anchored review lines; `## Files`/`## Verification` = union over done stories.

## The Workflow driver (`.claude/workflows/vulyk-cycle.js`)
Args `{spec, stamp, top_model, second_model}` plus `worker_model`, `review_model`, `seat_model` (only off
`sonnet-builds`). Shell only via `cycle-clerk`. `advance --claim`; `build:W` → workers in parallel, a story still
listed is a miss, the second stops the run; `dispatch:` → seats in parallel (Tier 4 review = two `lead-review`),
then `advance --ingest`. `release` in `finally`.
- **Fable-limit fallback:** with a `model` other than `opus`, a `refused(r)` result (error matching `REFUSAL`, or
  a short string matching it with no `VERDICT|COUNCIL|STATUS` line) or an empty result whose same-model ping is
  also empty is rerun once on `opus`; not an attempt. Entries go in `fallbacks`; `/vulyk-build` journals them.
- Tests: `cycle|council|telemetry.test.sh --part <topic>` / `--list-parts`; full set once per round (scripts.md).

Plan.md `**Briefed:**`/`**Branch:**` and the story `status:` edits use `sed_inplace` (lib.sh).

last-verified: 2026-10-29 (cross-platform, 0.44.0; ADR-001, 013, 015, 023, 025)
