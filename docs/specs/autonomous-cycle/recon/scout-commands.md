# Scout report: `.claude/commands/*.md`, `.claude/agents/*.md`, `templates/*.md`, `.claude/rules/`

## Purpose
VULYK's command/agent/template layer implements a 6-stage human-gated delivery cycle (spec→plan→code→tests→human→ship) with deterministic gates (`wave-check`, `trace-check`, `scope-check`, `acceptance-log`, `ship-check`) and a caste-based model cascade (Queen/Lead/Worker/Drone).

## Entry points
- `.claude/commands/vulyk-plan.md` — stage 01/02, brief+recon+stories+approval
- `.claude/commands/vulyk-build.md` — stage 03, wave dispatch, per-story commit
- `.claude/commands/vulyk-review.md` — stage 04/05, lead-review + drone-acceptance + human check
- `.claude/commands/vulyk-ship.md` — stage 06, history/version/publish/next-circle
- `.claude/agents/drone-acceptance.md` — blind acceptance gate contract (council-contract base)

## Key types / contracts
- Story frontmatter: `story, spec, status, tier, worker, tracer, wave, blocked_by` (`templates/story.md:1-12`)
- Plan confirmation lines: `**Approved:** / **Branch:** / **Checked:** / **Shipped:**` (`templates/plan.md:59-62`)
- Worker return contract: `STATUS/FILES/TESTS/INTERFACES/CONCERNS/BLOCKERS` (`worker-code.md:25-32`, `worker-test.md:27-33`)
- `drone-acceptance` return contract (see Q2)

## Dependencies
Commands dispatch agents by name+`model:` param; agents never call each other (no subagent-spawns-subagent). Deterministic scripts (`wave-check.sh`, `trace-check.sh`, `scope-check.sh`, `acceptance-log.sh`, `ship-check.sh`, `state.sh`, `top-model.sh`) are invoked from commands, not agents (except `drone-acceptance`/`lead-review` hold raw `Bash`).

## Gotchas
- No `templates/brief.md` exists — confirmed by a failed Read (file does not exist). `brief.md` is instead written ad hoc per `vulyk-plan.md:9`'s inline instructions (verbatim blockquote + `redact.sh` + date).
- `.claude/rules/` contains **only** `README.md` — this repo's own `CLAUDE.md` Profile block is still `<fill in>` (unbootstrapped), consistent with zero path-scoped rule files existing yet.
- Direct listing tools (Glob/Grep with a bare `path`) returned no results anywhere in this repo during this recon; every file below was confirmed via direct `Read` at its known path instead. `scripts/acceptance-log.sh` itself was not read (out of scope for this pass — commands/agents/templates/rules only); the "who parses which labels" answer below is derived from the *invocation contract* visible in `vulyk-review.md`, not from the script's internals.

## Answer

**1. Command frontmatter + human-wait/gate mentions (file:line)**

| Command | description / argument-hint | Human-wait / Checked / human-check.sh | drone-acceptance / acceptance-log.sh | **Approved:** |
|---|---|---|---|---|
| `vulyk-plan.md:1-4` | "Queen planning mode..." / `<goal description>` | step 3 (`:10`) stops for approval word at Tier 3-4; step 9 (`:16`) stops for approval, writes `**Approved:**` | — | `:16` (writes placeholder replacement) |
| `vulyk-build.md:1-4` | "Execute approved stories..." / `[spec slug or story id...]` | refuses without approval marker, step 1 (`:8`) | — | reads it (refuses without) `:8` |
| `vulyk-review.md:1-4` | "Adversarial review gate..." / `[spec slug, branch, or file scope]` | step 7 (`:14`) stops for stage 05, `human-check.sh` invoked twice in same line | step 3 (`:10`) dispatches drone-acceptance; step 4 (`:11`) `acceptance-log.sh`; step 6 (`:13`) `acceptance-log.sh --check` | — |
| `vulyk-ship.md:1-4` | "Stage 06..." / `[spec slug...]` | step 1 (`:8`) refuses via `ship-check.sh` if stage 05 open; step 3 (`:12`) stops for human to press publish | `ship-check.sh` reads `**Checked:**` indirectly (not acceptance-log itself) | reads via `ship-check.sh` |
| `vulyk-status.md:1-4` | "Hive dashboard..." / `[]` | none (read-only report) | none | none |
| `vulyk-bootstrap.md:1-4` | "Adapt VULYK to this project..." / `[--quick...]` | none explicit (interview, not stage-05 human-check) | mentions `drone-acceptance` removal caveat (`:10`) | none |
| `vulyk-update.md:1-4` | "Check for a newer VULYK release..." / `[version]` | step 4 (`:20-22`) asks and waits for owner yes/no | none | none |
| `vulyk-evolve.md:1-4` | "Weekly self-evolution..." / `[--dry-run...]` | step 4 human gate (`:11`) — presents changeset, applies nothing | none | none |
| `vulyk-handoff.md:1-4` | "Save session state..." / (none) | none | none | none |
| `vulyk-gc.md:1-4` | "Memory garbage collection..." / `[]` | "needs human decision" items presented, decide nothing unilaterally (`:10`) | none | none |
| `vulyk-map.md:1-4` | "Build or refresh codebase map..." / `<path or module name...>` | none | none | none |

