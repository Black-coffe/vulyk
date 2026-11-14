# Scout report: the cycle (build -> council -> repair state contract)

Other slices: `cycle-state.md` (run state, claim, advance, verdict, repair), `cycle-suite.md` (suite gate, Workflow driver).

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
Gitignored: `PAUSE`, `DRIVER`, `.vulyk/court/`, `.vulyk/reports/`, `.vulyk/state/`.
Paperwork in `plan.md`/`brief.md` is only the lines a cycle script writes (`lib.sh spec_doc_strip`: plan `**Briefed|Branch|
Council|Checked|Shipped:**` + `## Needs a human`; brief `reopen`'s `**After escalation ...**` + `> ` lines); any other
change to either is a hand edit: it stales the round (named in the stderr line) and goes through `revise`.

## Verbs (exit 0 ok · 1 usage · 2 precondition · 3 paused · 4 malformed report / red verify · 5 stale · 6 escalate · 7
verification paused)
Last stdout line is one JSON object (`emit`); mutating verbs on exit 0 carry the post-verb `status`.
- **`--short` (0.53):** anywhere after the verb; the verb runs as usual, its last line becomes `short_line`: only the
  fields the Workflow driver reads, stories by id (the driver's clerk call uses it). Exit code is the verb's.
- **Branch guard (0.31):** `branch_guard <spec> <verb>`: plan.md has a `**Branch:**` and HEAD differs → exit 2,
  never switches; none yet = pass. Called by `claim`, `close-story`, `open-round`, `stamp-red`, `suite`, `revise`, `reanchor`.
- `status [--json]` (read-only) · `briefed` · `branch` (refuses a `vulyk/<slug>` already merged and behind the
  default) · `escalate` · `judge` · `record-seat` · `manual-done`.
- **Red receipt (ADR-025):** frontmatter `red: required` (planner-marked; `fm_red` reads frontmatter only)
  closes only on a receipt. `stamp-red <story> [--stamp S]` runs `## Verification` once and writes
  `red_verified_at: <ts> <test-hash>` + a `## Red receipt` section (0.47: its fenced tail leads with up to 3
  lines of the failing output carrying `red_reason`, then the last 10 lines, redacted). Exit 4, nothing written: not
  required, empty `red_reason`, no sealed test, only tests in `## Files`, every line exits 0, 126/127, timeout, or
  `red_reason` (`grep -F`, one layer of matching YAML quotes stripped first, 0.52) in no failing line; exit 2 no
  sha256 tool. It re-hashes each stored line output against its record before the verdict reads it (0.53).
  `close-story` calls `red_gate` after scope-check: exit 4
  `no red receipt` / `test changed after red receipt` / `no implementation change since red receipt`.
- **Approved version (ADR-032, reworked 0.53):** a story's approved version is a commit `cycle.sh` itself made
  (`branch`, `revise`, `repair`), recorded in the run state (`approved_sha`, `record_approved`); no commit subject is
  trusted. `story_blocks_guard` (`close-story`, `stamp-red`) compares `## Verification`, `## Files`, `red:`, `narrow:` with
  it: differ → exit 4 `story blocks differ from the approved version (<sha7>)`; no record at Tier 3-4 → exit 2 `no approved
  record for <story>: run bash scripts/cycle.sh revise <story>` (Tier 1-2: a stderr note). `claim`/`branch` seed records
  once from commit subjects (`seed_approved`); `approved_missing_guard` refuses a branched Tier 3-4 spec with an open
  story and no record. A close is a commit `story(<id>): ...` (`has_close_commit`); `status` counts a `done` story
  with no such commit as `in-progress`; `close-story` on it re-runs the gates (`--allow-empty`).
- **`revise <story>` (0.53):** pause/branch guarded; journals `revised <id>`, commits the story + `plan.md`, `brief.md`,
  `journal.md` as `vulyk(<slug>): revised <id>`, records that commit as approved. The only way to change a story's gate
  blocks, `plan.md` or `brief.md` mid-build; a hand commit approves nothing. Not on the clerk's or workers' list.
- **`reanchor <spec> --reason <text> [--commit]` (0.53):** main session; moves the open wave's claim head
  (`wave.<W>` in the `claim` state record) to HEAD with a journal line; exit 2 no open wave.
- After `red_gate`, `defects-check.sh --files <## Files>` runs when a `status: block` card exists: red → exit 4
  `defect card <ref> fails on <file>`, gate error → exit 2. `stamp-red --baseline` restores `RED_IMPL` files to HEAD,
  stamps, restores (no stash; Queen only). `briefed`/`branch` at Tier 2-4 need `**Approved:**` or `--go` (exit 2
  `Tier <N> plan needs ...`; `--go` goes on the Briefed line and re-stamps an old one).
- **prompt-check gate (0.43):** after the defect gate, when `## Files` has a path under `scripts/`, `.claude/agents/`,
  `.claude/commands/` or `templates/`, `close-story` runs `prompt-check.sh --touched <## Files>`: exit 1 with an
  `error` line → exit 4 (first `error` line); exit 1 with none → exit 4 `prompt-check crashed`; 2 = stderr note.
- `close-story <file> [--commit] [--stamp]` - scope-check; at Tier 3-4 scope counts from the head `claim` recorded for
  the wave (`scope-check.sh --since <sha>`): a path committed since it → exit 4 `edited outside ## Files: ...` at once;
  no recorded head → exit 2. `--commit` with a dirty out-of-scope, non-paperwork path → the same exit 4. A
  `## Verification` segment matching a `round-only` row → exit 2.
  Each segment must be a `## Commands` cell or `none — reviewed by lead-review`. **Verify runner (gate-split-02,
  `verify_run`, shared with `stamp-red`):** each line under its own cap `VULYK_VERIFY_TIMEOUT` (default 300; a
  value above 300, or junk/0, acts as 300; 124 → exit 4, naming the line); the call has a budget
  `VULYK_VERIFY_CALL` (default 540): a line starts only if its cap fits what is left (the first line of a call
  always runs), else `verify_pause` writes a resume mark and exits 7 `verification paused`; rerun the same verb
  to resume at that line (the mark is the cycle's verify record, see `cycle-state.md`). No timeout/gtimeout/Python
  cap = uncapped; a command's own 124 is then not a timeout.
  Only the wave's last open story refuses a dirty stray; with a wave-mate open it notes and goes on. Done + clean tree →
  `ok:true` "already done".

last-verified: 2026-11-14 (0.53.0-dev.1 audit-fixes-1113; ADR-001, 013, 025, 029, 032)
