# Software factory study: Opus analyst report

2026-10-19. Factory paths are relative to the clone root
`sf-src/repo/src/software-factory-claude-code/` (abbreviated `F:`). VULYK paths are relative to
`E:/Projects/vulyk`. Everything cited was read this session; what was not is marked "not checked".

**Bottom line.** The factory is a small, well-cut version of VULYK's loop: one skill, seven agents,
markdown state. VULYK already has almost every mechanism, mostly in a stronger, script-checked form. It
lacks three things worth having: (1) a merge that checks for conflicts before it runs and aborts
cleanly when it fails, (2) a targeted "a human looks at this one" rule keyed to risky areas (money,
auth, deploy, schema, new dependency) instead of the blanket human look VULYK dropped, (3) a worktree
per spec, so the loop stops holding the owner's checkout and specs can run side by side. (1) is a
Tier 1 fix, (2) is Tier 2, (3) is Tier 4 and needs the owner's call.

## 1. What the factory is

**Loop.** `feature → spec-writer → builder → [security, ux, ui, code] → WAIT FOR ALL → approver →
merge | needs-human`, with any `CHANGES` resuming the builder (F:`.claude/skills/factory/SKILL.md:15-21`).
One agent per step, each writing exactly one file (SKILL.md:23-31): `spec.md`, `build.md` + commits,
`round-N/review-<lens>.md`, `decision.md`.

**Roles and models.** spec-writer Opus, builder Opus, security reviewer Opus, UX/UI/code reviewers
Sonnet, approver Opus (F:`README.md:22-29`). The orchestrator is whatever session runs `/factory`; it
"never write[s] code, specs, reviews or decisions" and is the only writer of `job.json`
(SKILL.md:8-11). In the video one orchestrator ran on Sonnet at low effort while subagents stayed Opus.

**State model.** Per job: `factory/jobs/<id>/job.json` with `stage` (`spec|build|review|approve|merged|needs-human`),
`round`, and current-round `reviews` (SKILL.md:73-89). The file is rewritten whole on every change
(SKILL.md:89). Job folders are gitignored and live in the main checkout, never in a worktree
(SKILL.md:50-52, 59-60). The dashboard reads verdicts straight from each review's first line, so
`job.json` is a cache over the files (F:`factory/dashboard.html:312`). The original design had one
shared `board.json`; it was split per job so parallel sessions never write the same file
(F:`README.md:106-108` vs F:`BUILD_PROMPT.md:56`).

**Commands.** `/factory <feature>`, `/factory next`, `/factory approve <id>`, `/factory rework <id>
<note>` (SKILL.md:101-215). Free-form after the skill name.

**The small details that make it work.**
- *Claim by mkdir.* Job id = next 3-digit number; claimed with `mkdir` without `-p`; on failure take
  the next number (SKILL.md:103-107).
- *Claim by Edit on the backlog.* `/factory next` replaces the first `- [ ]` line with
  `- [x] <item> → claimed` in one Edit; a failed Edit means another session won, so re-read and take the
  next (SKILL.md:193-199). The claim marker is later replaced by the job id.
- *Worktree per job* at `../<repo>-factory/<id>` on `factory/<id>`; the main checkout "is the user's,
  and it may be dirty or on another branch. Only Merge touches it" (SKILL.md:42-49, 108-114). Every
  agent is told "the shell returns to the main checkout after every command, so start every Bash
  command with `cd <worktree> && `" (e.g. F:`.claude/agents/builder.md:14-20`).
- *Port allocation.* builder `5100+10n`, UX `5101+10n`, UI `5102+10n` (SKILL.md:97-99), plus a
  per-agent `agent-browser --session <id>-<role>` (builder.md:53-58), so parallel jobs never see each
  other's pages.
- *Verdict on the first line*: `STATUS: READY|BLOCKED`, `VERDICT: PASS|CHANGES`, `APPROVE|ESCALATE`
  (SKILL.md:127-130, 139-140, 159-162). A reviewer that writes no file or a non-verdict first line
  stops the job (SKILL.md:143-144).
- *WAIT FOR ALL.* Four reviewers spawned in one message; verdicts written to `job.json` as each lands;
  "Never resume the builder mid-round" (SKILL.md:136-144).
- *MAX_RESUMES = 2*, so at most 3 rounds (SKILL.md:33-35). On exhaustion the orchestrator writes
  `decision.md` = `ESCALATE` naming the outstanding reviewers (SKILL.md:151-154).
