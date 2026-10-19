# Placement council: Fable seat

Inputs: research-opus.md, research-sonnet.md, research-fable.md, the Queen's verified facts. Local git is 2.55 and
`git merge-tree -h` lists `--write-tree` (checked this session).

## 1. Verdicts

| Id | Idea | Verdict | Change of mind |
|---|---|---|---|
| A | `merge-tree --write-tree` precheck + `merge --abort` rule | **ADOPT** | none |
| B | `.claude/vulyk-escalate` globs + "for the owner" lines at «Выпускаем?» | **ADOPT**, deterministic only | I drop my optional `## For the owner` reviewer section: Opus is right that the value is the script, and a reviewer paragraph re-adds model judgment at a human stop. The Queen may still add two plain lines at the stop (Opus idea 5), labelled as hers |
| C | Worktree per spec | **DEFER** to a study (`/vulyk-plan --study`) | none |
| D | Branch guard in `close-story` | **ADOPT** | none; Sonnet's "check first whether close-story refuses" is now answered: it does not (`scripts/cycle.sh:1821`, no `abbrev-ref`/`show-current` anywhere) |
| E | Print plan `## Assumptions` (and `## Descoped`) at the ship stop | **ADOPT**, as part of B | I missed it. `## Descoped` already reaches the owner, but only in `/vulyk-ship` step 5, after the merge (`vulyk-ship.md:39-40`); `## Assumptions` is read by no script (`grep Assumptions scripts/*.sh`: none) |
| F | Port base per spec | **DEFER**, inside C's study | none |
| G | `docs/specs/backlog.md` + `/vulyk-plan next` | **DEFER** (was ADAPT) | No recorded pain; the unattended path (`--go`, no-question mode) exists but nothing shows it is used. Sonnet's reason for rejecting is wrong (section 3), so DEFER, not REJECT |
| H | **Setup step after `worktree add`** (missed by all three) | **ADAPT**, Tier 2 | The factory runs the repo's fresh-checkout setup in every new worktree and stops if it fails (`SF:SKILL.md:114-117`). `build_court` does `worktree add --detach` plus the brief reduction, nothing else (`scripts/cycle.sh:2088-2135`). In a hive whose commands need `node_modules`/a venv, every probe in the court fails, the seat writes `N/A - why: environment:` (`council-opus.md:38-39`), and `judge` counts N/A as unanimity (`docs/cycle.md:50-51`): GREEN on the reviewer alone, the blind seat having run nothing (`safeguard-bypassable-or-late`) |

Also agreed with both: REJECT four seats, Sonnet reviewers, resumed builder, gitignored state, HTML board.

## 2. Placement, tier, grouping, order

**Spec 1 `safe-merge` (A + D), Tier 2**, the Queen solo, one reviewer.
- `scripts/ship-check.sh`: stage 06 block before the `Shipped` check (`:286-289`): when `BRANCH_NOW != DEFAULT`,
  `git merge-tree --write-tree "$DEFAULT" HEAD`; non-zero → `fail 06 "ship: merge into $DEFAULT would conflict: <paths>"`.
- `.claude/commands/vulyk-ship.md` step 2 (`:16-23`): a failed merge is `git merge --abort`, stay on the branch, no
  `--record`, report.
- `scripts/cycle.sh` `cmd_close_story` (`:1821`), after the guards: `git rev-parse --abbrev-ref HEAD` must equal
  plan.md's `**Branch:**`, else exit 2 `error "on <b>, story branch is <Branch>"`, no commit. Optionally the same in
  `open-round`.
- `docs/adr/001` precondition rows (`:181-183`); `docs/cycle.md` invalidation table (`:78-86`).
- `tests/cycle.test.sh` (already fixtures both): a conflicting commit on `main` → `NOT READY`; close-story from
  another branch → exit 2, no commit.

