# Token forensics - VULYK in the owner's real projects

Date: 2026-09-26 · Author: forensics agent (study work, no code changed) · Window: recent = 2026-09-13 .. 2026-09-26 (VULYK v0.12+), older = before 2026-09-13.

All scripts and intermediate data: `C:\Users\Andrei\AppData\Local\Temp\claude\E--Projects-vulyk\ab3ad363-426f-4070-af5d-43b2737db097\scratchpad\forensics\` (called `F\` below). Every number in this file names the script that produced it.

## Key numbers (details and scripts in the sections below)

| # | Finding | Number | Section |
|---|---|---|---|
| 1 | The owner's "~3M per task" is most likely the Workflow's printed `totalTokens`, which is the **sum of each agent's final context size**, not tokens processed | per task median 2.56M printed vs **84.9M raw / 13.5M weighted** processed (~29x); owner projects only: 96.4M / 15.8M | 0, 8 |
| 2 | Cache reads dominate raw tokens | 95.4% of raw | 1 |
| 3 | A median cycle task | 67.5 dispatches (43 clerks, 9.5 workers, 5 seats, 2.5 lead-review), 3 Workflow launches, 2 sessions, 165 active min, ~21 h elapsed | 1, 6 |
| 4 | Where weighted spend goes | Queen 30.5% · workers 30% · review apparatus 30.7% (seats 13.4%, lead-review 9.7%, clerks 7.6%) | 2 |
| 5 | Fixed cost of a dispatch | 27-36k-token first request, ~85% of it the inherited CLAUDE.md bundle, almost all a fresh cache write; fixed part = **23% of weighted spend** | 3 |
| 6 | cycle-clerk | 1,938 dispatches in 13 days, ~34k tokens each to return one JSON line; 6.2% of weighted spend; `status` polled 647 times | 3 |
| 7 | Queen context | median 239k tokens per call, ~120 calls per session - the same as the owner's non-VULYK sessions, so not the differentiator | 4 |
| 8 | Circles | 82% of specs run >= 2 rounds; only 32% are GREEN on round 1 and half of those are re-judged anyway at a new head (8 GREEN-after-GREEN rounds); lead-review BLOCK triggers 39 of 64 non-GREEN rounds (sole trigger in 14); extra circles = **29.5%** of the affected tasks' spend, median 3.05M weighted per extra round | 5 |
| 9 | Runs that stop early | 96 of 172 vulyk-cycle runs (56%) end before any verdict (dirty tree 28, `already done` 18, NEEDS_CONTEXT 15, verification not in Commands 10) and are relaunched | 7c |
| 10 | Review re-dispatch loop (katan, Tier 4, v0.17.0) | 44 lead-review dispatches where 6 were expected; surplus reviews overall 200M raw / 31M weighted | 5d, 7b |
| 11 | Seats hit their turn cap | council-sonnet/opus p90 = 60 calls = `maxTurns`; 67 empty-seat log lines in 39 runs | 2, 5 |
| 12 | VULYK vs non-VULYK, matched by changed code lines | **2.2-2.3x weighted tokens, 2-2.8x active time** at 500+ lines; parity at 101-500 lines; elapsed 21 h vs 2 h median; harness cost per session median $45 vs $19 | 6, 8 |

## 0. Method, definitions, and which "token" figure the owner sees

**Data.** 1,844 main sessions, 4,998 subagent transcripts (incl. workflow agents), 174 workflow run records, 60,751 Queen API calls and 94,028 subagent API calls across every dir under `~/.claude/projects` (`F\parse_all.py` -> `sessions.jsonl`, `agents.jsonl`, `workflows.jsonl`, `calls_main.csv`, `calls_agent.csv`). An API response written as several lines (one per content block) is deduped by `message.id`, keeping the max of each usage field.

**Validation.** For the 355 sessions (>1M tokens) that carry the harness's own `cost-state` ledger, the parsed total (Queen + all subagents) is a median **95.5%** of the harness total (p10 86.8%, p90 100%); cache reads 94.8%, cache writes 98.8% in aggregate. The transcripts under-report uncached input (1.5% of the harness figure - small side calls not logged) and output (74%). All figures below are therefore slight *under*-counts (`F\validate.py`).

**Session classes** (`F\build_tables.py` -> `session_table.csv`): a session is **VULYK** if it dispatches any VULYK agent (worker-*, council-*, lead-*, drone-*, cycle-clerk, queen-planner, librarian), runs the vulyk-cycle Workflow, a `/vulyk-*` command or Skill, or `scripts/cycle.sh`/`journal.sh`. `instr_vulyk` separately records whether the VULYK constitution was in the loaded CLAUDE.md.

**Task** (`F\task_table.py` -> `task_table.csv`) = (project, spec slug). Workflow agents go to the run's `args.spec`; other subagents to the first `docs/specs/<slug>` in their prompt; each Queen API call to the slug the Queen last named (Skill/command arg, Workflow arg, Agent prompt, edited path, Bash command). Active wall-clock = merged Queen+subagent event timestamps, gaps <= 15 min summed. A **cycle task** = a task with >= 1 vulyk-cycle run, council seat dispatch, or council-ledger row. 44 recent cycle tasks qualify.

**Token measures used throughout.**

| Measure | Definition | Note |
|---|---|---|
| raw | input + cache write + cache read + output, summed over every API call | what a "total tokens processed" counter shows |
| weighted | input + 1.25 x cache-write(5m) + 2 x cache-write(1h) + 0.1 x cache-read + output | the brief's cost approximation; output left at 1x as the brief instructs, so output is under-weighted relative to real prices |
| wf totalTokens | the `totalTokens` field of the Workflow run record | what the harness prints when a vulyk-cycle run ends |

**What `wf totalTokens` actually is** (`F\item0_check.py`, 2,798 workflow agents): each workflow agent's `tokens` equals **that agent's final context size** (last request's input + cache write + cache read) - true within 2% for **99.6%** of agents; the cumulative sum is ~2x larger even per agent. The run's `totalTokens` is the sum of those final context sizes. It is not consumption: an agent that took 40 turns is counted once, at its last context.

**Which figure the owner sees.** The owner's "up to ~3M tokens per task" matches `wf totalTokens`: vulyk-cycle runs have median 0.60M, p75 1.05M, max 4.65M per run (170 runs), and summed per task median **2.56M**, p75 3.96M (`F\item0_check.py`, `F\item1.py`). Per run, raw tokens processed are a median **13.3x** the printed totalTokens (weighted 2.6x); per task, **~29x**, because a task also pays for its Queen session and for dispatches outside the Workflow. So the owner's number is real but it *understates* the spend by an order of magnitude - it also omits the Queen's own session entirely.

| Recent cycle tasks (n=44) | median | p75 | max |
|---|---|---|---|
| wf totalTokens (owner's figure) | 2.56M | 3.96M | 17.2M |
| raw tokens processed | **84.9M** | 188.6M | 577.1M |
| weighted (cost approximation) | **13.5M** | 27.6M | 87.3M |

Harness-reported dollar cost (the `cost-state.totalCostUSD` the harness itself computes per session, not an estimate of mine) is in `session_table.csv` column `cost_usd`; e.g. the mmorpg web-bridge-p1 session `bfc65f95` reports **$153.89**.

## 1. Cost per VULYK task

Scripts: `F\task_table.py`, `F\item1.py`, `F\item1b.py`, `F\item1c.py`. Data: `F\item1_recent_tasks.csv`, `F\item1_stats.json`.

### 1a. Distribution, 44 recent cycle tasks (2026-09-13..26)

| Per task | median | p75 | max | mean |
|---|---|---|---|---|
| raw tokens | 84.9M | 188.6M | 577.1M | 126.9M |
| weighted tokens | 13.5M | 27.6M | 87.3M | 19.6M |
| of which Queen (main session) raw | 38.2M | 64.5M | 183.8M | 47.4M |
| of which subagents raw | 42.8M | 111.0M | 472.3M | 79.5M |
| active wall-clock (min) | **165** | 336 | 670 | 228 |
| sessions spanned | 2 | 3 | 6 | 2.1 |
| subagent dispatches | **67.5** | 97.5 | 237 | 72.3 |
| - cycle-clerk | **43** | 63 | 140 | 44 |
| - worker-code + worker-test | 9.5 | 15 | 36 | 10.9 |
| - council seats (sonnet/opus/haiku) | 5 | 9 | 25 | 6.7 |
| vulyk-cycle runs launched | 3 | 6 | 12 | 3.9 |
| council rounds (ledger) | 2 | 3 | 7 | 2.5 |
| repair waves (from run logs) | 0 | 1.25 | 4 | 0.84 |
| "seat returned empty - turn cap" events | 0 | 0.25 | 10 | 1.0 |

Composition across all 44 tasks: **cache reads are 95.4% of raw tokens**; the Queen is 37.3% of raw and 30.5% of weighted.

### 1b. By model (all 44 recent cycle tasks together, `F\item1b.py` -> `item1_models.csv`)

| Model | raw | share raw | weighted | share weighted | API calls |
|---|---|---|---|---|---|
| claude-opus-5 | 1,724M | 30.9% | 230M | 26.7% | 10,919 |
| claude-sonnet-5 | 1,708M | 30.6% | 297M | **34.5%** | 22,988 |
| claude-opus-5-5 | 1,385M | 24.8% | 202M | 23.4% | 9,533 |
| claude-fable-5-1 | 661M | 11.8% | 113M | 13.1% | 4,161 |
| claude-opus-4-8 | 71M | 1.3% | 12M | 1.4% | 765 |
| claude-haiku-4-5 | 28M | 0.5% | 8M | 0.9% | 660 |
| **total** | **5,577M** | | **862M** | | 48,030 |

Totals by field: input 0.22M · cache write 5m 193.5M · cache write 1h 25.8M · cache read 5,322M · output 36.0M. Sonnet 5 carries the largest weighted share because it runs the clerks and council-sonnet, each of which pays a fresh ~25-35k-token cache write when dispatched (section 3).

### 1c. Top 10 recent tasks by raw tokens (`F\item1c.py`)

Tokens in millions. `wf tT` = the owner-visible Workflow totalTokens summed over the task's runs.

| project | slug | first | raw | weighted | wf tT | Queen % | dispatches | clerks | workers | seats | lead-review | wf runs | rounds | final | repairs | empty seats | active h | sessions |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Recall | directions-projects-tags | 09-22 | 577.1 | 87.3 | 17.2 | 18 | 229 | 139 | 36 | 25 | 16 | 11 | 7 | GREEN | 1 | 10 | 9.5 | 2 |
| katan | ui-redesign | 09-23 | 460.7 | 69.5 | 4.5 | 19 | 86 | 39 | 15 | 4 | 14 | 2 | 1 | RED | 1 | 1 | 9.5 | 3 |
| YouTube_AI | 08-edit-video-mcp | 09-17 | 322.7 | 46.6 | 5.6 | 57 | 140 | 94 | 22 | 9 | 3 | 10 | 3 | ESCALATE | 2 | 2 | 11.2 | 4 |
| mmorpg | web-bridge-p1 | 09-24 | 295.3 | 48.0 | 10.4 | 19 | 173 | 107 | 21 | 22 | 10 | 4 | 6 | ESCALATE | 4 | 8 | 10.0 | 1 |
| fibi-next | acr-cosmetic-change-judge | 09-16 | 265.9 | 34.2 | 0 | 52 | 33 | 0 | 19 | 6 | 5 | 0 | 2 | RED | 0 | 0 | 4.9 | 3 |
| mmorpg | angela-second-base-bugs | 09-13 | 260.8 | 36.1 | 0.3 | 48 | 47 | 6 | 8 | 9 | 3 | 2 | 2 | GREEN | 0 | 0 | 3.8 | 6 |
| mmorpg | multibase-picker | 09-15 | 260.2 | 35.3 | 0 | 47 | 51 | 0 | 12 | 9 | 3 | 0 | 3 | GREEN | 0 | 0 | 3.9 | 4 |
| YouTube_AI | 11-video-skills | 09-21 | 254.0 | 40.3 | 8.9 | 17 | 170 | 112 | 24 | 21 | 6 | 7 | 4 | RED | 3 | 4 | 7.0 | 4 |
| katan | ui-redesign-p1-chart | 09-25 | 246.7 | 44.2 | 13.8 | 11 | 237 | 140 | 31 | 15 | 44 | 7 | 3 | ESCALATE | 2 | 6 | 7.9 | 1 |
| mmorpg | web-accounts-p0 | 09-23 | 210.5 | 31.3 | 5.9 | 30 | 106 | 63 | 22 | 10 | 3 | 5 | 2 | ESCALATE | 1 | 5 | 5.4 | 2 |

Readings:
- The ~3M the owner quotes is the *small* number. Every top-10 task processed 210-577M raw tokens (31-87M weighted); even the median task is 85M raw / 13.5M weighted.
- A median task needs **3 vulyk-cycle launches**, spans 2 sessions and 165 active minutes, and dispatches ~68 subagents, of which **43 are cycle-clerks** (one shell verb each).
- Tasks run without the Workflow driver (fibi-next acr-cosmetic-change-judge, mmorpg multibase-picker) put ~50% of their raw spend in the Queen instead - the loop moved into the main session.
- 7 of the top 10 ended RED or ESCALATE, not GREEN.

## 2. Where the tokens go inside a task

Script: `F\item2.py` -> `F\item2_types_cycle_tasks.csv`, `F\item2_type_medians_recent_sessions.csv`.

### 2a. Share by role, all 44 recent cycle tasks (5,584M raw / 863M weighted)

| Role | dispatches | per task | turns / dispatch | avg raw per dispatch | total raw | share raw | share weighted |
|---|---|---|---|---|---|---|---|
| **Queen (main session)** | 94 session-segments | 2.1 | 80 | 22.2M | 2,084M | **37.3%** | **30.5%** |
| worker-code | 450 | 10.2 | 37.3 | 3.63M | 1,635M | 29.3% | 28.1% |
| lead-review | 177 | 4.0 | 26.3 | 2.79M | 493M | 8.8% | 9.7% |
| cycle-clerk | **1,935** | **44.0** | 2.1 | 0.06M | 111M | 2.0% | **7.6%** |
| council-sonnet | 132 | 3.0 | 41.3 | 2.99M | 394M | 7.1% | 6.4% |
| council-opus | 85 | 1.9 | 38.5 | 3.07M | 261M | 4.7% | 4.5% |
| queen-planner | 78 | 1.8 | 11.8 | 1.01M | 79M | 1.4% | 2.8% |
| council-haiku | 77 | 1.8 | 22.5 | 1.70M | 131M | 2.3% | 2.5% |
| drone-docs | 30 | 0.7 | 31.3 | 3.12M | 94M | 1.7% | 1.6% |
| drone-scout | 53 | 1.2 | 17.2 | 1.27M | 67M | 1.2% | 1.5% |
| worker-test | 28 | 0.6 | 34.5 | 2.76M | 77M | 1.4% | 1.5% |
| worker-doc (project-local) | 16 | 0.4 | 33.6 | 2.88M | 46M | 0.8% | 0.8% |
| librarian | 22 | 0.5 | 15.2 | 1.11M | 24M | 0.4% | 0.5% |
| general-purpose / Explore / fork | 22 | 0.5 | 20-28 | 1.5-3.1M | 50M | 0.9% | 0.9% |
| lead-architect | 12 | 0.3 | 11.2 | 0.86M | 10M | 0.2% | 0.3% |
| drone-coverage | 24 | 0.5 | 2.5 | 0.10M | 2M | 0.0% | 0.2% |
| other project-local agents (redkollegiya-*, security-reviewer, ...) | 39 | 0.9 | - | - | 19M | 0.3% | 0.5% |

Grouped: **Queen 30.5%** of weighted spend · **implementation (workers) 30.4%** · **review apparatus (3 seats + lead-review + clerks) 30.7%** (seats 13.4%, lead-review 9.7%, clerks 7.6%) · planning/recon/docs ~8%.

### 2b. Per-dispatch medians, every recent VULYK session (not only cycle tasks)

| Agent type | dispatches | median API calls | p90 calls | median raw | median weighted | median duration | p90 duration | median peak context |
|---|---|---|---|---|---|---|---|---|
| cycle-clerk | 1,941 | 2 | 2 | 62k | 38k | 0.1 min | 0.3 min | 28k |
| worker-code | 503 | 31 | 75 | 2,092k | 342k | 5.6 min | 20.1 min | 87k |
| lead-review | 180 | 20 | 53 | 1,886k | 371k | 7.5 min | 12.2 min | 127k |
| council-sonnet | 133 | 42 | 60 | 2,807k | 405k | 5.6 min | 13.7 min | 93k |
| council-opus | 86 | 37 | 60 | 2,624k | 409k | 5.7 min | 11.0 min | 104k |
| queen-planner | 80 | 11 | 19 | 715k | 215k | 6.4 min | 20.5 min | 108k |
| council-haiku | 78 | 19.5 | 40 | 1,111k | 208k | 2.4 min | 6.9 min | 83k |
| drone-scout | 77 | 16 | 31 | 990k | 238k | 1.9 min | 4.3 min | 101k |
| general-purpose | 49 | 12 | 59 | 903k | 201k | 2.4 min | 8.5 min | 94k |
| drone-docs | 31 | 27 | 48 | 2,110k | 341k | 3.0 min | 6.1 min | 108k |
| worker-test | 29 | 30 | 65 | 2,027k | 324k | 6.5 min | 27.1 min | 107k |
| drone-coverage | 27 | 2 | 3 | 78k | 59k | 0.6 min | 1.5 min | 43k |
| librarian | 23 | 7 | 35 | 362k | 99k | 1.6 min | 6.2 min | 59k |

Readings:
- The Queen is the single largest consumer (30-37%), even though VULYK's rule is that the Queen only dispatches. It runs ~80 API calls per task-session, each re-reading a large context (section 4).
- council-sonnet and council-opus hit the p90 of **60 calls**, which is exactly their `maxTurns: 60` - the seats run into the ceiling (the driver logs "seat returned empty - turn cap suspected", section 1a).
- A single council seat (2.6-2.8M raw) costs about as much as a worker that writes a story (2.1M raw median). One council round = 3 seats + lead-review ~ 8.4M raw / ~1.4M weighted at medians - about four median workers.
- cycle-clerk is only 2% of raw tokens but **7.6% of weighted cost**: nearly all of its tokens are fresh cache *writes* (next section).

## 3. Fixed overhead per dispatch

Scripts: `F\item3.py` -> `F\item3_first_request.csv`, `F\item3_clerk_verbs.csv`; `F\item3b.py`. Population: 3,353 subagent dispatches in recent VULYK sessions (total spend of those sessions: 6,929M raw / 1,053M weighted).

### 3a. First request per agent type (system prompt + CLAUDE.md bundle + tool schemas + prompt)

| Agent type | n | median first request | p90 | median fresh cache write in it | median share served from cache | median CLAUDE.md-bundle chars | first request as % of the type's weighted spend | fixed prefix re-read on every turn, % of type's weighted |
|---|---|---|---|---|---|---|---|---|
| cycle-clerk | 1,938 | 27.0k | 36.3k | 24.7k | 15% | 57,060 | **82.5%** | **90.9%** |
| worker-code | 503 | 31.4k | 40.3k | 26.3k | 15% | 55,855 | 5.9% | 26.6% |
| lead-review | 180 | 34.5k | 37.1k | 32.2k | 0% | 58,665 | 7.8% | 25.3% |
| council-sonnet | 133 | 36.1k | 41.0k | 29.0k | 0% | 57,060 | 9.1% | 40.9% |
| council-opus | 86 | 32.6k | 37.0k | 31.9k | 0% | 57,060 | 7.8% | 32.6% |
| queen-planner | 80 | 29.5k | 39.8k | 29.5k | 0% | 35,921 | 10.5% | 20.3% |
| council-haiku | 78 | 48.2k | 57.9k | 48.2k | 0% | 46,330 | 20.6% | 56.4% |
| drone-scout | 77 | 28.4k | 41.7k | 27.0k | 0% | 35,764 | 14.1% | 35.2% |
| drone-coverage | 27 | 28.0k | 39.1k | 28.0k | 0% | 57,060 | 55.4% | 62.6% |
| librarian | 23 | 31.8k | 40.6k | 31.8k | 0% | 58,665 | 18.1% | 40.9% |

- Every dispatch starts at **~27-36k tokens** (council-haiku 48k: browser MCP tool schemas), and almost all of it is a **fresh cache write** - consecutive dispatches of different agent types share no prefix, and even back-to-back clerks reuse only ~15% of theirs.
- What fills it (`F\item3b.py`): clerk first-request tokens ~= 4.6k + 0.48 x CLAUDE.md-bundle chars (fit over 9 projects' medians). The bundle every subagent inherits is 57-65k chars in the heavy projects - e.g. mmorpg: global `CLAUDE.md` 5.1k + project `CLAUDE.md` 8.8k + **`CLAUDE.vulyk.md` 30.7k** + `AGENTS.md` 0.6k + rules README 0.5k + auto-memory `MEMORY.md` 14.3k chars. At ~0.48 tokens/char that bundle is ~28k of the clerk's ~34k first request (**~85%**). In fibi-next `CLAUDE.vulyk.md` is 27.9k chars, in Recall/katan/our-home ~14.6k.
- **Totals:** first requests alone are **106M weighted = 10.1%** of all recent VULYK spend. Counting that fixed prefix as it is re-read on every later turn of the same agent, the fixed part is **244M weighted = 23.2%** of spend (21.2% of raw).

### 3b. cycle-clerk: one shell verb per dispatch

| verb | dispatches | median Bash time | p90 | max | total Bash wall time | weighted tokens |
|---|---|---|---|---|---|---|
| cycle status | 647 | 3.7 s | 8.4 s | 18 s | 50 min | 19.4M |
| cycle record-seat | 421 | 2.5 s | 6.7 s | 16 s | 20 min | 16.2M |
| cycle close-story | 339 | 8.2 s | **301 s** | **1,193 s** | **424 min** | 12.5M |
| cycle claim | 148 | 0.7 s | 0.8 s | 1 s | 2 min | 5.1M |
| cycle release | 145 | 0.7 s | 0.8 s | 1 s | 2 min | 4.7M |
| cycle open-round | 121 | 3.2 s | 8.0 s | 18 s | 8 min | 3.8M |
| cycle judge | 80 | 4.3 s | 9.9 s | 25 s | 8 min | 2.5M |
| cycle branch | 34 | 1.8 s | 3.7 s | 7 s | 1 min | 1.1M |

- **1,938 clerk dispatches** in 13 days of recent VULYK work: 111M raw, **65.5M weighted = 6.2%** of all recent VULYK spend, ~44 per cycle task. Each one is ~27k tokens of first request plus a second call that re-reads it, to run a command whose median runtime is 0.7-8 s and whose useful output is one JSON line: all clerks together emitted 1.1M output tokens against 46.4M tokens of cache writes.
- `status` (647) is the most frequent verb - the driver polls the state machine through a subagent each time.
- 10% of `close-story` calls sit on the verification suite for **5+ minutes**, max ~20 min; `close-story` alone accounts for 424 min of Bash wall time. Tokens are not billed while waiting, but the cycle's wall-clock is.
- Model: clerks ran on claude-sonnet-5 (3,663 calls) and claude-haiku-4-5 (370 calls, before the Haiku ban).

## 4. The Queen's own context

Scripts: `F\item4.py` -> `F\item4_queen_sessions.csv`; `F\item4b.py` -> `F\item4b_injected.csv`. Comparison group: 71 recent non-VULYK work sessions (>= 3 edits, no VULYK constitution loaded).

### 4a. Context per Queen turn

| Queen, recent sessions | VULYK (86 sessions, 11,404 calls) | non-VULYK work (71 sessions, 9,808 calls) |
|---|---|---|
| API calls per session: median / p75 / max | 120 / 185 / 398 | 108 / 183 / 531 |
| context per call: median / p75 / p90 | **239k / 335k / 422k** | 272k / 411k / 536k |
| per-session peak context: median / max | 322k / 771k | 346k / 725k |
| first-call context (fixed start) | **80k** | 72k |
| cache reads as share of Queen raw | 98.3% | 98.6% |
| full cache rewrites (write > 50% of a >50k context) | 152, = 9.9% of Queen weighted | 85, = 6.5% |
| - of which after an idle gap > 5 min (> 60 min: 58) | 61 | 25 |
| share of Queen cache writes on the 1-hour TTL (2x price) | 99.1% | 100% |

Growth of the VULYK Queen's context with turn number (median per bin): calls 1-25: 115k · 26-50: 174k · 51-100: 235k · 101-200: 327k · 201-400: 457k. Each turn re-reads the whole context, so a 120-call session at ~240k per call is ~29M cache-read tokens (~2.9M weighted) before any output.

Readings:
- The Queen **does balloon** - it ends a typical session at 300-450k tokens - but so do the owner's non-VULYK sessions; per-turn context is not what separates the two. What separates them is how many sessions and turns a task takes (section 1: 2 sessions, ~80 Queen calls per task-segment) and everything the Queen dispatches.
- The Queen starts ~8k tokens heavier in VULYK sessions (80k vs 72k at call 1): the loaded CLAUDE.md bundle is 54k chars (median) vs 29k chars in non-VULYK sessions.
- Full rewrites of the Queen's context (`F\item4c.py`): of 152, 79 are the first call of a session, **58 follow an idle gap > 60 min** - the 1-hour cache TTL expired while the Queen waited (typically on a multi-hour vulyk-cycle run or on the owner) - 3 are mid-session model switches, 13 other. The 58 post-gap rewrites cost 25.0M weighted (6.6% of the Queen's weighted spend); all rewrites 37.5M (9.9%).
- The largest Queen sessions re-read 80-146M tokens of cache each (fibi-next `6571d28b` 398 calls / 139.8M, YouTube_AI `97f23534` 392 calls / 146.2M).

### 4b. Hook- and harness-injected context (chars; ~0.48 tokens per char, section 3)

| Source | VULYK sessions with it | median chars per session | non-VULYK median |
|---|---|---|---|
| CLAUDE.md bundle (harness `instructions`) | 82 / 86 | **54,367** | 28,975 |
| skill listing (harness) | 86 / 86 | 35,156 | 33,879 |
| deferred-tools list (harness) | 86 / 86 | 20,882 | 9,766 |
| agent listing (harness) | 86 / 86 | 12,727 | 12,859 |
| `total_tokens` reminders (harness, per turn) | 86 / 86 | 9,823 (~115 per session) | 9,212 |
| MCP server instructions (harness) | 82 / 86 | 4,372 | 3,383 |
| SessionStart additionalContext - owner's global `context_guard.py` | 76 / 86 | 923 | 1,772 |
| UserPromptSubmit additionalContext - owner's global `skill_router.py` | 63 / 86 | 2,207 | 1,708 |
| UserPromptSubmit additionalContext - global `context_guard.py` | 47 / 86 | 522 | 437 |
| SessionStart additionalContext - VULYK hooks | 1 / 86 | 15,281 | - |
| Stop hook system messages (context meter) | 45 / 86 | 313 | 193 |

- Hook injections are small: a few KB per session, and VULYK's own hooks injected context in only 1 of 86 recent sessions. They are not a cost driver.
- The VULYK-specific addition is the constitution in the CLAUDE.md bundle (`CLAUDE.md` + `CLAUDE.vulyk.md`): +25k chars (~12k tokens) per Queen request, re-read on every turn, and **inherited by every subagent** (section 3), where it is paid as a fresh cache write ~2,000 times in 13 days.

## 5. Circles (council rounds)

Scripts: `F\council_collect.py` -> `council_all.jsonl`; `F\item5.py` -> `item5_specs.csv`, `item5_nongreen_rounds.csv`; `F\item5b.py` -> `item5_round_cost.csv`, `item5_extra_circles.csv`; `F\item5c.py` -> `item5_review_loops.csv`.

**Ledger hygiene first.** The 20 project ledgers hold 242 lines but only **101 unique rounds over 38 specs**: the fibi-* worktrees share one ledger through git, and the installer copied VULYK's own rows (`autonomous-cycle`, `anomaly-telemetry`, ...) into 17 user projects before 0.17.0 stopped shipping `council.jsonl`. Counting per project without dedup would inflate rounds ~2.4x.

### 5a. Rounds per spec

| Period (date of the spec's first round) | specs | mean rounds | median | max | GREEN on round 1 | final GREEN | final ESCALATE | final RED |
|---|---|---|---|---|---|---|---|---|
| 2026-09-13 .. 09-23 (v0.12-0.16) | 31 | 2.71 | 2 | 7 | 10 (32%) | 22 | 6 | 3 |
| 2026-09-24 .. 26 (0.17.0 released 09-24) | 7 | 2.43 | 2 | 6 | 2 (29%) | 4 | 2 | 1 (open) |

Rounds-per-spec histogram: 09-13..23: 1 round x4, 2 x12, 3 x10, 4 x2, 5 x1, 6 x1, 7 x1 · 09-24..26: 1 x3, 2 x1, 3 x2, 6 x1.

Caveat on "after 0.17.0": of the 7 post-09-24 specs only **katan** (ui-redesign, ui-redesign-p1-chart) and **vulyk** (convergent-judge) actually ran 0.17.0; mmorpg and fibi-next run 0.16.0 (`.claude/vulyk-version`). Too few specs to call a trend. What the data does say: **31 of 38 specs (82%) ran two or more rounds**; only 12 (32%) were GREEN on round 1, and **6 of those 12 were judged again anyway** - 8 further rounds, all GREEN, each at a new branch head (e.g. fibi-next `acr-class-a-autorun`: three GREEN rounds in 60 minutes, one per Workflow launch; AI `worklog`: three GREEN rounds in 30 minutes). A GREEN verdict does not end the circle if anything is committed after it: the round goes stale and the next launch re-opens one. "One or two extra circles" is the normal path, not an outlier.

### 5b. What turned a round RED (64 non-GREEN rounds)

| Trigger (a round can have several) | 09-13..23 (50 rounds) | 09-24..26 (14 rounds) |
|---|---|---|
| **lead-review BLOCK** | **34** | 5 |
| council-opus RED | 18 | 8 |
| council-sonnet RED | 8 | 2 |
| council-haiku RED | 3 | 1 |
| a seat ABSENT (returned empty - turn cap / no report) | 14 seat-slots | 7 seat-slots |
| escalate: tier ceiling reached | 7 | 3 |
| escalate: env | 3 | 2 |
| **lead-review BLOCK as the only trigger** (all seats GREEN) | 13 | 1 |

- lead-review BLOCK is the dominant trigger (39 of 64 non-GREEN rounds); opus RED is second (26). council-sonnet, the seat that runs the suite, is GREEN in 80 of 101 rounds.
- A non-GREEN round names a median of **1** red ask (25% name none - BLOCK-only or ABSENT-seat rounds): the extra circle is usually spent on one ask or on a review finding outside the asks.
- Seats returning empty are common: 67 "returned empty - turn cap suspected" / "no report" log lines in 39 of 172 runs. council-sonnet/opus hit their `maxTurns: 60` (section 2b p90 = 60 calls).

### 5c. What one round and one extra circle cost

**Direct cost of one round** (Round + Judge phase agents per `cycle.sh judge`, 80 rounds in 31 specs): median **7.3M raw / 1.46M weighted**, p75 11.5M / 2.03M, max 104M raw. Composition of round-phase spend:

| In a round | dispatches per round | share of round weighted |
|---|---|---|
| lead-review | 2.00 | 34.4% |
| council-sonnet | 1.49 (re-asks after empty returns) | 24.1% |
| council-opus | 0.94 | 16.4% |
| cycle-clerk | **11.8** | 15.8% |
| council-haiku | 0.88 | 9.3% |

**Extra circles** = everything between the first verdict and the last verdict of a spec (repair planning, repair workers, re-rounds, clerks, and the Queen relaunching runs). 25 recent specs had >= 1 extra round, 49 extra rounds in all:

| | value |
|---|---|
| weighted spend inside extra-circle windows | **173M of those tasks' 586M = 29.5%** |
| weighted per extra round (median) | **3.05M** (raw ~20M) |
| median extra-circle window | 1.1 h (max 15.5 h, mmorpg web-bridge-p1) |
| worst: mmorpg web-bridge-p1 | 5 extra rounds, 27.4M weighted / 157M raw = 57% of the task; 73 clerks, 9 repair workers |
| worst: YouTube_AI 11-video-skills | 3 extra rounds, 21.0M weighted = 49% of the task |
| worst: vulyk anomaly-telemetry | 5 extra rounds, 14.4M weighted = 58% of the task |

A repair itself is cheap to plan (Repair phase: 37 queen-planner dispatches, 7.8M weighted in all); the money goes to the re-run round (seats + reviews + ~12 clerks) and the repair workers.

### 5d. A review re-dispatch loop (Tier 4, katan, v0.17.0)

In 4 katan runs the driver re-dispatched the Tier 4 review pair (gate `claude-opus-4-8` + second reviewer `sonnet`) **8-20 times inside one round**: the reviewer's report did not start with the `VERDICT: PASS|BLOCK` line, `record-seat ... review` returned a non-JSON line ("NO VERDICT: top=..."), and the driver logged `next: dispatch:review` and dispatched again - 22 such log lines. Run `wf_af3b5e6d-279` dispatched **20 lead-reviews for one round** and ended at `stop: record-seat exit 2` without a verdict.

| | value |
|---|---|
| surplus lead-review dispatches (beyond 1 per round, 2 at Tier 4), all 172 runs | 66 in 20 runs |
| of which the katan loop | 46 in 4 runs (18 + 14 + 8 + 6) |
| surplus review spend, all runs | **200M raw / 31.2M weighted**, 1,712 agent-minutes |
| katan loop alone | 102M raw / 16.8M weighted |

(Surplus counts of 1-2 in other runs can be legitimate re-asks of an open round carried over from a previous run; the katan cases are unambiguous.)

## 6. Comparison with non-VULYK work

Scripts: `F\item6.py`, `F\item6b.py` (code-line proxy), `F\item6c.py` (same-project contrast), `F\item6d.py` (elapsed time); data `F\item6_units.csv`.

**Groups (recent period).** A = the 44 VULYK cycle tasks (summed over their sessions). B = 49 VULYK sessions that dispatched >= 1 worker. C = 71 non-VULYK work sessions (no VULYK marker, no VULYK constitution loaded, >= 3 edits) - 37 from READINESS, 15 senseti-doker, 6 demo-skills-build, 4 research-machine, the rest scattered. D = 19 sessions in VULYK-installed projects that used none of the machinery. **Size proxy** = changed lines in code files (Edit old+new lines, Write content lines), excluding paperwork (`docs/specs/`, `memory/`, `.claude/`, `.vulyk/`, `docs/adr/`, `docs/wiki/`, `*.md`). Tests count as code, which flatters VULYK (its workers write tests).

### 6a. Raw medians (not size-matched)

| Group | n | median code files | median raw | median weighted | median active min | median subagents |
|---|---|---|---|---|---|---|
| A VULYK cycle task | 44 | 7.5 | 84.9M | 13.5M | 165 | 67.5 |
| B VULYK session with a build | 49 | 10 | 93.4M | 14.3M | 168 | 58 |
| C non-VULYK work session | 71 | 1 | 29.4M | 3.9M | 52 | 0 (41% use any) |
| D VULYK project, no machinery | 19 | 0 | 17.0M | 2.6M | 58 | 0 |

Unmatched, a VULYK task costs ~3.5x the tokens and ~3.2x the active time of a non-VULYK session - but it also changes far more code, so this ratio alone overstates the tax.

### 6b. Size-matched by changed code lines

| Code lines changed | VULYK task: n / median weighted / raw / active min | non-VULYK session: n / median weighted / raw / active min | ratio weighted | ratio active time |
|---|---|---|---|---|
| 1-100 | 1 / 1.5M / 8.3M / 11 | 12 / 3.4M / 28.6M / 35 | (n=1) | (n=1) |
| 101-500 | 6 / 3.7M / 25.8M / 55 | 7 / 3.8M / 29.4M / 42 | **1.0x** | 1.3x |
| 501-2,000 | 14 / 12.5M / 83.3M / 167 | 10 / 5.8M / 45.5M / 80 | **2.2x** | **2.1x** |
| 2,000+ | 18 / 31.5M / 202.1M / 312 | 7 / 13.8M / 105.7M / 113 | **2.3x** | **2.8x** |

Per 100 changed code lines (medians): VULYK 0.93M weighted, 11.2 active min; non-VULYK 0.73M weighted, 9.9 active min.

**Elapsed time** (first to last event, the owner's felt time): VULYK task median **1,254 min (~21 h)**, p75 3,210 min, spread over 2 sessions and 3 relaunches; non-VULYK session median 112 min, p75 240 min. Active (gap-capped) time: 201 vs 64 min.

**Same-project contrast** (`F\item6c.py`): only 11 sessions without VULYK machinery and with code edits exist in mmorpg / fibi-next / YouTube_AI / Recall / our-home transcripts (older transcripts are no longer on disk), too few to conclude.

Honest reading:
- On matched code volume, VULYK costs **~2.2-2.3x the weighted tokens and ~2-3x the active time** for mid and large changes (500+ code lines), and is at **parity for small changes** (101-500 lines). The owner's "5x" is reached on *elapsed* time (21 h vs ~2 h median, ~11x, but the VULYK tasks are also ~4x larger) and in individual bad tasks (the katan and mmorpg tasks in section 1c), not in the median.
- Where the extra goes on a matched task is sections 2-5: the review apparatus (~31% of weighted), the Queen re-reading a 240k context for ~120 turns per session, ~44 clerk dispatches, and the 30% of spend inside extra circles.
- Comparability limits: group C is dominated by two codebases (READINESS, senseti-doker) and runs mostly without subagents; half of its sessions changed no code at all (research and docs work) and are excluded from 6b; the matched buckets hold 6-18 VULYK tasks and 7-12 non-VULYK sessions each. Treat the ratios as +/-30%.

## 7. Two expensive recent tasks as timelines

Script: `F\item7.py <project> <session...>` -> `F\item7_timeline_*.csv` (Queen segments between dispatches; workflow agents folded into consecutive phase blocks). Local time. raw / weighted in millions.

### 7a. mmorpg `web-bridge-p1` (Tier 3, 16+3 stories, v0.16.0) - one session `bfc65f95`, 296.8M raw / 48.3M weighted, harness cost $153.89, printed Workflow totals 1.37 + 2.20 + 2.92 + 3.92 = 10.4M

| Start | Elapsed | Who | What | raw | w |
|---|---|---|---|---|---|
| 09-24 14:52 | 3 h 10 m | Queen + 2 drone-scout + queen-planner + lead-architect + drone-coverage + Explore | plan, ADR, grill with the owner (Queen ctx 116k -> 200k) | 14.8 | 2.9 |
| 18:05 | 59 m | run 1 Build: 7 worker-code, 13 clerks | stories 1-4; run **stops: worker returned NEEDS_CONTEXT** (story 05) | 33.3 | 5.1 |
| 19:04 | 46 m | run 2 Build: 2 worker-code, 6 clerks | rest of the build | 18.0 | 2.6 |
| 19:50 | 27 m | run 2 **Round 1**: 3 seats + council-sonnet re-ask + 2 lead-review + 12 clerks | RED | 32.0 | 4.7 |
| 20:17 | 7 m | Judge + Repair (queen-planner) + 1 repair worker + Queen relaunch | | 4.9 | 1.3 |
| 20:30 | 21 m | run 3 **Round 2**: 3 seats + 2 lead-review + 9 clerks | RED | 25.5 | 3.9 |
| 20:51 | 78 m | Repair + 2 repair workers (clerk `close-story` waits 10.8 min) | | 4.9 | 1.8 |
| 22:10 | 28 m | run 3 **Round 3**: 3 seats + sonnet re-ask + 2 lead-review + 11 clerks | ESCALATE (ceiling) | 31.8 | 4.8 |
| 22:38 | 33 m | Queen + manual lead-review + queen-planner | owner-driven security review, repair stories cut (Queen ctx -> 272k) | 16.6 | 2.6 |
| 23:11 | 53 m | run 4 Build: 3 workers, 6 clerks (`close-story` 17 min of suite runs) | | 13.1 | 2.8 |
| 09-25 00:04 | 26 m | run 4 **Round 4** + Judge + Repair | RED | 19.3 | 3.2 |
| 00:30 | **10 h 20 m** | run 4 Build: 2 workers | **one worker Bash call hung for 597 min** (story 15, overnight) - the whole run waited | 5.0 | 1.2 |
| 10:50 | 58 m | run 4 **Rounds 5 and 6** + repair worker | RED, then ESCALATE (ceiling) | 36.1 | 6.1 |
| 11:48 | 1 h 40 m | Queen + 3 worker-code + drone-docs + librarian | Queen finishes stories 17-19 by hand-dispatch and ships (Queen: 108 calls, ctx -> 386k, 35.6M raw) | 41.5 | 5.5 |

Where it went (`F\item7b.py`): the 6 round blocks = **140M raw / 21.2M weighted (47% / 44% of the task)**; 107 clerk dispatches; 5 "seat returned empty - turn cap" events (council-sonnet/opus ran to 60 calls); 4 Workflow launches, one ended by NEEDS_CONTEXT; one hung Bash cost 10 h of wall-clock; the run ended ESCALATE and the Queen finished the job by hand.

### 7b. katan `ui-redesign-p1-chart` (Tier 4, 20 stories, v0.17.0) - one session `f7aff30d`, 249.2M raw / 44.7M weighted, printed Workflow totals 13.8M over 7 runs

| Start | Elapsed | Who | What | raw | w |
|---|---|---|---|---|---|
| 09-25 13:34 | 2 h | Queen + 3 Explore + lead-architect + queen-planner + drone-coverage | plan (Queen ctx 116k -> 219k) | 15.0 | 3.1 |
| 15:37 | 8 m | run 1 Build: 4 workers, 6 clerks | **stops: `close-story` exit 2 - "verification not in ## Commands"** | 8.7 | 1.6 |
| 15:48 - 16:40 | 52 m | runs 2, 3, 4 Build: 20 workers, 32 clerks, + 3 hand-dispatched workers | each run **stops on NEEDS_CONTEXT**; the Queen fixes the story and relaunches | 42.5 | 7.5 |
| 16:42 | 9 m | run 5 Build: 1 worker, 4 clerks | built | 4.8 | 0.8 |
| 16:51 | **2 h 20 m** | run 5 **Round 1**: 2 seats empty (turn cap), then **20 lead-review dispatches** (10 x gate opus-4-8 + second sonnet) + 36 clerks | every review lacked the `VERDICT:` first line -> `record-seat` non-JSON -> re-dispatch; run ends at `record-seat exit 2`, no verdict | **82.1** | **13.4** |
| 19:12 | 1 h 33 m | run 6: Judge + Repair + **Round 2** (8 lead-reviews, 19 clerks) + Judge + Repair | RED | 43.2 | 8.1 |
| 20:45 | 2 h 6 m | run 7 **Round 3** (16 lead-reviews, 30 clerks) | RED at the Tier 4 ceiling -> ESCALATE; ended at `record-seat exit 2` | 53.0 | 10.3 |

Where it went (`F\item7b.py`): rounds + judges + repairs cost **172M raw / 29.0M weighted = 69% / 65% of the task**, driven by 44 lead-review dispatches where 6 were expected. The build itself (all workers and build clerks, 5 runs) cost 43.5M raw / 8.9M weighted.

### 7c. Why vulyk-cycle runs end (all 172 runs, `F\item7c.py`)

End stage: `03-building` 45 · `04-council:GREEN` 29 · `03-built` 28 · no result 23 · `04-council:RED` 18 · `04-council:ESCALATE` 17 · `05-rejected` 7 · `06-shipped` 3. **96 of 172 runs (56%) ended before any verdict** and had to be relaunched by the Queen. Recorded stop reasons:

| stop | count |
|---|---|
| `open-round` exit 2: working tree not clean | 28 |
| `close-story` exit 2: already done | 18 |
| build: worker returned NEEDS_CONTEXT | 15 |
| `close-story` exit 2: verification not in `## Commands` | 10 |
| build: worker returned no report | 5 |
| `open-round` exit 2: `## Asks` missing or empty | 4 |
| `record-seat` exit 2: review already recorded / other | 3 |