- *Resume the same builder* by name with `SendMessage` (SKILL.md:121-122, 147-150).
- *Reviewer convergence.* From round 2 each lens reads its own previous review and checks each finding
  was fixed (reviewer-code.md:27-28); "Don't block on pre-existing issues" (reviewer-security.md:61-63);
  taste goes to Notes (reviewer-ui.md:67-68).
- *Approver rules.* APPROVE only if every acceptance criterion is met (spot-check one yourself), all four
  reviews PASS with no real problem in their Notes, and `git merge-tree --write-tree main <branch>` is
  clean (approver.md:31-37). ESCALATE on money/access/identity, deploy/CI/build scripts, schema
  migration, email, production data, a new dependency, or a spec Assumption that is really a product or
  business decision (approver.md:39-47). `decision.md` ends with "For the human: the exact decision or
  check you need from them, and the files to look at" (approver.md:60-62).
- *Merge preconditions.* `git status --porcelain -- . ':!factory/backlog.md'` empty and current branch
  `main`; the backlog is exempt because job branches never touch it (SKILL.md:166-172). Then
  `merge --no-ff`, `worktree remove`, `branch -d`; on failure `merge --abort` and needs-human; a failed
  worktree removal does not un-merge; "Never push" (SKILL.md:174-183).
- *Spec writer.* Context with real paths, numbered Requirements, Acceptance criteria each with a
  command or page and its expected result, Out of scope ("what a reasonable builder might be tempted to
  do"), and Assumptions with one-line reasons, which the approver escalates when they are product
  decisions (spec-writer.md:30-54). The real 001 spec has criteria like "It prints `1 1 1 2`"
  (F:`factory/jobs/001-blog-reading-time/spec.md:81-86`). Note: the source never tells the spec writer to
  ask the human. The "choices for the human" seen in the video is the orchestrator relaying an
  ambiguity; in the files the only channel is `## Assumptions` → approver ESCALATE.
- *Rework.* Note saved verbatim to `rework-<k>.md`, fresh builder, fresh MAX_RESUMES (SKILL.md:205-215).
- *Nothing repo-specific in the agents*; all of it comes from AGENTS.md/CLAUDE.md (SKILL.md:37-38).

**What happened in the two real jobs.** Both passed round 1. 001 was escalated only because it edited a
prerender script, a one-line cache-key change the spec itself required (F:`.../001-blog-reading-time/decision.md:4,21`).
002 auto-merged. In both jobs the UX and UI reviewers reviewed "from the diff only; I did not run the dev
server" (002 `review-ux.md:7`, `review-ui.md:7`; 001 `review-ux.md:7`). Only the builder and one UI
review actually opened a browser.

## 2. Comparison with VULYK

| Factory mechanism | VULYK | Evidence |
|---|---|---|
| Orchestrator decides nothing, one state writer | **Has, stronger**: the driver "dispatches agents and decides nothing else"; `cycle.sh` is the state machine, tested | `.claude/workflows/vulyk-cycle.js:10-20` |
| Claim by mkdir | **Has**: `DRIVER` file written under `noclobber`, race re-read | `scripts/cycle.sh:2590-2606` |
| Clean-tree precondition with an exempt file | **Has, stronger**: `dirty_outside_paperwork` at claim, plus a per-hive glob list `.claude/vulyk-paperwork` | `scripts/cycle.sh:434-448, 2580-2588`; `docs/cycle.md:82` |
| Verdict on first line | **Has**: `VERDICT: PASS|BLOCK` line 1, by-position parse | `.claude/agents/lead-review.md:64-80` |
| WAIT FOR ALL | **Has**: seats in one `parallel`, then one `advance --ingest` | `vulyk-cycle.js:183-189` |
| Missing/bad report → stop | **Has, stronger**: rejection re-asked once with the error, a third dispatch stops | `vulyk-cycle.js:157-162, 172` |
| MAX_RESUMES / exhausted → ESCALATE | **Has, stronger**: tier ceiling 1/2/3, plus `half` and `no-progress` early exits | `docs/cycle.md:58-64` |
| Reviewer checks its own previous findings | **Has**: round ≥2 reads `since..head` + previous round | `lead-review.md:35-38` |
| Don't block on pre-existing issues | **Has, stronger**: BLOCK needs `[ask N]` or `[regression]` with base-side evidence | `lead-review.md:49-56` |
| Resume the same builder | **Different by design**: RED round → repair story with findings verbatim to a fresh worker | `docs/cycle.md:56-57`; `vulyk-cycle.js:116-119` |
| Rework `<note>` | **Has**: `cycle.sh reopen "<decision>"`, another tier's worth of rounds | `docs/cycle.md:85` |
| `/factory approve` | **Has**: `human-check.sh ACCEPTED` then `/vulyk-ship` | `docs/cycle.md:66-71` |
| Spec writer: Out of scope / Assumptions | **Has**: story `## Non-goals`; plan `## Assumptions` shown at the approval stop; grill with recommended option first | `templates/story.md:54`; `.claude/commands/vulyk-plan.md:28,53-55`; `templates/grill.md:28-29` |
| Acceptance criteria with expected output | **Has, mechanical**: `## Verification` run by `close-story`; blind seats record `run:`/`saw:` | `templates/story.md:65-92`; `.claude/agents/council-opus.md:125-128` |
| Reviewers read the builder's own account (`build.md`) | **Deliberately not**: blind court holds only `brief.md`; reading plan/journal is a BREACH | `council-opus.md:109-117` |
| Specialist lenses (security, UX, UI) | **Weaker on security**: no security seat; `lead-review` covers "security holes" inside correctness; a security probe only for the Tier 4 second reviewer. UX/UI: `council-haiku` black-box walk when *Client path* is filled | `lead-review.md:20`; `.claude/commands/vulyk-build.md:79-80` |
| Approver risk-class ESCALATE (money, auth, deploy, schema, dependency, product assumption) | **Lacks**. Nothing routes a diff to the owner by what it touches. Planning asks for a test on money/security/data-write logic only | `.claude/agents/queen-planner.md:32`; `vulyk-plan.md:42-44` |
| "For the human: exact decision + files" | **Weaker**: `## Needs a human` is written mechanically (round, RED asks); the Queen prints it verbatim | `scripts/cycle.sh:913-933`; `vulyk-build.md:91-93` |
| Merge preconditions: on main, clean, `merge-tree` conflict pre-check, `merge --abort` | **Weaker**: `ship-check.sh` checks the tree and notes the branch; `/vulyk-ship` says only "merge … the way the Profile's *Release / deploy* row says". No conflict pre-check, no abort rule (grep for `merge-tree`/`merge --abort` in scripts/.claude/docs: no hits) | `scripts/ship-check.sh:95-125`; `.claude/commands/vulyk-ship.md:22-23` |
| Never push | **Has** | `vulyk-ship.md:24-27` |
| Worktree per job, main checkout stays the owner's | **Lacks**: `branch` checks out `vulyk/<slug>` in the main tree; "the loop holds the working tree" for the whole build. Worktrees exist only for the court | `scripts/cycle.sh:1424-1430`; `docs/adr/001-cycle-state-contract.md:343`; `scripts/cycle.sh:2089-2105` |
| Parallel jobs + port allocation | **Lacks**, and the gap is documented: parallel council rounds hit `EADDRINUSE`; advice is "one at a time, or ephemeral ports" | `docs/pipeline.md:77-86` |
| Backlog queue + `/factory next` | **Lacks a queue**: the next-circle draft is handed to the owner; "Do not open a spec for them" | `vulyk-ship.md:31-41`; `docs/cycle.md:123-137` |
| Dashboard | **Has another form**: `/vulyk-status` and the pulse band (live phase/wave/round/agents) | `.claude/commands/vulyk-status.md:1-25`; `docs/pulse.md:1-20` |
| One-line progress per transition | **Has** | `vulyk-build.md:11-12`; `vulyk-cycle.js:202` |
| Transient, gitignored state | **Different**: VULYK commits paperwork (plan, journal, council files) | `docs/cycle.md:16-20` |
| Cheap orchestrator, strong subagents | **Has a knob**: model profiles | ADR-020 (`docs/adr/020-model-profiles.md`, not opened this session) |

## 3. Ideas worth adopting (ranked)

**1. ADOPT: safe merge in `/vulyk-ship`.** Before merging: on the default branch, tree clean outside
paperwork, and `git merge-tree --write-tree <default> <branch>` reports no conflict. If the merge fails
anyway: `git merge --abort`, record nothing, tell the owner. *Why VULYK:* today step 2 is one sentence
with no conflict rule (`vulyk-ship.md:22-23`). The default branch can move between the green round and
the ship (owner commits, another spec shipped, a hotfix), and a half-done merge leaves the owner's
checkout in a merge state, with the `**Shipped:**` record possibly still to write. *Cost:* a few lines in
`vulyk-ship.md` step 2, optionally one check in `ship-check.sh`. Tier 1. `merge-tree --write-tree`
needs a fairly recent git; the fallback is a trial `merge --no-commit --no-ff` + `--abort`. Which
version introduced it was not checked; verify before shipping.

**2. ADAPT: targeted "ask a human" by risk class, checked by a script, not by an approver agent.** A
hive file `.claude/vulyk-escalate` (same shape as `.claude/vulyk-paperwork`: globs, `#` comments),
seeded by `/vulyk-bootstrap` from the repo (payments, auth, rules, deploy/CI, migrations, dependency
manifests). `ship-check.sh` reads `git diff --name-only <base>..<head>` against it. On a hit, the green
prompt changes from «Выпускаем?» to a plain-language question that names the class, the files and the
exact decision, with `human-check.sh ACCEPTED` as the way through. Two extras come along: a dependency
manifest change counts as a hit, and any `(assumed)` grill answer or `## Assumptions` line that is a
product decision gets shown at the same prompt. *Why VULYK:* VULYK dropped the mandatory human look
because it had become ceremony (`docs/cycle.md:35-42`). That was right, but it left no way back for the
few diffs where an owner look is substantive. Assumptions are shown at the approval stop
(`vulyk-plan.md:53-55`), but Tier 1 and `--go` / no-question mode skip that stop, and nothing brings
them back at ship time. The factory's own run shows the risk of over-tight lists: 001 escalated a
one-line cache key. So start the list narrow, keep it in a file per hive, and have it name *what* to
decide. *Cost:* a new optional file, about 20 lines in `ship-check.sh`, a line in the Terminal sections
of `vulyk-build.md`/`vulyk-review.md`, a bootstrap question, tests in `tests/cycle.test.sh` or the
ship-check tests. Tier 2. It also stays off the constitution, which is at 7269 bytes against ADR-016's
caps (headroom not checked).

**3. ADAPT (owner decision): a worktree per spec.** `cycle.sh branch` would create
`../<repo>-vulyk/<slug>` (or `.vulyk/spec/<slug>`) on `vulyk/<slug>` instead of checking it out in the
main tree. Workers, clerk and reviewer get the path and the "`cd <worktree> && ` on every Bash call"
rule. Only `/vulyk-ship` touches the main checkout. *Why VULYK:* a Tier 3 build holds the owner's
working tree for hours (`ADR-001:343`), and VULYK cannot run two
specs at once. The factory shows it can be done in prompts alone. *Cost:* high. `branch`, `claim`'s
clean-tree check, `close-story`/`scope-check` (they assume cwd = repo root), `build_court` (already
worktree-aware, and has the Windows `core.longpaths` handling at `cycle.sh:2073, 2099`), the driver
prompts, `/vulyk-pause` semantics, and the e2e/driver tests. Spec paperwork lives on the branch, so it
would live in the worktree too. That is consistent, but `/vulyk-status` would have to read across
worktrees. Tier 4 with `lead-architect` and an ADR. Run a study first, not a build.

**4. ADAPT, only together with 3: a port base per spec.** `status --json` carries `port_base` (for
example `5100 + 10·n` from a spec counter), and the Profile's dev-server command gets a `<port>`
placeholder. Seats and workers use `base+0/1/2`. *Why:* `docs/pipeline.md:77-86` already names the
`EADDRINUSE` failure that parallel councils hit. *Cost:* small once worktrees exist. Without 3 it is
speculative (Law 2).

**5. ADAPT: "For the human" in an escalation.** When `next` is `escalated`, the Queen prints the
mechanical `## Needs a human` block and then adds three lines in the owner's language: the decision
needed, the files to look at, and the recommended exit (ACCEPTED / reopen with a decision / leave). *Why:*
the block is assembled by `cycle.sh` (`:913-933`), and an owner who sees only round numbers and ask
numbers has to dig. This matches the owner's "plain bottom line first" rule. *Cost:* a few lines in
`vulyk-build.md:91-93` and `vulyk-review.md`. Tier 1.

**6. ADAPT, low priority: a backlog file.** `/vulyk-ship` step 5 also appends the next-circle draft to
`docs/backlog.md` as `- [ ]` lines, the owner edits or deletes them, and `/vulyk-plan next` takes the
first one the owner kept. The claim-by-Edit trick only matters with parallel sessions (idea 3). *Why:*
the draft is printed in chat; its sources stay on disk, but they are spread across council files and
plan.md. *Cost:* small. The danger is the framework choosing the next circle, which `vulyk-ship.md:40-41`
forbids. Fine as long as only the owner adds or keeps lines.

**7. REJECT: a separate Opus approver after the council.** VULYK's council is unanimous, blind and
script-judged, and `ship-check.sh` gates the merge. The approver's real value (risk classes, conflict
check) is covered mechanically by ideas 1 and 2 at zero tokens. In job 001 it mostly re-read `build.md`
and re-ran two commands (decision.md:7-16). It would also be one more judge reading the hive's own
account, which the court's blindness exists to avoid.

