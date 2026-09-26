# Architecture audit - why VULYK is expensive and slow (code + config reading)

Recon agent: architecture. Date 2026-09-26. Source: the repo at `cb3b90c` (v0.17.0), read-only.
Evidence is `path:line`. Token estimates use chars / 3.7. Everything here is derived from the
code and configuration; measured transcript numbers are the transcript agent's job.

## 0. Ledger facts that frame everything (VULYK's own `memory/stats/council.jsonl`, 16 rows, 5 specs)

| Spec | Rounds | Verdict per round | What drove each non-GREEN round |
|---|---|---|---|
| autonomous-cycle | 3 | RED, RED, GREEN | r1, r2: `review: BLOCK` with `red: []` - every blind seat GREEN/N/A |
| fable-review-remainders | 2 | RED, GREEN | r1: `review: BLOCK`, `red: []` |
| anomaly-telemetry | 6 | RED, RED, ESC(ceiling), RED, RED, ESC(env) | r1-2: council-opus RED + review BLOCK; r3: review BLOCK only; r4-5: council-opus RED; r6: haiku ABSENT |
| driver-hardening | 2 | GREEN, ESC(env) | r2 opened *after* a GREEN (stale pack), sonnet ABSENT |
| convergent-judge | 3 | RED, ESC(ceiling), GREEN (after `reopen`) | r1, r2: `review: BLOCK`, `red: []` |

Seat scoreboard across all 16 rows (derived with one python pass over the file):

| Seat | Model / effort | RED ever? | Notes |
|---|---|---|---|
| `council-sonnet` | sonnet, session effort, 60 turns | **0 of 16** | GREEN every time it reported; ABSENT once (caused ESCALATE env). Runs the full suite every round. |
| `council-haiku` (black box) | sonnet | **0 of 16** | GREEN or N/A only; ABSENT once (caused ESCALATE env). |
| `council-opus` | opus | 4 of 10 dispatched | the only blind seat that ever found anything (anomaly-telemetry r1, r2, r4, r5) |
| `lead-review` | TOP_MODEL (fable/opus), effort high | **BLOCK in 8 of 16** | sole cause of 6 of the 11 non-GREEN rounds |

Consequence, stated once: the "one or two extra circles" are, in this ledger, overwhelmingly
**lead-review BLOCKs**, not blind-seat REDs; the two cheapest-looking seats (sonnet, haiku) have
never turned a round RED but have twice turned one into an ESCALATE by being ABSENT. The transcript
agent should confirm the same pattern holds in the owner's other hives.

### 0.1 Corroboration from the driver's own run files (one spec, convergent-judge, Tier 2)

Read from `~/.claude/projects/E--Projects-vulyk/678bec46-.../workflows/wf_*.json` (`workflowProgress`
per agent, `totalTokens` per run). Not a full measurement - the transcript agent owns that - but
it is the ground truth the code analysis below is checked against.

