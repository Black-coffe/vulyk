# ADR-001: The cycle's state contract - one truth on disk, two thin drivers

- Status: proposed
- Date: 2026-09-12
- Spec: docs/specs/autonomous-cycle (v0.12.0)

## Context

v0.12.0 replaces stage 05 (the mandatory human look) with an agent council and moves the
loop *build -> gates -> council -> repair* out of the Queen's session. The loop must run under
two drivers with identical behaviour: (1) `.claude/workflows/vulyk-cycle.js`, a Workflow
script - deterministic, background, resumable, unable to ask a human; (2) the Queen's own
session stepping through the same loop where Workflow is unavailable (Claude Code < 2.1.154,
Pro without the flag).

Two facts decide the shape. First, the constitution: a stage is closed by a file on disk,
never by a chat turn, and every existing gate (`acceptance-log.sh`, `human-check.sh`,
`ship-check.sh`) is a model-free script whose record carries the commit and the pack
fingerprint it was given against. Second, the Workflow runtime: a script has **no filesystem,
no shell, no Node API and no clock** - only `agent()`, `parallel()`, `pipeline()`, `phase()`,
`log()`. It cannot hold a round counter that survives a crash, cannot write a ledger, and its
resume replays cached `agent()` results by call order. Whatever the loop's truth is, the
script cannot be where it lives.

The adversarial review named the gaps this ADR closes: where the round counter lives (2.4),
how evidence survives a crash (2.4), how a human takes the tree back (2.5, 5.3), how BLOCK,
STALE and "round" compose (5.2), and who computes a verdict (4.1: the grill settled it - a
script judges rounds, the Queen only escalation and the final report).

## Options

1. **Deterministic phases as bash scripts with one stable CLI; both drivers call them and
   branch on a `next:` field.** Tradeoff: one more clerk agent per phase in the Workflow
   (Haiku, ~1 turn) because the script cannot run bash itself.
2. **Logic in the Workflow script, duplicated in the command prompt for the fallback.**
   Tradeoff: two implementations of the verdict rule and the ceiling; the JS half is
   untestable in a bash-only CI; the round counter lives in a run's memory and resets on
   restart - the ceiling becomes unreachable in the crash it exists for.
3. **One long-running foreman agent that dispatches seats via nested `Agent`.** Tradeoff:
   needs the nested-subagent setting in every hive; the foreman's context accumulates every
   report (the cost Workflow exists to avoid); it dies with a crash; its verdicts are a
   model's, not a rule's, so two runs can disagree on the same evidence.
4. **Extend `state.sh` to carry round state.** Rejected outright: `state.sh` is a derived,
   gitignored view; a derived file cannot be the truth of anything.

## Decision

Option 1. The loop state is a small set of committed files, each with exactly one writer,
all written by `scripts/cycle.sh`; the verdict is computed by that script from labelled
lines in seat reports; both drivers are a `while` loop over `cycle.sh status --json` that
performs the one action named in `next` and nothing else.

### D1. Files, owners, schemas

