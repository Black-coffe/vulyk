# Scout report: agents and commands (v0.40.0)

## Purpose
Every `.claude/agents/*.md` and `.claude/commands/vulyk-*.md` (ADR-013 light VULYK, ADR-015 Sonnet
executes / Opus judges). Retired: `council-sonnet.md`, `drone-acceptance.md` - do not dispatch
them. Frontmatter is the model/effort/turn cap; `vulyk-cycle.js` has no `CAPS` table, its empty-result
message points at the agent file's `maxTurns` (`reasonFor` :33).

## Agents - frontmatter, job, report
`omitClaudeMd: true` (no constitution loaded) on cycle-clerk, council-opus, council-haiku,
drone-scout, drone-coverage, drone-docs, drone-horizon, librarian. The rest (`queen-planner`, `worker-code`,
`worker-test`, `lead-review`, `lead-architect`; docs/architecture.md:21) keep it for host conventions.
`scripts/prompt-check.sh` enforces this against that sentence (rule `omit-claude-md`).
- **lead-review** (`opus`, `high`, `maxTurns:60`, `experimental: cacheTtl: 1h` frontmatter,
  lead-review.md:8-9; Read/Grep/Glob/Bash) - the `review` seat of every
  round; Tier 4: two dispatches. Judges five items (lead-review.md:16-33): 1 `## Asks` (+ `## Descoped`);
  2 correctness; 3 warn-only checks + `scripts/defects-check.sh` red debt; 4 the project's rules: a diff
  line breaking a Never (✗) / How-to (→) line of a card shown for its path = a major `[unanchored]`
  naming the card ref (reaches the owner at ship); Allowed (✓) is no finding. Item 5 (0.40.0, :30-33): for
  each `red: required` story read its `## Red receipt` tail and `red_reason`; a tail showing a staged break
  (an error inside the implementation, not the missing behaviour) = major `[ask N]`; no receipt is never asked.
  Reads (:34-47): round 1 `merge-base..head`; round 2+ `since..head` + previous `review.md`; ONE
  `git diff <range> -- <every path>` so the card hook delivers `docs/defects/` cards (a `+N cards` fold is
  opened at `docs/defects/<ref>.md`). Verdict (:56-65): BLOCK needs an anchored Critical/Major: `[ask N]`
  (a security hole or data-loss path the diff adds, shown reachable; hardening = minor) or `[regression]`
  (base-side evidence); else `[unanchored]`.
  Line 1 `VERDICT: PASS|BLOCK`; line 3 `SUITE: ok|FAIL|TIMEOUT <N>s budget <B>s|none` (lead-review.md:49-54,82,94):
  runs the `Full suite / build` row once per round under `timeout $((VULYK_SUITE_TIMEOUT:-590)+5)`; FAIL =
  BLOCK with a `[regression]` Critical; TIMEOUT leaves the verdict, `judge` escalates. ≤ 5 minors.
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
  worker-code.md:42-44; exit 2 `verification is round-only` = the story named a `round-only` row,
  worker-code.md:58 - `NEEDS_CONTEXT`), after three failures `## Findings` + `returned: WALL`. **Red first
  (0.40.0, ADR-025), step 2 of both workers, only for `red: required`:** write the test `## Files` names (no
  mock of logic not yet written), write `red_reason:`, run `cycle.sh stamp-red <story> --stamp <S>`, then
  implement, then `close-story`; never edit the implementation to produce a red (a staged break =
  `NEEDS_CONTEXT`). Step 6 maps each gate/stamp-red exit-4 message to an action (worker-code.md:45-55). Never edit `status:`,
  never stash/checkout/reset/clean. Step 3 (worker-code.md:27-33; was step 2): a bug fix runs `symbol-map.sh <file>
  --story <story>` on a root file first, greps only what it cannot vouch for (`textual` names, callers of an
  `imports not parsed` file); a fix needing a file outside `## Files` = `NEEDS_CONTEXT`.
- **queen-planner** (`opus`, `high`, `maxTurns:40`; Read/Write/Grep/Glob) - Tier 3-4 plan + stories
  (`model:` per story: queen-planner.md:21-26, ADR-015/020; `## Verification` cites only `## Commands`
  rows without `round-only`, queen-planner.md:30). Never reads source; never plans repairs
  (`cmd_repair` writes `model: opus`). Marks `red: required` (frontmatter, planner only) a story that adds a
  branch, loop, parser, or money/security/data-write handling; its test file is in its own `## Files` and
  `## Verification`, `red_reason:` prefilled when known, and no later-wave `worker-test` story for it
  (queen-planner.md:36-42). T4 dispatch: `<top_model>`. `## Files` lists every reached path; the
  brief's symbol-map output (`--exact`) is a source: `exact` lines go into `## Files` when the change reaches
  them, a non-zero `textual <N> not shown` under `tests`/`importers` is a recon question for `drone-scout`,
  unchanged importers stay out (queen-planner.md:31-35).
