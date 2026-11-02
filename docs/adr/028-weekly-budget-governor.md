# ADR-028: The weekly-budget governor - one script, one journal per account, a ladder routing reads

- Status: proposed
- Date: 2026-11-02
- Spec: docs/specs/weekly-budget (brief `## Asks` 1-9 are decided and bind this ADR; this ADR settles only *where*
  and *how*, not *whether*)
- Amends: ADR-015 (the Fable list and the gate dispatches), ADR-020 (what a profile means under a budget state).
  Respects ADR-011 (clerk verbs), ADR-024 (no background reliance).

## Context

Nothing in VULYK knows about the account's limits. `fable-fallback` (ADR-015 amendment, 0.39.0) acts after a refusal;
`top-model.sh` routes by plan, statically. The `fable-budget` study measured Fable at 40% of one account's spend with
the weekly bar at 80%, and `docs/model-cascade.md`'s "never reached by design" is wrong. The owner wants a governor
that reads the 7-day limit, computes a daily allowance, warns, steps VULYK's own dispatches down a ladder, pauses a
build below a 10% reserve, and lets Fable 5.5 arrive without a code edit (brief, Asks 1-9).

Facts the design stands on (recon.md, research-budget-formula.md, research-cc-updates.md):

- Headless `claude -p "/usage" --output-format stream-json --verbose` costs $0 (`local_command_run.command: usage`,
  `total_cost_usd: 0`, ~15 s) and returns `usage_report.rate_limits.limits[]` with `weekly_all`, `weekly_scoped`
  (Fable, the only source of that share) and `session` (5h) where present. Under Git Bash without
  `MSYS_NO_PATHCONV=1` the argument became a $0.19 model call. The SDK marks the shape "experimental".
- Hooks never carry `rate_limits`; the statusline does, but one `statusLine` per user and VULYK does not own it.
- `used_percentage`/`percent` is an integer; one step is ~1.7 h at flat pace (C1). Several sessions and both owner
  machines draw one pool; two accounts on one machine share nothing (C4; grill: the C5 "re-anchor" was a two-account
  data mix-up).
- The Workflow driver (`.claude/workflows/vulyk-cycle.js`) has no shell; every mutating verb goes through
  `cycle-clerk` -> `cycle.sh`, and `pause_guard` already turns `<spec>/PAUSE` into exit 3 that the driver honours.
- ADR-024: no agent protocol may depend on a background command finishing. So nobody can "poll in the background".
- CONTRIBUTING: "anything that touches auth will be declined". The OAuth usage endpoint and `.credentials.json` are
  out of bounds.
- 2.1.312: a subagent's `autoCompactWindow` can lower (never raise) the window; 2.1.316: `CLAUDE_CODE_SUBAGENT_EFFORT`.
  Neither is measured by VULYK yet.

## Options

### Fork 1 - where the governor lives
1. **New `scripts/budget.sh` (bash 3.2, I/O and verbs) + `scripts/budget.py` (the formula, pure, via `scripts/py.sh`).**
   One owner of the journal, the poller, the state and the overrides; everything else asks it. Testable with fixed
   snapshots. Cost: one more script pair and one more OWNED path in `install.sh`.
2. Fold it into `top-model.sh`. No new file, but a plan resolver grows a poller, a journal and a state machine, and
   `--floor`/`--explain` callers pay the poll.
3. A statusline shim journals `rate_limits` (horizon H1). Zero model calls and free samples, but no Fable share, and it
   needs each owner to chain a statusline VULYK does not own: a setup step the default path must not need.
4. The pulse plugin owns it. User-scope, terminal-only, optional: a governor that is absent on an owner without the mod.

### Fork 2 - how routing consumes the state
1. **`top-model.sh` and `model-profile.sh --role` apply the ladder as the last step, after the plan rule and before
   the floor check; `cycle.sh status --json` carries the resolved families so the driver re-reads them per wave.**
2. The governor edits the profile file / `settings.local.json`. A state that outlives the week and the account.
3. The driver applies the ladder itself from a new launch argument. Fixed at launch: a 6-hour run never steps.

### Fork 3 - where the gate fires and who polls
1. **Gate inside `cycle.sh advance` (exit 3 through the existing PAUSE), plus one line in `/vulyk-build`, `/vulyk-plan`
   and `/vulyk-review` before a multi-agent dispatch. Polling is lazy: whoever calls `budget.sh gate|state` refreshes
   the journal when the newest row is older than the interval; hooks do it in the main session, `advance` does it
   during a Workflow run.**
