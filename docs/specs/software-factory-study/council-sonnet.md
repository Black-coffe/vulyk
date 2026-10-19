# Placement council, round 2: Sonnet analyst

Read: research-fable.md, research-opus.md, my own. Re-checked this session: `scripts/ship-check.sh:95-125`, `scripts/lib.sh:60-82`, `install.sh:70-82`, `scripts/cycle.sh:1821-1850`, `tests/` (ship-check cases live in `tests/cycle.test.sh`, 13 hits; `:176` says no separate ship-check suite exists).

## 1. Verdicts

| Idea | Verdict | Changed my mind? |
|---|---|---|
| A. merge-tree precheck + `merge --abort` rule at ship | **ADOPT** | no |
| B. owner-named escalate globs + plain "for the owner" lines at «Выпускаем?» | **ADAPT**: warn, never a second stop; no new reviewer section | refined: I had "Profile row or rules file"; the glob file is better (same reader as `vulyk-paperwork`) |
| C. worktree per spec | **DEFER** as a `--study` report, no story | no |
| D. branch guard in close-story | **ADOPT** (small) | upgraded from "check first": `close-story` (`cycle.sh:1821-1850`) has no HEAD vs `**Branch:**` test |
| E. print Assumptions/Descoped at ship | **ADOPT** | upgraded: Opus's argument decides it, Tier 1 and `--go` skip the approval stop, so an assumption is never shown to the owner at all |
| F. port base per spec | **REJECT now**, fold into the C study | no |
| G. backlog + `/vulyk-plan next` | **REJECT now** (revisit after C) | no |
| Fable 6: ticked evidence per acceptance criterion | **REJECT** | new |

G reason: the unattended run Fable wants means Tier 2-4 plans on assumed grill answers (`templates/grill.md:57-63`), against Law 1 and the approval stop of ADR-008; a queue also lets the framework choose the next circle, which `vulyk-ship.md:40-41` forbids.

## 2. Placement

**Spec 1, `ship-safety`, Tier 2 (A + D).** Delivered first.
- A: new check in `scripts/ship-check.sh` stage 03 using plan `**Branch:**` (not HEAD, so it works from either branch) against `$DEFAULT`: `git merge-tree --write-tree` conflict = `fail`, naming the paths. `.claude/commands/vulyk-ship.md` step 2 gains: failed merge then `git merge --abort`, stay put, report. Missing input (no default branch, no Branch line, unsupported git) must be a visible refusal or note, never a silent pass (defect card safeguard-bypassable-or-late). Opus's fallback of a trial `merge --no-commit` is rejected: it mutates the owner's checkout.
- D: `cmd_close_story` after `driver_guard` (`cycle.sh:1821`), exit 2 when `git rev-parse --abbrev-ref HEAD` differs from plan `**Branch:**`. Also turn `ship-check.sh:98-108`, which prints `BRANCH_NOW` next to `BRANCH_REC` but never compares them, into a comparison (this one is in none of the three reports).
- Tests: `tests/cycle.test.sh`. A needs a conflicting-branch fixture plus its neighbour (clean merge, still green); D needs a wrong-branch fixture plus a right-branch one (Law 6 shape: original case and neighbour form).
- Why together: both are deterministic refusals in the ship path and share the fixture repo.

**Spec 2, `ship-brief`, Tier 2, possibly Tier 3 (B + E + "for the human").**
- `scripts/lib.sh`: generalise `hive_paperwork_path` (`:72-82`) into one glob reader used for `.claude/vulyk-paperwork` and `.claude/vulyk-escalate`.
- `ship-check.sh`: print `touches escalate paths: <list>` (diff from merge-base with `$DEFAULT`) and plan `## Assumptions`/`## Descoped`. Info lines, exit code unchanged.
- `.claude/commands/vulyk-build.md:84-90` and `vulyk-review.md` green terminal: quote those lines in the question and in the `claude -p` one-line recommendation. The Queen writes the two plain lines (decision needed, files to look at) from `ship-check` output, in the owner's language, per the plain-bottom-line rule. Recommended option stays first.
- `install.sh:78`: add `.claude/vulyk-escalate` beside `.claude/vulyk-paperwork` as host-owned (return 1). **No report has this.** Without it an upgrade overwrites or removes the owner's list (cards upgrade-overwrites-host-edits, framework-fix-skips-live-hives).
- `.claude/commands/vulyk-bootstrap.md` (+ `bootstrap/interview.md`): ask and seed the file; empty or absent file prints nothing.
- Tests: ship-check cases in `tests/cycle.test.sh`; install manifest case in the maintenance/constitution suite (not checked which). It touches scripts, install and two commands, so the Queen may call it Tier 3 (then workers build, council `opus`+`review`).

