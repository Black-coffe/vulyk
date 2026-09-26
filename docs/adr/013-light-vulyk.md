# ADR-013: Light VULYK — a single agent below Tier 3, a driver without a clerk per verb, a council that converges

- Status: accepted (owner, 2026-09-26: "запускай его в работу… пускай это станет следующей версией")
- Date: 2026-09-26 · Version: 0.18.0
- Evidence: `docs/specs/token-audit/report.md` and `evidence/` (forensics over 1,844 sessions; code audit
  H1–H26; Anthropic guidance, two sources per claim)
- Supersedes:
  - ADR-001 D2 — one clerk per verb;
  - ADR-001 D3 — the seat roster;
  - ADR-002 — council at every tier ("never to zero");
  - ADR-007/012 — the gate model on every review;
  - ADR-008 — worker + close-story + council-sonnet running the same suite.

  Everything else in those ADRs stands.

## Context

A median VULYK task processed 84.9M raw tokens (13.5M weighted) and dispatched 67 subagents, 43 of
them `cycle-clerk`. Spend split into three near-equal parts: the Queen 30.5%, workers 30.4%, and
review machinery 30.7%. On top of that:

- the instruction bundle every subagent inherits was 23% of all spend;
- extra council rounds took 29.5% of the spend of the tasks that had them;
- 56% of driver runs stopped before a verdict.

Anthropic's guidance for the current models (Opus 5.5, Fable 5.1) names three of VULYK's shapes as
anti-patterns:

- separate agents for plan/execute/review;
- agents split by type of work;
- verification scaffolding around a model that verifies itself.

## Decisions

### D1 — Routing: one agent below Tier 3

