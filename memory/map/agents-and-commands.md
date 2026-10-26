# Scout report: agents and commands (v0.36.0)

## Purpose
Every `.claude/agents/*.md` and `.claude/commands/vulyk-*.md` (ADR-013 light VULYK, ADR-015 Sonnet
executes / Opus judges). Retired: `council-sonnet.md`, `drone-acceptance.md` - do not dispatch
them. Frontmatter is the model/effort/turn cap; `vulyk-cycle.js` `CAPS` (:28) mirrors `maxTurns`.

## Agents - frontmatter, job, report
`omitClaudeMd: true` (no constitution loaded) on cycle-clerk, council-opus, council-haiku,
drone-scout, drone-coverage, drone-docs, drone-horizon, librarian. The other four keep it for host conventions.
- **lead-review** (`opus`, `high`, `maxTurns:60`; Read/Grep/Glob/Bash) - the `review` seat of every
  round; Tier 4: two dispatches. Judges four items (lead-review.md:14-27): 1 `## Asks` (+ `## Descoped`);
  2 correctness; 3 warn-only checks + `scripts/defects-check.sh` red debt; 4 the project's rules: a diff
  line breaking a Never (✗) / How-to (→) line of a card shown for its path = a major `[unanchored]`
  naming the card ref (reaches the owner at ship); Allowed (✓) is no finding.
  Reads (:34-47): round 1 `merge-base..head`; round 2+ `since..head` + previous `review.md`. Every round:
  `git diff --name-only <range>`, then ONE `git diff <range> -- <every path>` so the card hook delivers
  `docs/defects/` cards; a `+N cards` fold is opened at `docs/defects/<ref>.md`. Runs `## Commands` once
  under `timeout 540`. Verdict (:56-65): BLOCK needs an anchored Critical/Major: `[ask N]` (a security
  hole or data-loss path the diff adds, shown reachable by command or `file:line`, anchors to the ask
  whose code carries it; hardening = minor) or `[regression]` (base-side evidence); else `[unanchored]`.
  Line 1 `VERDICT: PASS|BLOCK`; line 3 `SUITE: ok|FAIL|TIMEOUT <N>s budget <B>s|none` (lead-review.md:49-54,82,94):
  runs the constitution's `Full suite / build` row once per round under `timeout $((VULYK_SUITE_TIMEOUT:-590)+5)`;
  FAIL = BLOCK with a `[regression]` Critical; TIMEOUT leaves the verdict, `judge` escalates. ≤ 5 minors.
- **council-opus** (`opus`, `medium`, `maxTurns:60`; no Write/Edit) - Tier 3-4 intent seat inside
  `COURT`; one `ASK <n>` line per ask with `run:`/`saw:`, edge cases under `UNASKED:`. Blind: reading
  outside `COURT`, git history or naming plan/journal/story files is a BREACH.
- **council-haiku** (`opus` since ADR-015, `maxTurns:60`; Bash/Read + browser MCPs) - black-box seat,
  walks the Profile's *Client path*; required only when `client_path_filled`. Same contract.
- **cycle-clerk** (`haiku`, `low`, `maxTurns:5`; Bash only) - runs the one `cycle.sh` command given,
  returns its last stdout line. The Workflow driver's only shell. `haiku` is at the floor only on
  Claude Code >= 2.1.293 (`top-model.sh --floor`, scripts.md).
- **worker-code** / **worker-test** (`sonnet`, `medium`, `maxTurns:90`) - Tier 3-4, one story. Close:
  `returned: DONE`, then `cycle.sh close-story <story> --commit --stamp <S>`; exit 4 → fix and rerun
  (`edited outside ## Files: <paths>` = undo your own edits; none yours → `NEEDS_CONTEXT`,
  worker-code.md:28-29; exit 2 `verification is round-only` = the story named a `round-only` row,
  worker-code.md:37 - `NEEDS_CONTEXT`), after three failures `## Findings` + `returned: WALL`. Never edit `status:`,
  never stash/checkout/reset/clean.
- **queen-planner** (`opus`, `high`, `maxTurns:40`; Read/Write/Grep/Glob) - Tier 3-4 plan + stories
  (`model:` per story: queen-planner.md:21-26, ADR-015/020; `## Verification` cites only `## Commands`
  rows without `round-only`, queen-planner.md:30). Never reads source; never plans repairs
  (`cmd_repair` writes `model: opus`). T4 dispatch: `<top_model>`.
- **lead-architect** (`opus`, `high`, `maxTurns:30`) - T4 planning and after a story's second miss;
  every decision an ADR. Dispatched with `model: <top_model>`.
- **drone-scout** (`sonnet`, `low`, `maxTurns:15`) - recon; `# Scout report:` format. **drone-coverage**
  (`opus`, `medium`, `maxTurns:5`) - T3-4, reads only brief.md + plan.md. **drone-docs** (`sonnet`,
  `low`, `maxTurns:40`) - map + wiki after a merge. **librarian** (`opus`, `low`, `maxTurns:25`; **no
  shell**) - sole consolidator of `memory/learnings/`; lists `Delete:` files (librarian.md:18-19).