**Spec 2 `owner-stop` (B + E + Opus's plain lines at escalation), Tier 2** by cost; a strict reading of the routing
table says Tier 3. Say so at the plan.
- `scripts/lib.sh`: `hive_escalate_path` beside `hive_paperwork_path` (`:68-72`), reading `.claude/vulyk-escalate`.
- `scripts/ship-check.sh`: after stage 03, `git diff --name-only $(git merge-base $DEFAULT HEAD)..HEAD` against the
  globs → a `note` line, never a `fail` (the stop exists; CONSOLIDATED #1-#3); an `--owner` mode printing that
  line, plan.md `## Assumptions` and `## Descoped`, and the count of `(assumed)` answers in brief.md.
- `vulyk-build.md` `green` (`:86-90`) and `vulyk-review.md` (`:34-36`): quote `--owner` in the question;
  `escalated` (`vulyk-build.md:91-93`): the Queen adds the decision, the files, the recommended exit.
- `bootstrap/interview.md` question 18 + `vulyk-bootstrap.md` writes the file; `install.sh` never touches it. No
  CLAUDE.md bytes.
- `tests/cycle.test.sh`: a glob hit and a miss.

**Spec 3 `court-setup` (H), Tier 2**: `.claude/vulyk-setup` (one command per line) run by `build_court` after the
reduction, under `timeout`; failure → `open-round` exit 2 `"court setup failed"`, never a seat N/A. C reuses it.

**Study `spec-worktree` (C + F)**: a report, no tier. Must answer: `ROOT` resolution in `cycle.sh`, a court nested
in a worktree, the clerk's relative `bash scripts/cycle.sh` (`vulyk-cycle.js:75`), `EnterWorktree`, Windows
`core.longpaths`, `/vulyk-status` across worktrees, pause. Then Tier 4 with `lead-architect` and an ADR.

Order: safe-merge → owner-stop → court-setup → spec-worktree study → G reconsidered after the study.

## 3. Attacks

**Opus.** (1) Citations `council-opus.md:109-117` and `:125-128` (table rows "Acceptance criteria" and "Reviewers read
the builder's own account") point past the end of a 60-line file; the content is at `:18-25` and `:32-35`. (2) Idea 3
proposes the factory's "`cd <worktree> &&` on every Bash call" rule. In VULYK the clerk runs a relative
`bash scripts/cycle.sh ...` from the Queen's cwd (`vulyk-cycle.js:75`), so every verb would still act on the main
checkout; a `cd` prefix is also what moves a session's cwd on this machine and is ruled out for that reason. The
mechanism must be a path argument to `cycle.sh` (`--root`/env), which is why C is a study.

**Sonnet.** (1) Table row "Reviewer re-reads its previous review: seats are fresh each round" is wrong on both seats:
`lead-review` in round 2+ reads `since..head` plus "the previous round's `review.md` and seat files" and answers whether
the previous findings are fixed (`lead-review.md:35-38`); blind seats GREEN/N/A in round n-1 are carried into round n
(`docs/cycle.md:53-55`). (2) The backlog REJECT reasons "each tier needs a grill/approval stop ... an unattended
queue conflicts with those stops": Tier 1 runs straight through (`vulyk-plan.md:51-52`), `--go` closes the intake
without waiting (`:60-62`), and no-question mode assumes every recommended answer (`templates/grill.md:57-63`). A
queue conflicts with nothing; it is unasked-for, which is a different reason.

**Missed by all three:** H above, and a smaller one: every factory agent that starts a dev server stops it when done
(`SF:builder.md:57-58`, `reviewer-ux.md:37-38`); `lead-review.md` and `council-haiku.md` carry no such line (grep:
none), and `docs/pipeline.md:78-84` blames `EADDRINUSE` on parallel rounds only. Not verified that a seat's server
outlives its Bash call here; one sentence per agent costs nothing.

## 4. Grill questions for the owner

1. **A conflict found by `merge-tree`: refuse (`NOT READY`) or warn?** Recommend refuse. `ship-check` exists to say
   "did anyone look at *this*"; a green that cannot merge is not this.
2. **Escalate paths for VULYK itself, and does bootstrap seed hives?** Recommend `install.sh`, `scripts/lib.sh`,
   `scripts/cycle.sh`, `.github/workflows/`, `CLAUDE.md`; hives get a short seeded list the owner confirms at
   bootstrap. Job 001 shows a model-derived list fires on a one-line edit; the owner names the paths.
3. **Tier 2 or Tier 3 for `owner-stop`?** Recommend Tier 2: ~60 lines across four files, one reviewer; a hive run
   costs more than the change. Law 5 binds from Tier 3 only.
4. **Does any hive need an install step before its `## Commands` run?** Recommend asking before cutting spec 3:
   if yes, H is a live hole in the blind seat today; if no hive does, H rides with the worktree study instead.
5. **Worktree per spec: study now, or wait for a felt pain?** Recommend the study now, no build: it is the one idea
   that changes daily use (the hive stops holding the checkout), and three analysts independently rated its cost
   high; the study is cheap and the build is not.
