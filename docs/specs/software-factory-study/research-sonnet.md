# Software factory (zazencodes) vs VULYK: Sonnet analyst

Factory source root (abbrev. `SF`): `zazencodes-season-3/src/software-factory-claude-code/`. Citations `SKILL:n` = `.claude/skills/factory/SKILL.md`, `AG:<name>:n` = `.claude/agents/<name>.md`, `BP:n` = BUILD_PROMPT.md. VULYK paths are under `E:/Projects/vulyk`.

## 1. What the factory is

A 7-agent, one-skill pipeline: `feature -> spec-writer -> builder -> 4 parallel reviewers -> WAIT FOR ALL -> approver -> merge | needs-human` (SKILL:15-21). Everything is prose instructions to an LLM orchestrator plus markdown/JSON files; there is no script, no state machine code, no tests.

**Roles and models.** spec-writer, builder, security reviewer and approver on Opus; ux, ui, code reviewers on Sonnet (AG:*:5; README table). The session that types `/factory` is the orchestrator (SKILL:8-11), "never writes code, specs, reviews or decisions", only moves the job and writes `job.json`.

**State model.** Files, not conversation (BP:86). One folder per job `factory/jobs/<id>/` with `spec.md`, `build.md`, `round-N/review-*.md`, `decision.md`, `rework-k.md`, plus `job.json` (SKILL:62-89). `factory/jobs/` is gitignored runtime state (SKILL:58-60; README step 3), so the state is transient and lives in the main checkout, never in a worktree (SKILL:50-52). `job.json` is rewritten whole on every change by the orchestrator LLM (SKILL:89). Each agent writes exactly one file (AG:builder:10, AG:approver:10, all reviewers).

**Commands** (SKILL:101-215): `/factory <feature>`, `next` (backlog), `approve <id>` (merge a needs-human job), `rework <id> <note>`.

**Small mechanisms that make it work:**
- Job id claim by `mkdir factory/jobs/<id>` without `-p`; failure means another session took the number, retry next (SKILL:103-107).
- Backlog claim by one exact-line Edit `- [ ] x` -> `- [x] x -> claimed`; a failed Edit means the line changed, re-read and take the next (SKILL:193-196).
- Verdict on the first line: `VERDICT: PASS|CHANGES` for reviews (AG:reviewer-code:60-65), `APPROVE|ESCALATE` for decision.md (AG:approver:65), `STATUS: READY|BLOCKED` for build.md (AG:builder:73,93). The orchestrator reads only line 1 (SKILL:127, 140, 159-162). A first line that is not a verdict means stop and tell the user (SKILL:143-144).
- WAIT FOR ALL: round is done only when all four files exist; never resume the builder mid-round; verdicts are written to job.json as each lands so the dashboard chips fill (SKILL:139-144).
- `MAX_RESUMES = 2` (max 3 rounds); exhaustion makes the orchestrator write `decision.md` itself as ESCALATE (SKILL:33, 151-154). The only artifact the orchestrator writes.
- Builder is spawned with a name `builder-<id>` and resumed with `SendMessage` pointing at the round folder (SKILL:121, 147-150; BP:93-94), so it keeps its context across rounds (limitation noted in video: only within one session).
- Worktree per job: `git worktree add -b factory/<id> <worktree> main` then repo setup; main checkout stays the user's and only Merge touches it (SKILL:42-54, 111-117).
- Port allocation: builder `5100+10n`, ux `5101+10n`, ui `5102+10n`; browser sessions named `<job-id>-builder|ux|ui` so jobs never drive each other's browser (SKILL:97-99; AG:builder:57; AG:reviewer-ux).
- Every prompt starts with the absolute-path header `Job folder / Worktree / Branch` (SKILL:93-95); agents `cd <worktree> &&` on every Bash because the shell resets (AG:builder:15-19).
- Merge preconditions: clean main checkout (`git status --porcelain -- . ':!factory/backlog.md'` empty) and on `main`; backlog exempt because `next` edits it and job branches never touch it (SKILL:166-170). Dirty means `needs-human`, not failure; `git merge --no-ff`, `worktree remove`, `branch -d`; merge failure runs `merge --abort`; never push (SKILL:175-183). The video shows this exemption was added after a real auto-merge failure.
- Approver: APPROVE only if every criterion met with evidence, spot-checks at least one itself, all four PASS, and `git merge-tree --write-tree main <branch>` has no conflicts (AG:approver:31-37). Escalation list is category-based: money/access/identity, deploy/CI/hosting/build scripts, schema migration/email/prod data/new dependency, and spec Assumptions that are product decisions (AG:approver:39-47). Real run: job 001 passed 4/4 yet was ESCALATED for a one-line edit in a prerender script, with "For the human" naming the exact decision and files (`factory/jobs/001-*/decision.md`).
- Spec writer: fixed template Context / Requirements / Acceptance criteria (each "one observable behaviour plus how to verify") / Out of scope / Assumptions "where the request was ambiguous, each with a one-line reason" (AG:spec-writer:30-54); "smallest change", reuse named patterns, doc updates as requirements (AG:spec-writer:58-65). In the video it also asked the owner a clarifying question through the orchestrator.
- Builder: verifies `git branch --show-current` equals its branch before touching code (AG:builder:35-37); stages explicit paths, never `git add -A`, tree clean at end (AG:builder:64-65); lint only changed files, never repo-wide `--fix` (AG:builder:50); build.md records evidence per acceptance criterion and a Log per round (AG:builder:69-91).
- Reviewers: from round 2 read their own previous review and check each finding was fixed (AG:reviewer-code:27-28); CHANGES only for real blocking problems in this change, pre-existing issues go to Notes (AG:reviewer-security:61-63); a failing check is always CHANGES (AG:reviewer-code:66).
- Rework: note saved verbatim to `rework-k.md`, fresh builder, fresh `MAX_RESUMES` (SKILL:209-215).
- Dashboard: static HTML polling job.json every 2 s (README:190-193); one short status line per transition (SKILL:219-221).

