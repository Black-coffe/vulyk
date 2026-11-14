# Scout report: commands - plan, build, review, models (split from agents-and-commands.md)

Other slices: `agents-and-commands.md` (agents), `commands-ship.md` (ship, update, status, gc and the rest).

## Per-release command changes
- **0.53 (audit-fixes-1113):** a story the Queen changes after `NEEDS_CONTEXT` (`## Files`, `## Verification`, `red:`) is
  committed with `bash scripts/cycle.sh revise <story>` before its worker reruns (`/vulyk-build`; `/vulyk-plan` step 9
  likewise); it commits story + `plan.md` + `brief.md` + journal and records that commit as the approved version; a
  hand commit approves nothing. `/vulyk-plan` `--go` comes only from the owner's own words, never added by the Queen.
  `owner-guard.sh` refuses `human-check.sh ACCEPTED|REJECTED`, `briefed --go` and new `**Approved:**`/`**Checked:**`
  lines unless the main session quotes the owner (`scripts-hooks.md`). The workers never commit.
- **0.52 (beta-fixes-1113):** `/vulyk-resume` switches a clean tree to the spec branch (`"switched"`, cycle-state.md);
  `/vulyk-build` handles the driver's `needs_context` return (the Queen reads the story's `## Findings`).
- **0.50 (ADR-032):** `/vulyk-build` at Tier 2-4 opens only on `**Approved:**` or a Briefed line with `--go`.
  Workers never run `stamp-red --baseline`.
- **0.49:** `/vulyk-plan` sends no scout for an area with a fresh map slice; grill asks in batches
  of <= 4, no confirm question; horizon in an existing repo only with `--horizon`; Tier 3-4 approval starts the build
  in the same turn; plan committed before the approval stop. `/vulyk-bootstrap` takes facts from the repo, asks only
  on conflict/gap, maps no area, docker rows `docker compose exec -u <user> <service> <cmd>`, no `/clear`.
  `/vulyk-models --recommend` always `sonnet-builds`. Driver launch passes `launched_at` (cycle-suite.md).

## Commands - what each runs
- **`/vulyk-plan`** - step 0 deliverable (document → brief + report, stop); tier; brief via `redact.sh`; recon
  (scouts: T1 0-1, T2 ≤1, T3 ≤2, T4 ≤4); grill T2-4; plan (Queen T1-2, `queen-planner` T3-4, `lead-architect` T4);
  stories; `wave-check.sh` + `trace-check.sh`; `drone-coverage` T3-4. T1 → `cycle.sh briefed --mode mini-brief` +
  `/vulyk-build`. T2-4 stop for `**Approved:**` (`--go` opts out). Step 2: a request carrying a stack trace runs
  `bash scripts/trace-autopsy.sh docs/specs/<slug>/brief.md`; `autopsy.md` is a lead, not a verdict. Step 3: a
  frame line in `autopsy.md` makes the location known, so T1-2 send no scout for it; T2-4 run `symbol-map.sh
  --exact <file>` once per file (many files in one call get cut at 1536 bytes). Step 6: critical stories get `red:
  required`. **Step 3a horizon** (ADR-022; `--horizon` forces, `--no-horizon` skips; skipped for study, T0-1,
  no-question): fires on zero grep hits of the capability's 2-4 terms in `memory/memory.md`, `memory/map/`,
  source; three parallel `drone-horizon` (no `model:`) given brief path, recon summary and the Profile rows
  *Configurations that exist today* + *Owner language*; Queen cuts to ≤ 3; a kept `kind: gap` needs a named ask or
  verbatim request fragment else `extension`; kept ones `H1`-`H3` in `docs/specs/<slug>/horizon.md`, never into
  `brief.md`. Grill (`templates/grill.md` `## Horizon questions`): one question each inside the 3-7 cap, ordered
  ordinary, `gap`, `extension`; «Добавить»/«Не добавлять»; silence = not added. `## Answers` entries open
  `(horizon H<n>)` and end `adopted`/`declined`/`offered, not adopted`.
- **Fable-limit fallback, session path** (ADR-015 exception): `/vulyk-build`, `/vulyk-review`, `/vulyk-plan`
  redispatch a refused dispatch once on `model: opus`, journal it and record `telemetry.sh fable_limit_fallback`.
- **`/vulyk-models`** - quiz via `model-profile.sh --recommend`/`--explain`, one `AskUserQuestion`, then `--set`.
  **Profile-aware dispatch** (ADR-020): `/vulyk-plan`, `/vulyk-build` and `/vulyk-review` pass `model:` only when
  the profile is not `sonnet-builds`.
- **`/vulyk-build`** - `**Tier:**` picks the path. Solo T1-2: loop `cycle.sh advance`; `build:W` → the Queen
  implements each story (a `red: required` story first gets test + `red_reason:` + `stamp-red` with no `--stamp`),
  `close-story --commit`; `dispatch:review` → one `lead-review`, then `advance --ingest`. Hive T3-4:
  `top-model.sh --floor` first (exit 1 stops); then `top-model.sh`, `second_model`, 16-hex stamp, journal line,
  Workflow tool with `scriptPath` (never `name:`); a thrown call records `telemetry.sh record driver_refused`. No
  Workflow: same loop with `--stamp --claim`, Agent tool, `release` on every exit. Terminal `green`:
  `AskUserQuestion` «Выпускаем?»; yes runs `vulyk-ship` via Skill. Before asking for the human check
  it runs `human-check.sh --show docs/specs/<slug>` and pastes it as a fenced block in the reply text (0.48).
- **`/vulyk-review`** - claim + `advance --claim`; dispatch the seats `next` names; `advance --ingest`; release.
  `build:W` = RED → repair story, `/vulyk-build`.

last-verified: 2026-11-14 (0.53.0-dev.1 audit-fixes-1113; split from agents-and-commands.md; ADR-015, 020, 022, 032)
