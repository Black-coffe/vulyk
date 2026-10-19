# Software factory study: Fable analyst

Factory source cited as `SF:<path>:<line>` (root `zazencodes-season-3/src/software-factory-claude-code/`).
VULYK cited as `<path>:<line>` from `E:/Projects/vulyk`. Everything below was read this session; "not checked" means it.

## 1. What the factory is

One skill (`/factory`, 220 lines), seven subagents, markdown state. The session that runs the skill is the
orchestrator: it spawns every agent, is the only writer of `job.json`, and "never write[s] code, specs, reviews
or decisions" itself (`SF:.claude/skills/factory/SKILL.md:8-11`).

**Loop** (`SKILL.md:15-21`): feature → spec-writer → builder → four reviewers in parallel → WAIT FOR ALL → any
CHANGES: resume the builder (`MAX_RESUMES = 2`, so at most 3 rounds, `SKILL.md:33-35`) → all PASS → approver →
APPROVE merges to `main`, ESCALATE goes to `needs-human`.

**State model** (`SKILL.md:62-89`): `factory/jobs/<job-id>/` holds `spec.md`, `build.md`, `round-N/review-*.md`,
`decision.md`, `rework-k.md`; gitignored, "runtime state that never lands in a commit". `job.json` has a `stage`
enum (`spec|build|review|approve|merged|needs-human`), `round`, and the current round's `reviews` map, rewritten
whole on every change. Earlier rounds are not in `job.json`: the dashboard reads the first line of each review
file directly (`SF:factory/dashboard.html:312`).

**Verdict on the first line.** Every review starts `VERDICT: PASS|CHANGES`, `build.md` starts
`STATUS: READY|BLOCKED`, `decision.md` starts `APPROVE|ESCALATE` (`SF:BUILD_PROMPT.md:87-88`,
`SF:.claude/agents/builder.md:73,93`, `approver.md:65`). The orchestrator reads only that line; a reviewer that
writes no file or a non-verdict first line stops the run ("stop and tell the user", `SKILL.md:143-144`).

**Guards and sequencing.**
- Claim-by-mkdir: the job id is the next 3-digit number; `mkdir factory/jobs/<job-id>` without `-p` claims it, a
  failure means another session won, pick the next number (`SKILL.md:103-107`).
- Claim-by-Edit on the backlog: `/factory next` replaces the first `- [ ]` line with `- [x] <item> → claimed` in one
  Edit; a failed Edit means another session claimed it, re-read and take the next (`SKILL.md:193-199`).
- One worktree per job, `../<name>-factory/<job-id>` on `factory/<job-id>`, branched from `main`; the main checkout
  "is the user's, and it may be dirty or on another branch. Only Merge touches it" (`SKILL.md:40-54,111-117`).
- Port allocation: job `n` gets `5100+10n` (builder), `5101+10n` (ux), `5102+10n` (ui), plus a per-job
  `agent-browser --session <job-id>-<role>` (`SKILL.md:96-99`, `builder.md:52-58`).
- WAIT FOR ALL: verdicts are written to `job.json` as they land (dashboard chips), but the round ends only when all
  four files exist; "Never resume the builder mid-round" (`SKILL.md:139-144`).
- The builder is a named agent (`builder-<job-id>`) resumed by `SendMessage` with the round folder, so it keeps its
  context across rounds (`SKILL.md:121-122,147-150`); rounds exhausted → the orchestrator writes `ESCALATE` itself
  (`SKILL.md:151-154`).
- Merge preconditions: main checkout clean except `factory/backlog.md` (exempt because every `/factory next`
  edits it and job branches never touch it) and on `main`; `git merge --no-ff`, then `worktree remove`,
  `branch -d`; a failed merge is `git merge --abort` + `needs-human`; "Never push" (`SKILL.md:164-183`).
- Needs human: the branch and worktree stay for inspection; the user runs `/factory approve <id>` or
  `/factory rework <id> <note>` (verbatim note to `rework-k.md`, fresh builder, fresh `MAX_RESUMES`,
  `SKILL.md:185-215`).
- Reporting: "one short line per transition" (`SKILL.md:217-221`).