2. A daemon / background poller. Nobody owns the process across three OSes, and ADR-024 forbids relying on it.
3. Gate in the driver only. The driver has no shell and the solo path would stay ungated.

### Fork 4 - the ~400K agent window
1. **`autoCompactWindow: 400000` in each VULYK agent's frontmatter, shipped only after a measurement story proves it
   is honoured on the current Claude Code.** Per-agent, committed, main session untouched.
2. `CLAUDE_CODE_AUTO_COMPACT_WINDOW` in `settings.json` env. Also caps the main session, which Ask 7 keeps at 1M.
3. The dispatch parameter. Not documented for the Agent tool; would be a probe of its own.

### Fork 5 - version-agnostic Fable
1. **Routing and the governor match the family (`fable` alias, `scope.model.display_name` containing `Fable`,
   `claude-fable-*`), never a version; `token-report.py` prices by family + minimum version; the floor stays data.**
2. Drop the floor line for Fable. Then a provider pin to Fable 5 goes unnoticed, the regression ADR-015 exists for.

### Fork 6 - public-repo constraints
1. **The only external call is Claude Code's own `/usage`; the journal lives under the Claude config dir; API /
   unknown plans read `n/a`; `VULYK_BUDGET=0` and `budget.sh override off` switch it off; telemetry keeps codes only.**
2. Read a personal tool's cache (cs, the owner's shim) when present. Works for one owner, silently differs for others.

## Decision

Option 1 on every fork. Deciding factors: a single owner of the data (fork 1), a ladder that moves mid-run without a
second state store (fork 2), reuse of PAUSE and lazy refresh so no process has to stay alive (fork 3), a cheap undo
(fork 4: one frontmatter line per agent), and no auth surface (fork 6).

### 1. `scripts/budget.sh` + `scripts/budget.py`

- **Journal.** `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/vulyk/budget/` holds `journal.jsonl` (append-only; one row per
  accepted reading: `ts`, `cc_version`, `windows[]` = `{kind, percent, resets_at, scope, severity, is_active}` copied
  verbatim), `override` (one line: `boost|hold|off <until-epoch> <reason>`), `announced` (last state shown as a
  banner), `poll-disabled` (reason, when the safety guard fired). Rows older than two reset windows are trimmed on
  write. Nothing else is stored: no "what's contributing" text, no account id, no tokens.
- **Poller `poll`.** Runs `MSYS_NO_PATHCONV=1 VULYK_BUDGET_POLLING=1 claude -p "/usage" --output-format stream-json
  --verbose --model haiku` through `scripts/run-capped.py` (cap 90 s), with cwd = the journal dir (no project hooks
  load there) and the inherited `CLAUDE_CONFIG_DIR` (so the reading and the journal belong to the same account by
  construction). A reading is accepted only when `local_command_run.command == "usage"` AND `total_cost_usd == 0`
  AND `usage_report.rate_limits.limits[]` parses; any other outcome writes `poll-disabled` with the raw reason and
  prints one sentence to the owner; the next `poll` is a no-op until `budget.sh override poll-on`. A parsed report
  with no `limits[]` (API key, usage-based billing, unknown plan) writes a row `{kind: none}` and the state reads
  `n/a`. `poll` is a no-op when the newest row is younger than `VULYK_BUDGET_POLL_MIN` (default 20 min); a `mkdir`
  lock serialises two sessions. `--force` bypasses the interval, never the guard.
- **Formula `budget.py`** (stdin JSON rows -> stdout JSON state; no I/O of its own; table tests on fixed snapshots).
  Per window present (`weekly_all`, `weekly_scoped` Fable, `session` 5h): remaining `R`, days to reset `d`, daily
  allowance `D = (R - reserve)/d` (reserve 10 pp of the week, `VULYK_BUDGET_RESERVE`), burn over the last 1 h and
  24 h from the journal (a rate needs >= 2 rows >= 20 min apart and >= 1 pp moved, else that window abstains),
  forecast = exhaustion time and landing at reset. Fable is evaluated on its own bucket (percent of its 50 pp cap,
  B5 d) with the same formula; the 5h window feeds the hourly allowance (`H = min(H_7d, R_5h/T_5h)`). States:
  `off`, `n/a`, `no-data` (no row in the current reset window or newest row > 6 h old), `ok`, `warn` (every known
  window forecasts exhaustion before reset; the 24 h window must be known), `downgrade-1` (warn sustained across
  >= 2 readings >= 40 min apart, or the Fable bucket alone in warn), `downgrade-2` (24 h forecast exhausts > 24 h before
  reset, or `R - reserve` below one neutral day), `reserve-pause` (`R <= reserve` with > 24 h to reset),
  `boost` (landing < 85 with > 12 h to reset). Leaving a state needs the opposite condition plus margin (12 h of
  forecast or 10 pp of landing), so one integer step cannot flap it. The window that bites first wins. An override
  replaces the state until its `until` (default: next reset) and is journaled with who/when/why.