| File | Writer | Content / schema | Committed |
|---|---|---|---|
| `docs/specs/<slug>/brief.md` `## Asks` | `/vulyk-plan` at grill close | numbered list `1. <verbatim ask>`; A = its length; the council judges only these | yes |
| `plan.md` `**Briefed:** via grill, <owner>, <date>` | `cycle.sh briefed` (called by `/vulyk-plan`) | stage 01+02 in autonomous mode; `**Approved:**` stays for the two-stop mode; `/vulyk-build` and `ship-check.sh` accept either | yes |
| `plan.md` `**Branch:** vulyk/<slug>` | `cycle.sh branch` (called by `/vulyk-build` / the driver) | unchanged meaning | yes |
| `plan.md` `**Council:** <GREEN\|RED\|ESCALATE\|STALE> round <N>, <date>, at <head>, pack <fp>[ - red: 2,5]` | `cycle.sh judge` / `escalate` | appended, never replaced, one line per round - a mirror of the ledger row, human-readable | yes |
| `plan.md` `## Needs a human` | `cycle.sh escalate` | reason (`ceiling` / `half` / `env`), one row per RED ask with its evidence across rounds, paths of the seat files | yes |
| `plan.md` `**Checked:**` | `human-check.sh` (unchanged) | optional override: `ACCEPTED` outranks a RED/ESCALATE, `REJECTED` outranks a GREEN | yes |
| `docs/specs/<slug>/council/round-N/ROUND` | `cycle.sh open-round` | **the open marker**: `head=<sha>` `pack=<fp>` `opened=<ts>` `court=<path>` `ceiling=<3\|6\|...>`; `mkdir` of the directory is the atomic act | yes |
| `docs/specs/<slug>/council/round-N/<haiku\|sonnet\|opus\|review>.md` | `cycle.sh record-seat` (stdin) | seat report verbatim under one header comment `<!-- seat: sonnet · model: <id\|alias> · round: 2 · head: … · pack: … · attempt: 1 · recorded: <ts> -->`; a rejected attempt is kept as `<seat>.attempt-K.md` | yes |
| `memory/stats/council.jsonl` | `cycle.sh judge` / `escalate` | **the close marker**, one flat row per round (schema below) | yes |
| `docs/specs/<slug>/journal.md` | `scripts/journal.sh` only (from `cycle.sh`, `/vulyk-plan`, `/vulyk-ship`, hooks) | append-only, one line per state change: `- <ts> · <stage> · <what happened> · next: <what next>`; stage vocabulary = `state.sh` stages + `paused` | yes |
| `docs/specs/<slug>/PAUSE` | `cycle.sh pause` or a human's `touch` | first line: who/why; a semaphore, not a record - the journal line is the record | **no** (gitignored) |
| `.vulyk/court/<slug>/round-N/` | `cycle.sh open-round` / `judge` | git worktree at the pack commit, `docs/specs/<slug>/` reduced to `brief.md` | **no** (gitignored) |
| `.claude/state.json` | `state.sh` (unchanged) | gains stages `04-council:<verdict>` and `paused`; derived, never truth | no |

`council.jsonl` row (flat on purpose - the existing readers extract fields with a greedy
`sed`, so no nested object may contain a key named `verdict`):

```
{"ts":"2026-09-13T02:14:07Z","spec":"<slug>","round":2,"verdict":"GREEN|RED|ESCALATE|STALE",
 "head":"abc1234","pack":"1a2b3c4d5e6f","asks":7,"red":[2,5],"red_unevidenced":[],"na":1,
 "review":"PASS|BLOCK|ABSENT","haiku":"GREEN|RED|N/A|ABSENT","haiku_model":"<id or alias>",
 "sonnet":"…","sonnet_model":"…","opus":"…","opus_model":"…","attempts":4,
 "escalate":"ceiling|half|env|null","note":"<one line, redacted>"}
```

**Resume and atomicity.** The round counter is the number of `council/round-*` directories;
it lives in git, never in a run. A round is *open* when its `ROUND` file exists and no
`council.jsonl` row carries its number. Crash rules, all handled by `open-round` and `judge`
being idempotent:

- `round-N/` exists without `ROUND` -> nothing happened; `open-round` rewrites `ROUND`.
- open round, HEAD unchanged -> resume it: seats whose file exists are *done*, the rest
  are *missing*; nothing is re-dispatched that already returned.
- open round, HEAD moved (a manual code commit, a repair) -> the round is stale. With no
  seat file, `open-round` re-stamps it in place; with any seat file, it writes a `STALE`
  row for N (it was a dispatch, it counts against the ceiling) and opens N+1.
- row written, `**Council:**` line or journal line missing -> `judge` recomputes and writes
  whichever of the three is absent, in the fixed order seat files -> row -> plan line ->
  journal. The row is authoritative; the line is its mirror.

`paperwork_only()` in `ship-check.sh` and `human-check.sh` gains `*/council/*`,
`*/journal.md`, `memory/stats/council.jsonl`, so recording a round never stales a round.

