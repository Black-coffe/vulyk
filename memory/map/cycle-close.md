# Scout report: the cycle - close-story gates (split from cycle.md)

Other slices: `cycle.md` (files, verbs, red receipt, approved version), `cycle-state.md` (run state, advance, verdict),
`cycle-repair.md` (repair), `cycle-suite.md` (suite gate, Workflow driver).

## Gates after `red_gate`
- After `red_gate`, `block_card_gate` runs `defects-check.sh --files <## Files>` when a `status: block` card exists
  (it skips the library's own `*.fixture`, `*.terms` and `fixtures/` files): red → exit 4
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

last-verified: 2026-11-17 (split from cycle.md; ADR-025, 029, 032)
