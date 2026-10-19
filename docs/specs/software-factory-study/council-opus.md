# Council round 2: Opus placement

2026-10-19. Reads `research-{opus,fable,sonnet}.md`. Every VULYK fact below was checked this session.

**Bottom line.** Two Tier 2 specs and one study. Spec 1, *git guards*, covers A, D and a branch
cleanup nobody proposed. Spec 2, *owner at ship*, covers B, E and "for the human". The study covers
C and F. G stays out.

## 1. Verdicts

| Idea | Verdict | Change and why |
|---|---|---|
| A: `merge-tree` precheck + `merge --abort` | **ADOPT** | Sharpened. Only exit 0 means clean and exit 1 means conflict. Any other exit (old git `--write-tree` usage error, a bad ref) must be `NOT READY: cannot check`, never a pass (defect card *safeguard-bypassable-or-late*). VULYK is public, so hives' git varies; local 2.55 proves nothing for them. |
| B: `.claude/vulyk-escalate` + "for the human" at «Выпускаем?» | **ADAPT** | The check is mechanical: `ship-check.sh` lists matching paths, and the Queen writes the decision line. I reject Fable's `## For the owner` section in `lead-review` (see 3). The list is owner-confirmed, not model-derived (Sonnet's version). |
| C: worktree per spec | **DEFER → study** | Narrowed to Tier 3-4. At Tier 1-2 the Queen builds herself (`CLAUDE.md` routing). A worktree there means every Edit/Read path and every `cycle.sh` call moves off the session cwd, which is the owner's no-`cd` rule colliding with the solo path. |
| D: branch guard | **ADOPT, widened** | No HEAD-vs-branch check exists anywhere in `cycle.sh`: grep `abbrev-ref\|show-current\|symbolic-ref` returns zero hits. `open-round` builds the court from whatever HEAD is, so the guard is one helper called by `claim`, `close-story` and `open-round`, not by `close-story` alone. |
| E: Assumptions/Descoped at ship | **ADAPT, half** | Print `## Assumptions` and `(assumed)` grill answers before «Выпускаем?», print only. Descoped is already guarded: `lead-review.md:16-18` counts an unlogged shrink as undelivered, `descope_not_in_brief` at `cycle.sh:294`, and it is printed after ship (`vulyk-ship.md:39`). |
| F: port base per spec | **DEFER with C** | Without parallel specs it is speculative (Law 2). |
| G: backlog + `/vulyk-plan next` | **REJECT now** | With one spec per checkout there is nothing to claim against. Fable's unattended `claude -p --go` path stacks `(assumed)` answers (`templates/grill.md:57-63`) on a skipped approval stop (`vulyk-plan.md:60-62`), the stop the owner set. Revisit with C. |
| Fable 6: evidence ticks per AC | **REJECT** | The builder grading itself. `close-story` already runs `## Verification` on the record (`templates/story.md:69-92`), and ticks give `lead-review` the self-report to anchor on that the factory's reviewers fell for (001 `review-code.md:14`). |
| Sonnet 6: conditional security lens | **DEFER** | It needs the escalate match at round time (a `status` field), not at ship. Revisit once B has run for a while. |

## 2. Placement and order

**Spec 1: git guards (Tier 2, within the scripts module plus one command step).**
- `scripts/ship-check.sh`, stage 06: `merge-tree --write-tree <default> <head>`, read as 0 / 1 / else.
- `.claude/commands/vulyk-ship.md` step 2: on a failed merge, `git merge --abort`, record nothing, report.
  After a good merge, `git branch -d vulyk/<slug>` (the safe `-d`).
