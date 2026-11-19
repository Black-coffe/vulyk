---
story: guards-1115-04
spec: guards-1115
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 3
blocked_by: [guards-1115-03]
red: required
red_reason: a seat git read outside the allowlist is denied
red_verified_at: 2026-11-16T08:56:00Z c7202b23d8244a7b877fa70203954b1e042d60b9ece843fe15756ce66cd3dd80
---

# court-guard: git by allowlist, resolved paths, glued options, the seat's own court

## Goal
`.claude/hooks/court-guard.sh` after this story (plan.md `## Contracts` C2, O2), for a blind council seat only:
1. **Git by allowlist (private S8).** A git command passes only when its verb is on a short list and its arguments
   fit that verb's rule; every other verb is denied, whether git knows it as a command or as an alias. A revision
   that names a path under `docs/specs/` is denied in every verb.
2. **Resolved paths (private S7).** Every path is judged by its resolved form (links followed); no system location
   that can point back into the project counts as allowed.
3. **Glued options (private S9).** A script or pattern glued to its option is the script; the word after it is
   judged as a path.
4. **Own court (private S10).** A path in another round's court is denied.
5. **Temp folder (private S10).** The main session's working folder under the temp directory is denied.
6. **Header (O2).** It ends with the list of what stays open, in general words: code handed to an interpreter on its
   command line is kept on purpose for seats, and the header says so.

Private input, read first: `~/.vulyk/audits/known-defects-2026-11-15/` `security.md` S7, S8, S9, S10 and
`decisions.md` FINAL (A3, A4). Comments, labels and notes say what the hook refuses, never a form that still passes.
Before building, read both seat prompts and the dispatch text of `/vulyk-build` for every git command and every
path a seat is told to use, and for the directory a seat's calls start in. The allowlist holds those git forms; if
one cannot be allowed without reopening item 1, or a seat's Read calls cannot be tied to its court, return
`NEEDS_CONTEXT` with the sentence.

## Requirements
> 5. The blind council seat's court cannot be left through the named form classes: git reads by an allowlist wherever git stands as a command; paths resolved (dot-dot, a link or junction, one made in the same call, letter case), a path glued to its option, held in a variable set in the same call, inside a quoted substitution, or a file URL; no system-path escape. Any other form is named open in the header (private S7, S8, S9).
> 6. The header-named open forms are closed as answered above (private S6, S10), and each hook header lists exactly what it still leaves open, in general words, and says the guards stop accidents and shortcuts of a cooperative agent, not an adversary.
> 7. Every closed gap has a failing test with the original form and a neighbour form (Law 6), and no legitimate flow of the Queen, a worker or a council seat is denied (existing suites stay green).

## Files
- .claude/hooks/court-guard.sh
- .claude/agents/council-opus.md
- .claude/agents/council-haiku.md
- tests/inject.test.sh

## Non-goals
- Do not deny an interpreter's inline code, and do not read what such code does: that form stays open, named.
- The hook still acts only for the two blind seats; the main session and every other agent pass untouched.
- Do not touch `git-guard.sh`, `owner-guard.sh`, `.claude/settings.json`, `install.sh`, `cycle.sh` (court building
  and `record-seat` stay as they are), `docs/hooks-reference.md`.
- Change a seat prompt only where it tells a seat to run a git command or read a path the guard now refuses, or
  where the seat must be told to work from inside its court: that sentence, nothing else.
- In `tests/inject.test.sh` edit only the court-guard block; an existing case flips only when contract C2 says so.

## Map slice
`memory/map/scripts-guards.md` → Purpose, court-guard.sh; `memory/map/cycle-state.md` → Staleness, PAUSE, seat
reports (court), Seats and the verdict; `memory/map/agents-and-commands.md` → Agents (council-opus, council-haiku).

## Acceptance criteria
- [ ] `--check`, blind-seat input: a git read through a verb outside the allowlist is denied (label contains `a seat
  git read outside the allowlist is denied`); neighbours: the same read through an alias given on the command line
  and through a low-level verb are denied. Every new case fails on HEAD.
- [ ] Each allowlisted form passes inside the court, among them every git form the seat prompts name; the existing
  denials (an object read with no pathspec, or with one under `docs/specs/`) hold.
- [ ] For each of S7, S9 and both parts of S10 the original form and a neighbour form are denied; their plain twins
  inside the seat's court pass.
- [ ] A seat standing in its court reads its own court and `.vulyk/reports/`; with one court on disk a Read by
  absolute path into it passes from any directory; with two courts and a call that stands in neither, a court path
  is denied and the reason says to work from inside the court.