- **lead-architect** (`opus`, `high`, `maxTurns:30`) - T4 planning and after a story's second miss;
  every decision an ADR. Dispatched with `model: <top_model>`.
- **drone-scout** (`sonnet`, `low`, `maxTurns:15`) - recon; `# Scout report:` format. **drone-coverage**
  (`opus`, `medium`, `maxTurns:5`) - T3-4, reads only brief.md + plan.md. **drone-docs** (`sonnet`,
  `low`, `maxTurns:40`) - map + wiki after a merge. **librarian** (`opus`, `low`, `maxTurns:25`; **no
  shell**) - sole consolidator of `memory/learnings/`; lists `Delete:` files (librarian.md:18-19).
- **drone-horizon** (0.35.0, ADR-022; `sonnet`, `medium`, `maxTurns:20`; `tools:` Read/Grep/Glob/WebSearch/
  WebFetch only, drone-horizon.md:4) - one `lens:` per dispatch (altitude|depth|range); step 1 takes the two
  Profile rows from the dispatch, reads the constitution `## Profile` only if missing (:18-20). ≤ 3
  proposals (`what/why/cost/check/sources/status/kind/ask line`), `DROPPED:`; writes nothing. Two dated
  sources else `не подтверждено`; WebFetch ≤ 2; reply ≤ 60 lines.

## Commands - what each runs
- **`/vulyk-plan`** - step 0 deliverable (document → brief + report, stop); tier; brief via
  `redact.sh`; recon (scouts: T1 0-1, T2 ≤1, T3 ≤2, T4 ≤4); grill T2-4; plan (Queen T1-2,
  `queen-planner` T3-4, `lead-architect` T4); stories; `wave-check.sh` + `trace-check.sh`;
  `drone-coverage` T3-4. T1 → `cycle.sh briefed --mode mini-brief` + `/vulyk-build`. T2-4 stop for
  `**Approved:**` (`--go` opts out). Step 2 (vulyk-plan.md:21-26, 0.42.0): when the request carries a stack
  trace, runs `bash scripts/trace-autopsy.sh docs/specs/<slug>/brief.md` right after the brief; `autopsy.md`
  beside it is a lead, not a verdict. Step 3 (:27-34): a frame line in `autopsy.md` makes the location known, so
  Tier 1-2 send no scout for it; T2-4 `symbol-map.sh --exact <file>` once
  per file the plan likely names (many files in one call get cut at 1536 bytes), outputs kept for the plan;
  checklist line: meta-tests, docs/ADR, `.env.example`, re-exports, sibling files. Step 6 (vulyk-plan.md:81-85):
  the Queen/planner marks critical stories `red: required` and names the test in `## Files` and `## Verification`. **Step 3a horizon** (vulyk-plan.md:35-55; `--horizon` forces, `--no-horizon`
  skips; skipped for study, T0-1, no-question): fires on zero grep hits of the capability's 2-4 terms in
  `memory/memory.md`, `memory/map/`, source (a container hit does not count); three parallel `drone-horizon`
  (no `model:`), each given brief path, recon summary and the Profile rows *Configurations that exist today* +
  *Owner language* verbatim; Queen cuts to ≤ 3; a kept `kind: gap` needs a named ask or verbatim request
  fragment (written beside it) else relabelled `extension`; kept ones numbered `H1`-`H3` in
  `docs/specs/<slug>/horizon.md`; never into `brief.md`. Grill (`templates/grill.md:49` `## Horizon
  questions`): one question each inside the 3-7 cap, ordered ordinary, then `gap`, then `extension`; the
  cap's leftovers stay in `horizon.md`; «Добавить»/«Не добавлять»; silence = not added; «Добавить»
  recommended only for `gap`. `## Answers` entries open `(horizon H<n>)` and end `adopted`/`declined`/
  `offered, not adopted` (grill.md:73-77, :87).