**Roles.** Spec-writer (Opus) reads the real code in the worktree ("don't guess at names"), writes Context with
cited paths, Requirements, Acceptance criteria each with "how to verify it: a command, a page, or a file",
Out of scope ("what a reasonable builder might be tempted to do but must not"), and Assumptions each with a
one-line reason; "The approver escalates to a human when one of these is a product decision"
(`SF:.claude/agents/spec-writer.md:22-54`). Rules: smallest change, reuse an existing pattern by name, doc
updates are requirements, tests only if the repo has a runner (`spec-writer.md:56-65`). Builder (Opus): checks
`git branch --show-current` first, else BLOCKED; records evidence per acceptance criterion in `build.md`; lints
only changed files, never `--fix` repo-wide; stages explicit paths, never `git add -A`; "Don't paper over a failure
to reach READY" (`builder.md:34-36,43-65,93-96`). Reviewers: security (Opus), ux/ui/code (Sonnet); from round 2
each re-reads its own previous file and checks each finding was fixed (`reviewer-code.md:28-29`); CHANGES only for
bugs, spec gaps, failing checks; style goes under Notes; pre-existing issues are Notes, not blockers
(`reviewer-code.md:65-68`, `reviewer-security.md:61-63`); ux/ui "Don't sign in or submit forms: the dev server
may talk to real services" (`reviewer-ux.md:36-37`). Approver (Opus): "approve only what you would merge
yourself"; APPROVE needs every criterion met with convincing evidence plus one spot-check of its own, all four
PASS with no Note describing a real problem, and `git merge-tree --write-tree main <branch>` clean; ESCALATE on
money/access/identity, deploy/CI/hosting config, schema migration, email, production data, a new dependency, or
a spec Assumption that is a product decision; `decision.md` ends with "For the human: the exact decision or
check you need from them, and the files to look at" (`approver.md:9-62`).

**What the real jobs show.** Job 001 passed all four reviews and was escalated for a one-line edit to a
prerender script (deploy class) (`SF:factory/jobs/001-blog-reading-time/decision.md:4`); the author calls the
guardrails too tight (video notes). Three of the eight reviews say "diff review only; I did not run the browser"
or "I did not run the browser or prerender acceptance criteria myself. The build log reports them as passing"
(`SF:.../001.../round-1/review-code.md:14`, `review-ux.md:7`, `002.../review-ui.md:7`): the lenses trust the
builder's own evidence.

## 2. Comparison with VULYK