Every relaunch repeats the claim/status/branch clerks (~5 x ~34k tokens) and a Queen turn on a 200-300k context; a median task pays 3 launches.

## 8. Robustness checks and older-period contrast

Script: `F\item8.py`.

| Recent cycle tasks | n | median raw | p75 raw | median weighted | p75 weighted | median printed wf totalTokens | median active min | median dispatches | median clerks | median rounds |
|---|---|---|---|---|---|---|---|---|---|---|
| all | 44 | 84.9M | 188.6M | 13.5M | 27.6M | 2.56M | 165 | 67.5 | 43 | 2 |
| **owner projects only (VULYK repo excluded)** | 36 | **96.4M** | 219.5M | **15.8M** | 32.4M | 2.73M | 160 | 67.5 | 41.5 | 2 |
| VULYK repo only | 8 | 52.1M | 79.8M | 11.0M | 15.2M | 2.20M | 282 | 69.5 | 45.5 | 3 |

Excluding the framework's own repo makes the user-project picture slightly *worse*: median 96M raw / 15.8M weighted per task.

**Session level, older vs recent** (transcripts on disk start 2026-08-31, so "older" = 08-31..09-12, VULYK v0.9-0.11):

| VULYK sessions | n | median raw | median weighted | p75 weighted | Queen share of weighted | median subagents | median active min | median harness cost |
|---|---|---|---|---|---|---|---|---|
| 08-31 .. 09-12 | 78 | 58.2M | 8.2M | 18.7M | 44% | 8 | 108 | $41.59 |
| 09-13 .. 09-26 | 86 | 55.1M | 8.8M | 15.1M | 36% | 15.5 | 100 | $45.36 |

Per session, spend is flat across versions; the Workflow driver moved ~8 points of spend from the Queen into subagents and doubled the dispatch count, without lowering the total.

**Harness-reported cost** (`cost-state.totalCostUSD`, computed by Claude Code itself, recent sessions): VULYK sessions median **$45.36**, p75 $80.70, max $373.24, total $4,526 over 79 sessions; non-VULYK work sessions median **$19.05**, p75 $46.48, max $150.51, total $2,273 over 70 sessions.
