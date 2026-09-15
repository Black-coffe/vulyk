# Scout report: agents and commands (post v0.12.0)

## Purpose
Every `.claude/agents/*.md` caste and `.claude/commands/vulyk-*.md` entry point, as they
stand after the council replaced stage 05. `drone-acceptance.md` is **gone** - do not
dispatch it or point anyone at it; its ledger role is `acceptance-log.sh`, kept only as
`ship-check.sh`'s fallback for pre-council specs (see `memory/map/scripts.md`).

## Agents - model, tools, angle, report contract
- **council-haiku/sonnet/opus** (`sonnet` (junior rung, ADR-007)/`sonnet`/`opus`; `Bash,Read,+mcp__chrome-devtools__*,
  mcp__claude-in-chrome__*` (haiku only) / `Bash,Read,Grep,Glob` (sonnet, opus); no Write/Edit;
  `maxTurns:60`) - the three blind seats, one round, one court. haiku: black-box, walks the
  *Client path* like a client, drives the Profile's Browser MCP row only when named, reads no
  source. sonnet: the only seat given the full-suite command, runs it once then proves every
  `## Asks` item with `run:`/`saw:`. opus: intent seat, judges what the owner meant beyond the
  literal ask; edge cases go under `UNASKED:`, never folded into an `ASK` line. Shared return
  contract: `COUNCIL/MODEL/COURT/VERDICT/ASSUMED CONFIG/RAN/PATH` + one `ASK <n>` line/ask +
  `UNASKED:`/`BREACH:`, 40 lines max (`cycle.md` D3). Dispatch names only `slug`/`round`/
  `court` - never `round_dir` (echoing it back is a taint). v0.13.1: when the dispatch also
  gives a report path (`.vulyk/reports/<slug>/round-N/<seat>.attempt-K.md`), the seat writes its
  report there verbatim as the very last action - not a BREACH.
- **cycle-clerk** (`sonnet` - junior rung, ADR-007, `Bash` only, `maxTurns:5`) - runs exactly the one `cycle.sh`/
  `journal.sh` command given, returns the last stdout line verbatim, no verdict logic. The
  Workflow driver's only shell access.
- **lead-review** (`opus`, `Read,Grep,Glob,Bash`, `maxTurns:60`) - adversarial review, sees
  everything (diff, stories, plan, wiki, ADRs). Report's **first line** is exactly `VERDICT:
  PASS`/`VERDICT: BLOCK` (v0.12.0: `record-seat … review` parses only that line); findings
  grouped critical/major/minor, each `file:line` + condition to satisfy, never a patch. Never
  enters the court. Same report-path-as-last-action contract as the council seats (v0.13.1).
- **drone-coverage** (`sonnet`, `Read` only, `maxTurns:5`) - reads ONLY `brief.md`+`plan.md`,
  never story files. v0.12.0: reports **by ask number** (`## Asks`'s `1..N` if present, else
  its own reading-order numbering, states which) - `Ask <n>: <verbatim>` under
  `## Absent`/`## Partial`. `CANNOT RUN: no brief.md at <path>` when the file is missing.
- **drone-scout** (`sonnet`, `Read,Grep,Glob`, `maxTurns:15`) - recon only. Report:
  `# Scout report: <target>` with `## Purpose/Entry points/Key types/Dependencies/Gotchas/
  Answer` - the format every `memory/map/*.md` slice follows (+ `last-verified`).
- **drone-docs** (`sonnet`, `Read,Write,Edit,Grep,Glob`, `maxTurns:40`) - this agent; owns
  `memory/map/`+`docs/wiki/` only, never code/commands/agents/specs/CLAUDE.md. Diff is the
  source; a story's `## Implementation notes` only locates where to look.
- **worker-code** (`sonnet`, `Read,Write,Edit,Grep,Glob,Bash`, `maxTurns:90`) / **worker-test**
  (same tools, `maxTurns:90`) - one story each, touches only its `## Files`. Final line
  `STATUS: DONE|NEEDS_CONTEXT|WALL`; a wall (3 failed distinct approaches) writes `##
  Findings` to the story file first. Never edits `memory/` or the wiki.
- **queen-planner** (`opus`, `Read,Write,Grep,Glob`) - Tier 3-4 synthesis: goal+brief+scout
  reports+map pointers -> a plan. Never reads source. Also the `repair` dispatch target (cuts
  fix stories into the existing plan, one per critical/major finding or RED ask).
- **lead-architect** (`opus`, `Read,Grep,Glob,Write`) - consulted, not deployed. Every
  decision becomes an ADR (`templates/adr.md`). Output: ADR path, 3-sentence summary,
  affected stories.
- **librarian** (`sonnet`, `Read,Write,Edit,Glob`, `maxTurns:25`) - the only agent that
  merges into `memory/learnings/` and prunes memory files. Report: merged/deleted/stale/
  needs-a-human, terse. Also the ADR harvest from `## Plan deltas` at `/vulyk-ship` step 5.