### D2. The phase CLI

One script, `scripts/cycle.sh <verb> <spec-dir> [...]`, plus `scripts/journal.sh`. Unlike
the report-only gates, this is a machine contract: **exit codes mean something**, and the
last stdout line is always one JSON object so no driver parses prose.

| Verb | Precondition (exit 2 names the failing one) | Effect |
|---|---|---|
| `status <spec> [--json]` | - | derives everything above; prints `next` (below); never writes |
| `briefed <spec> [--commit]` | `## Asks` present, non-empty | writes `**Briefed:**`; journal |
| `branch <spec> [--commit]` | Briefed or Approved | creates/switches `vulyk/<slug>`, writes `**Branch:**` |
| `close-story <story-file> [--commit]` | worker returned | `scope-check.sh`, `## Verification` x `repeat:`, `status: done`, commit `story(<id>): <title>`; exit 4 on red verification (the driver routes to the repair path of `/vulyk-build` step 5) |
| `open-round <spec> [--commit]` | Branch; all stories `done`/`blocked`; clean tree; `## Asks`; not paused; round count < ceiling | `mkdir round-N`, `ROUND`, opens the court, journal; exit 6 `ESCALATE` when the ceiling is reached instead |
| `record-seat <spec> <N> <seat> [--model <id>] < report` | open round; `head` in `ROUND` == HEAD | validates the report contract (D3); writes the seat file; exit 4 `MALFORMED` (kept as `attempt-K`) when a label is missing, an ask number is uncovered, a RED lacks evidence, or the report is **tainted** (names a story id `<slug>-NN`, `plan.md`, `journal.md` or `council/` - things a blind seat cannot know) |
| `judge <spec> [--commit]` | four seat files present, or a seat exhausted its two attempts (`ABSENT`) | computes the verdict (D4), row -> line -> journal, removes the court |
| `escalate <spec> [--commit]` | called by `judge` itself or by the driver on exit 6 | `**Council:** ESCALATE`, row, `## Needs a human`, journal |
| `reopen <spec> "<owner's decision>" [--commit]` | last row is ESCALATE | appends the decision verbatim to `brief.md` `## Answers`, raises `ceiling` by 3 in the next `ROUND`, journal |
| `pause <spec> ["why"]` / `resume <spec>` | - | creates / removes `PAUSE`; journal; `resume` prints `stale: true` if HEAD moved while paused |

Every mutating verb checks `PAUSE` first and exits **3 `PAUSED`** without acting; `status`,
`pause`, `resume` are exempt. Exit codes: 0 ok · 1 usage · 2 precondition · 3 paused ·
4 malformed / red verification · 5 stale · 6 escalate. `--commit` commits the paperwork as
`vulyk(<slug>): <verb> …`; both drivers always pass it, so paperwork commits are uniform.

`status.next` is one of: `briefed` · `branch` · `build:<wave>` · `close-story:<file>` ·
`open-round` · `dispatch:<missing seats, comma-separated>` · `judge` · `repair` · `green` ·
`escalated` · `paused` · `shipped`. It is the entire interface between the state and a driver.