- `scripts/cycle.sh`: a `branch_guard` helper (HEAD must equal plan.md's `**Branch:**`), called from
  `cmd_claim`, `cmd_close_story` (`:1821`) and `cmd_open_round` (`:2261`). `cmd_branch` (`:1425-1426`)
  refuses to reuse an existing `vulyk/<slug>` that is already merged into the default branch.
- `docs/cycle.md` invalidation table and the ADR-001 D2 precondition table.
- Tests: `tests/cycle.test.sh` gets the wrong-branch and reused-slug cases, each with a neighbour-form
  fixture (Law 6 style). Ship-check needs conflict and old-git cases; which test file covers
  `ship-check.sh` today was not checked.

**Spec 2: owner at ship (Tier 2, with a grill for questions Q1-Q3).**
- `scripts/lib.sh`: an `escalate_path` reader next to the paperwork reader (`:72`).
- `scripts/ship-check.sh`: prints `touches escalate paths: <list>`, plus `## Assumptions` and `(assumed)` answers.
- `.claude/commands/vulyk-build.md` Terminal `green` (`:86-90`) and `escalated` (`:91-93`), and
  `vulyk-review.md` step 4: the question names the class, the files and the decision. An escalation
  ends with the decision needed, the files to look at, and the recommended exit.
- `.claude/commands/vulyk-bootstrap.md` + `bootstrap/interview.md`: propose globs, the owner confirms.
- `install.sh`: never ships or overwrites the hive's file, the same rule as `vulyk-paperwork`
  (`docs/cycle.md:82`).

**Study 3: worktree per spec at Tier 3-4 (+F).** `/vulyk-plan --study`, ending in `report.md`.

**Order:** Spec 1 → Spec 2 → Study 3. Spec 1 comes first because it is pure safety with no owner
choices. Spec 2 needs the grill. Spec 1 and Spec 2 stay separate because they share only
`ship-check.sh`, and merging them would push the work to Tier 3 (multi-module).

## 3. Attacks

**Fable, weakest claim:** idea 3 puts a `## For the owner` paragraph into `lead-review`'s report. That
report is parsed by position: verdict line, then BLOCK anchors under Critical/Major
(`cycle.sh:1535-1569`, `lead-review.md:64-83`). Any change to the reviewer contract means re-running
`tests/council.test.sh`, about 10 minutes per run on this box. The paragraph also duplicates what
`ship-check.sh` can print for free, and it turns owner-facing text into reviewer prose. The mechanical
path list plus one Queen-written line gets the same result at no token cost.

**Sonnet, weakest claim:** the table row "Reviewer re-reads its previous review → Seats are fresh each
round" is false. `lead-review` reads the previous round's `review.md` and seat files from round 2
(`lead-review.md:35-38`), and GREEN blind seats are carried forward (`docs/cycle.md:53-55`). Its G
rejection rests on two errors too. It cites Law 6, which is about defects, not briefs. And it says
"each VULYK tier needs a grill/approval stop", but Tier 1 has neither (`templates/grill.md:14`,
`vulyk-plan.md:51-52`).

**Missed by all three:**
1. 24 of the 26 `vulyk/*` branches in this repo are already merged into `main` and were never deleted
   (`git branch --merged main --list 'vulyk/*'`). `cmd_branch` checks out an existing branch instead of
   creating one (`cycle.sh:1425-1426`), so a reused slug builds on a stale, merged branch. The factory
   deletes its branch after merging (`SF:SKILL.md:174-178`). This goes into Spec 1.
2. The `merge-tree` exit-code trap (A above). None of the three reports said that a non-0/1 exit must
   refuse.
3. The guard belongs in `open-round`, not only in close-story (D above).

## 4. Owner questions (grill)

1. **When a diff touches an escalate path, warn or refuse?** Recommend: warn inside the existing
   «Выпускаем?». A refusal brings back the mandatory human look that `docs/cycle.md:35-42` shows had
   become ceremony. `human-check.sh` stays the deliberate path.
2. **Who writes `.claude/vulyk-escalate`?** Recommend: `/vulyk-bootstrap` proposes up to six globs from
   the repo, the owner confirms or edits them, and the installer never touches the file. A model-made
   list reproduces job 001, which escalated a one-line cache-key edit (`SF:.../001.../decision.md:4`).
3. **Delete `vulyk/<slug>` after a good ship?** Recommend: yes, with `git branch -d`, which refuses to
   delete an unmerged branch. The story commits stay in history through the `--no-ff` merge, and the
   ref only invites a stale reuse.
4. **Worktree study now or after Specs 1-2?** Recommend: after, and Tier 3-4 only. It is the costliest
   item, and Spec 1's branch guard is a precondition for any worktree work anyway.
5. **Backlog queue?** Recommend: no, until parallel specs exist.