- **Fable-limit fallback, session path** (ADR-015 exception): `/vulyk-build` (section `## Fable-limit
  fallback`, vulyk-build.md:95-108; solo review :36, hive wake-up reads the driver's `fallbacks` :63),
  `/vulyk-review` (step 2, :29-37) and `/vulyk-plan` (step 5, :59-74; `queen-planner`/`lead-architect`) redispatch
  a refused dispatch once on `model: opus` (not when already opus). Session test: an error carrying
  `You've reached your Fable limit`/`model_requires_usage_credits`, or text starting `Agent terminated early due
  to an API error` and carrying `reached your Fable limit` (a quoting report is a report). Each writes a
  `journal.sh` line, `telemetry.sh record fable_limit_fallback 1 0 --model fable --agent <a>`, one owner sentence.
  A second refusal is the old path. The driver's test differs (cycle.md).
- **`/vulyk-models`** (0.30.0) - quiz via `model-profile.sh --recommend`/`--explain`, one `AskUserQuestion`,
  then `--set <name>`; `claude -p` prints a pointer, writes nothing.
- **Profile-aware dispatch** (ADR-020, scripts.md): `/vulyk-plan`, `/vulyk-build` (passes `worker_model`,
  `review_model`, `seat_model`; a retry is `<top_model>`) and `/vulyk-review` pass `model:` only when the
  profile is not `sonnet-builds`; otherwise frontmatter applies.
- **`/vulyk-build`** - `**Tier:**` picks the path. Solo T1-2: loop `cycle.sh advance`; `build:W` → the
  Queen implements each story (a bug fix runs `symbol-map.sh <file> --story <story>` on a root file first,
  vulyk-build.md:20-23; a `red: required` story first gets test + `red_reason:` + `stamp-red` with no
  `--stamp`, vulyk-build.md:20-24), `close-story --commit`; `dispatch:review` → one `lead-review`, then
  `advance --ingest`. Hive T3-4 (vulyk-build.md:35): `top-model.sh --floor` first (exit 1 prints
  `below floor` lines and stops); then `top-model.sh`, `second_model`, 16-hex stamp, journal line,
  Workflow tool with `scriptPath` (never `name:`); a thrown call records `telemetry.sh record
  driver_refused`. No Workflow: same loop with `--stamp --claim`, Agent tool, `release` on every exit.
  Terminal `green`: `AskUserQuestion` «Выпускаем?»; yes runs `vulyk-ship` via Skill.
- **`/vulyk-review`** - claim + `advance --claim`; dispatch the seats `next` names; `advance --ingest`;
  release. `build:W` = RED → repair story, `/vulyk-build`.
- **`/vulyk-ship`** - `ship-check.sh` (NOT READY refuses). Stage 03 runs `git merge-tree --write-tree`
  of the spec branch into the default: 0 clean, 1 conflict (never overridden; repair only on the
  owner's yes), other = "cannot check". Release commit; local `merge --no-ff` only on a clean default
  tree, failure → `merge --abort`; then `branch -d` (never `-D`). Prints the publish command, never
  runs it; when it pushes and tags and `.github/workflows/` exists, the printed order is push, green CI on
  that commit, then tag + push tag (red = no tag; vulyk-ship.md:31-35); `drone-docs`/`librarian` only with work; next-brief draft.
- **`/vulyk-status`** - driver line, council stats, `token-report.py`, `state.sh` table, map freshness,
  `defects-index.sh --counts`, `maintenance due|waits for` lines. Writes only `.claude/state.json`.
- **`/vulyk-evolve`** - `evolve-ledger.py . resolve` + `window` (a `pending` branch stops the run);
  builds the changeset in worktree `.claude/worktrees/evolve-<date>` on `vulyk/evolve-<date>`; telemetry
  prints, never sends. `--dry-run` writes no row. Step 2 (vulyk-evolve.md:82): once ≥ 3 `horizon.md` exist,
  counts `(horizon H` picks in `brief.md` `## Answers` (adopted/declined/offered) plus unanswered kept
  proposals, against ADR-022's reversal rule.
- **`/vulyk-gc`** - dispatches `librarian`; main session `git rm`s its `Delete:` list. **`/vulyk-gc memory`**
  (0.32.0) - main session alone: `memory-triage.sh`, one `AskUserQuestion`, nothing written before a yes;
  step 10 (0.41.0, vulyk-gc.md:56) runs `memory-triage.sh --mark`, also when nothing moved, so the brief stays quiet.
- **`/vulyk-pause`** / **`/vulyk-resume`** wrap `cycle.sh pause`/`resume`. **`/vulyk-update`** -
  `vulyk-update.sh . --check`, ask; step 6 renames the hive's full-suite row to `Full suite / build
  (round-only)` (or adds it with `none`), ADR-023. **`/vulyk-bootstrap`** - interview, Profile + Commands markers, scouts →
  map; a no is the Profile row `| Bootstrap | declined <date> |`.
- **`/vulyk-map`**, **`/vulyk-handoff`**: `!` injections go through `${CLAUDE_PROJECT_DIR}`, never a
  relative script path (`injection-check.sh`); `handoff.sh dump "${CLAUDE_SESSION_ID}"`.

last-verified: 2026-10-28 (trace-autopsy merge 46d13ad, 0.42.0 /vulyk-plan steps 2-3; ADR-013, ADR-015, ADR-020, ADR-022, ADR-025). Over the ~80-line cap (136): not trimmed this pass.