**The Workflow driver** is a loop with no verdict logic. The runtime forbids shell access, so
every verb is run by `cycle-clerk` (`.claude/agents/cycle-clerk.md`: `model: haiku`,
`tools: Bash`, `maxTurns: 5`, prompt "run exactly this command, return the last stdout line
verbatim"; needs `Bash(bash scripts/cycle.sh:*)` and `Bash(bash scripts/journal.sh:*)` in the
hive's allowlist, which `install.sh` adds). A seat's report reaches `record-seat` as a
heredoc in the clerk's prompt; the contract validation is what catches a garbled copy.

```js
export const meta = { name: 'vulyk-cycle', description: 'build → council → repair, ceiling 3',
  phases: [{title:'Build'},{title:'Round'},{title:'Judge'},{title:'Repair'}] }
const spec = args.spec, TOP = args.top_model            // resolved by the Queen's shell
const clerk = (cmd) => agent(`Run exactly: bash scripts/cycle.sh ${cmd}\nReturn the last stdout line verbatim.`,
  { agentType: 'cycle-clerk', effort: 'low', schema: LAST_LINE }).then(r => JSON.parse(r.line))
for (;;) {
  const st = await clerk(`status ${spec} --json`)
  if (['green','escalated','paused','shipped'].includes(st.next)) return st
  if (st.next.startsWith('build:'))     { /* wave workers via pipeline(), each → clerk close-story */ }
  else if (st.next === 'open-round')    await clerk(`open-round ${spec} --commit`)
  else if (st.next.startsWith('dispatch:')) await pipeline(st.next.slice(9).split(','),
      seat => agent(SEAT_PROMPT[seat](st), { agentType: `council-${seat}`, model: seat === 'review' ? TOP : seat }),
      (report, seat) => clerk(`record-seat ${spec} ${st.round} ${seat} <<'EOF'\n${report}\nEOF`))
  else if (st.next === 'judge')         await clerk(`judge ${spec} --commit`)
  else if (st.next === 'repair')        { /* queen-planner (model: TOP) cuts fix stories from st.red + BLOCK findings */ }
}
```

**The fallback driver** (`/vulyk-build` when the session brief reports "Workflow: unavailable")
runs the same `status` -> act loop with the Queen's own Bash for the verbs and the Agent tool
for seats. Same files, same verbs, same `next`; the difference is only whose context the
reports pass through. `/vulyk-status` and the SessionStart brief say which driver is active.

**Resume is the disk, not the run.** `/vulyk-resume` relaunches the Workflow fresh (`args:
{spec, top_model, stamp}` with `stamp` from the shell) and never passes `resumeFromRunId`: a
cached `status` result replayed after a human touched the tree is exactly the wrong answer.
A fresh launch costs one clerk call per already-closed step; it never re-dispatches a seat
whose file exists.

### D3. The council report contract

A seat's final message is exactly this, 40 lines max. Seats never write files
(`disallowedTools: Write, Edit, NotebookEdit`); the driver records.

```
COUNCIL: <slug> · round <N> · seat <haiku|sonnet|opus>
MODEL: <model id if the seat knows it, else "unknown">
COURT: <absolute path of the worktree it worked in>
VERDICT: GREEN | RED | N/A
ASSUMED CONFIG: <configuration judged against - from the Profile row, or "none given">
RAN: <commands actually executed, or "nothing">
PATH: <client path walked and how far - or "none named">
ASK <n>: GREEN | RED | N/A - <ask, short> - run: <cmd> saw: <output> | url: <where> saw: <what> | why: <reason>
UNASKED: <behaviour nobody asked for> | none
BREACH: none | <what was read that should not have been, and what was re-verified after>
```

Mechanical rules `record-seat` enforces: one `ASK <n>` line per number in `## Asks`, no
extras; `VERDICT` is `RED` iff some ask is RED, `N/A` iff every ask is N/A, else `GREEN`;
evidence tokens are `run:`+`saw:` or `url:`+`saw:` for GREEN/RED and `why:` for N/A.
A missing token is `MALFORMED` -> the seat is re-asked once with the gap named; on the second
attempt an unevidenced RED **stays RED** (the grill's rule) but is listed under
`red_unevidenced` and does not count toward the half-of-asks trigger, and an unevidenced
GREEN becomes N/A. `lead-review` keeps its own contract; `record-seat … review` extracts
only `PASS`/`BLOCK` and stores the whole report. An environmental failure (`EADDRINUSE`, a
missing service) is `N/A - why: environment: …`, never RED - a gate that names its own
interference is believed, as `docs/pipeline.md` already says.

### D4. The verdict rule (`cycle.sh judge`)

A = number of asks; RED_e = asks with an evidenced RED in any seat; RED_u = unevidenced
after re-ask; N = this round's number; C = ceiling from `ROUND` (3, +3 per `reopen`).

| Condition (first match wins) | Round verdict | `next` |
|---|---|---|
| `PAUSE` exists | none - `judge` exits 3 | `paused` |
| `**Checked:** REJECTED` newer than this round's `ROUND` | RED (owner outranks council) | `repair` |
| all three seats ABSENT | ESCALATE, `escalate:"env"` | `escalated` |
| \|RED_e\| >= ceil(A / 2) | ESCALATE, `escalate:"half"` - the plan is wrong, rounds are not burnt | `escalated` |
| review = BLOCK, or RED_e ∪ RED_u non-empty | RED; if N >= C -> ESCALATE, `escalate:"ceiling"` | `repair` / `escalated` |
| every seat GREEN or N/A, review PASS | GREEN | `green` |
| every seat N/A, review PASS | GREEN with `na:3` - passes on lead-review + story verification only (Tier 1 and VULYK itself) | `green` |

A round is one dispatch of `lead-review` ∥ three seats on one pack commit. Any fix - for a
BLOCK or a RED - is a new commit, therefore a new round; BLOCK never spawns a round of its
own. `ship-check.sh` stage 04+05 becomes: newest `council.jsonl` row for the spec is GREEN,
its `pack` is the current fingerprint, its `head` is HEAD or only paperwork landed since -
or, for specs recorded before v0.12.0, the acceptance row as today. A `**Checked:**
ACCEPTED` newer than the row satisfies the stage regardless of the row's verdict; the
ledger then shows both.

### D5. Blindness enforcement - the court

`open-round` creates `.vulyk/court/<slug>/round-N/` with `git worktree add --detach <path>
<head>`, then deletes everything under `docs/specs/<slug>/` except `brief.md` (stories,
`plan.md`, `journal.md`, `council/`). `Read`/`Grep` stay in the seats' toolset; inside the
court they find nothing to read. All three seats share the one court read-only and receive
its absolute path as `COURT`; the suite command goes to the sonnet seat only, the *Client
path* row (parallel-safe by the Profile's own rule: headless runner, curl, CLI) to all three,
and the *Browser MCP* row to the haiku seat only. `lead-review` never enters the court - it
needs the stories - and runs in the main tree at the same commit. `judge` removes the
worktree (`git worktree remove --force`, then `prune`); an orphaned court from a crash is
removed by the next `open-round`. Reading outside the court is a prompt rule with a
detector: `record-seat` marks a report tainted when it names a story id, `plan.md`,
`journal.md` or `council/`, and re-asks once.

### D6. Human intervention

`/vulyk-pause <slug>` = `cycle.sh pause`; the Workflow stops at its next clerk call (a seat
already running finishes and its report is recorded on resume). The journal and the terminal
print, at loop start, "the loop holds the working tree of `vulyk/<slug>`; to edit, run
`/vulyk-pause`". `/vulyk-resume <slug>` = `cycle.sh resume` then a fresh driver launch.
A manual code commit at any point makes the open round or the newest verdict `STALE` by the
same `paperwork_only` rule the human check uses today; the next `open-round` opens a new
round, and the ceiling still counts it. After `ESCALATE` the owner has three exits, all on
the record: `human-check.sh ACCEPTED` (ship over the council), `cycle.sh reopen "<decision>"`
(three more rounds, the decision quoted into `## Answers`), or leaving the spec open.

## Consequences

- **Easier:** one implementation of the verdict, the ceiling and staleness, tested in bash
  on every push; a driver that fits on one screen; a loop that survives `/clear`, a crash and
  a hive without Workflow identically; evidence the Queen reads from files at wake, not from
  a transcript. Blindness has a mechanism and a detector instead of an honour clause.
- **Harder / accepted debt:** the Workflow script is not executed in CI (bash-only runner);
  it is kept logic-free so that a `node --check` is all it needs where node exists. The clerk
  adds ~5 Haiku calls per round (each one turn, negligible). A seat's report crosses one
  Haiku copy on its way to disk; the contract check catches a mangled copy, a faithful
  paraphrase it cannot. `MODEL:` is `unknown` where a seat cannot see its own id, which
  weakens the rollback signal's comparability - recorded honestly rather than invented.
- **Token cost** (goes into `docs/token-economy.md`): per round, 3 cold-cache seats (one
  Opus-class) + `lead-review` at the top model + clerks; on RED, one planner dispatch at the
  top model plus workers. Against today's 1 Sonnet + 1 Opus per spec that is roughly 2-3x the
  gate cost at the target of <= 2 rounds. The fallback driver pays the same dispatches and
  additionally carries ~120 lines of reports per round through a pinned top-model session -
  the most expensive path, and `/vulyk-status` says so.
- **Migration:** `templates/plan.md` gains `**Briefed:**` and `**Council:**` placeholders;
  `ship-check.sh`, `human-check.sh`, `state.sh` learn the new files; `drone-acceptance.md`
  becomes three seat agents plus `cycle-clerk.md`; `.gitignore` gains `.vulyk/` and
  `docs/specs/*/PAUSE`; `install.sh` adds the two `Bash(...)` allow rules. Specs recorded
  under v0.11 keep working through the acceptance row.
- **Tests that must exist** (`tests/council.test.sh`, wired into `ci.yml` beside
  `cycle.test.sh`, synthetic repo, fixture reports): GREENx3+PASS -> GREEN; one evidenced RED
  -> RED; unevidenced RED -> exit 4 then RED on attempt 2 and excluded from `half`; 4 of 7
  asks RED -> ESCALATE `half`; three RED rounds -> ESCALATE `ceiling`; `reopen` -> ceiling 6;
  `ROUND` without a row -> `status` says open and lists missing seats; row without a plan
  line -> `judge` completes it; manual commit on an open round with a seat file -> STALE row
  and round N+1; `PAUSE` -> every mutating verb exits 3; `paperwork_only` accepts council
  commits; `ship-check` READY on `Briefed` + GREEN, NOT READY on RED, READY on RED +
  `Checked: ACCEPTED`, NOT READY on GREEN + `Checked: REJECTED`; a report naming `demo-01`
  -> tainted; the court contains `brief.md` and nothing else under the spec; `judge` removes
  the court.

## Invariants created

- The verdict of a round is computed only by `scripts/cycle.sh judge`; no model writes
  `**Council:**`, `council.jsonl` or `## Needs a human`.
- The round counter is the set of `docs/specs/<slug>/council/round-*` directories in git.
  A driver never holds it, and a resume never trusts a cached copy of it.
- A round is one dispatch on one pack commit; any commit after it is a new round, and
  STALE rounds with a seat file count toward the ceiling.
- Seats return reports, never write files; the driver records them through `record-seat`,
  which validates the contract before anything reaches disk.
- A seat report that names a story id, `plan.md`, `journal.md` or `council/` is tainted.
- The council works in a worktree at the pack commit whose `docs/specs/<slug>/` holds only
  `brief.md`; `lead-review` never works there.
- `PAUSE` is honoured by every mutating verb of `cycle.sh`, not by a driver's goodwill.
- `.claude/workflows/vulyk-cycle.js` contains no verdict, ceiling or staleness logic; it
  switches on `status.next` and dispatches agents.
- Paperwork commits are made only by `cycle.sh --commit` as `vulyk(<slug>): …`, and
  `paperwork_only()` lists every file the cycle writes.

## Revisit when

- A third driver appears (a cron/`claude -p` runner) - the `status`/`next` contract must
  hold for it unchanged, or the contract was not the truth.
- `council.jsonl` over the first month shows `red_unevidenced` blocking more rounds than
  `red` - the "unevidenced RED stays RED" rule is then costing rounds without catching
  defects and should flip to N/A.
- Claude Code gives Workflow scripts a shell or filesystem primitive - the clerk agent
  becomes a direct call; the CLI stays.
- A hive's Client path cannot be made parallel-safe - seats then need sequential dispatch
  (`dispatch:` one seat at a time), which the `next` contract already permits.