**8. REJECT: resume the same builder with SendMessage.** The factory itself lists "resuming the builder
only works within a session" as a limitation (video-notes). VULYK's repair story carries the findings
verbatim to a fresh worker, survives `/clear`, and is how the owner's "relaunch fresh, never
resumeFromRunId" rule works (`.claude/commands/vulyk-resume.md`, not opened).

**9. REJECT: four fixed lenses on every round.** The real jobs show UX/UI lenses doing diff-only PASSes
on diffs with no visual surface. VULYK sizes the council by tier (`docs/cycle.md:99-104`). Keep one
piece: when idea 2's risk file hits a security class, `lead-review`'s dispatch gets the security-probe
line the Tier 4 second reviewer already has (`vulyk-build.md:80`). That is ADAPT, folded into 2.

**10. REJECT: reviewers fed the builder's evidence (`build.md`).** It conflicts with the court's taint
rule (`council-opus.md:111-117`), the core of why VULYK's stage 05 catches things (`docs/cycle.md:35-42`).

**11. REJECT: gitignored transient job state.** VULYK's committed paperwork is what makes `/clear` and
relaunch safe. The factory's own limitation list says "state is not tracked cleanly yet".

**12. REJECT for now: external intake (GitHub issues, Sentry) and an HTML dashboard.** Intake is
speculative (Law 2), and VULYK is public with no-push defaults. The pulse band and `/vulyk-status`
already cover what the dashboard covers.

