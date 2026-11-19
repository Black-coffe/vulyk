# Scout report: the cycle - repair and next-round scope (split from cycle-state.md)

Other slices: `cycle.md` (files, verbs, gates), `cycle-state.md` (run state, claim, advance, verdict),
`cycle-suite.md` (suite gate, Workflow driver).

## Repair (ADR-013 D4)
`cmd_repair` runs only when `next == repair`. Writes `<slug>-NN-repair-round-<n>.md` and records its commit as the
approved version: `worker: worker-code`, **`model: opus` on purpose** (ADR-015), `wave: <max+1>`, `red: required`
kept unless `repair_unmarks`. `## Requirements`/`## Findings` = RED asks, anchored review lines, red suite PART lines.
**Scope (ADR-040 D2, 0.54):** `## Files` = `repair_scope_paths` (each existing path the findings name via
`finding_paths`, its `symbol-map.sh --exact` tests, the `## Files` of done stories serving a pathless RED ask
(`repair_ask_stories`: a `## Requirements` line found inside the ask text), `docs/defects/*`); no path at all = the
union of every done story's `## Files` (stderr line, no acceptance criteria). `## Verification` = `repair_scope_rows`
(rows of the done stories tied by `## Files` overlap, `repeat:` dropped; none = `none — reviewed by lead-review`).
**Next round (ADR-040 D1, D3, D4):** `round_scope <spec> <n>` reads committed records only (HEAD's `council.jsonl` +
`council/REOPEN`): `narrow` by default; `full design` for a reopened `half`/`no-progress` ESCALATE; `full norecord` when
no row reads. `repair` prints it and writes `narrow: true` for `narrow`. `build_round` freezes `repair=`, then `narrow=1`
+ `asks=` (`round_asks`: RED asks of round n, asks served by done stories whose `## Files` the `since..head` diff
touches, every ask when no round holds a blind report; empty = review only) + `rerun=` (`round_rerun`: FAIL steps of
the last gate log that ran steps (`gate_log_round`); `all` if the step count changed) + `second=none`, or `full=<why>`.
`court_round_asks` commits `round-asks` in the court. `open-round <spec> --full` (`open_round_full`; owner only):
`full=asked`, `since=` the branch base, no carry; exit 2 while a round is open or no merge-base.

last-verified: 2026-11-17 (split from cycle-state.md; ADR-013, 015, 040)