- **Verbs.** `poll [--force]`, `state [--json]` (one human line or the JSON: state, per window `{percent, resets_at,
  daily, burn_1h, burn_24h, forecast}`, `ladder`, `reason`, `age`), `gate [--json]` (= `state` with a lazy `poll`
  first; exit 0 pass, exit 3 reserve-pause with the reason on stdout, exit 0 on `off|n/a|no-data` with a warning line),
  `override boost|hold|off|poll-on [--until <when>] [--why <text>]`, `explain` (for `/vulyk-status`).

### 2. Routing: the ladder is a function of (profile, plan, budget state)

- The budget state adds one more rung step at the end of the resolution: `env > constitution pin > profile > plan`
  gives the baseline; `budget.sh state --json`'s `ladder` then lowers or raises families. `top-model.sh --explain`
  and `model-profile.sh --explain` print the step (`budget: downgrade-1, Fable -> Opus on the gate, because ...`).
  `--floor` is unchanged: the ladder moves between families at or above the floor and never below it.
- **The Fable list (amends ADR-015 D1 and model-cascade "four uses"):** the Tier 4 `lead-review`, `lead-architect`,
  a missed story's retry. The Tier 4 `queen-planner` leaves the list: planner, Tier 1-3 review and both blind seats
  run on `opus` under every profile (Ask 6). Each Fable dispatch passes `effort: high` explicitly, never `xhigh`.
- **Rungs.** `downgrade-1`: every Fable role -> `opus` (the ADR-015 fallback made pre-emptive; recorded the same
  three ways with a new code `budget_downgrade`). `downgrade-2`: additionally `worker`/`routine` roles that resolve
  to `opus` -> `sonnet` (under `sonnet-builds` nothing more can drop: judges never go to the builders' family, so the
  rung only warns). `boost`, on plans where Fable is inside the plan: the Tier 3-4 planner and the Tier 1-3 review
  return to `fable` (Ask 6 "при недорасходе"). `boost` on Pro/API changes nothing: the plan rule still bounds the top
  rung, Fable never bills credits because of a budget state. The Fable bucket's own state can hold `downgrade-1`
  while the all-model state is `ok`.
- **Mid-run.** `cycle.sh status --json` and the `advance` result gain a `budget` object (`state`, `ladder`:
  `{gate, second, worker, review, seat, retry}`, `reason`). The driver takes families from the latest status when
  present and from its launch arguments otherwise; no new clerk verb (ADR-011). A step the driver applied is logged
  and returned in the run's result beside `fallbacks`, and `/vulyk-build` records it.
