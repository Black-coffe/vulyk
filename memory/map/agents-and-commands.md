# Scout report: agents and commands (v0.26.0)

## Purpose
Every `.claude/agents/*.md` and `.claude/commands/vulyk-*.md` (ADR-013 light VULYK, ADR-015 Sonnet
executes / Opus judges). Retired: `council-sonnet.md`, `drone-acceptance.md` - do not dispatch
them. Frontmatter is the model/effort/turn cap; `vulyk-cycle.js` `CAPS` (:28) mirrors `maxTurns`.

## Agents - frontmatter, job, report
`omitClaudeMd: true` (no constitution loaded) on cycle-clerk, council-opus, council-haiku,
drone-scout, drone-coverage, drone-docs, librarian. The other four keep it for host conventions.
- **lead-review** (`opus`, `high`, `maxTurns:60`; Read/Grep/Glob/Bash) - the `review` seat of every
  round; judges `## Asks` (+ `## Descoped`). Round 1 `merge-base..head`; round 2+ `since..head`. Runs
  `## Commands` once under `timeout 540`. Line 1 `VERDICT: PASS|BLOCK`; BLOCK needs an anchored line
  (`[ask N]`/`[regression]`), else `[unanchored]`; ≤ 5 minors. Tier 4: two dispatches.
- **council-opus** (`opus`, `medium`, `maxTurns:60`; no Write/Edit) - Tier 3-4 intent seat inside
  `COURT`; one `ASK <n>` line per ask with `run:`/`saw:`, edge cases under `UNASKED:`. Blind: reading
  outside `COURT`, git history or naming plan/journal/story files is a BREACH.
- **council-haiku** (`opus` since ADR-015, `maxTurns:60`; Bash/Read + browser MCPs) - black-box seat,
  walks the Profile's *Client path*; required only when `client_path_filled`. Same contract.
- **cycle-clerk** (`haiku` since 0.26.0, `low`, `maxTurns:5`; Bash only) - runs the one `cycle.sh`
  command given, returns its last stdout line verbatim. The Workflow driver's only shell. `haiku` is
  at the floor only on Claude Code >= 2.1.293 (`top-model.sh --floor`, scripts.md).
- **worker-code** / **worker-test** (`sonnet` since ADR-015, `medium`, `maxTurns:90`) - Tier 3-4, one
  story. Close: `returned: DONE`, then `cycle.sh close-story <story> --commit --stamp <S>`; exit 4 →
  fix and rerun (`edited outside ## Files: <paths>` = undo your own edits to those paths; none yours →
  `NEEDS_CONTEXT` naming them, worker-code.md:28-29), after three failures `## Findings` + `returned: WALL`; other exits →
  `NEEDS_CONTEXT`. Never edit `status:`, never stash/checkout/reset/clean.
- **queen-planner** (`opus`, `high`, `maxTurns:40`; Read/Write/Grep/Glob) - Tier 3-4 plan + stories
  (no `model:` line by default; `opus` for judgment-heavy work; `haiku` for routine stories only when the
  brief says `routine stories: model: haiku`: queen-planner.md:21-26, ADR-015/020). Never
  reads source; never plans repairs (`cmd_repair` writes `model: opus`). T4 dispatch: `<top_model>`.
- **lead-architect** (`opus`, `high`, `maxTurns:30`) - T4 planning and after a story's second miss;
  every decision an ADR. Dispatched with `model: <top_model>`.
- **drone-scout** (`sonnet`, `low`, `maxTurns:15`) - recon; `# Scout report:` format. **drone-coverage**
  (`opus`, `medium`, `maxTurns:5`) - T3-4, reads only brief.md + plan.md, reports absent/partial asks.
  **drone-docs** (`sonnet`, `low`, `maxTurns:40`) - map + wiki after a merge. **librarian** (`opus`,
  `low`, `maxTurns:25`; **no shell**) - sole consolidator of `memory/learnings/` (40-entry
  `CONSOLIDATED.md`); lists `Delete:` files, main session deletes (librarian.md:18-19).

## Commands - what each runs
- **`/vulyk-plan`** - step 0 deliverable (document → brief + report, stop); tier; brief via
  `redact.sh`; recon (scouts: T1 0-1, T2 ≤1, T3 ≤2, T4 ≤4); grill T2-4; plan (Queen at T1-2,
  `queen-planner` at T3-4, `lead-architect` at T4); stories; `wave-check.sh` + `trace-check.sh`;
  `drone-coverage` T3-4. T1 → `cycle.sh briefed --mode mini-brief` + `/vulyk-build`. T2-4 stop for
  `**Approved:**` (`--go` opts out).
- **`/vulyk-models`** (0.30.0) - the quiz: `model-profile.sh --recommend` + `--explain`, one
  `AskUserQuestion` (recommended profile first), then `--set <name>`; `claude -p` prints a one-line
  pointer and writes nothing. Offered once by the SessionStart brief while no profile is chosen.