| Tier | Who builds | Council (required seats) | Round ceiling | Driver |
|---|---|---|---|---|
| 0 | the Queen, directly, no paperwork | none | — | none |
| 1 | the Queen (**solo**) | `review` | 1 | none — the Queen runs `cycle.sh` herself |
| 2 | the Queen (**solo**), in a fresh session after approval | `review` | 2 | none |
| 3 | workers in waves | `opus review` (+ `haiku` when the Profile's Client path is filled) | 3 | Workflow `vulyk-cycle.js` |
| 4 | workers in waves + `lead-architect` | as Tier 3; `review` folds a second reviewer | 3 | Workflow |

**Solo mode.** At Tier 1–2 the Queen takes the stories in wave order, implements each one herself,
and closes it with `cycle.sh close-story <story> --commit`. Everything else — branch, round,
verdict, repair story — goes through `cycle.sh advance`, which the Queen runs from her own Bash.
There is no clerk and no court worktree. The Queen dispatches one `lead-review` per round.

**Law 5** now binds from Tier 3 only.

**`council-sonnet` is retired.** It returned 0 RED in 16 rows of VULYK's own ledger and was GREEN
in 80 of 101 rounds across 20 hives; its job — running the suite — was already done by the worker
and `close-story`. `record-seat` still accepts `sonnet` so that old rounds stay readable, but no
tier requires it.

**The black-box seat `council-haiku`** is required only when the constitution's Profile row
`Client path` is filled. "Filled" means the value is non-empty, does not start with `<fill`, and
does not start with `none`, case-insensitive.

The constitution is `CLAUDE.vulyk.md` when that file exists, otherwise `CLAUDE.md`. The same
lookup applies everywhere VULYK reads the constitution, including `close-story`'s `## Commands`
check. Hives with a sidecar used to fail that check against `CLAUDE.md`.

### D2 — `cycle.sh advance`: one call per agent boundary

```
bash scripts/cycle.sh advance <spec-dir> [--stamp <s>] [--claim] [--ingest]
```

1. **`--claim`** (requires `--stamp`): runs `claim <spec> <stamp>` first. If the claim fails,
   `advance` emits the claim's own failure line and stops.
2. **`--ingest`**: for the open, non-stale round, it goes through every required seat that has no
   `<seat>.md` and no `<seat>.attempt-2.md`.
   - The attempt it expects is `k = 2` if `<seat>.attempt-1.md` exists, else `1`.
   - It records `.vulyk/reports/<slug>/round-<n>/<seat>.attempt-<k>.md` through
     `record-seat --file`.
   - If that file does not exist, it records an empty report on stdin, so a dead or turn-capped
     seat still spends its attempt, as before.
   - Tier 4 `review`: it first folds `review-top.attempt-<k>.md` and
     `review-second.attempt-<k>.md`. The fold rule is `foldReviews` from the 0.17 driver:
     - both first lines are `VERDICT: PASS|BLOCK` → `VERDICT: BLOCK` if either blocks, else
       `PASS`, followed by both bodies;
     - otherwise → `NO VERDICT: …` followed by both bodies. A missing file counts as an empty
       body.

     The folded text goes to `record-seat` on stdin.
   - Every rejection (exit 4) is collected as `{"seat","attempt","error"}`.
3. **Loop, at most 12 steps.** It reads `status`. If `next` is `branch`, `open-round`, `judge` or
   `repair`, it runs that verb as a subprocess of itself with `--commit` (and `--stamp` when
   given), then loops. Any other `next` ends the loop.
   - A sub-verb with `ok:false` ends `advance` with that verb's `verb/exit/next/error` and that
     exit code.
   - Exit 6 (escalate, `ok:true`) is not a failure: the loop continues, and `status` then reads
     `escalated`.
4. **Last stdout line**, key order fixed:

   ```
   {"ok":true,"verb":"advance","exit":0,"next":"<status.next>","steps":["open-round",...],"rejected":[...],"status":{<status --json>}}
   ```

   On a stop: `ok:false`, the failing verb's `exit`, `next` and `error`, plus `"failed":"<verb>"`,
   `steps` and `rejected`. There is no `status` key on a stop.

`advance` is `DRIVER`-guarded through its sub-verbs, exactly as they are today. `status --json`
gains three keys:

- `"since"`: the previous round's recorded head while round n>1 is open, else `null`.
- `"seat_attempt"`: `{"<seat>":k,…}` for every missing required seat of the open round, else
  `{}`.
- `"seats"`: the open round's frozen required list, else `[]`.

### D3 — A council that converges

- **Frozen roster.** `open-round` writes `seats=<space-separated list>` (the D1 roster, frozen at
  open) and `since=<previous round's head>` (for n>1) into `ROUND`.
  - Every place that reads the required seats reads `seats=` first. For rounds opened before
    0.18, it falls back to `required_seats_for_tier(round_tier)`.
  - When no blind seat is required, `open-round` builds **no court worktree**: `court=` is
    empty and `status.court` is `null`.
- **Carry-forward.** When round n>1 opens, every blind seat (`haiku`, `sonnet`, `opus`) whose file
  in round n-1 exists with `VERDICT: GREEN` or `VERDICT: N/A` is copied into round n as
  `<seat>.md`. The first line of the copy gets ` · carried: round <n-1>` appended. `review` is
  never carried. The journal line of `open-round` names the carried seats.
  - Tradeoff, accepted: a repair that silently breaks an ask a carried seat had proven is caught
    only by the reviewer. The reviewer reads exactly that diff.
- **The reviewer judges the diff, not the branch.** In round n>1 `lead-review` receives
  `since..head` and the previous round's directory. It checks two things: whether the previous
  findings are fixed, and whether that diff introduces a regression. It does not re-review the
  whole branch.
  - A GREEN round that goes stale — for example, a hand fix — therefore reopens as a round that
    re-runs only the review on the new diff.
- **The reviewer prompt drops "find reasons this change should NOT merge"** and the "report
  everything" framing. It flags only what breaks an ask or correctness.
  - BLOCK still needs an anchored `## Critical`/`## Major` line (`[ask N]` or `[regression]`), as
    D4 of convergent-judge requires.
  - A major needs a reproducing command or a `file:line`.
  - Minors are optional and go to the next circle.
- **Model.** `lead-review` runs on its frontmatter model (`opus`) at Tier 1–3. The gate model
  (`TOP_MODEL`) is passed only at Tier 4, together with the second reviewer, and on a missed
  story's retry. `lead-architect` and the Tier 4 `queen-planner` keep the gate model.
- **`reopen` routes to `repair`.** After `reopen`, `status` reads the reopened ESCALATE row:
  - `env` → `open-round` (the round itself failed, re-run it);
  - any other reason and the round is not stale → `repair`;
  - stale → `open-round`.

  `reopen` itself emits `next:"repair"` (or `open-round` for `env`).
- **Paperwork.** `VERSION` and `CHANGELOG.md` join `is_paperwork_path`, so the release commit
  `/vulyk-ship` makes no longer stales a GREEN round.

### D4 — `cycle.sh repair`: a mechanical repair story, no planner

```
bash scripts/cycle.sh repair <spec-dir> [--commit] [--stamp <s>]
```

It runs only when `status.next == repair`, and writes one story file,
`<spec>/<slug>-NN-repair-round-<n>.md`, where NN is the next free story number and n is the round
being repaired.

Frontmatter:
- `story: <slug>-NN`
- `status: todo`
- `returned:`
- `worker: worker-code`
- `model: opus`
- `wave: <max wave + 1>`
- `blocked_by: []`

Sections:
- `# Repair round <n>`
- `## Goal` — one line.
- `## Requirements` — the brief's `## Asks` items that the round's row lists in `red` or
  `review_asks`, each quoted as `> N. <text>`. Any other RED ask comes from the seat files.
- `## Findings`, verbatim:
  - every RED `ASK` line from the round's seat files;
  - every `## Critical`/`## Major` list line of `review.md` that carries an `[ask N]` or
    `[regression]` tag.

  `[unanchored]` lines are never copied; they wait for `/vulyk-ship`'s next circle.
- `## Files` — the union of `## Files` of the spec's done stories.
- `## Verification` — the union of their `## Verification` lines, deduplicated, `repeat:` dropped.

It is idempotent: if a todo story already names `repair-round-<n>`, it writes nothing. It commits
the file under `--commit`, and its last line is `emit_status`.

`trace-check.sh` accepts a `## Requirements` quote that matches a brief `## Asks` item — the digits,
the dot and the text, whitespace-normalized.

The Workflow driver no longer dispatches `queen-planner` for repairs. In solo mode the Queen
implements the repair story like any other.

### D5 — Workers close their own stories; verification runs once

- `worker-code` / `worker-test` finish by writing `returned: DONE` and running
  `bash scripts/cycle.sh close-story <story> --commit --stamp <s>`.
  - The stamp comes from the dispatch prompt; it is absent in solo mode.
  - On exit 4 they read the output, fix, and run it again, at most three times. After that they
    set `returned: WALL` and stop.
  - They do not run the full `## Verification` separately before `close-story`; `close-story` is
    that run, recorded. Targeted checks while working are fine.
- `close-story` on a story that is `done` with a clean tree now returns `ok:true`, exit 0, with a
  note "already done" and `emit_status`. It no longer exits 2.
- `close-story` runs verification under `timeout` when a working `timeout` exists. The whole run —
  every line, every `repeat` — shares one budget of `${VULYK_VERIFY_TIMEOUT:-540}` seconds. Exit 124,
  or a spent budget → exit 4, `error: "verification timed out after <N>s: <cmd>"`.
  - 540 s keeps the verb inside the Bash tool's 10-minute cap, so a slow suite reports instead of
    dying silently.
  - The budget is per run, not per command, because a repair story unions every story's lines.
- `claim` refuses a working tree dirty outside paperwork, with the same predicate `open-round`
  uses (factored into one function) and `error: "working tree not clean"`. An owner's stray file
  now stops a run before the build, not after it.
- `scope-check.sh`, with no range given, excludes paths declared in `## Files` by other stories
  of the same spec that are not `done`. Parallel stories no longer count each other as out of
  scope.
- `wave-check.sh` reports every `## Verification` segment that is not a `## Commands` cell of the
  constitution. The gap now surfaces at plan time instead of stopping a run.
- `tests/council.test.sh --quick` skips the slow replay/regression sections and must finish in
  under ~3 minutes on Windows. The full run stays the release gate.

### D6 — The Workflow driver

`vulyk-cycle.js` (args: `spec`, `stamp`, `top_model`, `second_model`) makes exactly one clerk call
per agent boundary. Its loop:

- **Start:** `advance --stamp S --claim`.
- **`build:W`:** the wave's workers run in parallel.
  - Prompt: story file, stamp, and "your last step is `close-story … --commit --stamp S`".
  - `model`: the story's own model; `TOP` on the story's second attempt.
  - Then one `advance --stamp S`.
  - A story still listed as todo in the next status is a miss. The second miss stops the run and
    names the file.
- **`dispatch:<seats>`:** the seats run in parallel.
  - Each seat writes its report to the path for `status.seat_attempt[seat]`.
  - Tier 4 review: two reviewers, `TOP` and `SECOND`, writing `review-top` and `review-second`.
  - Then one `advance --stamp S --ingest`.
  - A seat still listed afterwards is re-dispatched once with the rejection reason from
    `rejected`. A seat that would need a third dispatch in the same round stops the run.
- **Any other `next`:** terminal → return the status; anything else → stop with it.
- **Safety cap:** 40 loop iterations.
- **Release** in `finally`.

The driver no longer dispatches `queen-planner`, and no longer polls `status` separately:
`advance` carries it. The Queen no longer runs `claim` before launch.

There is no in-script deadline: the Workflow API has no clock. Deadlines live in the verbs
(`timeout` in `close-story`) and in agent bodies (every Bash call carries a timeout).

### D7 — What every subagent loads

- **`omitClaudeMd: true`** (Claude Code ≥ 2.1.271) on `cycle-clerk`, `council-opus`,
  `council-haiku`, `drone-scout`, `drone-coverage`, `drone-docs` and `librarian`. Their delegation
  prompt and their own body carry everything they need. Workers, `lead-review`, `queen-planner`
  and `lead-architect` keep the constitution — they need the host's conventions.
- **The constitution shrinks** to Laws, routing, Secrets, Profile and Commands, under ~7 KB and
  under 120 lines.
  - Model ladder, cycle, token economy, compaction and evolution move to `docs/` and to the
    `/vulyk-*` commands, which load only into the Queen.
  - No MUST/NEVER/CRITICAL shouting anywhere in agents or commands; emphasis goes on one line at
    most.
- **Upgrades.** The installer still never overwrites a constitution on its own.
  `install.sh --upgrade --constitution replace` writes the new constitution with the host's
  `VULYK:PROFILE` and `VULYK:COMMANDS` blocks transplanted and its telemetry row kept. The old
  file is kept as `<name>.pre-0.18.md`. Plain `--upgrade` prints the size difference and the
  command. `scripts/vulyk-update.sh` passes `--constitution replace` through.
- **Dead weight removed:**
  - the `session-end-learnings.sh` hook, which wrote empty stubs; the Chronicle plugin replaces it;
  - `anomaly-scan.sh` on `Stop` — it stays on `SessionEnd`;
  - `"effortLevel"` in `.claude/settings.json`, which has no effect on Opus 5.5;
  - `status: in-progress` and `tracer:` from the story template;
  - the ADR-001 pointer in the reviewer prompt;
  - `council-sonnet.md`.

  The installer removes retired framework files from a hive on upgrade, through the manifest
  diff.

### D8 — Measure what is spent

`scripts/token-report.py <project-dir> [--spec <slug>] [--since YYYY-MM-DD] [--json]` reads
`~/.claude/projects/<encoded>/` and reports raw and weighted tokens, dispatches by agent type and
rounds, per spec. It deduplicates by `message.id` and counts subagents and workflow agents. It
never reports the Workflow's `totalTokens` as spend, because that figure is the sum of final
contexts. `/vulyk-status` and `/vulyk-evolve` show its per-spec lines.

## Consequences

- **Dispatches per task:**
  - Tier 1: from 14 (10 clerks) to 1 reviewer.
  - Tier 2: from 21–33 to 1–2 reviewers plus scouts.
  - Tier 3: from 35–53 to about 6 workers + 2 seats + 3–4 clerk calls per round. `tests/e2e.test.sh`
    measures 4 clerk calls for a one-wave, one-round run.
- **What stays:** state on disk, the approval stop, verbatim requirements with `trace-check`, the
  council ledger, the ceiling and no-progress rules, and `reopen`.
- **Where quality is guarded now:**
  - at Tier 1–2, by one fresh-context reviewer on Opus 5.5 plus the recorded verification run;
  - at Tier 3–4, by the intent seat, the reviewer, and the black box where a client path
    exists.
- **Contract tests change with the contract:** `cycle.test.sh`, `council.test.sh` and
  `driver.test.sh` are updated in the same release.
- **Expected saving:** −40…55% on a median task. That is an estimate from spend shares, to be
  measured with `token-report.py` after a few specs run on 0.18.