## 4. What VULYK does better (do not regress)

- State moves through a tested script, not prompt prose. The driver cannot misjudge a verdict because it
  never judges one (`vulyk-cycle.js:10-20`).
- Blind seats in a court reduced to `brief.md`, plus `run:`/`saw:` evidence on every ask. The factory's
  reviewers read the builder's own claims, and two of four said so ("The build log reports them as
  passing", 001 `review-code.md:14`).
- Anchored BLOCKs (`[ask N]`/`[regression]`), `no-progress` and `half` early escalation. The factory has
  a bare resume counter.
- Upfront intent capture: grill with the recommended option first, verbatim `## Asks`, coverage drone,
  approval stop. The factory catches ambiguity only at the end, as an escalation.
- Rejected reports are re-asked with the reason. The factory just stops.
- Paperwork exemptions as a per-hive file, not a hard-coded path.
- STALE detection when code moves after a verdict (`docs/cycle.md:82`). The factory has none: a commit
  after APPROVE would merge unseen.

## 5. Open questions for the owner

1. **Worktree per spec (idea 3): study it now?** Recommended: yes, as a study (`/vulyk-plan --study`),
   not a build. It is the only idea that changes what VULYK can do (the owner keeps the checkout, specs
   run in parallel), but it touches `cycle.sh`'s core and Windows path handling, so it needs evidence
   first.
2. **Risk-class escalation (idea 2): ship the file empty, or seeded by bootstrap?** Recommended: seeded
   by `/vulyk-bootstrap` with a short list the owner confirms (money, auth, deploy/CI, migrations,
   dependency manifests). An empty default helps nobody, and an auto-derived long list repeats the
   factory's "too tight" escalations.
3. **Backlog file (idea 6): wanted?** Recommended: not until idea 3 lands. With one spec at a time, the
   next-circle draft in chat plus the files on disk is enough.
4. **Do ideas 1 and 5 need a brief, or are they Tier 1 now?** Recommended: one Tier 1 spec covering both;
   both are a few lines in the ship and build/review commands.
