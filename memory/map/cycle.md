# Scout report: the cycle (build -> council -> repair state contract)

Other slices: `cycle-state.md` (run state, claim, advance, verdict), `cycle-repair.md` (repair),
`cycle-close.md` (close-story gates), `cycle-suite.md` (suite gate, Workflow driver).

## Purpose
Truth lives in committed files under `docs/specs/<slug>/`, written only by `scripts/cycle.sh`. One verb,
`advance` (ADR-013), steps the loop to the next agent boundary; the Queen (Tier 1-2, or Tier 3-4 without
Workflow) or `.claude/workflows/vulyk-cycle.js` (Tier 3-4) calls it and dispatches the agent `next` names.
Contract: ADR-001 (D2, D3 superseded) + ADR-013 + ADR-029 (gate split). No line numbers: `grep -n '^cmd_name()'`.

## Files, one writer each
`brief.md ## Asks` ← `/vulyk-plan` · `plan.md **Briefed:**/**Approved:**` ← `briefed` / the owner ·
`**Branch:**` ← `branch` · `**Council:**`, `## Needs a human` ← `judge`/`escalate` · `**Checked:**` ←
`human-check.sh` (`--commit` commits that line and its record row alone) · `council/round-N/ROUND` ←
`build_round` · `council/round-N/suite.log` ← `suite` ·
`council/REOPEN`, `CEILING` ← `reopen` · `council/round-N/<seat>.md` ← `record-seat` ·
`<slug>-NN-repair-round-<n>.md` ← `repair` · `council.jsonl` ← `judge`/`escalate` · `journal.md` ← `journal.sh`.
`council/merge-suite.log` ← `suite --merge` (cycle-suite.md). Gitignored: `PAUSE`, `DRIVER`, `.vulyk/{court,reports,state}/`.
**Solo gate (0.54, opt-in):** `solo_gate_on` is true only when the default branch's root `.vulyk-solo-gate` reads
exactly `merge-only` (spec branch cannot switch it). Then a non-narrow Tier 1-2 round's `suite` (`solo_tier`) runs no
step and writes `SUITE: none - Tier 1-2: ...` (`steps=0`), unless ROUND `full=asked|design`; `round_rerun` is empty.
**One fence rule (0.54, ADR-040):** every story-section reader skips fenced lines with the same `FENCE_AWK` line
(`fence_line($0) || fence_n { next }`): `cycle.sh`, `scope-check.sh`, `wave-check.sh`, `trace-check.sh` carry it
byte for byte (`council.test.sh` part `round-scope5` compares them); a red receipt's output fence is longer than
any backtick run in it.
Paperwork in `plan.md`/`brief.md` is only the lines a cycle script writes (`lib.sh spec_doc_strip`: plan `**Briefed|Branch|
Council|Checked|Shipped:**` + `## Needs a human`; brief `reopen`'s `**After escalation ...**` + `> ` lines); any other
change to either is a hand edit: it stales the round (named in the stderr line) and goes through `revise`.

## Verbs (exit 0 ok · 1 usage · 2 precondition · 3 paused · 4 malformed report / red verify · 5 stale · 6 escalate · 7
verification paused)
Last stdout line is one JSON object (`emit`); mutating verbs on exit 0 carry the post-verb `status`.
- **`--short` (0.53):** anywhere after the verb; last line becomes `short_line` (fields the Workflow driver reads);
  on `dispatch` lines `court` is relative to the repo root (tails-1115), not absolute.
- **Branch guard (0.31):** `branch_guard <spec> <verb>`: `**Branch:**` set and HEAD differs → exit 2, never switches.
  Called by `claim`, `close-story`, `open-round`, `stamp-red`, `suite`, `revise`, `reanchor`.
- `status [--json]` (read-only) · `briefed` · `branch` (refuses a `vulyk/<slug>` already merged and behind the
  default) · `escalate` · `judge` · `record-seat` · `manual-done`.
- **Red receipt (ADR-025):** frontmatter `red: required` (planner-marked; `fm_red` reads frontmatter only)
  closes only on a receipt. `stamp-red <story> [--stamp S]` runs `## Verification` once and writes
  `red_verified_at: <ts> <test-hash>` + a `## Red receipt` section (0.47: its fenced tail leads with up to 3
  lines of the failing output carrying `red_reason`, then the last 10 lines, redacted). Exit 4, nothing written: not
  required, empty `red_reason`, no sealed test, only tests in `## Files`, every line exits 0, 126/127, timeout, or
  `red_reason` (`grep -F`, matching YAML quotes stripped) in no failing line; exit 2 no sha256 tool. Stored line
  outputs are re-hashed before the verdict reads them (0.53). On a finished run it writes `red_rec_put`
  (guards-1115-03: `tests=`, `impl=`, `stamped=` in the run-state record
  `verify.<id>.stamp-red.receipt`) before the story file; a failed re-stamp leaves the last one. `sr_sweep` removes
  stamp-red's own `vulyk-sr.*` dirs a day old at start; every exit but a pause removes its stored output.
  `close-story` calls `red_gate` after scope-check: exit 4 `no red receipt` / `red receipt has no stamp-red record` /
  `red receipt differs from its stamp-red record` (the story's hashes must equal the record's) / `test changed after red
  receipt` / `no implementation change since red receipt`. A hand-written receipt therefore never closes.
- **Approved version (ADR-032, reworked 0.53):** a story's approved version is a commit `cycle.sh` itself made
  (`branch`, `revise`, `repair`), recorded in the run state (`approved_sha`, `record_approved`); no commit subject is
  trusted. `story_blocks_guard` (`close-story`, `stamp-red`) compares `## Verification`, `## Files`, `red:`, `narrow:`
  with it: differ → exit 4 `story blocks differ from the approved version (<sha7>)`; no record at Tier 3-4 → exit 2
  `no approved record for <story>: run bash scripts/cycle.sh revise <story>` (Tier 1-2: a stderr note).
  `claim`/`branch` seed records
  once from commit subjects (`seed_approved`); `approved_missing_guard` refuses a branched Tier 3-4 spec with an open
  story and no record. A close is a commit `story(<id>): ...` (`has_close_commit`); `status` counts a `done` story
  with no such commit as `in-progress`; `close-story` on it re-runs the gates (`--allow-empty`).
- **`revise <story>` (0.53):** pause/branch guarded; journals `revised <id>`, commits the story + `plan.md`, `brief.md`,
  `journal.md` as `vulyk(<slug>): revised <id>`, records that commit as approved. The only way to change a story's gate
  blocks, `plan.md` or `brief.md` mid-build; a hand commit approves nothing. Not on the clerk's or workers' list.
- **`reanchor <spec> --reason <text> [--commit]` (0.53):** main session; moves the open wave's claim head
  (`wave.<W>` in the `claim` state record) to HEAD with a journal line; exit 2 no open wave.
- Gates after `red_gate` (`block_card_gate`, prompt-check, `close-story` scope and verify runner) are in `cycle-close.md`.

last-verified: 2026-11-18 (solo-gate-1118 solo gate; tails-1115 short court; guards-1115 red_gate/red_rec;
  ADR-001, 013, 025, 029, 032, 040)