| Factory mechanism | VULYK | Evidence |
|---|---|---|
| Orchestrator writes state, agents each write one file, context from files | **Stronger.** `cycle.sh` is the only writer; the driver "decides nothing", never reads prose; a worker's outcome is a frontmatter key, not chat | `.claude/workflows/vulyk-cycle.js:10-18`, `docs/adr/006-worker-status-channel.md`, `memory/map/cycle.md:9-16` |
| Verdict on the first line, malformed = stop | **Stronger.** `record-seat` rejects a bad first line (exit 4, MALFORMED), re-asks once, then ABSENT → ESCALATE `env`; seats also need one `ASK n` line per ask with `run:`/`saw:` and are tainted if they name stories | `scripts/cycle.sh:1543-1544`, `docs/pipeline.md:18-19` |
| WAIT FOR ALL, never resume builder mid-round | **Has it.** `judge` needs every seat file or two spent attempts; a commit during a round re-stamps or STALEs it | `docs/adr/001:183`, `docs/cycle.md:81` |
| MAX_RESUMES=2 | **Richer.** Ceiling 1/2/3 by tier, plus `half`, `no-progress`, `env`; `reopen` adds a tier's worth | `docs/cycle.md:53-64`, `scripts/cycle.sh:1274` |
| Resume the same builder with its context | **Different by design.** A repair story goes to a fresh worker with findings verbatim; survives `/clear`; costs orientation | `cycle.sh:2608` (map `:76-81`), `.claude/agents/lead-review.md:58-60`, `queen-planner.md:40` |
| Claim-by-mkdir / noclobber | **Has it.** `claim` is `noclobber` on `DRIVER`; `mkdir round-N` is the atomic act | `scripts/cycle.sh:2594`, `docs/adr/001:123` |
| Backlog with claim-by-Edit, `/factory next` | **Lacks it.** The next-circle draft is handed to the owner as text; "Do not open a spec for them" | `.claude/commands/vulyk-ship.md:36-41` |
| Worktree per job; owner's checkout stays free | **Lacks it.** `cmd_branch` checks the spec branch out in the main tree; "the loop holds the working tree"; `/vulyk-pause` exists to hand it back. Only the blind court is a worktree; `/vulyk-evolve` is the one builder that works in `.claude/worktrees/` | `scripts/cycle.sh:1425-1440`, `.claude/commands/vulyk-build.md:47-48`, `vulyk-pause.md:18-19`, `cycle.sh:2099`, `vulyk-evolve.md:88` |
| Parallel jobs, per-job ports and browser sessions | **Lacks it, documented.** "What is not safe is judging several specs at once"; `EADDRINUSE` named | `docs/pipeline.md:78-84` |
| Builder checks it is on the right branch | **Lacks it.** No `show-current`/`abbrev-ref` anywhere in `cycle.sh` (grep); `close-story` commits on whatever HEAD is; `ship-check` only notes the branch | `scripts/ship-check.sh:96-109` |
| Merge preconditions: clean, on main, `merge-tree` conflict check, `--abort`, branch cleanup, never push | **Weaker.** `ship-check` reads six artifacts and tree cleanliness; `/vulyk-ship` merges locally and prints the publish command; no `merge-tree` precheck, no abort rule, branch cleanup not checked | `scripts/ship-check.sh:95-138`, `.claude/commands/vulyk-ship.md:16-26` |
| Escalation classes (money, auth, deploy, deps, product assumption) + "For the human" paragraph | **Weaker.** `## Needs a human` is mechanical (reason, RED asks, seat dir); the ship stop is «Выпускаем?» with the round count; no risk-class list in the Profile or reviewer | `scripts/cycle.sh:993-1000`, `vulyk-build.md:86-90`, `CLAUDE.md` Profile |
| Spec: Out of scope, Assumptions with reasons, AC with a probe each | **Has it.** Story `## Non-goals` with the same rationale; plan `## Assumptions` vetoable at the stop; grill with recommended-first options. AC lines carry no probe; the blind seat invents one per ask | `templates/story.md:54-59`, `templates/plan.md:11-14`, `templates/grill.md:19-31`, `council-opus.md:32-35` |
| Builder evidence per acceptance criterion | **Weaker form.** Worker reports `TESTS:`/`CONCERNS:` and notes; `close-story` runs `## Verification` on the record; AC boxes are not required to be ticked with evidence | `worker-code.md:26,56-65`, `templates/story.md:65-67` |
| Reviewer: lint changed files only, never `--fix`; explicit paths, never `add -A` | **Stronger.** Law 3 + `scope-check` + `close-story` commits exactly `## Files` | `templates/story.md:44-52`, `scripts/scope-check.sh:1-30` |
| Reviewer re-reads own previous round | **Has it.** Round 2+ reads `since..head` plus previous findings | `lead-review.md:35-38` |
| Don't block on pre-existing issues | **Has it.** `[regression]` needs base-side evidence; untouched code waits for the next circle | `lead-review.md:38,49-56` |
| Four lenses (security, ux, ui, code) | **Different.** `review` (asks + correctness, security named inside correctness), `opus` (intent), `haiku` (client walk, only with a Client path). No dedicated security lens | `lead-review.md:19-20`, `docs/cycle.md:44-51` |
| Reviewers trust the builder's evidence (jobs show it) | **Stronger.** Seats must run each ask; "a project gate's green is not your `saw:`" | `council-opus.md:34-35` |
| Model split: Opus builds, Sonnet reviews ux/ui/code | **Opposite, on purpose.** Sonnet executes, Opus judges; the family that builds never judges | `CLAUDE.md` Models, `docs/adr/015` |
| Orchestrator is a model (Sonnet, low effort) | **Cheaper.** The driver is JS with no model; its hands are a Haiku clerk with `maxTurns: 5` | `cycle-clerk.md:5-7`, `vulyk-cycle.js` |
| Dashboard polling `job.json` | **Partial.** Pulse band (live, terminal), `/vulyk-status` (on demand), `journal.md`, `.claude/state.json`; no browser board | `docs/pulse.md:1-20`, `vulyk-status.md` |
| `/factory rework <note>`, `/factory approve` | **Has it.** `cycle.sh reopen "<decision>"`, `human-check.sh ACCEPTED/REJECTED` | `docs/cycle.md:66-71,85` |
| Runtime state gitignored | **Opposite.** Council files, journal, stats are committed: the record is the point | `memory/map/cycle.md:9-16` |