**2. `drone-acceptance.md` — full report contract**

Frontmatter (`:1-7`): `name: drone-acceptance`, `tools: Read, Grep, Glob, Bash`, `model: sonnet`, `maxTurns: 20`.

Inputs it MUST receive (`:13-16`, and `vulyk-review.md:10`): spec's `brief.md`, the repository, one run/verification command; optionally the *Configurations that exist today* row (preferably CLAUDE.md `## Profile` block, else a **named section** of a milestone ledger) and the *Client path* row. Inputs it must NOT receive (`:18-23`): anything under `docs/specs/` except `brief.md` — not plan.md, not stories, not `## Implementation notes`/`## Findings`; if plan.md is attached it must decline to read it and say so.

Exact return contract (`:71-79`):
```
ACCEPTANCE: <slug>
VERDICT: ACCEPTED | REJECTED | CANNOT_RUN
ASSUMED CONFIG: <deployment shape judged against, or "none given">
RAN: <commands actually executed>
PATH: <client path walked and how far, or "none named">
<one line per ask: WORKS | BROKEN | UNVERIFIABLE - the ask - the evidence>
UNASKED: <behaviour hit that brief never asked for, or "none">
```
Rules: `REJECTED` requires ≥1 `BROKEN` line; a `CANNOT RUN HERE: <reason>` first-line variant is allowed when nothing is reachable (`:59-67`); 25-line cap.

**How `acceptance-log.sh` is fed** (`vulyk-review.md:11-13`): the Queen (main session) reads the drone's `VERDICT` line from its final-message report, then manually runs `bash scripts/acceptance-log.sh docs/specs/<slug> <ACCEPTED|REJECTED|CANNOT_RUN> "<one line>"` — the verdict and a human-composed one-liner are passed as **CLI arguments**, not auto-parsed from a saved report file. The script itself (not read in this pass) then "reads the story statuses itself" and computes the drift number, and stamps commit + pack fingerprint. `acceptance-log.sh --check <spec-dir>` (`:13`) answers `CURRENT`/`STALE`/`NO VERDICT RECORDED`. This CLI-argument hand-off (Queen extracts label → passes as arg) is the pattern a three-seat council contract would need to replicate or extend.

**3. `lead-review.md`, `worker-code.md`, `worker-test.md` — return contracts**

- `lead-review.md` (`:1-7`: tools `Read, Grep, Glob, Bash`, model `opus`, maxTurns 25). Verdict format: `BLOCK` (≥1 critical) or `PASS`, no middle verdict (`:29`). Report is prose, not a fixed label block: findings grouped critical/major/minor, each with `file:line`, a routing word (`plan`|`worker`, `:25`), and "the condition to satisfy" sentence (`:27`) — no `STATUS/FILES/TESTS` fields.
- `worker-code.md` (`:1-7`: tools `Read, Write, Edit, Grep, Glob, Bash`, model `sonnet`, maxTurns 40). Contract (`:25-32`):
```
STATUS: DONE | NEEDS_CONTEXT | WALL
FILES: <touched, comma-separated>
TESTS: <command + one-line outcome>
INTERFACES: <public surface changed, or "none">
CONCERNS: <or "none">
BLOCKERS: <only for NEEDS_CONTEXT/WALL>
```
25-line max.
- `worker-test.md` (`:1-7`: same tools as worker-code, model `sonnet`, maxTurns 30). Same contract shape (`:27-34`) but `INTERFACES: none` fixed, `TESTS:` line also names added test names.

**4. One-paragraph gists + input contracts**

