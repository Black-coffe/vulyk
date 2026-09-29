# Scout report: agents and commands (v0.24.0)

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
- **cycle-clerk** (`sonnet`, `low`, `maxTurns:5`; Bash only) - runs the one `cycle.sh` command given,
  returns its last stdout line verbatim. The Workflow driver's only shell.
- **worker-code** / **worker-test** (`sonnet` since ADR-015, `medium`, `maxTurns:90`) - Tier 3-4, one
  story. Close: `returned: DONE`, then `cycle.sh close-story <story> --commit --stamp <S>`; exit 4 →
  fix and rerun, after three failures `## Findings` + `returned: WALL`; other exits →
  `NEEDS_CONTEXT`. Never edit `status:`, never stash/checkout/reset/clean.
- **queen-planner** (`opus`, `high`, `maxTurns:40`; Read/Write/Grep/Glob) - Tier 3-4 plan + stories
  (`model: sonnet` each, `opus` only for judgment-heavy work: queen-planner.md:21, ADR-015). Never
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
- **`/vulyk-build`** - `**Tier:**` picks the path. Solo T1-2: loop `cycle.sh advance`; `build:W` → the
  Queen implements each story, `close-story --commit`; `dispatch:review` → one `lead-review`, then
  `advance --ingest`, one re-dispatch on rejection. Hive T3-4: `top-model.sh`, `second_model`, 16-hex
  stamp, journal line, Workflow tool with `scriptPath` (never `name:`); a thrown call records
  `telemetry.sh record driver_refused`; stop with `file` → story `blocked` + `lead-architect`. No
  Workflow: same loop with `--stamp --claim`, Agent tool, `release` on every exit. Terminal `green`:
  `AskUserQuestion` «Выпускаем?»; yes runs `vulyk-ship` via Skill, no / `claude -p` → one-line advice.
- **`/vulyk-review`** - claim + `advance --claim`; dispatch the seats `next` names; `advance --ingest`;
  release. `build:W` = RED, repair story → `/vulyk-build`. `green` asks the same question.
- **`/vulyk-ship`** - `ship-check.sh` (NOT READY refuses); release commit; local merge; prints the
  publish command, never runs it; `drone-docs`/`librarian` only with work; next-brief draft.
- **`/vulyk-status`** - driver line, unpushed merges, council stats, `token-report.py`, `state.sh`
  table, map freshness. Writes nothing but `.claude/state.json`.
- **`/vulyk-evolve`** - step 0 `evolve-ledger.py . resolve` + `window` (a rejected hypothesis is not
  re-proposed without newer evidence; a `pending` branch stops the run); step 1 learnings + skills +
  `token-report.py --since <7 days>` + corrections counter (0.24.0, vulyk-evolve.md:17-29: `bash
  .claude/hooks/defect-intake.sh --lexicon` to a temp file, litopys found via PATH then
  `~/.claude/plugins/cache/litopys/litopys/*/bin/litopys` newest first, first with the `corrections`
  verb wins; prints `corrections (7d): n by lexicon · m in records · u not in docs/defects`, or a
  "not installed" / "update to 0.4.0+" line; blocks nothing; "filed" = quote verbatim in `docs/defects/`);
  7-day council/human/anomaly check-in; telemetry consent/publish (prints, never sends); repo-only
  `telemetry.sh inbox`; step 4 admission rules (caps in `tests/maintenance.test.sh`); step 5 builds
  the changeset in worktree `.claude/worktrees/evolve-<date>` on `vulyk/evolve-<date>` (`inbox --clear`
  runs there), then `add`/`run` rows and a ledger-only commit (a `run` row even with 0 proposals).
  `--dry-run` writes no proposal/run row.
- **`/vulyk-gc`** - dispatches `librarian`; main session `git rm`s its `Delete:` list + stubs, prunes
  snapshots >14 days, runs one guarded line (vulyk-gc.md:20): refuses (`gc: refused - ...lost more
  than half`, no commit) when entries or bytes of `CONSOLIDATED.md` fell below half, else commits
  `chore(memory): gc`. A refusal means show the owner the diff.
- **`/vulyk-pause`** / **`/vulyk-resume`** - wrap `cycle.sh pause`/`resume`; resume relaunches fresh.
- **`/vulyk-update`** - `vulyk-update.sh . --check`, CHANGELOG summary, ask; `--constitution replace`
  is a separate choice. **`/vulyk-bootstrap`** - interview, Profile + Commands markers, scouts → map;
  the SessionStart brief offers it once while the Profile holds `<fill in`; a no is the Profile row
  `| Bootstrap | declined <date> |`.
- **`/vulyk-map`**, **`/vulyk-handoff`** (`handoff.py dump` + summary). gc/evolve/map are prompted by
  the SessionStart `maintenance due: ...` line (scripts.md).

last-verified: 2026-09-30 (v0.24.0, ADR-013, ADR-015)