| Run | What it covered | Wall | Driver tokens | Dispatches | cycle-clerk share |
|---|---|---|---|---|---|
| `wf_19a7cbb7-85e` | build, 4 stories, ended at `open-round` refused (dirty tree) | 201 min | 899 056 | 35 = 27 clerk + **8 worker for 4 stories** | 524 661 (**58 %**) |
| `wf_8275f24e-0e0` | round 1 RED -> repair -> round 2 ESCALATE | 814 min | 1 292 279 | 37 = 27 clerk + 5 worker + 2 sonnet + 2 review + 1 planner | 525 709 (**41 %**) |
| `wf_555bc814-f33` | repair story 07 -> round 3 GREEN | 72 min | 507 751 | 14 = 11 clerk + 1 worker + 1 sonnet + 1 review | 204 590 (40 %) |
| **Total, driver only** (Queen's own plan/grill/ship session excluded) | | **18 h** | **2 699 086** | **86 = 65 clerk + 14 worker + 3 sonnet + 3 review + 1 planner** | **1 254 960 (46 %)** |

Per-type totals across the three runs: clerk 1.25 M (46 %), worker-code 0.72 M (27 %), lead-review
(Fable 5.1) 0.44 M (16 %), council-sonnet 0.19 M (7 %), queen-planner (Fable 5.1) 0.09 M (3 %).

What the per-agent rows show (each one is traced to code in section 3):
- **Every clerk call costs 18.1-18.7 k tokens for one Bash call** (2 model turns) - i.e. a ~9 k
  fixed prefix per turn. The owner's own memory note records ~55 k per clerk in a hive whose
  constitution is 68 + 39 KB (`memory/vulyk-next-circle-clerk-json-loss.md`, "the constitution is
  the lever"). Clerk cost scales with the hive's `CLAUDE.md`, not with the task.
- **7 of 8 `close-story` clerks in the build run returned empty after 10.4-17.1 min, 5 tool calls
  each** - the 600 s Bash timeout (`.claude/agents/cycle-clerk.md:16`) against a suite that runs
  9+ min on Windows. Each one was "recovered" by a `status` poll, counted as success, and the
  **worker was re-dispatched from scratch** on the same model (story 02 four times, story 01 twice,
  story 05 four times in the next run). 7 surplus worker dispatches (4 + 3), ~85 min of dead
  clerk time in the build run alone (10.4 + 17.1 + 10.4 + 10.4 + 10.4 + 13.3 + 12.8 min). The
  retries ran on `claude-opus-5-5`, not the gate model - proof the driver never counted them as
  misses (see hole H1).
- **Round 1 took 10.5 h because `lead-review` stalled**: run log line `[stall] agent "Adversarial
  review for convergent-judge, round 1" stalled (no progress) after 37159s - retrying (1/5)`.
  There is no per-agent wall-clock budget anywhere in the driver.

## 1. End-to-end trace

Assumptions of the trace: Workflow tool present (the default driver), session `effortLevel: medium`
(`.claude/settings.json:3`), Queen pinned to `opus` (`.claude/settings.local.json`), Max plan so
`TOP_MODEL = fable` (`scripts/top-model.sh`). "Clerk" = one `cycle-clerk` subagent (Sonnet, effort
low, maxTurns 5, `.claude/agents/cycle-clerk.md:5-7`) running one `cycle.sh` verb.

### 1.1 Tier 1 - "one module, clear task" (e.g. recolour a button)

| # | Step | Who / model / effort | Context handed or told to read | Seq / par | Blocks on a test run? |
|---|---|---|---|---|---|
| 0 | Session start: 4 SessionStart hooks | hooks -> Queen context | `[VULYK]` brief line, gate-model line (~120 tok), update notice (0 or 6 lines), **handoff restore up to 12 000 chars** on `/clear`/`compact`/fresh start (`.claude/hooks/handoff.py:826-844`) | seq | no |
| 1 | `/vulyk-plan` loads | Queen, opus, medium | `vulyk-plan.md` 6.1 KB on top of CLAUDE.md 16.2 KB + global CLAUDE.md 8.6 KB + MEMORY.md 2 KB | - | no |
| 2 | Deliverable + tier call | Queen | routing matrix (`vulyk-plan.md:8-21`) | seq | no |
| 3 | `brief.md` written (verbatim, through `redact.sh`) | Queen | - | seq | no |
| 4 | Recon | Queen | `memory/memory.md` (4.1 KB) + map slice(s) (10.5-13 KB each here; cap says ~80 lines, actual 126-167); `drone-scout` 0-1, only if location unknown (`vulyk-plan.md:27-32`) | seq | no |
| 5 | Grill | - | skipped at Tier 1; `## Asks` = the task phrase (`vulyk-plan.md:37-38`) | - | no |
| 6 | `plan.md` + exactly one story file | Queen | reads `templates/plan.md` 4 KB + `templates/story.md` 5.1 KB | seq | no |
| 7 | `wave-check.sh` + `trace-check.sh` | Queen's Bash | output enters the Queen's context | seq | no |
| 8 | `cycle.sh briefed --commit --mode mini-brief` | Queen's Bash | always straight-through at Tier 1 (`vulyk-plan.md:67-68`) | seq | no |
| 9 | `/vulyk-build` launch | Queen | loads `vulyk-build.md` **16.2 KB**; runs `top-model.sh`, stamp, `journal.sh`, **`cycle.sh claim`** (`vulyk-build.md:32-37`), then `Workflow` | seq | no |
| 10 | driver: `claim` again, same stamp - an idempotent no-op (`cycle.sh:2201-2207`) | clerk | 1 verb | seq | no |
| 11 | driver: `status --json` | clerk | - | seq | no |
| 12 | driver: `branch --commit` | clerk (carries status) | - | seq | no |
| 13 | driver: `build:1` -> `worker-code` | Opus 5.5, medium, maxTurns 90 | story file + "the map slice it names" + `.claude/rules/` (`vulyk-cycle.js:220`, `worker-code.md:13-14`) | par (1 here) | **yes - worker runs `## Verification` until green** (`worker-code.md:16`) |
| 14 | driver: `close-story --commit` | clerk | `scope-check.sh` + **the same `## Verification` again** x `repeat` (`cycle.sh:1663-1716`); 600 s Bash cap | seq per story | **yes - second run** |
| 15 | driver: `status` poll | clerk | the build branch never uses the status `close-story` carries (`vulyk-cycle.js:207-255, 333`) | seq | no |
| 16 | driver: `open-round --commit` | clerk (carries status) | builds a git worktree court, prunes the spec dir to `brief.md`, commits inside the court (`cycle.sh:1788-1858`) | seq | no |
| 17 | driver: `dispatch:sonnet` -> `council-sonnet` | Sonnet, session effort, maxTurns 60 | COURT path, round, slug; reads `brief.md ## Asks`, CLAUDE.md `## Profile` + `## Commands` (`council-sonnet.md:30-40`) | par (1 here) | **yes - third run: full suite first, then per-ask runs** (`council-sonnet.md:35-40`) |
| 18 | driver: `record-seat --file` | clerk | validates labels, ASK coverage, evidence, taint (`cycle.sh:1325-1437`) | seq | no |
| 19 | driver: `status` poll | clerk | the dispatch branch ignores the carried status too | seq | no |
| 20 | driver: `judge --commit` | clerk | GREEN carries status; RED at Tier 1 is **ESCALATE ceiling at once** (`tier_ceiling 1`, `cycle.sh:224-231, 950-951`) | seq | no |
| 21 | driver: `release` (finally) | clerk | - | seq | no |
| 22 | Wake-up | Queen | reads `journal.md` tail + newest round's seat files (`vulyk-build.md:142-147`) | seq | no |
| 23 | `/vulyk-ship` | Queen | loads `vulyk-ship.md` 5.4 KB; `ship-check.sh`; version bump + CHANGELOG commit; local merge; `--record`; commit | seq | no |
| 24 | Next circle | **`drone-docs` (opus, low, 40 turns) "with the merged diff" + `librarian` (opus, low, 25 turns) ADR harvest** (`vulyk-ship.md:108`) | Queen then gathers UNASKED/minor/descoped verbatim | par | no |

A one-line Tier 1 task therefore pays: brief + plan + story + 2 gate scripts + a commit per state
change (briefed, branch, story, open-round, judge, shipped, release, merge) + 10 clerks + 1 worker
+ 1 seat + 2 ship drones, and **the story's verification three times** (worker, close-story,
council-sonnet's full suite). Only an explicit Tier 0 call escapes it (`CLAUDE.md` routing row 0).

### 1.2 Tier 2 - "feature within a module" (3 stories, one wave)

Differences from Tier 1 only:

| # | Step | Who / model / effort | Notes |
|---|---|---|---|
| 4 | Recon | Queen + **1 `drone-scout`** (Opus 5.5, low, 15 turns) | `vulyk-plan.md:29-30` |
| 5 | Grill | Queen, 3-7 `AskUserQuestion` turns, one question per turn (`templates/grill.md:196-224`) | every turn re-sends the Queen's whole prefix |
| 6 | Plan | Queen **drafts inline** (Tier 3-4 delegate to `queen-planner`) + 2-4 story files with verbatim `## Requirements` | `vulyk-plan.md:39-45` |
| 9 | **Approval stop** | owner reads the plan and says a word; `journal.sh 02-approved` | default since v0.13 (ADR-008) |
| 13 | `build:1` | **3 `worker-code` in parallel, one shared working tree** (no worktree per worker) | each runs verification while the others are still editing |
| 14 | `close-story` x3 | clerks, **strictly sequential** (`vulyk-cycle.js:228-255`) | each runs the suite on a tree still holding the other stories' uncommitted edits |
| 17 | `dispatch:sonnet,review` | `council-sonnet` in the court **and `lead-review` at `TOP_MODEL` (Fable 5.1), effort high, 60 turns, in the main tree**, in parallel | lead-review is told to "review its stories and plan", diff the branch and read `docs/adr/001-cycle-state-contract.md` (34.5 KB) (`vulyk-cycle.js:130-131`) |
| 18 | `record-seat` x2 | clerks, sequential | a MALFORMED seat is re-dispatched whole, inside the loop, before the next seat is recorded (`vulyk-cycle.js:284-304`) |
| 20 | `judge` | clerk | RED round 1 -> `repair`; RED round 2 -> ESCALATE (`tier_ceiling 2`) |
| R | `repair` | **`queen-planner` at `TOP_MODEL` (Fable), effort high, no maxTurns** (`vulyk-cycle.js:323-326`, `queen-planner.md:5-7`) cuts fix stories; the loop repeats build -> close -> open-round -> **every required seat again from zero** -> judge | no `wave-check` / `trace-check` on repair stories in the Workflow driver |

### 1.3 Subagent dispatch counts per task (Workflow driver, from the code paths above)

Shapes assumed: Tier 1 = 1 story; Tier 2 = 3 stories in 1 wave; Tier 3 = 6 stories in 2 waves
(4 + 2); one RED round repairs 1 / 1 / 2 stories. "Queen-side" = plan + ship dispatches.

| Tier | Path | Queen-side | Driver agents (worker / seat / planner) | Driver clerks | **Total** | Clerk share |
|---|---|---|---|---|---|---|
| 1 | minimum (location known) | 0 + 2 ship | 1 worker + 1 seat | 10 | **14** | 71 % |
| 1 | + scout | 1 + 2 | 2 | 10 | 15 | 67 % |
| 1 | one RED | 0-1 | 2 | 11 | **13 + human** (no repair at Tier 1: RED = ESCALATE; after `reopen`, `next` is `open-round`, not `repair`, so a relaunch re-councils unchanged code) | 85 % |
| 2 | happy path | 1 scout + 2 ship | 3 workers + sonnet + review | 13 | **21** | 62 % |
| 2 | one RED round | 1 + 2 | + 1 planner + 1 worker + 2 seats | 13 + 8 = 21 | **33** | 64 % |
| 3 | happy path | 2 scouts + queen-planner + drone-coverage + 2 ship = 6 | 6 workers + 4 seats | 19 | **35** | 54 % |
| 3 | one RED round | 6 | + 1 planner + 2 workers + 4 seats | 19 + 11 = 30 | **53** | 57 % |
| 4 | happy (12 stories, 3 waves) | 4 scouts + planner + architect + coverage + 2 ship = 9 | 12 workers + 3 seats + 2 reviewers | 26 | **52** | 50 % |

Clerk arithmetic (happy path): `claim` + `status` + `branch` + one `close-story` per story + one
`status` poll per wave + `open-round` + one `record-seat` per seat + one `status` poll after the
dispatch wave + `judge` + `release`. A RED round adds `status` (after the planner) + one
`close-story` per repair story + `status` + `open-round` + one `record-seat` per seat + `status` +
`judge`. The docs' figure "roughly 5 cycle-clerk calls" (`docs/token-economy.md:77`) is half the
real Tier 1 minimum and a quarter of Tier 3's.

Multipliers on top of the happy path (each one seen in the run files, section 0.1):

| Event | Extra dispatches | Bound |
|---|---|---|
| `close-story` verification > 600 s (clerk Bash cap) | +1 empty clerk (10 min), +1 `status` recovery clerk, +1 `status` poll, **+1 full worker re-dispatch** | **none** - never counted as a miss (H1) |
| Seat report MALFORMED (format, evidence, taint) | +1 whole seat re-dispatch (a suite re-run for sonnet) + 1-2 clerks | once per seat per round |
| Worker empty / red close | +1 worker on `TOP_MODEL` | 2 per story, then stop |
| Agent stalls | Workflow runtime retry after ~10 h | the runtime's own (1/5) |
| Any non-paperwork commit after GREEN (release bump, hand fix) | a whole new round: open-round + every seat + records + judge | none (`ship-check.sh:203-204`) |

## 2. Cost model

### 2.1 The fixed prefix every subagent pays on every turn

A Claude Code subagent starts with its own system prompt, its tool schemas, **the project memory
files** and its agent body; the brief assumed `CLAUDE.md` is loaded into subagents and the run
files agree: a clerk whose whole job is one Bash call costs 18.1-18.7 k tokens over 2 model turns,
which only adds up if ~9 k of prefix rides every turn.

| Component (VULYK repo) | Bytes | ~Tokens | Loaded into |
|---|---|---|---|
| `CLAUDE.md` (constitution) | 16 164 | 4 400 | Queen + every subagent, every turn |
| `AGENTS.md` (imported by `@AGENTS.md`, `CLAUDE.md` last line) | 599 | 160 | same |
| `.claude/rules/README.md` - has **no `paths:` frontmatter**, so it loads everywhere | 531 | 140 | same |
| `~/.claude/CLAUDE.md` (owner's global rules, mostly Cyrillic) | 8 619 | 2 500-3 500 | same - outside VULYK, but paid by every VULYK dispatch |
| Subagent system prompt + env block | - | 1 000-2 000 (unmeasured) | every subagent |
| Tool schemas | - | Bash only ~1 k; Read/Grep/Glob/Bash ~3 k; + Write/Edit ~4 k; `council-haiku` also names `mcp__chrome-devtools__*, mcp__claude-in-chrome__*` (`council-haiku.md:4`) - up to ~50 more schemas unless deferred | per agent |
| **Measured total, clerk** | | **~9 100-9 300 per turn** | |

In an installed hive the installer merges the VULYK constitution into the host's own `CLAUDE.md`
(`install.sh:216-239, 305-307`), so the prefix is host + VULYK. The owner's note on a hive with a
68 + 39 KB constitution: **~55 k per clerk dispatch**. Every multiplier below scales with that.

### 2.2 Per dispatch type

| Dispatch | Model / effort / maxTurns | Own body | Told to read (beyond the prefix) | Measured tokens (run files) |
|---|---|---|---|---|
| `cycle-clerk` | sonnet / low / 5 | 1.3 KB | nothing - but `close-story` streams the verification output into its context (`cycle.sh:1707`, `bash -c "$vline"` inherits stdout) | 18.1-18.7 k per verb; `close-story` 20-36 k and up to 5 tool calls |
| `worker-code` / `worker-test` | opus / medium / 90 | 3.2 KB | story (budget 6 KB, `templates/story.md:16`), **the map slice** (here 10.5-13 KB each, 126-167 lines against a cap of ~80, `drone-docs.md:25`), `.claude/rules/`, source, verification output every iteration | 24-118 k (mean ~52 k over 14) |
| worker retry | `TOP_MODEL` (Fable) | same + "`git diff` them first" | everything again from zero | - |
| `council-sonnet` | sonnet / session / 60 | 3.5 KB | `COURT/brief.md`, `COURT/CLAUDE.md` Profile + Commands (**a second copy of the constitution it already has in its prefix**, read through the Read tool), full-suite output, one probe per ask | 54-72 k |
| `council-opus` | opus / session / 60 | 3.6 KB | same minus the suite | (not in these runs) |
| `council-haiku` | sonnet / session / 60 | 4.1 KB | brief + Profile; browser MCP schemas | (not in these runs) |
| `lead-review` | `TOP_MODEL` / **high** / 60 | **7.3 KB** | "review its stories and plan" (plan.md here 15 KB, stories 3-9 KB each), "diff the branch ... against its base" (the whole branch, every round), **`docs/adr/001-cycle-state-contract.md` 34.5 KB (~9.3 k)** (`vulyk-cycle.js:131`), wiki + ADRs of touched modules (`lead-review.md:16`) | 129-184 k per round |
| `queen-planner` (repair) | `TOP_MODEL` / high / **no cap** | 3.2 KB | brief, seat reports under `round_dir`, `templates/story.md`, plan.md | 89 k |
| `drone-scout` | opus / low / 15 | 1.3 KB | the target area | - |
| `drone-coverage` | opus / medium / 5 | 3.1 KB | brief + plan | - |
| `drone-docs` (every ship) | opus / low / 40 | 3.2 KB | "the merged diff" + touched map/wiki + grep of map/wiki/ADRs | - |
| `librarian` (every ship) | opus / low / 25 | 3.8 KB | plan.md deltas + `docs/adr/` | - |
| Queen | opus / medium | - | `vulyk-plan.md` 6.1 KB, `vulyk-build.md` **16.2 KB**, `vulyk-ship.md` 5.4 KB, templates 13 KB, memory.md 4.1 KB, map slices, the handoff (<=12 000 chars), and it **writes** brief/plan/stories itself at Tier 1-2 (output tokens) | the transcript agent's number |

### 2.3 The multipliers

| # | Multiplier | Formula | VULYK repo | Host hive (~55 k/clerk) |
|---|---|---|---|---|
| M1 | **Clerk per verb** | clerks x 2 turns x prefix | Tier 1: 10 x 18.5 k = **185 k**; Tier 2 happy: 13 x 18.5 k = 240 k; Tier 3 + one RED: 30 x 18.5 k = 555 k | Tier 1: **550 k**; Tier 2: 715 k; Tier 3 + RED: **1.65 M** - before a single line of code |
| M2 | **Prefix x turns, every agent** | turns x (constitution + global) | a 40-tool-call worker resends ~9 k x 41 = 370 k of prefix | ~27 k x 41 = **1.1 M** for one worker |
| M3 | **Seats x rounds x re-reading** | per round: every required seat from zero + lead-review re-reads plan, stories, ADR-001 and the whole-branch diff | lead-review 129-184 k per round | same, plus prefix growth |
| M4 | **Suite runs per story** | worker (>= 1, until green) + `close-story` (x `repeat`) + council-sonnet (full suite, once per round) | `tests/council.test.sh` ~9-10 min on Windows: >= 20 min of suite per story before the council, `close-story` serial across the wave | same shape, the host's own suite |
| M5 | **Retry to the gate model** | a missed story and every repair plan run on `TOP_MODEL` | Fable 5.1 on Max: the docs' own Artificial Analysis figure is ~3x Opus 5.5 per task (`docs/model-cascade.md:24-27`) | same |
| M6 | **Unbounded restart** | close-story timeout -> status recovery -> worker again (H1) | 7 surplus workers + ~85 min on one spec | same |
| M7 | **Queen context growth** | small in the Workflow path: the run returns one object and the Queen reads only journal tail + seat files at wake-up (`vulyk-build.md:128-147`). Large in the fallback path (~120 lines of seat reports per round, `docs/token-economy.md:90-94`) and across plan -> build -> ship in one session (three command files = 27.7 KB loaded) | - | - |

Why "any size costs up to 3 M": M1 and M2 do not scale with the task. They scale with the number
of state changes (fixed by the loop's shape, ~10 at Tier 1) and with the size of the hive's
constitution. A button recolour in a hive with a 107 KB `CLAUDE.md` pays ~550 k in clerks and
~1 M in prefix re-sends inside its one worker and one seat before any real work is counted.

## 3. Holes

Ranked by token/time cost, highest first. Severity: **T** = token/time cost, **C** = correctness,
**D** = dead / unfinished / doc drift. "Seen" = observed in the run files of section 0.1.

| # | Hole | Evidence (`path:line`) | Sev | Fix direction (one line) |
|---|---|---|---|---|
| H1 | **`close-story` timeout restarts the worker, unbounded.** The clerk's Bash is capped at 600 s; a suite longer than that returns nothing; `clerk()` treats the empty line as a garble of a mutating verb, asks `status`, and hands back `{ok:true, recovered:'status'}`; the build branch reads `ok` and `continue`s, so the miss is never counted; the next poll shows the story still `todo` and the worker is dispatched again from zero on the same model. Nothing bounds the loop. **Seen:** 8 workers for 4 stories, 7 empty close-story clerks (~85 min), then story 05 four times in the next run. | `.claude/agents/cycle-clerk.md:16-18`; `.claude/workflows/vulyk-cycle.js:110-122` (recovered result), `:238-239` (`if (res.ok) continue`), `:251-253` (attempts only on the other path); `scripts/cycle.sh:1702-1716` (verification inside the verb) | **T, C** | Run verification outside the clerk (worker or a background job writing a result file), treat a recovered mutating verb as "unknown" not "ok", and count it toward the story's two-attempt bound. |
| H2 | **One LLM subagent per shell verb.** The Workflow runtime has no shell, so every `status`, `claim`, `branch`, `close-story`, `open-round`, `record-seat`, `judge`, `release` is a Sonnet subagent paying the full prefix twice. 10 clerks at Tier 1, 13 at Tier 2, 19-30 at Tier 3. **Seen:** 46 % of all driver tokens (1.25 M of 2.70 M on one spec); ~18.5 k per clerk here, ~55 k in a hive with a bigger constitution. | `.claude/workflows/vulyk-cycle.js:94-123`; clerk count per path in section 1.3; owner memory `vulyk-next-circle-clerk-json-loss.md` ("Clerk cost ~55k/dispatch ... the constitution is the lever") | **T** | Add one `cycle.sh advance` verb that performs every mechanical transition up to the next agent boundary and returns the dispatch list; let workers run their own `close-story` and seats their own `record-seat --file` (both already hold Bash). Tier 1 falls from 10 clerks to 2-3. |
| H3 | **The constitution rides every subagent turn.** `CLAUDE.md` is 16.2 KB; 9.1 KB of it (56 %: preamble, routing, ladder, cycle, token economy, compact, evolution) is Queen-only orchestration, 2.9 KB applies to all agents. Plus the owner's 8.6 KB global `CLAUDE.md` with four `🔴 MANDATORY` blocks. A clerk, a worker, a seat - each resends ~9 k (here) to ~27 k (host hive) per turn. The framework's own doc says to keep `CLAUDE.md` to standing instructions. | `CLAUDE.md:1-12, 31-112, 182-193, 201-220` (Queen-only); `docs/token-economy.md:105-106`; `install.sh:216-239` (merged into the host's `CLAUDE.md`); `~/.claude/CLAUDE.md` (7 MANDATORY/ОБЯЗАТЕЛЬНО markers) | **T** | Move routing/ladder/cycle/token-economy into the `/vulyk-*` commands (loaded only when the Queen runs them); keep `CLAUDE.md` to Laws + Secrets + Profile + Commands (~6 KB). |
| H4 | **`lead-review` is the extra-circle engine, and it cannot converge.** Prompt: "find reasons this change should NOT merge", "Report everything you found", "do not trim the list", BLOCK on any major; runs on Fable at effort high, re-reads the plan, every story, ADR-001 (34.5 KB) and the **whole branch diff** every round, as a fresh agent. Each round finds a *new* set of majors (round 1 of convergent-judge: 2 majors + 10 minors; round 2: 2 *different* majors + 10 minors); `no-progress` only catches the *same ask* twice. **Ledger:** BLOCK in 8 of 16 rounds; the only cause of 6 of the 11 non-GREEN rounds. | `.claude/agents/lead-review.md:10, 30, 34, 40`; `vulyk-cycle.js:130-131`; `scripts/cycle.sh:925-936` (no-progress = same ask only), `:947` (BLOCK -> RED); `docs/specs/convergent-judge/council/round-{1,2}/review.md`; `memory/stats/council.jsonl` | **T, C** | From round 2, review only the repair diff against the previous round's findings; BLOCK only on an anchored major with a reproducing command; cap the report; drop the "find reasons not to merge" framing on a frontier model. |
| H5 | **The story's verification runs at least three times, `close-story` runs serially.** Worker runs it until green; `close-story` runs it again (x `repeat`); `council-sonnet` runs the full suite once per round; `worker-test` is told to run "the full relevant suite". `close-story`s of a wave run one after another. On Windows `tests/council.test.sh` takes 9-10 min, so a 4-story wave pays >= 40 min of serial close-story alone. The constitution and ADR-008 call this "one suite run per close". | `.claude/agents/worker-code.md:16`; `scripts/cycle.sh:1700-1716`; `.claude/agents/council-sonnet.md:35-36`; `.claude/agents/worker-test.md:16`; `vulyk-cycle.js:228-255` (sequential for-loop); `docs/adr/008-approval-stop-and-study-work.md:51`; `CLAUDE.md:105` | **T** | Trust the worker's run when it reports the command and exit code and re-check deterministically (hash of files at run time) instead of re-running; run the full suite once per round, not per story; fast/full split as the owner already ordered. |
| H6 | **Every round re-dispatches every required seat from zero.** `missing_required_seats` looks only at the new round dir, so a seat that was GREEN on an unchanged ask is re-run, including `council-sonnet` (full suite each time) and `council-haiku`. Ledger: `council-sonnet` **0 RED in 16 rows**, `council-haiku` **0 RED** (6 N/A), `council-opus` 4 RED. | `scripts/cycle.sh:249-260, 1850`; `memory/stats/council.jsonl` (seat columns) | **T** | Carry a seat's GREEN forward when its asks' evidence is untouched by the repair diff; re-run only the seats (and asks) that went RED plus the reviewer on the repair diff. |
| H7 | **Parallel workers share one working tree.** A wave's workers edit the same checkout concurrently; each worker's verification and each `close-story` sees the other stories' uncommitted edits, so one story's break turns a neighbour's close red - a false miss that retries on the gate model. `scope-check.sh` counts every changed and untracked file in the tree, so every concurrent story "breaches" scope (convergent-judge: `out_of_scope` 34-41 per story). Its header claims the default range "is exactly that story's diff". | `vulyk-cycle.js:218-227` (no isolation); `scripts/scope-check.sh:12-15` (claim) vs `:65` (`git diff HEAD` + `ls-files --others`); `docs/specs/convergent-judge/next-circle.md:34` | **T, C** | One git worktree per worker (the court already proves the pattern), merged at close; scope-check the story's own path set only. |
| H8 | **No wall-clock budget per agent.** A stalled reviewer blocked round 1 for 10.3 h until the Workflow runtime's own stall detector retried it. The driver passes no timeout; `lead-review` holds Bash with no rule on long commands. | run log `wf_8275f24e-0e0.json`: `[stall] agent "Adversarial review ..." stalled (no progress) after 37159s - retrying (1/5)`; `vulyk-cycle.js:160-169` | **T** | Give each dispatch a deadline (race `agent()` against a timer and record the seat ABSENT/`worker threw`), and cap Bash in seat/reviewer prompts. |
| H9 | **Any non-paperwork commit after GREEN forces a whole new round.** The release commit (`VERSION`, `CHANGELOG.md`) that `/vulyk-ship` step 2 orders, a one-line hand fix, a doc tweak - each makes the GREEN row `STALE (commit)`, and the next launch re-runs the full court. Ledger: driver-hardening round 2 opened after a GREEN round 1 and ended ESCALATE env. | `scripts/ship-check.sh:203-204`; `scripts/lib.sh:42-52` (whitelist lacks `VERSION`, `CHANGELOG.md`); `docs/cycle.md:73`; `docs/specs/convergent-judge/next-circle.md:16` | **T** | Add release files to the paperwork whitelist; for a post-GREEN hand fix, re-judge only the diff since the GREEN head (reviewer on that diff), not a new full round. |
| H10 | **Dirty tree is checked only after the build.** `claim` and `branch` never check it; `open-round` does. **Seen:** an owner's untracked note let the driver build 4 stories (~3 h, 899 k tokens), then `open-round` refused and the run ended. A worker that touches a file outside `## Files` produces the same end, because `close-story` commits only `## Files`. | `scripts/cycle.sh:2192-2229` (claim), `:1165-1221` (branch), `:1959-1978` (open-round's check), `:1736-1741` (commit scope); journal `docs/specs/convergent-judge/journal.md` line 4 | **T** | Same cleanliness predicate at `claim`; at `close-story`, fail the story (not the run) on a stray file. |
| H11 | **`reopen` leaves `next: open-round`, not `repair`.** A relaunch after an owner's reopen re-councils unchanged code and collects the same BLOCK - a guaranteed wasted round unless the Queen cuts repair stories by hand first (what happened on convergent-judge). | `scripts/cycle.sh:2121, 2133`; `status` precedence `:489-497` | **T, C** | After `reopen`, `status` should route to `repair` with the escalated round's findings. |
| H12 | **A seat's format miss costs a whole seat run.** `record-seat` rejects attempt 1 for a missing label, an unevidenced GREEN/RED, an ASK count mismatch, or a "taint" (the seat echoing a spec path, even inside its own `run:` line); the driver re-dispatches the seat from zero (60 turns; sonnet re-runs the suite), serially inside the record loop. A second miss makes the seat ABSENT and the round ESCALATE `env` to the human - twice in the ledger, both with every judging seat GREEN. Meanwhile an **unevidenced RED still turns the round RED**. | `scripts/cycle.sh:1332-1393` (gates), `:1259-1276` (taint regex), `:943-947` (unevidenced RED counts); `vulyk-cycle.js:294-304`; ledger rows anomaly-telemetry r6, driver-hardening r2 | **T, C** | Re-ask by continuing the same agent (`SendMessage`) with "reformat only"; ignore taint inside backticked `run:` text; unevidenced RED should be `N/A`, like unevidenced GREEN. |
| H13 | **Tier 1 still pays the whole cycle.** A one-line change pays brief + plan + story + gate scripts + ~8 commits + 10 clerks + worker + seat + drone-docs + librarian = 14 dispatches; ADR-002 promised "two subagents". A Tier 1 RED is an immediate ESCALATE to the owner (ceiling 1, no repair). | `CLAUDE.md:42` (Tier 1 row); `docs/adr/002-council-scales-with-tier.md:48`; `scripts/cycle.sh:224-231`; `.claude/commands/vulyk-ship.md:108` | **T** | Tier 1 = worker + one reviewer + the Queen's Bash, no driver, no court, no ship drones; the council starts at Tier 2. |
| H14 | **Repair = a Fable planner writing new story files, then fresh workers from zero.** `queen-planner` runs on `TOP_MODEL`, effort high, **no maxTurns**, at every tier; the Workflow driver runs neither `wave-check` nor `trace-check` on what it cuts, and `trace-check` rejects the `## Asks` lines repair planners quote. **Seen:** 89 k tokens for the planner, then 4 dispatches of one repair story (H1). | `vulyk-cycle.js:311-326`; `.claude/agents/queen-planner.md:1-7`; fallback does run `wave-check` (`vulyk-build.md:76, 101`); `next-circle.md:15` | **T, C** | For <= 2 anchored findings, send the findings as conditions straight to one worker (or resume the original); planner only for plan-level (`plan`-routed) findings; cap planner turns. |
| H15 | **Redundant clerk calls on every run.** The Queen claims the semaphore, then the driver claims it again with the same stamp (idempotent no-op); the build and dispatch branches ignore the `status` that `close-story`/`record-seat` already carry and poll again; a BadLine recovery polls `status`, then the loop polls again. **Seen:** paired identical `status` clerks after every recovered close-story. | `.claude/commands/vulyk-build.md:32-37` + `vulyk-cycle.js:181`; `scripts/cycle.sh:2201-2207`; `vulyk-cycle.js:198, 333` (nextSt only for branch/open-round/judge); `scripts/cycle.sh:1761, 1321, 1435` (emit_status) | **T** | Drop the driver's claim or the Queen's; use the last carried status after a fan-out. ~2-4 clerks per run. |
| H16 | **The reviewer is pointed at VULYK's own ADR-001, which installed hives do not have.** `reviewPrompt` hard-codes `docs/adr/001-cycle-state-contract.md`; the installer ships `docs/adr/` without VULYK's ADRs. In a host hive the reviewer searches for it, or reads the host's own unrelated ADR-001. In VULYK itself it is 34.5 KB read every round. | `vulyk-cycle.js:131`; `install.sh:65` | **T, C** | Remove the pointer; the reviewer needs the brief's asks and the diff, not the cycle contract. |
| H17 | **Every ship dispatches `drone-docs` + `librarian`,** including Tier 1 and specs whose `## Plan deltas` is empty; `drone-docs` gets "the merged diff" through the Queen's context. | `.claude/commands/vulyk-ship.md:108`; `.claude/agents/librarian.md:20-27` | **T** | Skip the ADR harvest when deltas/descoped are empty; run `drone-docs` only when the diff touches a mapped module, and pass a range, not the diff. |
| H18 | **Map slices are twice their own cap, and workers read them whole.** Cap ~80 lines; actual 126-167 lines, 10.5-13 KB each. The worker prompt says "Read it fully, including the map slice it names". | `.claude/agents/drone-docs.md:25`; `memory/map/*.md`; `vulyk-cycle.js:220` | **T** | Enforce the cap in `drone-docs`/`/vulyk-map`; name sections, not files, in `## Map slice`. |
| H19 | **Two implementations of one state machine.** The Workflow driver (`vulyk-cycle.js`, 21 KB) and the fallback loop written as prose in `vulyk-build.md` (16 KB) must agree by hand; drift already recorded (the repair anchor rule, `wave-check` before waves, "cap 4 concurrent"). The 16 KB prose loads into the Queen on every `/vulyk-build`, even when the Workflow driver runs. | `.claude/commands/vulyk-build.md:55-111`; `vulyk-cycle.js`; `next-circle.md:42` | **T, D** | Keep one implementation; if a fallback stays, make it a script, not prose. |
| H20 | **Learnings capture is dead and noisy.** `session-end-learnings.sh` writes an empty stub every session (45+ files under `memory/learnings/`, no `CONSOLIDATED.md` exists); `VULYK_AUTOLEARN` runs `claude -p` inside a SessionEnd hook the platform caps at 60 s, so it can never finish (owner memory). The stubs inflate every story's scope count and needed a whitelist exception. | `.claude/hooks/session-end-learnings.sh:24-38`; `scripts/lib.sh:47-49`; owner memory `vulyk-chronicle-plugin-decisions.md` | **D, T** | Remove the hook (the Chronicle plugin was decided as its replacement), or write nothing unless there is content. |
| H21 | **Uncapped gate-model agents.** `queen-planner` and `lead-architect` have no `maxTurns` and run at effort high on the gate model; the driver's `CAPS` map duplicates frontmatter by hand. | `.claude/agents/queen-planner.md:1-7`; `.claude/agents/lead-architect.md:1-7`; `vulyk-cycle.js:34-35` | **T** | Give both a cap; derive `CAPS` from frontmatter or drop it. |
| H22 | **Docs that claim behaviour the code does not have.** "roughly 5 cycle-clerk calls" (real: 10-30); repair planner "Opus 5.5; the gate model at Tier 4" (code: `TOP_MODEL` at every tier); "a Tier 1 fix costs two subagents" (real: 14); "Workers - Sonnet-class ... where most tokens are spent" (Opus 5.5; clerks spend more); "one suite run per close" (two); "Seats and reviewers do not re-run the whole suite" vs `council-sonnet`'s "Run the full suite ... once, first"; `CLAUDE.md` "do not tell an agent to verify itself" vs `drone-docs` "Verify before you write"; `drone-scout` "dispatch liberally" vs the recon cap; `lead-review` "Use after /vulyk-build completes" vs its in-round seat role; `status` initialises `CEILING=3` for Tier 1/2. | `docs/token-economy.md:77-78`; `vulyk-cycle.js:325`; `.claude/commands/vulyk-plan.md:43`; `docs/adr/002-council-scales-with-tier.md:48`; `README.md:24`; `docs/adr/008-approval-stop-and-study-work.md:51`; `CLAUDE.md:29, 105`; `.claude/agents/council-sonnet.md:35`; `.claude/agents/drone-docs.md:39`; `.claude/agents/drone-scout.md:3`; `.claude/agents/lead-review.md:3`; `scripts/cycle.sh:419` | **D** | One pass to make docs describe the code; better, delete the prose that restates code. |
| H23 | **Dead or unreachable paths.** No writer ever sets `status: in-progress`, so `next: close-story:<file>` cannot occur; story `tier:`/`tracer:` are read by nothing in the loop (only `state.sh` displays `tier`); `compute_stage` is "not itself read by anything yet"; `council-haiku` is required at Tier 3-4 even when the Profile has no Client path (6 N/A of 16, 0 RED); an ABSENT seat (tooling failure) escalates to a human rather than retrying. | `scripts/cycle.sh:403-410, 483`; `templates/story.md:6-8`; `scripts/state.sh:108`; `scripts/cycle.sh:507-508, 943-944`; `docs/token-economy.md:79-81` | **D, T** | Delete `in-progress`/`tracer`; require the black-box seat only when `Client path` is filled; retry an ABSENT seat once before `env`. |
| H24 | **Owner's global rules inside every VULYK subagent.** `~/.claude/CLAUDE.md` (fact-check skill "MANDATORY" on any unfamiliar library, recommended-option rules, handoff-by-direction) is loaded into clerks, workers and seats - irrelevant to a clerk, and an invitation for a worker to run web fact-checks mid-story. Outside the repo, but paid by VULYK. | `~/.claude/CLAUDE.md` (four `🔴 MANDATORY` sections) | **T** | Scope those rules to the main session (a skill or output style), or tell subagents to ignore them. |
| H25 | **Hooks that run every turn.** `anomaly-scan.sh` runs `telemetry.sh scan` over the transcript on every `Stop` (python + jq; wall-clock, no tokens); `handoff.py` reads the transcript tail on every prompt and stop; the SessionStart handoff restore injects up to 12 000 chars into any session started within 12 h, whatever its topic. | `.claude/settings.json:31-35`; `.claude/hooks/anomaly-scan.sh:25-29`; `.claude/hooks/handoff.py:71, 813-844` | **T (low)** | Scan at SessionEnd only; restore the handoff only on `/clear`/`compact` or when the prompt names its topic. |
| H26 | **Tier 4 fold lets a PASS reviewer anchor the other reviewer's BLOCK** (concatenated bodies). | `vulyk-cycle.js:143-156`; `next-circle.md:35` (minor 12) | **C (low)** | Anchor only on the blocking reviewer's own critical/major lines. |

### 3.1 Loops that cannot converge or restart work

| Loop | Why it does not converge | Evidence |
|---|---|---|
| close-story timeout -> status -> worker again | the recovered status reads as success; `attempts` never increments | H1 |
| repair -> fresh reviewer on the whole branch -> new majors | each round is a new sample of an adversarial reviewer over an ever-larger diff; `no-progress` matches only the same ask number | H4 |
| reopen -> open-round on unchanged code | `next` is `open-round`, not `repair` | H11 |
| GREEN -> any code commit -> new full round | staleness is binary over the whole branch | H9 |
| seat MALFORMED -> whole-seat re-dispatch -> ABSENT -> ESCALATE env | a format rule decides the round, not the evidence | H12 |

### 3.2 Where one call could replace a chain

| Chain today | Dispatches | One call instead |
|---|---|---|
| `status` -> `branch` -> `status` (launch) and `close-story` x N -> `status` -> `open-round` (after a wave) | 3 + N+2 clerks | one `cycle.sh advance` clerk per agent boundary (H2) |
| `council-sonnet` + `lead-review` at Tier 1-2 | 2 agents + 2 record clerks | one reviewer (Opus 5.5) that runs each ask's command and reads the diff, writing one report |
| RED -> `queen-planner` -> new story files -> fresh worker(s) -> close | 1 planner + N workers + N clerks | send the anchored findings as conditions to one worker (resume the original where possible) |
| `drone-docs` + `librarian` at every ship | 2 agents | one docs pass, skipped when nothing mapped changed and no deltas exist |
| Queen claim + driver claim | 1 Bash + 1 clerk | one |

## 4. Principles: cost, what it buys, verdict

| Principle | Where | What it costs | What it buys | Verdict | Why (one line) |
|---|---|---|---|---|---|
| **Queen never reads source code** | `CLAUDE.md:102` | A scout per Tier 2 plan (prefix x up to 15 turns); map upkeep at every ship (`drone-docs`); plans drafted blind - most review findings in convergent-judge are routed `plan` | The Queen's long-lived context stays small | **Simplify** | At Tier 1-2, reading the 2-3 named files costs less than one scout's prefix; keep scouts for broad recon. |
| **Blind council** (court worktree, reduced spec dir, taint regex, BREACH) | `cycle.sh:1788-1858, 1259-1276`; `council-*.md:13-27` | A worktree + commit per round; whole-seat re-dispatch on a taint hit; two env-ESCALATEs from seats echoing paths; seats re-derive everything from zero each round | Judgement independent of the hive's own account; historically caught "a brief requirement delivered nowhere" (`docs/cycle.md:38-42`) | **Simplify** | Keep one blind intent seat (`council-opus`, the only seat with REDs: 4 of 10) from Tier 3; drop the sonnet seat (0 RED in 16) and the black-box seat unless `Client path` is filled; taint = warning. |
| **Clerk-only shell for the driver** | `vulyk-cycle.js:94-123` | 46 % of driver tokens; 10-30 subagents per task; the timeout loop (H1) | Background run, the Queen's context untouched, all state decided by `cycle.sh` on disk | **Simplify hard** | Keep "the script decides", drop "one subagent per verb": one `advance` verb per agent boundary, and workers/seats call their own verbs. |
| **Unanimity to GREEN** | `cycle.sh:938-964`; `docs/cycle.md:48-49` | Every judge can force a round; with `lead-review` at BLOCK 8 of 16, ~2 rounds per spec is the expected case, and a fresh reviewer per round rarely converges | No seat is ever overruled by a majority | **Simplify** | GREEN = no anchored, reproduced RED/BLOCK; from round 2 judge only the repair diff and last round's findings. |
| **Tier ceremony floor** (brief + plan + story + council + ship at Tier 1+) | `CLAUDE.md:42, 48`; ADR-002 "never to zero" | Tier 1 = 14 dispatches, ~8 commits, 10 clerks (~185 k here, ~550 k in a host hive) | Every change traceable to a verbatim ask and a verdict | **Simplify** | Tier 1 should be worker + one review, no driver; start the council at Tier 2. The traceability is worth it only where a round can actually be repaired (Tier 1 has ceiling 1). |
| **One worker per story, disjoint files per wave** | `queen-planner.md:16-20`; `wave-check.sh` | Each story = a worker prefix + re-orientation + a close-story clerk + a suite run + a commit; shared working tree breaks isolation (H7) | Law 3 scope boundary, one commit per story as rollback unit, parallel waves | **Keep, fix** | Right idea; give each worker its own worktree and push the payback test harder (fewer, larger stories at Tier 2). |
| **Map / memory system** (`memory.md`, `memory/map/`, `drone-docs`, `librarian`) | `CLAUDE.md:194-200`; `drone-docs.md`; `vulyk-map.md` | Slices at 2x their cap read whole by every worker; two drones at every ship; staleness checks | Recon reused across sessions and specs | **Simplify** | Keep a small pointer index; cap slices and point stories at sections; refresh maps on demand, not at every ship. |
| **Handoff hook** | `handoff.py` | Transcript tail read on every prompt/stop (time); up to 12 000 chars injected at SessionStart | Real session continuity; context-size warnings | **Keep, narrow** | Restore only on `/clear`/`compact` or when the topic matches. |
| **Learnings hook** | `session-end-learnings.sh` | An empty stub per session, 45+ files, scope noise, a whitelist exception | Nothing today: AUTOLEARN cannot run inside SessionEnd's 60 s | **Drop** | The owner already decided the Chronicle plugin replaces it. |
| **Telemetry** (anomaly scan, stats `.jsonl`) | `anomaly-scan.sh`; `telemetry.sh` (886 lines); `memory/stats/` | A scan on every `Stop`; `anomalies.jsonl` riding story commits; send is manual | `council.jsonl` is the most useful artefact in the repo (this audit's section 0 is built on it) | **Keep ledgers, simplify scan** | Keep `council.jsonl`; fix `scope.jsonl` (H7); scan once at SessionEnd. |
| **Approval stop by default** | ADR-008; `vulyk-plan.md:58-68` | One owner read per Tier 2+ plan | Prevents the v0.12 "built a plan nobody read" spend | **Keep** | Cheap and it removed the worst historical waste. |
| **Gate on `TOP_MODEL` (Fable on Max)** for review, repair planning, retries | ADR-012; `vulyk-cycle.js:162-167, 222, 325` | `lead-review` 129-184 k per round at ~3x Opus 5.5's price per task; the repair planner and every retry on Fable too | A reviewer that is not the model that wrote the code | **Simplify** | Review on Opus 5.5 with a narrowed scope; keep Fable for Tier 4 or a disputed BLOCK. Model diversity is also available from Sonnet. |
| **Verbatim requirements + `trace-check`** | `queen-planner.md:14`; `trace-check.sh` | Almost free (a script); rejects `## Asks` quotes, so repair stories fail it | Stops invented work at plan time | **Keep, fix** | Accept `## Asks` items as a quote source. |
| **Disk as the only state + a commit per state change** | ADR-001; `cycle.sh` | ~8+ paperwork commits per spec; the paperwork whitelist and the staleness rules that grew around it (H9) | Crash-safe resume; the run can be re-launched from disk | **Keep the disk, cut the commits** | Resume needs the files, not a commit for each; staleness should look at code paths only. |
| **Law 5 - the Queen never touches story code** | `CLAUDE.md:19` | A two-line review fix costs a worker + close + a whole council round | The Queen's context never carries a diff | **Simplify** | Allow the Queen's own fix for review minors and Tier 1, checked by one reviewer on that diff. |

## 5. What this audit could not settle from the code alone

| Question | Why it matters | Who can settle it |
|---|---|---|
| Are the `mcp__chrome-devtools__*` / `mcp__claude-in-chrome__*` schemas loaded eagerly into `council-haiku`, or deferred? | Up to ~50 tool schemas per turn of the black-box seat | the transcript agent (first-turn input of a haiku seat) |
| Does the Claude Code Bash tool kill a command at its timeout or background it? | Decides whether a timed-out `close-story` still commits (the run files suggest the fourth attempt eventually landed) | the Anthropic-guidance agent / a 1-line experiment |
| Share of cache reads in the 18.5 k per clerk | Tokens vs. money vs. the subscription limit are not the same number | the transcript agent (`usage.cache_read_input_tokens`) |
| Why `council-sonnet` round 1 also ran 634 min | Whether the court's suite hung, or the machine slept | the transcript agent, `wf_8275f24e-0e0` seat transcript |
