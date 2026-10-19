# Report: software-factory-study

**Bottom line.** VULYK already has almost every mechanism of the ZazenCodes "software factory", usually in a stronger, script-checked form. The factory still shows five holes in VULYK worth closing: an unsafe merge at ship, no branch guard on story commits, no owner-named "a human looks at this" list at release, a blind court built without the hive's install step, and one shared checkout for every build. They become three Tier 2 specs and one study, in that order.

Method: the video was watched (transcript, plus frames sampled every 10 s), and the factory's full source was read from its public repo. Three analysts on three model families (Fable, Opus, Sonnet) researched independently (`research-*.md`), then read each other and argued placement (`council-*.md`). The Queen re-checked every load-bearing claim against the code; the checks are cited below. Owner decisions from the grill: `docs/grill/2026-10-19-software-factory.md`.

## What the factory is

One Claude Code session runs a `/factory` skill and becomes the orchestrator: `spec-writer` (Opus) → `builder` (Opus, on `factory/<id>` in its own worktree) → four reviewers in parallel (security Opus; UX, UI, code Sonnet) → WAIT FOR ALL → any `CHANGES` resumes the same builder (max 2 resumes) → `approver` (Opus) writes `APPROVE` (auto-merge to main) or `ESCALATE` (needs a human). State is gitignored markdown/JSON per job; a static HTML dashboard polls it; `/factory next` claims backlog items by an exact-line Edit; `/factory approve|rework` are the human's handles. Details with `SF:` citations: `research-fable.md` §1, `research-opus.md` §1.

## Findings, with evidence

| # | Factory mechanism | VULYK today | Verdict |
|---|---|---|---|
| A | Merge only on a clean default branch; `merge --abort` on failure (`SF:SKILL.md` Merge) | No `merge-tree`, no `merge --abort` anywhere in `scripts/` or commands (grep, checked); `vulyk-ship.md:22-23` says "merge" in one sentence | ADOPT, plus a `git merge-tree --write-tree` precheck. Any exit other than 0/1 is NOT READY, never "clean" |
| D | Agents assert the job's branch | `close-story` (`scripts/cycle.sh:1821`) never compares HEAD with `**Branch:**` (checked); `ship-check.sh:98-108` prints both branches but never compares them | ADOPT: one helper called from `claim`, `close-story`, `open-round` |
| D2 | Merged branch and worktree removed after merge | 24 of 26 `vulyk/*` branches in this repo are merged and never deleted (checked); `cmd_branch` (`cycle.sh:1425-1426`) silently reuses an existing branch, so a reused slug builds on a stale merged branch | ADOPT: refuse to reuse a merged branch; `git branch -d` after ship |
| B | Approver escalates by risk class (billing, auth, access) | Every GREEN round asks «Выпускаем?» with the same text; nothing names risky paths. The factory's model-derived list escalated a one-line deploy edit (job 001), so the list must be owner-named | ADAPT: `.claude/vulyk-escalate` globs (reader beside `vulyk-paperwork`, `scripts/lib.sh:68-72`), `ship-check.sh` prints hits; the Queen adds the decision needed. Host-owned in `install.sh` |
| E | Spec `## Assumptions` escalated by the approver (`SF:spec-writer.md:51`, `SF:approver.md:46`) | No script reads plan `## Assumptions` after the approval stop; Tier 1 and `--go` skip that stop | ADOPT inside B: Assumptions and `(assumed)` grill answers shown before «Выпускаем?» |
| H | Fresh-checkout setup runs in every worktree, stop on failure (`SF:SKILL.md:114-117`) | `build_court` does `worktree add --detach` and nothing else (`cycle.sh:2099`, checked); a probe that needs `node_modules`/a venv fails, the seat may write `N/A`, and `N/A` counts toward unanimity (`docs/cycle.md:50`) | ADAPT: `.claude/vulyk-setup` run by `build_court`; failure = `open-round` exit 2 |
| C | A worktree per job; several jobs in parallel | One shared checkout; a build holds it for hours (`ADR-001:343`) | DEFER to a study: `ROOT` resolution, the clerk's relative `bash scripts/cycle.sh` (`vulyk-cycle.js:75`), shared stats ledgers, no-`cd` rule |
| F | Port base per job | `EADDRINUSE` from parallel rounds already documented (`docs/pipeline.md:77-86`) | DEFER, inside C |
| G | `backlog.md` + `/factory next` | none | DEFER: no recorded pain; revisit after C |

