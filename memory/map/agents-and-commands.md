# Scout report: agents and commands (v0.44.0)

## Purpose
Every `.claude/agents/*.md` and `.claude/commands/vulyk-*.md` (ADR-013 light VULYK, ADR-015 Sonnet executes / Opus
judges). Retired: `council-sonnet.md`, `drone-acceptance.md` - do not dispatch them. Frontmatter is the
model/effort/turn cap; `vulyk-cycle.js` has no `CAPS` table (its empty-result message points at `maxTurns`).

## Agents - frontmatter, job, report
`omitClaudeMd: true` on cycle-clerk, council-opus, council-haiku, drone-scout, drone-coverage, drone-docs,
drone-horizon, librarian; the rest (`queen-planner`, `worker-code`, `worker-test`, `lead-review`,
`lead-architect`) keep the constitution (docs/architecture.md). `scripts/prompt-check.sh` enforces it
(rule `omit-claude-md`).
- **lead-review** (`opus`, `high`, `maxTurns:60`, `experimental: cacheTtl: 1h`; Read/Grep/Glob/Bash) - the
  `review` seat of every round; Tier 4: two dispatches. Judges five items: 1 `## Asks` (+ `## Descoped`);
  2 correctness; 3 warn-only checks + `defects-check.sh` red debt; 4 the project's rules (a diff line breaking a
  card's Never/How-to line = major `[unanchored]` naming the card ref; Allowed is no finding); 5 for each
  `red: required` story, its `## Red receipt` tail and `red_reason` (a staged break = major `[ask N]`; no receipt
  is never asked). Reads: round 1 `merge-base..head`; round 2+ `since..head` + previous `review.md`; ONE
  `git diff <range> -- <every path>` so the card hook delivers `docs/defects/` cards. BLOCK needs an anchored
  Critical/Major: `[ask N]` or `[regression]` (base-side evidence); else `[unanchored]`.
  **Suite step (ADR-023, ADR-024):** line 1 `VERDICT: PASS|BLOCK`; line 3 `SUITE: ok|FAIL|TIMEOUT <N>s budget
  <B>s|none`. Runs the `Full suite / build` row once per round, in the foreground (ADR-024: no reliance on
  background commands in subagents), as `run_capped $((VULYK_SUITE_TIMEOUT:-590)+5) <row>` (sourced from `scripts/lib.sh`; portable
  where `timeout` is absent) with Bash `timeout: 600000`; FAIL = BLOCK with a `[regression]` Critical; TIMEOUT leaves the verdict, `judge` escalates. ≤ 5 minors.
- **council-opus** (`opus`, `medium`, `maxTurns:60`; no Write/Edit) - Tier 3-4 blind seat inside `COURT`; one
  `ASK <n>` per ask, edge cases under `UNASKED:`; reading outside `COURT` or naming plan/story files is a BREACH.
  **council-haiku** (`opus` since ADR-015; Bash/Read + browser MCPs) - black-box seat on the Profile's *Client path*.
- **cycle-clerk** (`haiku`, `low`, `maxTurns:5`; Bash only) - runs the one `cycle.sh` command given, returns its
  last stdout line. The Workflow driver's only shell. `haiku` is at the floor only on Claude Code >= 2.1.293.
- **worker-code** / **worker-test** (`sonnet`, `medium`, `maxTurns:90`) - Tier 3-4, one story. Close: `returned:
  DONE`, then `cycle.sh close-story <story> --commit --stamp <S>`; exit 4 → fix and rerun (`edited outside ##
  Files` = undo your own edits; none yours → `NEEDS_CONTEXT`; exit 2 `verification is round-only` →
  `NEEDS_CONTEXT`), after three failures `## Findings` + `returned: WALL`. **Red first (ADR-025), only for `red:
  required`:** write the test `## Files` names, write `red_reason:`, run `cycle.sh stamp-red <story> --stamp <S>`,
  then implement, then `close-story`; never edit the implementation to produce a red. Step 6 maps each gate exit-4
  message to an action. Never edit `status:`, never stash/checkout/reset/clean. A bug fix first runs `symbol-map.sh
  <file> --story <story>` on a root file; a fix needing a file outside `## Files` = `NEEDS_CONTEXT`.
