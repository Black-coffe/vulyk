# Weekly budget: a governor on the 7-day limit, a model ladder, a narrower Fable (plan)

**Tier:** 4 · **Spec slug:** `weekly-budget` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-028 (this design; amends ADR-015 and ADR-020), ADR-011 (clerk verbs, no new driver verb), ADR-024 (no background reliance), ADR-025 (red receipt), ADR-023 (`round-only` rows), card `shell-needs-gnu-or-bash4` (bash 3.2 / BSD, Python only via `scripts/py.sh`), card `measurement-unlike-reality` (every measured number states how its setup differs from a real build)
**Depends on:** 0.44.0 (`0837af9`): `lib.sh` `run_capped`, `scripts/py.sh`, `scripts/run-capped.py`, `portability-check.sh` inside `tests/maintenance.test.sh`

## Goal
VULYK learns how much of the account's week is left and spends it on purpose. One script pair, `scripts/budget.sh` (I/O, verbs) and
`scripts/budget.py` (a pure formula), polls Claude Code's own free `/usage` lazily, journals readings per config dir, and turns
them into a state: a daily allowance `(R - reserve)/days`, a 1 h and 24 h burn, a forecast, and a verdict (`ok`, `warn`,
`downgrade-1/2`, `reserve-pause`, `boost`, or the honest `off`/`n/a`/`no-data`). Routing (`top-model.sh`, `model-profile.sh`)
applies that state as the last rung step; `cycle.sh advance` pauses a build below the 10% reserve through the existing PAUSE;
the driver re-reads families per wave; Fable shrinks to the Tier 4 final review, the architect and a retry at `effort: high`,
with its own bucket and no version pin; VULYK agents compact at ~400K if Claude Code honours the field. The owner sees it at
session start, in a banner on each state change, in the pulse band and in `/vulyk-status`, and can switch it off or say
"more today / hold" with one journaled command. Four measurements come first, because three design choices hang on them.

## Assumptions
- **ADR-028's open tension, default as the ADR chose it - the owner decides at approval:** Ask 6 puts the planner, Tier 1-3
  review and both blind seats on `opus` under every profile, so under `opus-builds` Tier 1-3 judges are Opus judging Opus (the
  ADR-015 exception as a steady state; `--explain` says so, and `boost` returns Fable there first). The alternative, keeping
  `fable` for `opus-builds` judges outside `boost`, is one `case` line in story 05 and changes nothing else.
- **No new `## Commands` row.** `CLAUDE.md` sat at its byte cap after 0.44.0 (`tests/maintenance.test.sh` cap test; recon Q1
  confirms the count). Budget and ladder tests ride in `tests/model-profile.test.sh` (the `Model profile tests` row), as
  `trace-autopsy` rides in `tests/symbol-map.test.sh`; the gate in `tests/cycle.test.sh`, the driver in
  `tests/driver.test.sh`, hooks in `tests/maintenance.test.sh`. `tests/token-report.test.sh` has no row and runs only in the
  round's full suite. If the owner prefers a separate `tests/budget.test.sh`, a `CLAUDE.md` trim must pay for its row.