## Commands - what each runs, what it never does
- **`/vulyk-plan`** - tier classify -> brief (`redact.sh` piped) -> recon (`drone-scout`) ->
  grill (`templates/grill.md`, Tier 2-4; Tier 1 writes `## Asks` as the task phrase, no grill)
  -> plan (`queen-planner` Tier 3-4, inline Tier 2) -> stories -> `wave-check.sh`+
  `trace-check.sh` -> `drone-coverage` -> `cycle.sh briefed --commit` (`--mode mini-brief`/
  `assumed` as applicable) -> **stops for the owner's approval** (v0.13.0, ADR-008; `--go`
  or the grill's straight-through opt-in launches directly; a document deliverable ends at
  report.md before any of this). Never writes story code itself, never
  skips `wave-check`/`trace-check` once stories exist.
- **`/vulyk-build`** - resolves `top_model`/`second_model`/a random `stamp`, detects
  `Workflow` vs fallback, prints the "tree is not yours" journal line, then calls the
  `vulyk-cycle` Workflow or runs the same `status`->act loop itself (full verb table in
  `cycle.md`). Never writes `**Council:**`/`council.jsonl`/verdict logic itself - always
  through `cycle.sh`; never dispatches `queen-planner` twice for the same round. v0.13.1: on
  `dispatch:<seats>` gives each seat a report path and records with `record-seat ... --file
  <path>` first, falling back to the stdin heredoc only on exit 2 `error: "file: ..."`; a
  worker/seat/reviewer's empty return is logged by one of three reasons (`threw:`/`returned
  empty - turn cap suspected .../`returned no report`) per `cycle.md`'s Report-path section.
  v0.14.0: a `--fallback`-less refusal (no `Workflow` tool) and a Workflow call that itself
  throws both record `bash scripts/telemetry.sh record driver_refused 1 0 --spec <slug> --ref
  driver:<slug>:<date>` before stopping (`docs/telemetry.md`).
- **`/vulyk-review`** - one on-demand round: `open-round --commit` (refusal = surface
  verbatim, point at `/vulyk-build`), dispatch only the seats `missing` names (Tier 4: +
  second reviewer, folded stricter-of-two), `record-seat` each (same `--file`-then-heredoc
  scheme as `/vulyk-build`, v0.13.1), `judge --commit`. Never cuts repair stories itself -
  that always goes back through `/vulyk-build`.
- **`/vulyk-ship`** - `ship-check.sh` (refuse on NOT READY unless the owner overrides out
  loud) -> version bump+CHANGELOG commit if not already on branch -> local merge -> print the
  publish command from *Release / deploy* -> `ship-check.sh --record` -> dispatch
  `drone-docs`+`librarian` for the next circle. **Never pushes, tags, publishes or deploys**,
  never waits for the human to run the printed command.
- **`/vulyk-status`** - read-only: driver mode, `council.jsonl` stats (specs/median rounds to
  green/escalations/escaped defects), `state.sh` story table, memory freshness, learnings
  buffer, skill stats, `top-model.sh --explain`. Writes nothing.
- **`/vulyk-pause`/`/vulyk-resume`** - wrap `cycle.sh pause`/`resume`; pause explains the
  discard-and-re-dispatch consequence for an in-flight seat report; resume always relaunches
  the driver fresh (`/vulyk-build` step 1), never `resumeFromRunId`. v0.14.0: a relaunch
  records `bash scripts/telemetry.sh record driver_relaunched 1 0 --spec <slug> --ref
  driver:<slug>:<date>` first.
- **`/vulyk-evolve`** - harvest -> **new in v0.12.0**: 7-day `council.jsonl`/`human.jsonl`
  check-in (median rounds, escalations, escaped defects vs. REJECTED count; prints a "models
  are ready" signal when escaped defects exceed the human-gate baseline) -> **new in v0.14.0**:
  a same-window `memory/stats/anomalies.jsonl` count by code (`bash scripts/telemetry.sh enum`
  for the row list), then `bash scripts/telemetry.sh consent` gates a `publish`/`publish
  --dry-run` call (prints its recipe, never sends) -> **VULYK-repo-only**: `bash
  scripts/telemetry.sh inbox` prints `<week> <code> <rows> <hives>` per merged bundle, its
  table goes into the CHANGELOG entry, then (full path only) `inbox --clear` **stages** the
  emptied `telemetry/inbox/<week>/` deletions (`git rm`, no commit) -> diagnose ->
  changeset on `vulyk/evolve-<date>` -> human gate. Applies NOTHING to main; `--dry-run`
  stops after diagnosis (and skips `inbox --clear`). Full contract: `docs/telemetry.md`.
- **`/vulyk-bootstrap`** - interview -> fill `## Profile` (now includes the `Telemetry`
  consent row `install.sh` also writes, `off` by default) -> `top-model.sh --apply`
  **unconditionally now** (the council runs unattended, so the session must run on the
  resolved model, not just be told about it) -> prune roster (the council trio's removal is
  never silent) -> map -> seed memory/wiki.
- **`/vulyk-map`/`/vulyk-gc`/`/vulyk-handoff`/`/vulyk-update`** - unchanged this release:
  scout-batch map refresh; `librarian` GC pass; session-state dump to `.claude/handoff/`; the
  release-upgrade wrapper over `vulyk-update.sh`.

last-verified: 2026-09-14