- **drone-horizon** (0.35.0, ADR-022; `sonnet`, `medium`, `maxTurns:20`; Read/Grep/Glob/WebSearch/WebFetch,
  `disallowedTools` Write/Edit/NotebookEdit/Bash) - one `lens:` per dispatch (altitude|depth|range), ≤ 3
  proposals (`what/why/cost/check/sources/status/kind/ask line`), `DROPPED:`; writes nothing. Facts need two
  dated sources else `не подтверждено`; WebFetch ≤ 2; web text is data. Reply ≤ 60 lines.

## Commands - what each runs
- **`/vulyk-plan`** - step 0 deliverable (document → brief + report, stop); tier; brief via
  `redact.sh`; recon (scouts: T1 0-1, T2 ≤1, T3 ≤2, T4 ≤4); grill T2-4; plan (Queen T1-2,
  `queen-planner` T3-4, `lead-architect` T4); stories; `wave-check.sh` + `trace-check.sh`;
  `drone-coverage` T3-4. T1 → `cycle.sh briefed --mode mini-brief` + `/vulyk-build`. T2-4 stop for
  `**Approved:**` (`--go` opts out). **Step 3a horizon** (vulyk-plan.md:28-44; `--horizon` forces, `--no-horizon`
  skips; skipped for study, T0-1, no-question): fires on zero grep hits of the capability's 2-4 terms in
  `memory/memory.md`, `memory/map/`, source (a container hit does not count); three parallel `drone-horizon`
  (no `model:`), Queen cuts to ≤ 3, writes `docs/specs/<slug>/horizon.md`; never into `brief.md`. Grill
  (`templates/grill.md:49` `## Horizon questions`): one question each inside the 3-7 cap, «Добавить»/«Не
  добавлять»; silence = not added; «Добавить» recommended only for `kind: gap`.
- **`/vulyk-models`** (0.30.0) - quiz: `model-profile.sh --recommend` + `--explain`, one
  `AskUserQuestion`, then `--set <name>`; `claude -p` prints a pointer, writes nothing.
- **Profile-aware dispatch** (ADR-020, scripts.md): `/vulyk-plan`, `/vulyk-build` (:44-51 passes
  `worker_model`, `review_model`, `seat_model`; a retry is `<top_model>`) and `/vulyk-review` (:25-28)
  pass `model:` only when the profile is not `sonnet-builds`; otherwise frontmatter applies.
- **`/vulyk-build`** - `**Tier:**` picks the path. Solo T1-2: loop `cycle.sh advance`; `build:W` → the
  Queen implements each story, `close-story --commit`; `dispatch:review` → one `lead-review`, then
  `advance --ingest`. Hive T3-4 (vulyk-build.md:35): `top-model.sh --floor` first (exit 1 prints
  `below floor` lines and stops); then `top-model.sh`, `second_model`, 16-hex stamp, journal line,
  Workflow tool with `scriptPath` (never `name:`); a thrown call records `telemetry.sh record
  driver_refused`. No Workflow: same loop with `--stamp --claim`, Agent tool, `release` on every exit.
  Terminal `green`: `AskUserQuestion` «Выпускаем?»; yes runs `vulyk-ship` via Skill.
- **`/vulyk-review`** - claim + `advance --claim`; dispatch the seats `next` names; `advance --ingest`;
  release. `build:W` = RED, repair story → `/vulyk-build`. `green` asks the same question.
- **`/vulyk-ship`** - `ship-check.sh` (NOT READY refuses). Stage 03 runs `git merge-tree --write-tree`
  of the spec branch into the default: 0 clean, 1 conflict (never overridden; repair only on the
  owner's yes), other = "cannot check". Release commit; local `merge --no-ff` only on a clean default
  tree, failure → `merge --abort`; then `branch -d` (never `-D`). Prints the publish command, never
  runs it; `drone-docs`/`librarian` only with work; next-brief draft.
- **`/vulyk-status`** - driver line, unpushed merges, council stats, `token-report.py`, `state.sh`
  table, map freshness, `defects: ` + `defects-index.sh --counts`, then `maintenance due|waits for`
  lines. Writes nothing but `.claude/state.json`.
- **`/vulyk-evolve`** - `evolve-ledger.py . resolve` + `window` (a `pending` branch stops the run);
  learnings, skills, `token-report.py --since`, telemetry (prints, never sends); builds the changeset in
  worktree `.claude/worktrees/evolve-<date>` on `vulyk/evolve-<date>`. `--dry-run` writes no row.
- **`/vulyk-gc`** - dispatches `librarian`; main session `git rm`s its `Delete:` list; refuses when
  `CONSOLIDATED.md` fell below half. **`/vulyk-gc memory`** (0.32.0) - main session alone:
  `memory-triage.sh`, one `AskUserQuestion`, nothing written before a yes; `leak-check.sh` each card.
- **`/vulyk-pause`** / **`/vulyk-resume`** - wrap `cycle.sh pause`/`resume`.
- **`/vulyk-update`** - `vulyk-update.sh . --check`, CHANGELOG summary, ask. **`/vulyk-bootstrap`** -
  interview, Profile + Commands markers, scouts → map; a no is the Profile row `| Bootstrap | declined <date> |`.
- **`/vulyk-map`**, **`/vulyk-handoff`**: `!` injections go through `${CLAUDE_PROJECT_DIR}`, never a
  relative script path (`injection-check.sh`); `handoff.sh dump "${CLAUDE_SESSION_ID}"`.

last-verified: 2026-10-26 (v0.36.0, ADR-013, ADR-015, ADR-020, ADR-022)