- [ ] Other temp entries and the remaining system locations pass as today; any other `agent_type` and the main
  session are untouched; with no Python a seat's every call is denied, as today.
- [ ] No seat prompt tells a seat to run a git command or read a path the guard refuses;
  `bash scripts/prompt-check.sh --touched .claude/agents/council-opus.md .claude/agents/council-haiku.md` has no error.
- [ ] The header's last block lists what stays open and names nothing this story closed;
  `bash scripts/portability-check.sh .claude/hooks/court-guard.sh` is clean.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- files changed, decisions, surprises - 1-2 lines each; the allowlist you settled on and why. End with one
`CHANGELOG:` line per ask (5, 6) that says what the guard does now. -->
- `.claude/hooks/court-guard.sh`: READS denylist and its pathspec walk replaced by `check_git` over `GIT_VERBS`; `full()` uses realpath; `/proc/` dropped from SYSTEM; `scratch()` denies `claude*` under /tmp and the temp folder; glued `-e`/`--expression=`/`--regexp=`/`--source=` count as the script, glued `-f`/`--file=` as a path; `-f` now also ends the script slot; own court via `court_of`/`stand`/`court_count`; header rewritten, open block last.
- Allowlist: `status`, `version`/`--version`, `rev-parse` with query options, `ls-files` with listing options; globals `-C`, `--no-pager`, `-P`. Why: the seat prompts and the build dispatch tell a seat to run no git command at all and name `git status` only (its deleted lines as a BREACH); these four read no history. `-c` and any GIT_* word are denied too, as they point git elsewhere or define aliases.
- On Windows `/tmp` is read as `%TEMP%` in `native()`: without it a project under the temp folder was reachable by its Git Bash spelling (test `cat $CP/docs/...`).
- Own court: a `cd` from no court into a round's court makes it the call's court (seats' Bash starts at the project root, so `cd COURT &&` must pass with two courts); that entry is named open in the header.
- Read/Grep/Glob now also allow `.vulyk/reports/` (the acceptance names it for a seat standing in its court).
- Seat prompts: one bullet each, Bash calls start with `cd <COURT> &&`, a refused court Read is redone in Bash from inside.
- tests/inject.test.sh: `git log -- src` passing flipped to denied (C2); the link case uses `ln -s`, else a Windows junction (`mklink /J`), and fails if neither can be made.
CHANGELOG: (5) a blind seat's court cannot be left: git only by a four-verb allowlist (aliases, low-level verbs, `-c`, GIT_* and spec revisions denied), every path judged resolved with /proc no longer a system location, a glued script option is the script, another round's court and the main session's temp folder are denied.
CHANGELOG: (6) court-guard's header ends with the forms it still leaves open, in general words, interpreter inline code kept on purpose for seats.

## Findings

## Red receipt
- command: bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh
- exit: 1
- tests: c7202b23d8244a7b877fa70203954b1e042d60b9ece843fe15756ce66cd3dd80 (tests/inject.test.sh)
- impl: fdc74f8e97dee4d5a502b939a16c6c460af30ee7d2ac642759ac92ddbc9d327c
- stamped: 2026-11-16T08:56:00Z

```
::error::court guard: a seat git read outside the allowlist is denied: git log --oneline -- src - expected 'deny', got 'allow'
::error::court guard: a seat git read outside the allowlist is denied: git -c alias.v=show v HEAD:src/a.md - expected 'deny', got 'allow'
::error::court guard: a seat git read outside the allowlist is denied: git unpack-file 0123abcd - expected 'deny', got 'allow'
::error::court guard: another round's court is denied: ls .. - expected 'deny', got 'allow'
::error::court guard: another round's court is denied: cd <temp>/tmp.Ms3SEUBAYt/courtproj/.vulyk/court/acme/round-1 && cat <temp>/tmp.Ms3SEUBAYt/courtproj/.vulyk/court/other/round-1/docs/specs/other/brief.md - expected 'deny', got 'allow'
--- latency
  median defects-inject.sh (Bash): 134 ms over 30 calls (fixture library; target <= 200 ms)
  ok    median latency, Bash, <= 200 ms
  median defects-inject.sh (Edit): 134 ms over 30 calls (fixture library; target <= 200 ms)
  ok    median latency, Edit, <= 200 ms
  median defects-inject.sh (Read, not a story): 70 ms over 30 calls (fixture library; target <= 100 ms)
  ok    median latency, non-story Read, <= 100 ms
inject.test.sh: 200 checks, 30 failed
```