**Study, `worktree-per-spec` (C + F), `/vulyk-plan --study`, no code.** After specs 1-2. Questions it must answer: the no-`cd` rule means path arguments through `cycle.sh`; `build_court` inside a worktree (`cycle.sh:2099`, `core.longpaths`); shared ledgers `memory/stats/*` and `.claude/state.json`; `claim`'s dirty-tree rule; whether `EnterWorktree` moves the whole session (Fable: not checked, nor by me). Ports only if parallel specs are wanted.

Order: Spec 1, Spec 2, study. Spec 2 builds on 1's `ship-check` edits, so serial, not parallel.

## 3. Attacks

**Fable.**
- Weakest: idea 6 (workers tick criteria with evidence). The builder would write the reference it is measured against (card measurement-unlike-reality), and Fable's own section 1 shows the factory's reviewers deferring to `build.md` ("I did not run the browser", `001/round-1/review-code.md:14`). `close-story` already runs `## Verification` on the record and the worker returns `TESTS:`. Adds ceremony, not evidence.
- `lead-review` gaining `## For the owner`: `record-seat` parses the report by position (`memory/map/cycle.md:69-72`), so a new section risks the parser for something the Queen can write from the diff.
- "`claude -p --go` unattended runs" justifies the backlog; but `--go` with assumed answers is the path Law 1 and ADR-008 constrain.

**Opus.**
- Weakest: the `.claude/vulyk-escalate` hit "changes «Выпускаем?» to a plain-language question". That swaps the question the owner already answers and could drop the recommended-first yes. Keep one question, add lines.
- The trial-merge fallback (see above) mutates the working tree.
- Cites a session-private note in a doc under `docs/specs/` of a public repo; cite the ADR line only (`ADR-001:343`), per the no-private-notes-in-public-repo rule and card outward-artifact-carries-internals.
- "Specs run in parallel" is oversold in idea 3: DRIVER is per spec dir, but the shared stats ledgers, `.claude/state.json` and the cwd-relative scripts are not, and the report lists them without sizing the cost.

**Missed by all three:** (1) `install.sh:78` host-ownership for the new glob file; (2) the `ship-check.sh:98-108` branch comparison gap; (3) the `claude -p`/no-`AskUserQuestion` path of the green terminal also needs the escalate and assumption lines, since that is where unattended runs end.

## 4. Questions for the owner

1. **A hit on the escalate list: warning lines under one question, or an extra explicit step?** Recommend warning lines only. «Owner looks» as a mandatory stage was deliberately removed (CONSOLIDATED #1-#4); the owner still answers once and can see exactly why.
2. **What goes in VULYK's own `.claude/vulyk-escalate`?** Recommend `install.sh`, `scripts/lib.sh`, `scripts/cycle.sh`, `.github/workflows/`, `CLAUDE.md`; hives get theirs from the bootstrap interview and an absent file means silence. The list is the owner's, not a model's guess (job 001 shows a derived list firing on a one-line edit).
3. **A merge-tree conflict: refuse (`NOT READY`) or note?** Recommend refuse; a GREEN that cannot merge is the ship gate's reason to exist. On a git too old for `--write-tree`, print an explicit "not prechecked" note and rely on the abort rule.
4. **Study the worktree-per-spec now, or wait?** Recommend study after specs 1-2, started only if the owner says the held checkout or waiting for a second spec actually hurts; the study is cheap, the build is the costliest item here.
5. **Backlog file?** Recommend no; the next-circle draft at ship plus files on disk is enough while one spec runs at a time.
