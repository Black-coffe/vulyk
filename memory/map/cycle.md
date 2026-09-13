# Scout report: the cycle (build -> council -> repair state contract)

## Purpose
v0.12.0 replaces stage 05 (mandatory human look) with a tier-scaled agent council. Truth
lives in committed files under `docs/specs/<slug>/`, written only by `scripts/cycle.sh`; two
drivers (`.claude/workflows/vulyk-cycle.js`, or the `/vulyk-build` fallback loop) both just
poll `cycle.sh status --json` and act on `next`. Full record: `docs/adr/
001-cycle-state-contract.md`; stage table: `CLAUDE.md` `## The cycle`. Verified against
`scripts/cycle.sh` (1867 lines) directly.

## Files, one writer each
`brief.md ## Asks` (numbered) ← `/vulyk-plan` grill · `plan.md **Briefed:**/**Approved:**` ←
`cycle.sh briefed` · `**Branch:**` ← `branch` · `**Council:** <verdict> round N...` (appended
per round) ← `judge`/`escalate` · `## Needs a human` ← `escalate` / ceiling exit ·
`**Checked:**` ← `human-check.sh` · `council/round-N/ROUND` (`head=pack=opened=court=
ceiling=tier=`) ← `open-round`→`build_round` · `council/REOPEN`/`CEILING` ← `reopen` ·
`council/round-N/<seat>.md` (+`.attempt-K.md`) ← `record-seat`, committed only at
`judge`/`escalate` time · `memory/stats/council.jsonl` (1 row/round) ← `judge`/`escalate` ·
`journal.md` ← `journal.sh` only. Gitignored: `PAUSE` ← `pause`/a human `touch`;
`.vulyk/court/<slug>/round-N/` ← `open-round`/`judge`; `.claude/state.json` ← `state.sh`.

## `cycle.sh` verbs (exit 0 ok·1 usage·2 precondition·3 paused·4 record-seat MALFORMED/close-story red-verify·5 stale·6 escalate)
`status [--json]` read-only · `briefed [--commit] [--mode mini-brief|assumed]` · `branch
[--commit]` · `close-story <file> [--commit]` (scope-check + repeats `## Verification`, each
`&&`-segment must equal a cell of root `CLAUDE.md` `## Commands`, or the literal `none —
reviewed by lead-review`) · `open-round [--commit]` · `record-seat <spec> <N> <seat> [--model
id] <report on stdin>` · `judge [--commit]` · `escalate [--commit] [--reason ceiling|half|env]
[note]` (standalone; open round w/ seats missing) · `reopen "<decision>" [--commit]` ·
`pause`/`resume` (exempt from the PAUSE guard - every other mutating verb calls `pause_guard`
first, exits 3 if `PAUSE` exists).

## `status --json` keys and `next`
Keys: `spec, slug, stage, next, briefed, approved, branch, head, pack, stories{todo,
in-progress,done,blocked}, wave, wave_stories[{file,story,worker,repeat}], round, ceiling,
tier, open, court, missing[], stale, verdict, review, red[], round_dir, paused, shipped`.
`next`, first match wins: `shipped` → `paused` → `briefed` (no Briefed/Approved) → `branch`
(no Branch line) → `build:<wave>` (ready wave) → `close-story:<file>` (in-progress, wave has
no todo left) → [open round: `open-round` if stale, else `dispatch:<seats,csv>` if a required
seat is missing, else `judge`] → `escalated` (newest row ESCALATE, not `reopen`-cleared) →
`green` (newest row GREEN, pack matches, not stale) → `repair` (newest row RED, not stale) →
else `open-round`.

## Required seats by tier (`required_seats_for_tier`) and the verdict rule (`cmd_judge`)
1 → `sonnet` · 2 → `sonnet opus review` · 3/4 → `haiku sonnet opus review`; frozen into
`ROUND.tier=` at `open-round`, so a later `plan.md` edit never reshapes an open round. A seat
not required reads `""` (not ABSENT). Verdict, first match wins - A=asks count, `half =
max(2, ceil(A/2))`, `red_e`/`red_u` = evidenced/unevidenced RED ask numbers (evidenced wins
overlap), `absent_seats` = required seats with no accepted report, `override_red` = a
`human.jsonl` REJECTED row newer than `ROUND.opened`:
1. `override_red` → RED, `repair`. 2. `absent_seats` non-empty & `red_e`+`red_u` empty &
review != BLOCK → ESCALATE `env`. 3. `|red_e| >= half` → ESCALATE `half`. 4. review BLOCK, or
`red_e`/`red_u` non-empty → RED if round N < ceiling else ESCALATE `ceiling`. 5. else (every
seat GREEN/N/A, review PASS/absent) → GREEN.
Writes idempotently: `council.jsonl` row → `plan.md **Council:**` line → (`## Needs a human`,
ESCALATE only) → journal line, then always removes the court worktree, any verdict.

