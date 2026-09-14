# Scout report: agents and commands (post v0.12.0)

## Purpose
Every `.claude/agents/*.md` caste and `.claude/commands/vulyk-*.md` entry point, as they
stand after the council replaced stage 05. `drone-acceptance.md` is **gone** - do not
dispatch it or point anyone at it; its ledger role is `acceptance-log.sh`, kept only as
`ship-check.sh`'s fallback for pre-council specs (see `memory/map/scripts.md`).

## Agents - model, tools, angle, report contract
- **council-haiku/sonnet/opus** (`haiku`/`sonnet`/`opus`; `Bash,Read,+mcp__chrome-devtools__*,
  mcp__claude-in-chrome__*` (haiku only) / `Bash,Read,Grep,Glob` (sonnet, opus); no Write/Edit;
  `maxTurns:25`) - the three blind seats, one round, one court. haiku: black-box, walks the
  *Client path* like a client, drives the Profile's Browser MCP row only when named, reads no
  source. sonnet: the only seat given the full-suite command, runs it once then proves every
  `## Asks` item with `run:`/`saw:`. opus: intent seat, judges what the owner meant beyond the
  literal ask; edge cases go under `UNASKED:`, never folded into an `ASK` line. Shared return
  contract: `COUNCIL/MODEL/COURT/VERDICT/ASSUMED CONFIG/RAN/PATH` + one `ASK <n>` line/ask +
  `UNASKED:`/`BREACH:`, 40 lines max (`cycle.md` D3). Dispatch names only `slug`/`round`/
  `court` - never `round_dir` (echoing it back is a taint).
- **cycle-clerk** (`sonnet` - junior rung, ADR-007, `Bash` only, `maxTurns:5`) - runs exactly the one `cycle.sh`/
  `journal.sh` command given, returns the last stdout line verbatim, no verdict logic. The
  Workflow driver's only shell access.
- **lead-review** (`opus`, `Read,Grep,Glob,Bash`, `maxTurns:25`) - adversarial review, sees
  everything (diff, stories, plan, wiki, ADRs). Report's **first line** is exactly `VERDICT:
  PASS`/`VERDICT: BLOCK` (v0.12.0: `record-seat … review` parses only that line); findings
  grouped critical/major/minor, each `file:line` + condition to satisfy, never a patch. Never
  enters the court.
- **drone-coverage** (`sonnet`, `Read` only, `maxTurns:5`) - reads ONLY `brief.md`+`plan.md`,
  never story files. v0.12.0: reports **by ask number** (`## Asks`'s `1..N` if present, else
  its own reading-order numbering, states which) - `Ask <n>: <verbatim>` under
  `## Absent`/`## Partial`. `CANNOT RUN: no brief.md at <path>` when the file is missing.
- **drone-scout** (`sonnet`, `Read,Grep,Glob`, `maxTurns:15`) - recon only. Report:
  `# Scout report: <target>` with `## Purpose/Entry points/Key types/Dependencies/Gotchas/
  Answer` - the format every `memory/map/*.md` slice follows (+ `last-verified`).
- **drone-docs** (`sonnet`, `Read,Write,Edit,Grep,Glob`, `maxTurns:20`) - this agent; owns
  `memory/map/`+`docs/wiki/` only, never code/commands/agents/specs/CLAUDE.md. Diff is the
  source; a story's `## Implementation notes` only locates where to look.
- **worker-code** (`sonnet`, `Read,Write,Edit,Grep,Glob,Bash`, `maxTurns:40`) / **worker-test**
  (same tools, `maxTurns:30`) - one story each, touches only its `## Files`. Final line
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
  `assumed` as applicable) -> **launches the build directly** (v0.12.0: no approval stop
  unless the grill's two-stop opt-out was invoked). Never writes story code itself, never
  skips `wave-check`/`trace-check` once stories exist.
- **`/vulyk-build`** - resolves `top_model`/`second_model`/a random `stamp`, detects
  `Workflow` vs fallback, prints the "tree is not yours" journal line, then calls the
  `vulyk-cycle` Workflow or runs the same `status`->act loop itself (full verb table in
  `cycle.md`). Never writes `**Council:**`/`council.jsonl`/verdict logic itself - always
  through `cycle.sh`; never dispatches `queen-planner` twice for the same round.
- **`/vulyk-review`** - one on-demand round: `open-round --commit` (refusal = surface
  verbatim, point at `/vulyk-build`), dispatch only the seats `missing` names (Tier 4: +
  second reviewer, folded stricter-of-two), `record-seat` each, `judge --commit`. Never cuts
  repair stories itself - that always goes back through `/vulyk-build`.
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
  the driver fresh (`/vulyk-build` step 1), never `resumeFromRunId`.
- **`/vulyk-evolve`** - harvest -> **new in v0.12.0**: 7-day `council.jsonl`/`human.jsonl`
  check-in (median rounds, escalations, escaped defects vs. REJECTED count; prints a "models
  are ready" signal when escaped defects exceed the human-gate baseline) -> diagnose ->
  changeset on `vulyk/evolve-<date>` -> human gate. Applies NOTHING to main; `--dry-run`
  stops after diagnosis.
- **`/vulyk-bootstrap`** - interview -> fill `## Profile` -> `top-model.sh --apply`
  **unconditionally now** (the council runs unattended, so the session must run on the
  resolved model, not just be told about it) -> prune roster (the council trio's removal is
  never silent) -> map -> seed memory/wiki.
- **`/vulyk-map`/`/vulyk-gc`/`/vulyk-handoff`/`/vulyk-update`** - unchanged this release:
  scout-batch map refresh; `librarian` GC pass; session-state dump to `.claude/handoff/`; the
  release-upgrade wrapper over `vulyk-update.sh`.

last-verified: 2026-09-13
