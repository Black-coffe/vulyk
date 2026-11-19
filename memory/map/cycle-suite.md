# Scout report: the cycle - suite gate and Workflow driver (split from cycle.md)

Other slices: `cycle.md` (files, verbs, gates), `cycle-state.md` (run state, advance, verdict, repair).

## Suite gate
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
- **Narrow round (0.54, ADR-040 D4):** `cmd_suite` reads ROUND `narrow=1`: only the steps in `rerun=` run (`all` =
  every step; empty or missing = none, log `steps=0` + `SUITE: none - narrow repair round`); the verdict reads
  `SUITE: ok|FAIL <N>s - narrow repair round, steps <list|all> of <S>` (`suite_narrow_verdict`).
- **Solo gate (0.54, solo-gate-1118, opt-in):** `solo_gate_on` = the default branch's root `.vulyk-solo-gate` reads
  exactly `merge-only` (read via `git show`, so a spec branch cannot switch it off). Then `cmd_suite` on a non-narrow
  Tier 1-2 round (`solo_tier`, frozen tier) with no log runs no step: log `steps=0` + `SUITE: none - Tier 1-2: ...`,
  unless ROUND `full=asked|design` (those still run); `round_rerun` returns empty for such a round (no step re-runs).
- **`suite <spec> --merge [--commit]` (0.54, ADR-040 D5, `suite_merge` -> `suite_run`):** every step, no agent, into
  `council/merge-suite.log` (paperwork; head line = HEAD, kept when only paperwork follows it, else the log is replaced).
  Exit 2 while a round is open or the tree is dirty outside paperwork; a finished log is a no-op (green or red); the
  last line carries `"merge":true`. `ship-check.sh` `suite:` accepts it or the newest non-narrow round's `suite.log`.
- **Full-suite line (0.36; ADR-023, ADR-029):** a finished suite.log keyed to the round head overrides the
  `review` report: `record-seat` drops every reported `SUITE:` line and writes the log's under the VERDICT line.
  **0.46:** `record-seat` of a `review` with a `round-only` row and no finished log for the round head exits 2
  (`no suite.log for round N ... run cycle.sh suite`), nothing written, no attempt spent (not a re-ask; the
  same report records after the gate). `judge`: `SUITE: FAIL` and a legacy `SUITE: TIMEOUT` line are both a
  review BLOCK `[regression]` → repair, never `suite-timeout`. `VULYK_SUITE_TIMEOUT` is read nowhere;
  `escalate --reason suite-timeout` stays valid for old rows/reopen. `repair` also copies each red PART line of
  the finished log as a `- [regression]` finding.

## The Workflow driver (`.claude/workflows/vulyk-cycle.js`)
Args `{spec, stamp, top_model, second_model}` (+ `worker_model`, `review_model`, `seat_model` off `sonnet-builds`;
`launched_at`, `checkpoint_min` default 50). Shell only via `cycle-clerk`, which runs each verb with `--short`
(0.53; a worker is handed its story id). **Checkpoint (0.49):** past `checkpoint_min` between `launched_at` and the
last verb's `now`, the next wave/gate step/seat is not started; returns `{status:"checkpoint",next,elapsed_min}`; either
time missing = no checkpoint; no clock read. A `leftover` story from `claim` is re-dispatched with a note; 2nd miss stops.
`build:W` → workers in parallel, a still-listed story is a miss, the second stops
the run, except a still-listed story whose worker returned `NEEDS_CONTEXT` (0.52): no miss, the run stops with
`{status:"needs_context",stories:[{story,report}],next}` for the Queen; `dispatch:` → `gate(st)` first, then the seats in
parallel (Tier 4 review = two `lead-review`), then `advance --ingest`. `release` in `finally`.
- **`gate`:** loops `suite <spec> --commit --stamp S` via the clerk until `done:true`; `exit 3` → Paused;
  `ok:false` stops the run; an unreadable clerk line (`BadLine`) is asked again, within `SUITE_CALLS` = 32 calls
  total, then fails `suite not done after 32 calls` (safe: steps resume, a finished log is a no-op).
- **Claim / retry (0.50):** an unreadable `advance --claim` line is proven by a short re-claim with the same stamp
  (no leftover list); unproven stops. A missed story's retry model = first of [TOP, opus] not judging the round;
  none left → opus, result carries `retry_same_family`.
- **Fable-limit fallback:** a `refused(r)` or empty-and-ping-empty result off `opus` is rerun once on `opus`;
  entries go in `fallbacks`; `/vulyk-build` journals them. An empty agent result names `maxTurns` in its agent file.
- Tests: `cycle|council|telemetry.test.sh --part <topic>` / `--list-parts` (cycle parts incl. `close`/`close2`,
  `red`/`red2`; council `verbs`/`verbs2`/`verbs3`); full set once per round (scripts.md).

last-verified: 2026-11-18 (solo-gate-1118 solo gate; 0.54.0-dev.1 narrow-repair-1115; ADR-023, 029, 040)