- **A tension the Queen must put to the owner at plan approval, one line:** Ask 6 ("planner, review and council on
  Opus under every profile") makes `opus-builds` Opus-judges-Opus at Tier 1-3, the ADR-015 exception as a steady
  state. This ADR records it as that (the profile's `--explain` says so; `boost` restores Fable there first). The
  alternative, keeping `fable` for `opus-builds` judges outside `boost`, is one `case` line and can be chosen at
  approval without reopening anything else.

### 3. The gate fires in `cycle.sh advance`; polling is lazy and synchronous

- `advance` calls `bash scripts/budget.sh gate --json` before any step that dispatches agents (a build wave, a
  council round, a repair). Exit 3 makes `advance` write `<spec>/PAUSE` itself (first line
  `budget: reserve - <R>% left, <d> days to reset; lift: bash scripts/cycle.sh resume <spec>`) and exit 3 through
  the existing `pause_guard`; the driver's `Paused` path is unchanged. `budget.sh` never writes into a spec dir.
- One command lifts it: `cycle.sh resume <spec>` on a `budget:`-stamped PAUSE records
  `budget.sh override hold-lifted --spec <spec>` (journaled in both journals), and the gate does not re-pause that
  spec in the same reset window. `budget.sh override boost|hold|off` is the global "today more / hold" (Ask 9).
- `/vulyk-build` (both paths, beside `--floor`), `/vulyk-plan` (before the Tier 3-4 planner batch) and
  `/vulyk-review` run `budget.sh gate` once before dispatching; the Queen's own typing is never gated.
- **Who polls.** `gate` and `state` refresh the journal when it is older than the interval, in the caller's foreground,
  capped at 90 s: at SessionStart (new `budget-brief.sh`, sibling of `top-model-brief.sh`, same off switch pattern),
  at the main session's `Stop` hook (only when stale, so at most once per interval), and inside `advance` through the
  clerk during a Workflow run. The clerk's Bash call grows by ~15 s once per interval; the cap keeps it under the
  clerk's timeout (to be measured, below). No process outlives its caller (ADR-024).
- **Surfaces (Ask 8).** One `[VULYK] budget: ...` line at SessionStart; a `systemMessage` banner once per state
  change (`announced` file, the `handoff.py` once-per-level pattern) from a `budget-banner.py` on `Stop`; the pulse
  band appends the `state` one-liner (its own release in the plugin); `/vulyk-status` step 9 prints `budget.sh explain`.

### 4. The ~400K window: frontmatter, after a measurement

`autoCompactWindow: 400000` in every VULYK agent file (workers, judges, scouts, clerk; the Queen's session untouched)
is the chosen mechanism, shipped only if measurement M2 (below) shows a subagent compacts near 400K on the current
Claude Code. If M2 fails, Ask 7 ships as documentation (`/autocompact` guidance in `docs/model-cascade.md`), not as
an env var that would also cap the main session, and the owner is told. `CLAUDE_CODE_SUBAGENT_EFFORT` is not used:
every VULYK agent names its own `effort:` (ADR-015), so the variable would apply to none of them.

### 5. Version-agnostic Fable

Routing already names `fable`, the refusal regex names no version, and the governor matches
`scope.model.display_name` by family (`Fable`, case-insensitive) or `kind == weekly_scoped`. `token-report.py`
`READ_RATE` becomes family + minimum version (`fable >= 5.0 -> 0.025`, `mythos >= 5.0 -> 0.025`, `opus >= 5.5 ->
0.05`) using the `model_version` shape from `lib.sh`. The floor line `fable 5.1` stays: a floor is a minimum, Fable
5.5 arrives through the alias with zero edits, and raising the line later is the deliberate one-line diff ADR-015
prescribes (plus `label()` prints `>= 5.1`, which stays true).

### 6. Public-repo constraints

- Works on Pro, Max, Ultra, premium Team seats (where `/usage` returns `limits[]`); reads `n/a` on API keys,
  usage-based billing, standard seats without the report, and on any shape change (degrades to `no-data`, never to a
  guess). Nothing in VULYK opens `.credentials.json`, calls the OAuth endpoint or reads a third-party cache.
- No owner-specific path: the journal dir is derived from `CLAUDE_CONFIG_DIR` only. Two accounts = two config dirs =
  two journals; a hive never keys anything by account.
- Off: `VULYK_BUDGET=0` in the shell (this session) or `budget.sh override off` (persistent, journaled). Off means no
  poll, no gate, no ladder step, one line `budget: off` where the state would print.
- Telemetry: codes `budget_downgrade`, `budget_pause`, `budget_poll_disabled`, `budget_override` with the state word
  and the integer percent, nothing else. The `-p` session's transcript (a local command, no model call) is ignored by
  `token-report.py` and `model_below_floor` (no assistant model entry).

## Consequences

- Easier: one place to test the formula (table tests with the brief's own examples: 6 d / 20 % -> warn, 2 d / 50 % ->
  boost; a Fable bucket at 90 % with the week at 45 % -> Fable `downgrade-1` only); one place to read limits for any
  future feature (pre-run cost estimate, horizon altitude P3).
- Harder: `top-model.sh`, `model-profile.sh`, `cycle.sh status/advance`, the driver and three commands each gain one
  dependency on `budget.sh`; every hive upgrade carries it (`install.sh` OWNED + hook wiring, additive).
- Debt accepted: the data source is "experimental" and a 15 s foreground call; a shape change turns the governor into
  `no-data` until someone edits the parser. `downgrade-2` is nearly inert under `sonnet-builds`. The Fable share is
  only as fresh as the last poll (>= 20 min). Judges at `high` instead of `xhigh` is a quality bet the owner took.
- Opens ADR-015/020 text: `docs/model-cascade.md` "four uses" and "never reached by design" are rewritten; the profile
  table gains the Ask 6 row.

## Measurements the plan schedules before any build story

- **M1 - the poller on every shell.** Git Bash, PowerShell, macOS zsh, Linux bash: `total_cost_usd == 0`,
  `local_command_run.command == "usage"`, wall time, and the `limits[]` rows; the same on an API-key config dir
  (expect no report -> `n/a`); the meaning of `is_active` and `severity` (recon saw Fable `is_active: false` at 15 %);
  whether project hooks fire with cwd = journal dir; whether the `-p` session's transcript lands anywhere a VULYK scan
  reads. Cost: $0 per probe when the guard holds; one misfire costs a Haiku call.
- **M2 - `autoCompactWindow` in agent frontmatter (2.1.316).** A subagent fed ~450K tokens of generated text with
  `autoCompactWindow: 400000`: does a compaction appear in its transcript before 1M? Costs real tokens (one subagent
  reading ~450K on Haiku/Sonnet); run once, on the cheaper account.
- **M3 - the clerk's Bash timeout** with a 15-90 s `poll` inside `advance` (memory: "clerk Bash timeout"); if it
  bites, `advance` runs `gate` with `--no-poll` and the Stop hook alone refreshes.
- **M4 - movement of the integer percent over a working day** (how many 1 pp steps per hour of a build), to set the
  rate floors in `budget.py` from data rather than from cs priors.

## Invariants created

Copy verbatim into `docs/wiki/`:

1. `scripts/budget.sh` is the only reader of `/usage` and the only writer under `<config dir>/vulyk/budget/`; it
   never writes into a hive, a spec dir or any settings file.
2. A reading is accepted only when the headless call was a local command (`local_command_run.command == "usage"`)
   and cost nothing (`total_cost_usd == 0`); anything else disables polling until an owner turns it back on and is
   said aloud. The poller always runs with `MSYS_NO_PATHCONV=1`, `VULYK_BUDGET_POLLING=1`, the cheapest in-floor
   family pinned, cwd = the journal dir, and a time cap.
3. The governor never invents a number: with `off`, `n/a` or `no-data` it warns and neither pauses nor steps the
   ladder. No state is entered from a single sample.
4. The journal and the `claude` invocation derive from the same `CLAUDE_CONFIG_DIR`; nothing keys budget state by
   hive, by account id or by a path outside the config dir.
5. The ladder moves between families at or above the model floor, never below it, never to Fable on a plan where
   Fable bills credits, and never sends a judge to the family that wrote the code. Every step is recorded three ways
   (journal, telemetry code, one sentence to the owner) like the ADR-015 fallback.
6. Fable is dispatched only for the Tier 4 final review, `lead-architect` and a missed story's retry, at
   `effort: high`; `boost` may add the planner and the Tier 1-3 review on plans where Fable is inside the plan.
7. `cycle.sh` owns PAUSE: the gate's exit 3 is turned into `<spec>/PAUSE` by `advance`, lifted by `cycle.sh resume`,
   and both sides journal the lift.
8. Polling is lazy and foreground: a caller refreshes a stale journal within a time cap and returns; no process
   outlives its caller (ADR-024).
9. Nothing in VULYK matches a Fable version: routing names the family, `/usage` rows are matched by
   `display_name`/`kind`, prices by family and minimum version. The floor line is the one place a version lives.
10. The governor stores percents, reset times and its own decisions only: no tokens, no account identifiers, no
    credentials, no "what's contributing" text.

## Revisit when

- Claude Code exposes `rate_limits` to hooks or ships a documented usage CLI: the poller shrinks to a reader and the
  20-minute interval goes.
- `/usage` headless stops being free, changes shape twice, or is withdrawn: either the statusline shim (fork 1 option
  3) becomes the source, or the governor is retired to warn-only.
- The owner's reading after two weeks of journal shows `downgrade-2` never fires under `sonnet-builds`: drop the rung.
- A second profile wants a different ladder: `budget.py` gets a profile argument, not a second state machine.
- M2 fails and a later Claude Code documents a per-agent window: ship fork 4 option 1 then.
- Fable 5.5 ships: raise the floor line (ADR-015) and re-measure the judge-at-`high` bet in `token-report.py`.