- `drone-coverage.md` (`:1-7` tools `Read`, model `sonnet`, maxTurns 5): answers only "does the plan carry every brief ask?" Inputs strictly `brief.md` + `plan.md` — never story files; if either is attached anyway it must refuse to read and disclose. Output is a fixed markdown report (`## Absent/Partial/Carried/Plan work with no ask/Assumed away`, `:30-42`).
- `queen-planner.md` (`:1-6` tools `Read, Write, Grep, Glob`, model `opus`): delegated Tier 3-4 planner; inputs = goal, brief.md, scout reports, map/wiki pointers — never source files. Writes `plan.md` + story files per templates, with a mandatory merge pass (payback/neighbour tests) before finishing.
- `lead-architect.md` (`:1-6` tools `Read, Grep, Glob, Write`, model `opus`): consulted design authority; inputs = map slice + named files + `docs/adr/` history only (no codebase crawl); writes ADRs via `templates/adr.md`.
- `librarian.md` (`:1-7` tools `Read, Write, Edit, Glob`, model `sonnet`, maxTurns 25): sole writer for `memory/learnings/CONSOLIDATED.md`, map staleness flags, snapshot pruning, index verification; also runs the post-review ADR harvest, whose input is strictly `plan.md`'s `## Plan deltas`/`## Descoped` + `docs/adr/` — never stories or diffs.
- `drone-docs.md` (`:1-7` tools `Read, Write, Edit, Grep, Glob`, model `sonnet`, maxTurns 20): post-merge memory updater; input = the merged **diff** + touched map/wiki entries; treats worker `## Implementation notes` as a lead only, never a fact — every claim it writes must be independently re-verified against the tree.

**5. `templates/` inventory**

- `templates/plan.md` — spec-level plan: Goal/Assumptions/Stories(by wave)/Contracts/Integration gate/Descoped/Plan deltas, plus the four stage-confirmation marker lines `**Approved:** / **Branch:** / **Checked:** / **Shipped:**` (`:59-62`) — machine-read by `ship-check.sh`.
- `templates/story.md` — frontmatter machine-parsed keys (`story, spec, status, tier, worker, tracer, wave, blocked_by`, `:1-12`); marker/machine-parsed body sections: `## Requirements` (verbatim quotes, matched by `trace-check.sh`), `## Files` (machine-readable path list, parsed by `scope-check.sh` and `wave-check.sh` for collisions), `## Verification` (command + optional `repeat: N`), `## Implementation notes`/`## Findings` (worker-appended).
- `templates/adr.md` — Status/Date/Spec header, Context/Options/Decision/Consequences/Invariants created/Revisit when.
- `templates/wiki-note.md` — frontmatter `domain, tags, related, last-verified`.
- **No `brief.md` template** — confirmed absent (Read returned "File does not exist"); briefs are hand-assembled per the inline recipe in `vulyk-plan.md:9` (verbatim blockquote piped through `redact.sh`).

**6. `.claude/rules/` contents beyond README.md**

None. Only `.claude/rules/README.md` exists (confirmed via Grep/Glob returning no other matches in that directory). This tracks with VULYK's own `CLAUDE.md` `## Profile` block still being unfilled (`<fill in>` placeholders) — this repo, being the framework source rather than a bootstrapped consumer project, has not run `/vulyk-bootstrap` on itself to seed stack-specific rule files.

**7. `vulyk-status.md` / `vulyk-evolve.md` — stats files read, and where a `council.jsonl` would plug in**

- `vulyk-status.md` reads (not `memory/stats/*.jsonl` broadly, but specifically): `.claude/state.json` via `scripts/state.sh` (step 1, `:8`, derived story/stage view — never source of truth); `memory/map/*` last-verified vs. git churn (step 2, `:9`); raw file count in `memory/learnings/` (step 3, `:10`); `memory/stats/skills.json` top/bottom entries (step 4, `:11`); `scripts/top-model.sh --explain` output (step 5, `:12`). It does **not** currently read `scope.jsonl`, `acceptance.jsonl`, `human.jsonl`, or `ship.jsonl` directly, despite CLAUDE.md listing those as the stats series that exist (`CLAUDE.md` "Where things live").
- `vulyk-evolve.md` harvest step (`:8`) reads `memory/learnings/` (raw+CONSOLIDATED), `memory/stats/skills.json`, and optionally pasted `/insights` output — same gap, no `.jsonl` gate series consumed.
- **Plug-in point for a weekly `council.jsonl`:** the natural seam is `vulyk-status.md` step 4/5 (`:11-12`, "Skill usage" / "Budget posture") — insert a new numbered step reading `memory/stats/council.jsonl` and summarizing top/bottom or drift, mirroring how `skills.json` is already surfaced there; and symmetrically in `vulyk-evolve.md` step 1 "Harvest" (`:8`), add it alongside `skills.json` as a diagnostic input for the friction/archive-candidate lists in step 2 (`:9`). Neither command has an established `.jsonl`-reading pattern beyond `skills.json`, so this would be new plumbing, not an extension of an existing one.