## Staleness / ceiling / PAUSE-REOPEN-CEILING
Stale iff `ROUND.head` != HEAD AND the commits between are not `paperwork_only()` (lib.sh) -
the cycle's own paperwork never self-stales a round. Open+non-stale+unchanged HEAD →
`open-round` no-ops. Gone stale, no seat file yet → re-stamps `ROUND` in place (same N); with
a seat file → `write_stale_row` (seats default ABSENT) for N, opens N+1 - either way counts
toward the ceiling. Ceiling hit → `write_ceiling_escalate`, reason `"ceiling"`, exit 6;
default ceiling 3 (no `CEILING` file). `reopen "<decision>"` (newest row must be ESCALATE):
appends the decision to `brief.md ## Answers`, raises `CEILING` by 3, appends to `REOPEN`,
next `open-round`. `pause "why"` writes `PAUSE`; `resume` removes it, reports `stale:` if
HEAD moved, relaunches fresh (never `resumeFromRunId`) - an in-flight seat's report is
discarded and re-dispatched, never recorded from a paused run.

## Seat report contract (D3) and the court (D5)
Header `COUNCIL/MODEL/COURT/VERDICT/ASSUMED CONFIG/RAN/PATH`, one `ASK <n>: GREEN|RED|N/A -
... - run:+saw: | url:+saw: | why:` per `## Asks` item, `UNASKED:`, `BREACH:`. `VERDICT` must
be RED iff any ASK is RED, N/A iff all N/A. Missing label, ask mismatch, or GREEN/RED without
evidence → MALFORMED (exit 4, re-asked once, kept as `attempt-1.md`). Taint (exit 4): names
`docs/specs/<slug>/{plan.md,journal.md,council/}` (with/without prefix) or a story id
`<slug>-NN`. 2nd-attempt unevidenced RED stays RED but excluded from `half`; unevidenced
GREEN folds to N/A. `lead-review`: only its first line (`VERDICT: PASS|BLOCK`) is parsed.
Court: `build_round` runs `git worktree add --detach <path> <head>` at
`.vulyk/court/<slug>/round-N/`, strips its `docs/specs/<slug>/` to `brief.md` alone, commits
that reduction in the worktree's own detached history. Shared by all three blind seats;
`lead-review` never enters it. Reading outside `COURT` or its history is a self-reported
**BREACH**, not filesystem-enforced. `judge` always removes it, any verdict.

## Drivers
**Workflow** (`vulyk-cycle.js`, phases Build/Round/Judge/Repair): no verdict/ceiling/stale
logic of its own - every shell call goes through `cycle-clerk` (`haiku`, `Bash`, `maxTurns:
5`). `args:{spec, top_model, second_model, stamp}` (16-hex `stamp`, taken once by
`/vulyk-build` step 1, used only in the `record-seat` heredoc delimiter, never `EOF`, never
shown to a seat). Tier 4 review dispatches twice (`top_model`+`second_model`), folded
stricter-of-two before recording. `ok:false` on a clerk call ends the run, except
`record-seat` exit 4 (re-ask once) and a 2nd close-story/worker-report miss on one file
(blocks that story instead). **Fallback** (`/vulyk-build`, `Workflow` absent from the tool
list): same `status`→act loop, Queen's Bash for verbs and `Agent` for seats/workers - same
files, same `next` contract.

## Tests
`tests/council.test.sh` (fixture repo, no model calls): verdict table, staleness/ceiling/
reopen, PAUSE guard, taint/MALFORMED. `tests/cycle.test.sh`: the six-stage walk. Both wired
into `.github/workflows/ci.yml`.

last-verified: 2026-09-13