- **queen-planner** (`opus`, `high`, `maxTurns:40`; Read/Write/Grep/Glob) - Tier 3-4 plan + stories (`model:` per
  story, ADR-015/020; `## Verification` cites only `## Commands` rows without `round-only`). Never reads source;
  never plans repairs. Marks `red: required` (frontmatter, planner only) a story adding a branch, loop, parser, or
  money/security/data-write handling; its test is in its own `## Files` and `## Verification`, no later-wave
  `worker-test` story for it. `## Files` lists every reached path; the brief's `symbol-map --exact` output is a
  source (`exact` lines in when reached; `textual <N> not shown` is a recon question for `drone-scout`).
- **lead-architect** (`opus`, `high`, `maxTurns:30`) - T4 planning and after a story's second miss; every decision
  an ADR. Dispatched with `model: <top_model>`.
- **drone-scout** (`sonnet`, `low`, `maxTurns:15`) - recon; `# Scout report:` format. **drone-coverage** (`opus`,
  `medium`, `maxTurns:5`) - T3-4, reads only brief.md + plan.md. **drone-docs** (`sonnet`, `low`, `maxTurns:40`) -
  map + wiki after a merge. **librarian** (`opus`, `low`, `maxTurns:25`; no shell) - sole consolidator of
  `memory/learnings/`; lists `Delete:` files.
- **drone-horizon** (ADR-022; `sonnet`, `medium`, `maxTurns:20`; Read/Grep/Glob/WebSearch/WebFetch only) - one
  `lens:` per dispatch (altitude|depth|range); the two Profile rows come from the dispatch. ≤ 3 proposals
  (`what/why/cost/check/sources/status/kind/ask line`), `DROPPED:`; writes nothing. Two dated sources else
  `не подтверждено`; WebFetch ≤ 2; reply ≤ 60 lines.

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
  `AskUserQuestion` «Выпускаем?»; yes runs `vulyk-ship` via Skill.
- **`/vulyk-review`** - claim + `advance --claim`; dispatch the seats `next` names; `advance --ingest`; release.
  `build:W` = RED → repair story, `/vulyk-build`.
- **`/vulyk-ship`** - `ship-check.sh` (NOT READY refuses). Stage 03 runs `git merge-tree --write-tree` (0 clean, 1
  conflict never overridden, other = "cannot check"). Release commit; local `merge --no-ff` only on a clean default
  tree, failure → `merge --abort`; `branch -d` (never `-D`). Prints the publish command, never runs it (push, green
  CI, then tag); `drone-docs`/`librarian` only with work; next-brief draft.
- **Portable spelling (0.44.0):** command and agent shell blocks call Python as `bash scripts/py.sh ...` and
  date windows as `date -u -d '-N days' ... || date -u -v-Nd ...`; `portability-check.sh` reads their shell
  fences and multi-word inline spans (card `shell-needs-gnu-or-bash4`).
- **`/vulyk-status`** - driver line, council stats, `token-report.py`, `state.sh` table, map freshness,
  `maintenance due|waits for`. Writes only `.claude/state.json`.
- **`/vulyk-evolve`** - `evolve-ledger.py . resolve` + `window`; changeset in worktree on `vulyk/evolve-<date>`;
  step 2: once ≥ 3 `horizon.md` exist, counts `(horizon H` picks against ADR-022's reversal rule.
- **`/vulyk-gc`** - dispatches `librarian`; main session `git rm`s its `Delete:` list. `/vulyk-gc memory`: main
  session alone, one `AskUserQuestion`; step 10 runs `memory-triage.sh --mark`.
- **`/vulyk-update`** step 6 renames the hive's full-suite row to `Full suite / build (round-only)` (ADR-023).
  `/vulyk-pause`/`-resume` wrap `cycle.sh pause`/`resume`; `/vulyk-bootstrap` a no is `| Bootstrap | declined <date> |`.
- **`/vulyk-map`**, **`/vulyk-handoff`**: `!` injections go through `${CLAUDE_PROJECT_DIR}`, never a relative
  script path (`injection-check.sh`); `handoff.sh dump "${CLAUDE_SESSION_ID}"`.

last-verified: 2026-10-29 (cross-platform, 0.44.0; trimmed to the cap, line numbers dropped; ADR-013, 015, 020, 022, 023, 024, 025)