- **`state` never polls; `gate` and `poll` do.** ADR-028 §1 and §3 differ on this; routing and `--explain` must not pay a
  15 s call (the ADR's own reason for rejecting fork 1 option 2). Hooks and `advance` call `gate`/`poll`.
- **Pass on missing data is a named bypass, not a silent one** (card `safeguard-bypassable-or-late`): `off`, `n/a`,
  `no-data` let a build run with a printed warning (ADR-028 invariant 3), journaled; the poll guard (a non-free reading
  disables polling) ships in the same story as the poller, and no hook is wired before story 03 closes.
- **Measurements have known gaps, stated beside the numbers.** M1 runs on the build machine's Git Bash and PowerShell only:
  macOS zsh, Linux bash and an API-key config dir are not reachable by a worker (the guard plus the `haiku` pin caps a misfire
  at one Haiku call; `n/a` is a synthetic fixture). M4 samples ≤ 2 h of wave 1 spend, not a working build day: `budget.py` keeps
  ADR-028's floors as env-overridable defaults and uses M4 only to confirm or widen them. M2 uses a generated-text probe agent,
  not a real worker.
- **M2 costs real tokens** (one subagent reading ~450K). The Queen launches wave 1 under whichever account the owner names for
  probes; nothing in the story names an account.
- **`CLAUDE_CODE_SUBAGENT_EFFORT` is not used** although Answer 7 names it: every VULYK agent sets its own `effort:`
  (ADR-028 §4), so the variable would reach none of them.
- **Not story files:** the ADR-015 amendment line and ADR-028 status (Queen at ship), `docs/wiki/` invariants note,
  `memory/` map slices (`drone-docs` at ship), `CHANGELOG.md`/`VERSION`, and the pulse `plugin.json` bump (on `main` after
  the merge; a bump on the branch stales GREEN).
- **Coverage repairs (drone-coverage, 2026-11-02):**
  - **Ask 2:** the target is explicit. `budget.py` boosts when the forecast landing at the reset is below 85% used and warns when it is above 100% before the reset. 85–95% is the success band reported by `/vulyk-status` (story 03 constants, env-overridable).
  - **Ask 3:** the `session` limit kind is the 5-hour window. It is used only when `/usage` returns it (Pro, Max, unverified Ultra), and the window that runs out first decides.
  - **Ask 5:** `cycle.sh advance` runs between every wave of the Workflow driver and before every solo story, so the gate there is the per-batch check (story 07). `/vulyk-build` also calls `budget.sh gate` before launching the driver (story 08).
  - **Ask 7:** if M2 shows the frontmatter window is not honoured, the 400K cap ships as documentation only. The owner hears this in the wave-1 report, before wave 2.
  - **Plan work without an ask, kept with a reason:**
    - family pricing in `token-report.py` serves Ask 6 («Fable 5.5 без правки кода»; `READ_RATE` was keyed to `fable-5-1`);
    - the four telemetry codes record Ask 9's journal events in the existing anomaly ledger;
    - `VULYK_BUDGET_BRIEF=0` follows the off-switch pattern of `VULYK_TOP_MODEL_BRIEF`.
- **Hive rollout:** story 06 makes `install.sh` ship the scripts and wire both hooks additively; live hives receive it through
  `/vulyk-update` after the release, not through a story.

### Recon questions for `drone-scout` (answer before dispatch; each may widen a story's `## Files`)
1. `CLAUDE.md` byte count vs the cap in `tests/maintenance.test.sh`: is there room for a `Budget` row? (Default: none.)
2. Where do the 2 `textual` tests of `scripts/top-model.sh` live: `tests/model-profile.test.sh` or elsewhere? (Story 05.)
3. Does any test assert `telemetry.sh` `ENUM` contents or length (story 03 appends four codes)? Which suite/part?
4. Does `prompt-check` reject an unknown agent-frontmatter key such as `autoCompactWindow`? (Story 04.)
5. Which suite asserts `install.sh --upgrade` hook wiring (`wire_hook`) - `tests/telemetry.test.sh --part constitution`, another? (Story 06.)
6. Which file renders the pulse band, and does `tests/mods.test.sh` exercise it? (Story 06.)
7. Which of `scripts/cycle.sh`'s 16 textual importers parse `status --json` strictly enough that a new `budget` key breaks them (`state.sh`, `/vulyk-status`)? (Story 07.)
8. Does `tests/driver.test.sh` drive the driver with canned clerk lines, so story 08 builds against the `budget` contract in parallel with 07?

**Answered by the Queen (2026-11-02, grep; the dispatched scout hit its turn cap):**
1. No room: the `tests/maintenance.test.sh:88-90` cap binds at baa5219 size, so no new row.
2. The textual `top-model.sh` tests are in `tests/model-profile.test.sh` and `tests/telemetry.test.sh`.
3. No test names `ENUM`. Story 03 still runs `tests/telemetry.test.sh --part telemetry` (added to its Files and Verification).
4. `scripts/prompt-check.py:136-150` checks agent frontmatter for name and model only. No unknown-key rejection was found.
5. `install.sh` wiring is asserted in `tests/telemetry.test.sh` parts `install` / `wiring` / `upgrade`. Story 06 now names that suite and runs `--part wiring` and `--part upgrade`.
6. The band is rendered in `.claude/mods/vulyk-pulse/hooks/core.ts` (+ `core.test.ts`). `tests/mods.test.sh` runs `claude plugin test` and pins the weights to `token-report.py`. Already in story 06 via `.claude/mods/vulyk-pulse/**`.
7. Strict `status --json` readers are `.claude/workflows/vulyk-cycle.js` only (`scripts/state.sh` does not call it). An added `budget` key is additive.
8. `tests/driver.test.sh:2-3` runs the driver against a scripted clerk that answers with JSON lines, so story 08 can build against the `budget` contract alongside 07.

## Stories

**Wave 1** (measurements; report numbers, change no product file)
- `weekly-budget-01-measure-poller` — M1 guarded `/usage` on Git Bash + PowerShell, M3 clerk Bash ceiling, M4 1 pp step rate; synthetic fixtures
- `weekly-budget-02-measure-window` — M2: does `autoCompactWindow: 400000` in agent frontmatter compact a subagent before 1M

**Wave 2**
- `weekly-budget-03-governor` — `budget.sh` + `budget.py`: journal, guarded lazy poll, formula, states, overrides, telemetry codes (`red: required`)
- `weekly-budget-04-agent-window` — `autoCompactWindow: 400000` in every agent if M2 passed, else `/autocompact` docs only

**Wave 3**
- `weekly-budget-05-routing` — ladder as the last rung step in `top-model.sh` / `model-profile.sh`, the new Fable list, family pricing in `token-report.py`, `model-cascade.md` (`red: required`)
- `weekly-budget-06-surfaces` — SessionStart line, Stop banner + lazy poll, `/vulyk-status`, pulse band, `install.sh` wiring (`red: required`)

**Wave 4**
- `weekly-budget-07-gate` — `cycle.sh advance` gate -> PAUSE, `resume` lift, `budget` object in `status`/`advance` (`red: required`)
- `weekly-budget-08-driver-commands` — driver re-reads families per wave and returns `budget_steps`; gate + Fable-list prose in `/vulyk-build`, `/vulyk-plan`, `/vulyk-review` (`red: required`)

## Contracts
- **Journal dir** `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/vulyk/budget/`, written only by `budget.sh`: `journal.jsonl` rows
  `{"ts":<epoch>,"cc_version":"<v>","windows":[{"kind","percent","resets_at","scope","severity","is_active"}]}` (copied
  verbatim; `[{"kind":"none"}]` for a parsed report with no `limits[]`), trimmed to two reset windows on write; `override`
  one line `<verb> <until-epoch> <why>`; `announced` (last banner state); `poll-disabled` (raw reason); `poll.lock` (`mkdir`).
- **`bash scripts/budget.sh <verb>`**: `poll [--force]` (exit 0 always; skips when the newest row < `VULYK_BUDGET_POLL_MIN`
  min, default 20, or polling is disabled; a rejected reading writes `poll-disabled`, prints one sentence, records
  `budget_poll_disabled`) · `state [--json]` (read-only, never polls) · `gate [--json] [--no-poll]` (lazy `poll` unless
  `--no-poll`, then `state`; exit 0 pass, exit 3 `reserve-pause` with the reason on stdout; `off|n/a|no-data` exit 0 plus a
  `budget: <state> - ...` warning line) · `override boost|hold|off|poll-on [--until <when>] [--why <text>]` and
  `override hold-lifted --spec <dir>` (journaled, records `budget_override`) · `announce <state>` (exit 0 and records it when it
  differs from `announced`, exit 1 when already shown) · `explain` (multi-line, for `/vulyk-status`). Exit 1 usage.
- **Poll call:** `MSYS_NO_PATHCONV=1 VULYK_BUDGET_POLLING=1 claude -p "/usage" --output-format stream-json --verbose --model
  haiku`, cwd = journal dir, inherited `CLAUDE_CONFIG_DIR`, under `run_capped 90`. Accepted only when
  `local_command_run.command == "usage"` AND `total_cost_usd == 0` AND `usage_report.rate_limits` parses. Tests put a stub
  `claude` first on `PATH`.
- **`budget.py`** (via `bash scripts/py.sh`): stdin `{"now":<epoch>,"rows":[...],"override":null|{...},"cfg":{"reserve":10,...}}`,
  stdout the state JSON; no I/O. **State JSON:** `{"state":"off|n/a|no-data|ok|warn|downgrade-1|downgrade-2|reserve-pause|boost",
  "fable_state":"<same words>","windows":{"weekly_all|weekly_scoped|session":{"percent","resets_at","daily","hourly","pace",
  "burn_1h","burn_24h","forecast","landing"}},"ladder":{"fable":"keep|down|up","worker":"keep|down"},"reason":"<one sentence>",
  "age_s":<int>,"override":null|{"verb","until","why"}}`. Fable rows match `kind == weekly_scoped` or `display_name` containing
  `fable` (case-insensitive), never a version. Thresholds and hysteresis: ADR-028 §1.
- **Env:** `VULYK_BUDGET=0` (off this shell), `VULYK_BUDGET_POLL_MIN` (20), `VULYK_BUDGET_RESERVE` (10), `VULYK_BUDGET_POLLING=1`
  (set in the poll child; every budget hook exits 0 at once when set), `VULYK_BUDGET_BRIEF=0` (SessionStart line off).
- **Routing:** `top-model.sh` and `model-profile.sh --role <r>` read `budget.sh state --json` as the last step, after the plan
  rule and before the floor check; `--explain` adds `budget: <state>, <role> <from> -> <to>, because <reason>`; `--floor`
  unchanged; never below the floor, never Fable where it bills credits, never a judge to the builders' family.
- **Fable list:** Tier 4 `lead-review`, `lead-architect`, a missed story's retry, each dispatched at `effort: high`; `boost` on
  plans with Fable inside adds the Tier 3-4 planner and Tier 1-3 review.
- **Cycle:** `status --json` and the `advance` result gain `"budget":{"state","ladder":{"gate","second","worker","review",
  "seat","retry"},"reason"}` (resolved families). A budget PAUSE's first line is `budget: reserve - <R>% left, <d> days to
  reset; lift: bash scripts/cycle.sh resume <spec>`; `resume` on it runs `budget.sh override hold-lifted --spec <spec>`, journals
  it, and `advance` does not re-pause that spec in the same reset window. `advance` records `budget_pause`.
- **Driver result:** `budget_steps: [{"wave","role","from","to","reason"}]` beside `fallbacks`; families come from the latest
  `status.budget.ladder` when present, else the launch arguments. `/vulyk-build` journals each step and records `budget_downgrade`.
- **Telemetry:** `budget_downgrade`, `budget_pause`, `budget_poll_disabled`, `budget_override` appended to `ENUM`; a record carries
  the state word and an integer percent only.
- **Test failure lines** (red receipts): `FAIL budget <case>` in the budget block, `FAIL ladder <case>` in the ladder block of
  `tests/model-profile.test.sh`.
- **Measurement files:** `docs/specs/weekly-budget/measure-poller.json`, `measure-window.json` (shapes in stories 01-02);
  fixtures `tests/fixtures/budget/usage-{report,noreport,misfire}.json` (synthetic values, real shape).

**Rejected alternative:** a separate `tests/budget.test.sh` with its own `## Commands` row. Cleaner to read, but `CLAUDE.md` has no
bytes left under its cap test, and a row bought by trimming a Law is an owner's call, not a planner's; the piggyback has
precedent (`trace-autopsy` in `symbol-map.test.sh`) and the full suite runs every block either way.

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all. Approved is the owner's
word, the stop at Tier 2-4; Briefed is written by `cycle.sh briefed` instead, at Tier 1 ("via
mini-brief"), with `--go`, or in no-question mode ("assumed"). Either closes stage 02. Council and
Checked close stages 04+05 together: a GREEN council row is enough on its own, and Checked is the
owner's override in either direction, newest timestamp wins. No line of this comment may start with
a marker: the scripts read the first line that does.

There is no default tier: `cycle.sh open-round` refuses to open a round while the `**Tier:**` line above
is missing or unparsable.
-->
**Approved:** Andrei, 2026-11-02 (defaults kept: opus judges opus on opus-builds Tier 1-3; fail-open with a journaled warning when no limit data)
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path (--go, Tier 1): "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"). Alternative to **Approved:** above.>
**Branch:** <written by /vulyk-build before wave 1 - stage 03: the branch every story commit lives on>
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** <written by scripts/cycle.sh judge/escalate - stages 04+05: "<GREEN|RED|ESCALATE|STALE> round <N>, <date>, at <sha7>, pack <fp12>[ - red: 2,5]", appended once per round.>
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