## 3. Ideas worth adopting (ranked)

1. **ADOPT: `merge-tree` precheck and abort rule at ship.** `ship-check.sh` stage 06 runs
   `git merge-tree --write-tree <default> <head>`; a conflict is `NOT READY: merge would conflict in <paths>`.
   `/vulyk-ship` step 2 gains: a failed merge is `git merge --abort`, stay on the branch, report. Closes a hole the
   factory names and VULYK does not: a GREEN round can still be unmergeable after another spec shipped.
   Cost: ~20 lines of bash, one test in `tests/constitution.test.sh` or a new ship-check case. Lands in
   `scripts/ship-check.sh`, `.claude/commands/vulyk-ship.md`, `docs/cycle.md` table.

2. **ADOPT: the branch guard in `close-story`.** Refuse (exit 2, `on <branch>, story branch is vulyk/<slug>`)
   when `git rev-parse --abbrev-ref HEAD` is not plan.md's `**Branch:**`. Today a worker in a hive whose owner
   checked out another branch mid-pause would commit a story onto it. Cost: ~10 lines + a `cycle.test.sh` case.
   Lands in `scripts/cycle.sh cmd_close_story`, ADR-001 D2 precondition table.

3. **ADAPT: an escalate-paths file and a "for the owner" paragraph at the ship stop.** Not a new verdict and
   not a new human stop (CONSOLIDATED #1-#3 forbid one): the stop already exists («Выпускаем?»). Add
   `.claude/vulyk-escalate` (globs, same reader as `.claude/vulyk-paperwork`, `scripts/lib.sh:68-72`): payment,
   auth, deploy config, migrations, dependency manifests. `ship-check.sh` prints `touches escalate paths: <list>`
   deterministically; `lead-review`'s report gains an optional `## For the owner` (two sentences: what changed in
   those paths and the one check to make), and `/vulyk-build`'s question quotes both. Cost: lib.sh + ship-check
   + one reviewer section + the question text; a fixture for the globs. Lands in `scripts/lib.sh`,
   `scripts/ship-check.sh`, `.claude/agents/lead-review.md`, `.claude/commands/vulyk-build.md`, `vulyk-review.md`,
   `/vulyk-bootstrap` (seed the file from the interview). The factory's own lesson applies: job 001 shows a class
   list that fires on a one-line edit; keep it to paths the owner names, never a model's guess.

4. **ADAPT: build in a worktree, owner keeps the checkout.** `cmd_branch` creates
   `.claude/worktrees/<slug>` on `vulyk/<slug>` (the `/vulyk-evolve` precedent) instead of checking the branch
   out under the owner. Pain closed: the hive holds the tree for hours; `/vulyk-pause` exists only to give it
   back; the owner cannot work on another hive branch meanwhile. Cost: high. `cycle.sh` resolves `ROOT` from cwd;
   workers, seats and `close-story` would need the worktree path; the court nests a worktree inside one; the
   driver and clerk run from the Queen's cwd; the owner's global rule forbids `cd` in Bash (handoff tracking), so
   the mechanism must be path arguments, not `cd` prefixes as the factory does (`SF:builder.md:15-17`). Claude
   Code's `EnterWorktree` tool exists in this session's deferred list: not checked whether it moves the whole
   session, which would make this cheap. Recommend a Tier 3 study spike before any story. Parallel specs per hive
   (factory `SKILL.md:40-54`) ride on this but add port and browser-profile allocation; defer them.