- **Profile-aware dispatch** (ADR-020, scripts.md): `/vulyk-plan` (planner model at Tier 3; `--role routine`
  = `haiku` puts `routine stories: model: haiku` in the brief), `/vulyk-build` (:44-51 passes `worker_model`,
  `review_model`, `seat_model` to the Workflow; solo `lead-review` and seats via `--role review|seat`;
  a retry is `<top_model>`, `opus` when that is also the reviewer) and `/vulyk-review` (:25-28) pass `model:`
  only when the profile is not `sonnet-builds`; otherwise no model parameter and frontmatter applies.
- **`/vulyk-build`** - `**Tier:**` picks the path. Solo T1-2: loop `cycle.sh advance`; `build:W` → the
  Queen implements each story, `close-story --commit`; `dispatch:review` → one `lead-review`, then
  `advance --ingest`, one re-dispatch on rejection. Hive T3-4 (vulyk-build.md:35): step 1 runs `bash scripts/top-model.sh --floor`
  first, exit 1 prints its `below floor` lines and stops (no journal line, no launch); then `top-model.sh`,
  `second_model`, 16-hex stamp, journal line, Workflow tool with `scriptPath` (never `name:`); a thrown call records
  `telemetry.sh record driver_refused`; stop with `file` → story `blocked` + `lead-architect`. No
  Workflow: same loop with `--stamp --claim`, Agent tool, `release` on every exit. Terminal `green`:
  `AskUserQuestion` «Выпускаем?»; yes runs `vulyk-ship` via Skill, no / `claude -p` → one-line advice.
- **`/vulyk-review`** - claim + `advance --claim`; dispatch the seats `next` names; `advance --ingest`;
  release. `build:W` = RED, repair story → `/vulyk-build`. `green` asks the same question.
- **`/vulyk-ship`** - `ship-check.sh` (NOT READY refuses). Stage 03 fails on a third branch and runs
  `git merge-tree --write-tree` of the spec branch into the default: 0 clean, 1 conflict naming files +
  repair, other = "cannot check". A conflict is never overridden; the repair (merge default into the spec
  branch, new council round) only on the owner's yes. Release commit; local `merge --no-ff` only on a clean
  default tree, failure → `merge --abort`, stop; then `branch -d` (never `-D`). Prints the publish command,
  never runs it; `drone-docs`/`librarian` only with work; next-brief draft.
- **`/vulyk-status`** - driver line, unpushed merges, council stats, `token-report.py`, `state.sh`
  table, map freshness, step 3 `defects: ` + `defects-index.sh --counts` (or `defects: no library`), then
  the brief's `maintenance due|waits for` lines (else `maintenance: nothing due`). Writes nothing but
  `.claude/state.json`.
- **`/vulyk-evolve`** - step 0 `evolve-ledger.py . resolve` + `window` (a rejected hypothesis is not
  re-proposed without newer evidence; a `pending` branch stops the run); step 1 learnings + skills +
  `token-report.py --since <7 days>` + corrections counter (`defect-intake.sh --lexicon` to a temp file
  fed to litopys `corrections`; prints `corrections (7d): n by lexicon · m in records · u not in
  docs/defects`, or a "not installed" / "update to 0.4.0+" line; blocks nothing);
  7-day council/human/anomaly check-in; telemetry consent/publish (prints, never sends); repo-only
  `telemetry.sh inbox`; step 4 admission rules (caps in `tests/maintenance.test.sh`); step 5 builds
  the changeset in worktree `.claude/worktrees/evolve-<date>` on `vulyk/evolve-<date>` (`inbox --clear`
  runs there), then `add`/`run` rows and a ledger-only commit (a `run` row even with 0 proposals).
  `--dry-run` writes no proposal/run row.
- **`/vulyk-gc`** - dispatches `librarian`; main session `git rm`s its `Delete:` list + stubs, prunes
  snapshots >14 days, one guarded line: refuses (`gc: refused - ...lost more than half`, no commit) when
  `CONSOLIDATED.md` fell below half, else commits `chore(memory): gc`. **`/vulyk-gc memory`** (0.32.0) - the
  main session alone, never a subagent: `memory-triage.sh` lists private memory, one table into card /
  personal / delete, one `AskUserQuestion`, nothing written before a yes; cards are retold (a `## Source`
  line, no `## Owner quotes`), `leak-check.sh` each, moved files and their `MEMORY.md` lines deleted,
  `defects-index.sh`, commit `chore(defects): memory triage`.
- **`/vulyk-pause`** / **`/vulyk-resume`** - wrap `cycle.sh pause`/`resume`.
- **`/vulyk-update`** - `vulyk-update.sh . --check`, CHANGELOG summary, ask; `--constitution replace`
  is a separate choice. **`/vulyk-bootstrap`** - interview, Profile + Commands markers, scouts → map;
  the SessionStart brief offers it once while the Profile holds `<fill in`; a no is the Profile row
  `| Bootstrap | declined <date> |`.
- **`/vulyk-map`**, **`/vulyk-handoff`**: `!` injections go through `${CLAUDE_PROJECT_DIR}`, never a relative
  script path (`injection-check.sh`, scripts.md); `handoff.sh dump "${CLAUDE_SESSION_ID}"` reads exactly that
  session's transcript. gc/evolve/map are prompted by the SessionStart `maintenance due: ...` line.

last-verified: 2026-10-19 (v0.32.0, ADR-013, ADR-015, ADR-020)