**Design stance** (video): keep it small enough to understand in minutes; "this prompt is general", agent derives repo-specific escalation list; guardrails admitted too tight.

## 2. Comparison with VULYK

| Factory mechanism | VULYK | Verdict |
|---|---|---|
| Single orchestrator is the only state writer | `scripts/cycle.sh` is the single writer, one writer per file (`memory/map/cycle.md:9-16`); Queen/driver only call verbs | VULYK stronger (code, not prose) |
| State in files | Committed `docs/specs/<slug>/` + `journal.md` (`memory/map/cycle.md:3-8`); factory's is gitignored/transient | VULYK stronger (survives, reviewable) |
| Verdict on the first line | `lead-review` line 1 `VERDICT: PASS\|BLOCK` (`.claude/agents/lead-review.md:66-76`), seat reports `VERDICT` parsed by `record-seat` (`memory/map/cycle.md:69-72`), malformed = exit 4 and re-ask once | VULYK has it, with enforcement |
| WAIT FOR ALL | `status` returns `dispatch:<csv>` while a required seat is missing, `judge` only when all in (`memory/map/cycle.md:49-52`) | Has it |
| MAX_RESUMES | `tier_ceiling` 1/2/3/3 (`scripts/cycle.sh:355-361`), `no-progress`, `half`, `reopen` raises `CEILING` (`memory/map/cycle.md:57-63`) | VULYK stronger |
| Resume same builder via SendMessage | Not used: repair is a fresh `<slug>-NN-repair-round-n` story to a fresh worker, on opus (`memory/map/cycle.md:76-81`); owner memory notes `resumeFromRunId` is banned | Deliberate difference |
| Parallel reviewers by lens | `opus` + `review` (+ `haiku` if Client path) at Tier 3-4, Tier 4 adds a second reviewer told to probe security (`memory/map/cycle.md:57-58`, `docs/specs`-driver) | Has, different cut: intent/edge/black-box, not security/ux/ui/code |
| Reviewers see spec+build.md | VULYK seats are blind: `COURT` = detached worktree at the pack commit with only `brief.md`, taint check on story/plan/journal paths (`memory/map/cycle.md:69-74`, `.claude/agents/council-opus.md:16-24`) | VULYK stronger (no anchoring on the builder's self-report) |
| Approver agent, same-family as builder | None. Verdict by `cycle.sh judge`; then owner asked «Выпускаем?» (`.claude/commands/vulyk-build.md:84-90`); ship never auto-decides (`.claude/commands/vulyk-ship.md:9-15`) | Different: VULYK keeps a human at release |
| Escalation list by change category | No category rule. ESCALATE exists only as a judge outcome (absent seat, half, ceiling; `memory/map/cycle.md:60-63`). Constitution mentions security only inside Law 2. Profile has no "always human" field (`CLAUDE.md` Profile table) | **Lacking** |
| Spec `Assumptions` that approver escalates on | plan.md `## Assumptions`, coverage drone turns unanswered asks into Assumptions (`.claude/commands/vulyk-plan.md:48-49`), shown at the approval stop (`:53-55`). Not checked whether any gate reads them after the stop (grep of `scripts/*.sh` found none) | Weaker: shown once, never re-surfaced at ship |
| Clean-tree precondition | `claim` refuses dirty tree, `open-round` refuses dirty outside paperwork (`scripts/cycle.sh:436`, `memory/map/cycle.md:30-33`) with a paperwork whitelist | Has, more refined than the backlog exemption |
| `git merge-tree` conflict precheck | `ship-check.sh` grep for conflict/merge finds nothing relevant (only a note at `:109`); ship step 2 just merges (`vulyk-ship.md:22-23`) | Lacking (small) |
| Worktree per job, parallel jobs | One branch `vulyk/<slug>` checked out in the main checkout via `git checkout -b` (`scripts/cycle.sh:1396-1425`); worktrees are used only for blind courts (`scripts/cycle.sh:2099`). Two specs at once in one checkout is not supported; DRIVER lock is per spec dir (`scripts/cycle.sh:2594`, noclobber) | **Lacking** |
| Claim by mkdir / exact-line Edit | DRIVER claim uses `set -o noclobber` atomic write (`scripts/cycle.sh:2594-2600`) | Has equivalent for the driver |
| Port allocation per job | Not checked in VULYK; irrelevant without parallel checkouts | n/a |
| Backlog queue + `next` | None; `/vulyk-ship` hands the owner a "next brief draft" verbatim and opens no spec (`vulyk-ship.md:31-41`) | Lacking, by design |
| Dashboard | `/vulyk-status` text (`.claude/commands/vulyk-status.md`), `state.sh` derived JSON (`scripts/state.sh:1-18`), pulse mod (`docs/pulse.md`) | Has (no HTML board) |
| Rework with a note | `reopen "<decision>"` appends to `## Answers`, raises CEILING (`scripts/cycle.sh:~2366`; `memory/map/cycle.md:34-36`); `human-check.sh ACCEPTED` | Has |
| Builder checks its branch first | `worker-code.md` has no branch check (grep: none); `cmd_branch` hardens the checkout instead (`scripts/cycle.sh:1420-1425`) | Weaker for workers (not checked beyond grep) |
| Explicit-path staging, tree clean | `scope-check.sh`, `close-story --commit` refuses out-of-`## Files` dirt (`memory/map/cycle.md:23-26`) | VULYK stronger (mechanical) |
| Spec writer asks questions | `templates/grill.md` one `AskUserQuestion` round, recommended option first | VULYK stronger |
| Reviewer re-reads its previous review | Seats are fresh each round; same-ask-RED across rounds is detected by `judge` as `no-progress` | Different, equivalent goal |

## 3. Ideas worth adopting (ranked)

1. **ADAPT: category-based "always a human" rule at the release gate.**
   Idea: factory approver ESCALATEs on money/access/identity, deploy/CI/build scripts, schema migration, new dependency, product-decision Assumptions, even with 4/4 PASS (AG:approver:39-47; job 001 proves it fires on a one-line deploy-script edit). Gap closed: today a GREEN council on a change that touches auth or the deploy path gets the same «Выпускаем?» as a typo; `lead-review` has no category trigger and the constitution holds no list. Cost: low-medium. Land as: a Profile row `Always-human changes` (derive at `/vulyk-bootstrap` from the repo, as the video does) plus `ship-check.sh` listing matching paths/diff categories before «Выпускаем?», and a mention in `lead-review.md`. Constraint: CLAUDE.md is 7269 B and the owner memory says it is size-capped, so the list must live in a template/rules file with one pointer line in the Profile.
2. **ADAPT: re-surface plan Assumptions at the release gate.**
   Idea: factory ties spec Assumptions to the approver (AG:approver:46-47). Gap: VULYK shows `## Assumptions` once at the plan stop and no script reads them later (grep of `scripts/*.sh`: no hit), so a product-decision assumption approved in passing is never rechecked against what shipped. Cost: low. Land as: `ship-check.sh` prints plan.md `## Assumptions` and `## Descoped` next to the council line; `/vulyk-build` terminal «green» block quotes them in the Выпускаем? question. No new agent.
3. **ADAPT (defer, owner decision): parallel specs via a worktree per spec.**
   Idea: SKILL:42-54, 111-117. Gap: VULYK serializes work per checkout (`git checkout -b` in `cmd_branch`), so a second feature waits or fights the first for the working tree. A VULYK-specific advantage: spec state is committed on the spec branch, so a worktree holds its own paperwork cleanly, unlike the factory which had to keep gitignored state outside the worktree. Cost: high. `cycle.sh` uses repo-root-relative paths, `memory/stats/*` ledgers are shared and dirty-prone, `open-round` dirty rules, court paths, driver stamps all assume one checkout; plus a port rule for the Client-path seat. Land as: `cycle.sh branch --worktree`, `docs/adr/`, tests. Do not start before the owner confirms parallel specs is a felt pain.
4. **ADAPT: `git merge-tree --write-tree <default> <branch>` precheck in `ship-check.sh`.**
   Idea: AG:approver:37. Gap: ship currently learns of a conflict only at the merge; a precheck makes it a refusal with the conflicting paths before history is touched. Cost: very low (one line plus a test). Land in `scripts/ship-check.sh` and `tests/`.
5. **ADAPT (small): a worker branch assertion.**
   Idea: AG:builder:35-37 (first Bash call checks the branch). Gap: `worker-code.md` has none; `close-story` commits wherever HEAD is. Cost: one sentence in `worker-code.md`/`worker-test.md`, or better a `cycle.sh close-story` refusal when HEAD is not `**Branch:**`. Check first whether `close-story` already refuses (not read this session); if so, REJECT.
6. **ADAPT (optional): conditional security lens.** The factory always runs a dedicated security reviewer with a concrete checklist (AG:reviewer-security:31-46). VULYK covers security only in `lead-review` generally and the Tier 4 second reviewer. Adding a checklist section to `lead-review.md`, switched on when idea 1's categories match, costs a few lines and no new seat. A new always-on seat is a REJECT (Law 2, tokens).
7. **ADAPT (tiny): "For the human" block shape.** Decision.md's `## For the human` names the exact decision plus the files to look at (job 001). VULYK's `## Needs a human` is printed verbatim (`vulyk-build.md:91`); check that `judge`/`escalate` write both the decision and the files. Low cost, `cycle.sh escalate` text only.

**REJECT:**
- LLM-orchestrator state machine in prose (SKILL), including LLM-written `job.json`: VULYK's `cycle.sh` is deterministic, tested (`tests/cycle.test.sh`), and has staleness, taint and PAUSE the factory lacks.
- Resuming the same builder with `SendMessage`: contradicts the VULYK repair-story design (fresh worker, anchored findings, Opus after RED, ADR-015) and the owner's rule against `resumeFromRunId`.
- Non-blind reviewers that read `spec.md` and `build.md`: anchoring on the builder's report is exactly what the court removes.
- Builder-family approver auto-merging: violates "the family that builds never judges" (CLAUDE.md Models). Factory has Opus building and Opus approving. Ship stays a human «Выпускаем?».
- HTML dashboard: `/vulyk-status`, `state.sh` and the pulse mod already cover it; a polling page is an unrequested feature (Law 2).
- Backlog + `/factory next`: each VULYK tier needs a grill/approval stop and a brief with verbatim owner quotes (Law 6, ADR-008); an unattended queue conflicts with those stops. At most a "next circle" list, which `/vulyk-ship` already prints.
- Reviewer lens split by ux/ui: only meaningful for web apps; VULYK's black-box Haiku seat already walks the Client path.
- "Free-form skill args, not a strict schema" and gitignored runtime state: VULYK deliberately commits state.

## 4. What VULYK does better (do not regress)

Deterministic, tested state machine; committed, reviewable state; blind court with taint detection; convergent judge (no-progress, half, ceilings, anchored BLOCK); fresh-model repair on Opus; paperwork-aware staleness (commits after GREEN invalidate the round); scope-check per story; claim/PAUSE semaphores; model floor and family separation; verbatim owner quotes and defect library (Law 6); token accounting; the grill. The factory has none of these: reviews can predate the final HEAD (no stamp), a reviewer file only needs a first-line verdict (no evidence rule, no `ASK n: run/saw`), and nothing stops an LLM from mis-writing `job.json`.

## 5. Open questions for the owner

1. **Should GREEN ever skip «Выпускаем?» for low-risk changes?** Recommended: no. Ship is a reversible local merge, but memory shows the owner keeps the release stop and push/publish is already theirs; adopt only the escalation list (idea 1) to make the existing question carry a warning, not to remove it.
2. **Where do the "always-human" categories live and who writes them?** Recommended: `/vulyk-bootstrap` derives them per hive into a rules file (as the factory agent derived billing/course-access from the repo), the framework ships only a generic default (auth/money, deploy/CI, migrations, new dependency). Because VULYK is public, default must need no personal tooling.
3. **Is parallel work on two specs a felt pain?** Recommended: not yet; measure first (how often a second spec waits). Worktree-per-spec is the costliest item here and would touch `cycle.sh`, ledgers and tests.
4. **Should Assumptions be a ship-gate input (print only) or a blocker?** Recommended: print only; blocking turns every assumption into a stop and re-creates the extra human gate the owner removed.
