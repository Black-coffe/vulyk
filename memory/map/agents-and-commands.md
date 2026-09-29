# Scout report: agents and commands (v0.22.0)

## Purpose
Every `.claude/agents/*.md` and `.claude/commands/vulyk-*.md` (ADR-013 light VULYK, ADR-015 Sonnet
executes / Opus judges). Retired: `council-sonnet.md`, `drone-acceptance.md` - do not dispatch
them. Frontmatter is the model/effort/turn cap; `vulyk-cycle.js` `CAPS` (:28) mirrors `maxTurns`.

## Agents - frontmatter, job, report
`omitClaudeMd: true` (no constitution loaded) on cycle-clerk, council-opus, council-haiku,
drone-scout, drone-coverage, drone-docs, librarian. The other four keep it for host conventions.
- **lead-review** (`opus`, `high`, `maxTurns:60`; Read/Grep/Glob/Bash) - the `review` seat of every
  round; judges `## Asks` (+ `## Descoped`) and correctness. Round 1 `merge-base..head`; round 2+
  `since..head` + previous files. Runs the `## Commands` suite once under `timeout 540`. Report line 1
  `VERDICT: PASS|BLOCK`, then `## Critical`/`## Major`/`## Minor`; BLOCK needs an anchored line
  (`[ask N]`/`[regression]`), else `[unanchored]`; ≤ 5 minors. Tier 4: two dispatches.
- **council-opus** (`opus`, `medium`, `maxTurns:60`; Bash/Read/Grep/Glob, no Write/Edit) - Tier 3-4
  intent seat inside `COURT`; one `ASK <n>` line per ask with `run:`/`saw:` evidence, edge cases under
  `UNASKED:`. Blind: reading outside `COURT`, git history or naming plan/journal/council/story files
  is a BREACH / taint.
- **council-haiku** (`opus` since ADR-015, no `effort:`, `maxTurns:60`; Bash/Read + browser MCPs) - black-box
  seat, walks the Profile's *Client path*; required only when `client_path_filled`. Same contract.
- **cycle-clerk** (`sonnet`, `low`, `maxTurns:5`; Bash only) - runs the one `cycle.sh` command given
  (`timeout: 600000`), returns its last stdout line verbatim. The Workflow driver's only shell.
- **worker-code** / **worker-test** (`sonnet` since ADR-015, `medium`, `maxTurns:90`) - Tier 3-4, one story. Targeted
  checks while working. Close: `returned: DONE`, then `cycle.sh close-story <story> --commit --stamp
  <S>`; exit 4 → fix and rerun, after three failures `## Findings` + `returned: WALL`; other exits →
  `NEEDS_CONTEXT`. Never edit `status:`, never stash/checkout/reset/clean. Final message ≤ 25 lines.
- **queen-planner** (`opus`, `high`, `maxTurns:40`; Read/Write/Grep/Glob) - Tier 3-4 plan + stories
  (`model: sonnet` each, `opus` only for long-horizon/judgment-heavy work: queen-planner.md:21, ADR-015;
  verbatim `## Requirements`). Never reads source; never plans repairs (`cmd_repair` writes `model: opus`).
  Tier 4 dispatch carries `model: <top_model>`.
- **lead-architect** (`opus`, `high`, `maxTurns:30`) - consulted at Tier 4 planning and after a
  story's second miss; every decision an ADR. Dispatched with `model: <top_model>`.
- **drone-scout** (`sonnet`, `low`, `maxTurns:15`; Read/Grep/Glob) - recon; `# Scout report:` format
  every map slice follows. **drone-coverage** (`opus`, `medium`, `maxTurns:5`; Read) - Tier 3-4,
  reads only brief.md + plan.md, reports absent/partial asks by number. **drone-docs** (`sonnet`,
  `low`, `maxTurns:40`) - map + wiki from the tree after a merge. **librarian** (`opus`, `low`,
  `maxTurns:25`; Read/Write/Edit/Glob, **no shell**) - the only writer that consolidates
  `memory/learnings/` (40-entry `CONSOLIDATED.md`); it lists `Delete:` files and the main session
  deletes them (librarian.md:18-19); ADR harvest at `/vulyk-ship`.