5. **ADAPT: a backlog the owner fills, `/vulyk-plan next`.** `docs/specs/backlog.md` with `- [ ]` lines; `next`
   claims the first by one Edit (`→ <slug>`), then runs the normal plan. Pairs with the existing no-question mode
   (`templates/grill.md:57-63`) and `--go` for unattended runs. Keeps `/vulyk-ship`'s rule: the draft of the next
   brief is still only offered; the owner moves it to the backlog. Cost: one command section, one file, one
   `wave-check`-style line in `/vulyk-status`. Owner decision (Q2).

6. **ADAPT: evidence per acceptance criterion in the story.** Worker ticks each `- [ ]` with one evidence clause
   (`[x] ... — saw: <n> rows` or the command). Cheap, and gives `lead-review` a checklist to spot-check instead of
   re-deriving; the blind seats keep running asks themselves. Cost: two lines in `worker-code.md`/`worker-test.md`
   and the story template; story size budget already allows it. Watch the factory's failure mode: reviewers
   trusting build.md. VULYK's seats are bound not to (`council-opus.md:34-35`); keep that line.

7. **REJECT: four review lenses as four seats.** ADR-013 retired a seat for cost (it was GREEN 80/101 rounds);
   the factory's own evidence is three of eight lens reviews skipping their run. Security belongs as a named
   item in `lead-review`'s correctness list (it is: `lead-review.md:19-20`) and in the escalate paths above.
   The ui lens's "no visual change → PASS and say so" (`reviewer-ui.md:53`) is already `council-haiku`'s
   `N/A - why:` (`council-haiku.md:40-42`).

8. **REJECT: Sonnet reviewers, Opus builder, model orchestrator.** Inverts ADR-015 and the Law "the family that
   builds never judges"; the JS driver plus Haiku clerk is cheaper than any model orchestrator.

9. **REJECT: resume the same builder across rounds.** VULYK's fresh worker with verbatim findings is deliberate
   (ADR-013 D4), survives `/clear` and session death (the factory admits resume works only within a session),
   and keeps the judge from reading a builder's growing context. Revisit only with a measured orientation cost
   from `token-report.py`.

10. **REJECT: gitignored runtime state and a browser dashboard.** VULYK's record is committed on purpose; the pulse
    band and `/vulyk-status` cover the live view, and a board is an unrequested feature (Law 2; "offer, never
    auto-enable").

11. **REJECT: the spec writer reads source.** `queen-planner` never opens source by design (`queen-planner.md:15-16`);
    scouts do, at low effort. Different context economy, not a gap.

## 4. What VULYK does better

Evidence over trust: seats must run each ask (`run:`/`saw:`), a gate's green is not a `saw:`, BLOCKs must be
anchored to an ask or a regression with base-side proof; the factory's reviewers may and did defer to `build.md`.
Blindness: the court holds only the brief, taint is detected; the factory's reviewers read the spec and build log.
Convergence: diff-only re-review, carried seats, `no-progress` and `half` exits; the factory restarts the full
four-lens review each round. Scope: `## Files` is machine-checked and committed exactly; the factory relies on
prose ("never `git add -A`"). State: everything re-derived from committed files, a driver with no decisions, a
`DRIVER` semaphore with a known liveness oracle; the factory's `job.json` can drift and its claims are by
convention. Human gates: one stop at plan, one question at ship, override in both directions with a stale check;
the factory's needs-human is its only human path and fires on class lists a model derived.

## 5. Open questions for the owner

1. **Build in a worktree so the hive never holds your checkout?** Recommend: yes, but as a Tier 3 study spike
   first (EnterWorktree, `ROOT` resolution, the court inside a worktree, the no-`cd` rule), not a story now. It is
   the one factory idea that changes your daily experience; everything else is a guard.
2. **A backlog file and `/vulyk-plan next`?** Recommend: yes, small, only if you want unattended runs
   (`claude -p --go`); otherwise the next-circle hand-off already does the job and a queue is a feature nobody
   asked for.
3. **Which paths go in `.claude/vulyk-escalate` for VULYK itself?** Recommend: `install.sh`, `scripts/lib.sh`,
   `.github/workflows/`, `CLAUDE.md`; hives seed theirs at bootstrap. Your call, never the model's.
4. **Should a conflict found by `merge-tree` be `NOT READY` (refuse) or a note?** Recommend: refuse. A green that
   cannot merge is the ship-check's whole reason to exist.