**Rejected, all three agreeing:** a prose-driven LLM orchestrator (VULYK's `cycle.sh` state machine is tested); resuming the same builder by `SendMessage` (the factory admits it only works in-session; VULYK's fresh worker with verbatim findings survives `/clear`); four fixed review lenses (in both real jobs the UX/UI reviewers read only the diff and never opened the app); reviewers that read the builder's own account (VULYK's court is blind, with a taint check); a same-family approver that auto-merges; gitignored state; an HTML dashboard; external intake (GitHub issues, Sentry) for now.

**What VULYK does better and must keep:** script-held state re-derived from committed files; the blind court; seats that run each ask (`run:`/`saw:`); the convergent judge with tier ceilings and anchored BLOCKs; rounds that go stale when code moves.

## Recommended work, in order

Final order after the grill: 1, 3, 2, 4 (see Owner decisions).

1. **Spec `ship-safety`** (Tier 2): A + D + D2. Files: `scripts/ship-check.sh`, `.claude/commands/vulyk-ship.md` step 2, `scripts/cycle.sh` (branch helper; `cmd_branch` refuses a merged branch), `tests/cycle.test.sh`, ADR-001 rows.
2. **Spec `owner-at-ship`** (Tier 2, grill): B + E. Files: `scripts/lib.sh`, `scripts/ship-check.sh`, `vulyk-build.md` and `vulyk-review.md` Terminal sections and the `claude -p` green path, `vulyk-bootstrap.md` (proposes the list, the owner confirms), `install.sh` (host-owned file). No `CLAUDE.md` bytes; no new section in the `lead-review` report (`record-seat` parses it by position, `cycle.sh:1535-1569`).
3. **Spec `court-setup`** (Tier 2): H. Files: `scripts/cycle.sh` `build_court`, `.claude/vulyk-setup` contract, bootstrap question, `tests/council.test.sh`.
4. **Study `spec-worktree`** (C + F): a report, not a build.

## Not read or run

The factory's `dashboard.html` was skimmed only. No test suite was run (study work). Whether `EnterWorktree` moves the whole session was not checked. Which test file covers `ship-check.sh` today was not checked. The frames' "Verification" box on the mind map is cut off on screen.

## Evidence from live hives (H)

Seat files with `N/A ... environment:` exist in most local Node and Python hives. In one Python hive a blind seat judged all seven asks `N/A` "purely on COURT's own missing venv/.env/DB". A setup step fixes the venv and `node_modules` part; a live database or a GPU stack stays a legitimate `N/A`.

## Owner decisions (grill 2026-10-19, `docs/grill/2026-10-19-software-factory.md`)

1. The worktree-per-spec study runs after specs 1-2.
2. An escalate-path hit warns inside the one «Выпускаем?» question; no second stop.
3. VULYK's own `.claude/vulyk-escalate`: `install.sh`, `scripts/cycle.sh`, `scripts/lib.sh`, `CLAUDE.md`, `.github/workflows/`. Hives: bootstrap proposes, the owner confirms.
4. Spec branches are deleted after ship with `git branch -d`, and `cycle.sh` refuses to reuse a merged branch. Done the same day: the 24 merged `vulyk/*` branches in this repo were deleted with `-d`.
5. Hives that need an install step exist, so `court-setup` is real work. Queen's calls (all three analysts agreed): a merge-tree conflict refuses the ship; the backlog queue is deferred.

Order: `ship-safety` → `court-setup` → `owner-at-ship` → study `spec-worktree`. `court-setup` moves ahead of `owner-at-ship` because it closes a hole in the verdict itself, not in what the owner sees.

**Status 2026-10-19:** `ship-safety` built and shipped as 0.31.0 (council GREEN round 1); next in the queue is `court-setup`.