## Commands - what each runs
- **`/vulyk-plan`** - step 0 deliverable (document → brief + report, stop); tier; brief via
  `redact.sh`; recon (scouts: T1 0-1, T2 ≤1, T3 ≤2, T4 ≤4); grill T2-4; plan (Queen at T1-2,
  `queen-planner` at T3-4, `lead-architect` at T4); stories; `wave-check.sh` + `trace-check.sh`;
  `drone-coverage` T3-4. T1 → `cycle.sh briefed --mode mini-brief` + `/vulyk-build`. T2-4 stop for
  `**Approved:**` (`--go` opts out). T2 builds in a fresh session; T3-4 launch at once.
- **`/vulyk-build`** (6.1 KB) - `**Tier:**` picks the path. Solo T1-2: loop `cycle.sh advance`;
  `build:W` → the Queen implements each story and runs `close-story --commit`; `dispatch:review` →
  one `lead-review` (report path, `since` from round 2), then `advance --ingest`, one re-dispatch on
  rejection. Hive T3-4: `top-model.sh`, `second_model`, 16-hex stamp, journal line, Workflow tool
  with `scriptPath` (never `name:`); a thrown call records `telemetry.sh record driver_refused`. On
  return: stop with `file` → story `blocked` + `lead-architect`. Without Workflow: the same advance
  loop with `--stamp --claim`, agents via the Agent tool, `release` on every exit.
  Terminal `green` (0.22): `AskUserQuestion` «<slug>: council GREEN, round <n>. Выпускаем?»; yes runs
  `vulyk-ship` via the Skill tool, no / no `AskUserQuestion` (`claude -p`) → one-line `/vulyk-ship` advice.
- **`/vulyk-review`** - claim + `advance --claim`; dispatch the seats `next` names; `advance
  --ingest`; release. `build:W` = RED, repair story written → `/vulyk-build`. Step 4 `green` asks the
  same «Выпускаем?» question.
- **`/vulyk-ship`** - `ship-check.sh` (NOT READY refuses); release commit; local merge; prints the
  publish command, never runs it; `--record`; `drone-docs`/`librarian` only when they have work;
  next-brief draft (UNASKED, minors, `[unanchored]`, `## Descoped`, `## Needs a human`).
- **`/vulyk-status`** - driver line, unpushed merges, council stats, `token-report.py --since <14
  days>`, `state.sh` table, map freshness, learnings count. Writes nothing but `.claude/state.json`.
- **`/vulyk-evolve`** - step 0 `evolve-ledger.py . resolve` + `window` (a rejected hypothesis is not
  re-proposed without newer evidence; a `pending` branch stops the run); learnings + skills +
  `token-report.py --since <7 days>`; 7-day council/human/anomaly check-in; telemetry consent/publish
  (prints, never sends); repo-only `telemetry.sh inbox`; step 4 admission rules (always-loaded text
  grows only against owner-signed evidence; caps in `tests/maintenance.test.sh`); step 5 builds the
  changeset in worktree `.claude/worktrees/evolve-<date>` on `vulyk/evolve-<date>` (`inbox --clear`
  runs there, `VULYK_HIVE=`), then `add`/`run` rows and a ledger-only commit on the default branch
  (a `run` row even with 0 proposals). `--dry-run` writes no proposal/run row.
- **`/vulyk-gc`** - dispatches `librarian`, then the main session `git rm`s its `Delete:` list + stubs,
  prunes snapshots >14 days, commits `chore(memory): gc` (pathspec `memory/learnings memory/memory.md`).
- **`/vulyk-pause`** / **`/vulyk-resume`** - wrap `cycle.sh pause`/`resume`; resume relaunches
  `/vulyk-build` fresh (hive path records `driver_relaunched`), never `resumeFromRunId`.
- **`/vulyk-update`** - `vulyk-update.sh . --check`, CHANGELOG summary, ask; `--constitution replace`
  is a separate choice. **`/vulyk-bootstrap`** - interview, Profile + Commands markers, scouts → map;
  the SessionStart brief offers it once while the Profile holds `<fill in`; a no is the Profile row
  `| Bootstrap | declined <date> |`.
- **`/vulyk-map`**, **`/vulyk-handoff`** (`handoff.py dump` + summary).
- gc, evolve, map run themselves: `session-start-brief.sh` prints `maintenance due: ...` (see scripts.md).

last-verified: 2026-09-29 (v0.22.0, ADR-013, ADR-015)
