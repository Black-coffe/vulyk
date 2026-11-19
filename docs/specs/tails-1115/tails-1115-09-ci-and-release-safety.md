---
story: tails-1115-09
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 4
blocked_by: [tails-1115-02, tails-1115-03, tails-1115-05]
red: required
red_reason: a dev tag is refused at push
red_verified_at: 2026-11-17T13:41:02Z dcdeda58d16b0647ba70d10ab6f0009f9cda3f342c7d0fdfe1d5ad343826d300
---

# CI and release safety: pinned actions, a Windows install smoke, the defect gate in CI and ship-check, no dev tag pushed, a timing test without a clock

## Goal
Five changes around the release path (private `~/.vulyk/audits/known-defects-2026-11-15/`: `security.md` S18;
`tails.md` T26, T29, T51, T100).
1. S18: every action in `.github/workflows/ci.yml` is pinned by full commit SHA with the version in a trailing
   comment. Resolve each SHA with `git ls-remote <action repo> refs/tags/<tag>`, never from memory; no network is
   `NEEDS_CONTEXT`.
2. T51: the `install-smoke` job also runs on Windows under Git Bash, so story 02's byte check of the line-ending
   step runs where the defect lived.
3. T100: the repo-wide defect gate runs: a CI step in the `shell` job, and `ship-check.sh` reports NOT READY when
   `defects-check.sh` is red or cannot run.
4. T26: a push that carries a `-dev.N` version tag, or more than one version tag, is refused (plan.md
   `## Contracts` P1): `scripts/tag-push-check.sh`, the hook `scripts/git-hooks/pre-push` that calls it,
   `/vulyk-ship` step 2a putting the hook in place where it makes the local tag, and the card naming it.
5. T29: the trace-autopsy speed check in `tests/symbol-map.test.sh` is replaced by a bound on counted steps
   (process starts through a counting shim, or a counter the script prints); no wall clock is read.

Marked red: a new refusal on the publish path.

## Requirements
> 4. Secret masking and leak checking cover the shapes listed privately, and a masking failure stops the write instead of passing it through (S15-S17); CI actions are pinned to immutable versions (S18).
> 8. A timing test that depends on host load is replaced by a bound that uses no clock; known flaky tests are fixed.
> 2. The installer defects are fixed: release copies not counted as hive edits, untracked source files not copied, area-only cards named on upgrade, glob loops safe, side effects (user-scope mod, model pin) offered or flagged, never done silently (T7, T15, T22, T51-T55 and the rest of tails.md that touch install.sh).

## Files
- .github/workflows/ci.yml
- scripts/ship-check.sh
- scripts/tag-push-check.sh
- scripts/git-hooks/pre-push
- scripts/trace-autopsy.py
- .claude/commands/vulyk-ship.md
- docs/defects/public-release-per-change.md
- docs/defects/INDEX.md
- tests/cycle.test.sh
- tests/symbol-map.test.sh

## Non-goals
- Do not push, tag, or run a workflow: the new Windows job first runs at the owner's publish (plan.md
  `## Assumptions`). Do not mark a job `continue-on-error`.
- `/vulyk-ship` still prints the publish command and never runs it; the hook is copied only where step 2a makes
  the local tag, and an existing different `pre-push` hook is named, not replaced.
- Deleting a tag on the remote passes the check: a leaked dev tag must stay removable.
- Do not replace the card's existing `check:`; the card names the hook, its test and how it is switched off
  (`--no-verify`, a clone without the hook).
- In `ship-check.sh` add the defect stage only; the `--record` masking call is story 03's. No guard hook edit:
  refusing the push inside `git-guard.sh` is guards-1115's file.
- Change `trace-autopsy.py` only if the count needs it, and never its output.
- Edit `tests/cycle.test.sh` only in part `ship`.
- Both new scripts are executable in the index; run `bash scripts/portability-check.sh scripts/tag-push-check.sh
  scripts/git-hooks/pre-push scripts/ship-check.sh`.
- Run `bash scripts/defects-index.sh` after the card edit; never edit `INDEX.md` by hand.

## Map slice
`memory/map/scripts.md` → Entry points (`ship-check.sh`); `memory/map/commands-ship.md` → `/vulyk-ship` (step 2a);
`memory/map/scripts-checks.md` → Entry points (`trace-autopsy.sh`, `defects-check.sh`), Tests.

## Acceptance criteria
- [ ] Part `ship`: `tag-push-check.sh`, fed git's pre-push lines, exits 1 with a reason for a `refs/tags/` ref
  holding `-dev.`. The label contains `a dev tag is refused at push`. Neighbours: two release tags in one push are
  refused; one release tag passes; a branch push passes; a dev-tag deletion passes; empty input passes.
- [ ] `scripts/git-hooks/pre-push` passes its stdin to the check and returns its exit code; `vulyk-ship.md` step
  2a names the copy and what it does when a hook is already there; the card has its line.
- [ ] Part `ship`: with a library whose gate is red, `ship-check.sh` says NOT READY naming the defect gate; with
  no Python (the gate exits 2) it says it cannot confirm and is NOT READY; green passes as today.
- [ ] A test in part `ship` reads `ci.yml`: every `uses:` ends in a 40-hex SHA and a `# <version>` comment, the
  `shell` job runs `bash scripts/defects-check.sh`, and `install-smoke` lists a Windows runner with a bash shell.
- [ ] `tests/symbol-map.test.sh` holds no elapsed-time comparison for trace-autopsy; the new bound fails when the
  script does one more counted step per frame than today (shown once in the notes) and passes under load.
- [ ] `bash scripts/defects-check.sh` is green; every new case fails on HEAD and the notes list them.

## Verification
`bash tests/cycle.test.sh --part ship`
`bash tests/symbol-map.test.sh`
`bash scripts/defects-check.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per item and a `DOCS: <file> - <sentence>` line for each doc sentence story 11 must change. -->
- .github/workflows/ci.yml: every action pinned by full SHA from `git ls-remote` on 2026-11-17 (checkout and setup-node
  `refs/tags/v4` = `v4.4.0`, lightweight tags, so the code is what `@v4` ran; shellcheck already pinned); the shell job
  checks out full history (the gate dates quotes by git blame) and runs `bash scripts/defects-check.sh`; install-smoke
  adds `windows-latest`, `defaults.run.shell: bash`, an explicit `core.autocrlf true` before checkout, and on Windows
  runs `tests/telemetry.test.sh --part install-xp` (story 02's CR byte check). Not run: no workflow was started.
- scripts/ship-check.sh: a `defects` line after `ci`: exit 0 ok, 1 RED, any other exit "cannot confirm", both NOT READY;
  a repo with no `scripts/defects-check.sh` gets "not checked" (as `ci` does with no workflow). The gate runs with
  PYTHONDONTWRITEBYTECODE=1: its parser's `__pycache__` otherwise dirtied a fixture tree and opened stage 03.
- scripts/tag-push-check.sh (new), scripts/git-hooks/pre-push (new): P1 as written; a dev tag is refused under its
  local or remote name; the hook refuses the push when the check script is missing. Both are 100755 on disk but the
  index mode is close-story's `git add` under core.fileMode=false (the git guard refuses my `git add --chmod`).
- .claude/commands/vulyk-ship.md step 2a: the hook copy before the local tag, same hook = nothing, a different one named.
- docs/defects/public-release-per-change.md `## Check`: one sentence naming the hook, its test and its two ways off;
  `defects-index.sh` run, INDEX.md unchanged (the index reads no `## Check` text).
- tests/symbol-map.test.sh: the three-run clock check is gone; a Python shim counts every `subprocess.run` of
  trace-autopsy.py (run unchanged via runpy) and bounds it at 3 + 2 per resolved frame (7 here), output byte-equal to
  the plain run. Shown once: a copy with one extra git call per frame counts 9 on the same two-frame brief (red).
  trace-autopsy.py untouched.
- New cases red on HEAD (stamp-red receipt): part ship - the seven tag-push-check cases (label = red_reason), the reason
  names the tag, the four real-push hook cases, hook stdin/exit, hook without the script; the four ship-check defect
  cases plus "not checked" with no gate; the three vulyk-ship pins and the card pin; the three ci.yml reads. The
  symbol-map step bound passes on HEAD by design (it replaces a clock check; the script did not change).
CHANGELOG: every GitHub Action in CI is pinned by full commit SHA with its version in a comment (S18).
CHANGELOG: the install smoke job also runs on Windows under Git Bash, including the installer's CR byte check (T51).
CHANGELOG: CI runs the repo-wide defect gate, and ship-check says NOT READY when the gate is red or cannot run (T100).
CHANGELOG: a push carrying a `-dev.N` tag, or more than one version tag, is refused by a pre-push hook that /vulyk-ship puts in place where it makes the local tag (T26).
CHANGELOG: the trace-autopsy speed test bounds the git calls per frame instead of reading the clock (T29).
DOCS: docs/cycle.md - where ship-check's confirmations are listed, add the defects line: the repo-wide defect gate red or unable to run (no Python) is NOT READY.
DOCS: docs/hooks-reference.md - the git hook samples line names only `post-merge`; add `scripts/git-hooks/pre-push` (refuses a `-dev.N` tag or several version tags; copied by /vulyk-ship step 2a; off with `--no-verify`).

## Findings

## Red receipt
- command: bash tests/cycle.test.sh --part ship
- exit: 1
- tests: dcdeda58d16b0647ba70d10ab6f0009f9cda3f342c7d0fdfe1d5ad343826d300 (tests/cycle.test.sh, tests/symbol-map.test.sh)
- impl: d33a4751225a172f8ed02a9295c528b07a8997febf40cbc8546f3249f71bdd48
- stamped: 2026-11-17T13:41:02Z

```
::error::tag-push-check: a dev tag is refused at push (exit 1 with a reason) - exit 127 (want 1), output: bash: /e/Projects/vulyk/scripts/tag-push-check.sh: No such file or directory
::error::ci.yml: uses: lines not pinned by SHA + version comment:
              - uses: actions/checkout@v4
              - uses: actions/checkout@v4
              - uses: actions/checkout@v4
              - uses: actions/setup-node@v4   # driver and e2e run the real Workflow driver
              - uses: actions/checkout@v4
              - uses: actions/checkout@v4
              - uses: actions/checkout@v4
::error::ci.yml: the shell job does not run bash scripts/defects-check.sh
::error::ci.yml: install-smoke has no windows-latest runner with shell: bash
```

- close-story exit 4: `edited outside ## Files: memory/map/agents-and-commands.md, memory/map/cycle-close.md,
  memory/map/cycle-repair.md, memory/map/cycle-state.md, memory/map/cycle.md, memory/memory.md - committed since the
  claim head 8bdd6ac0`. None is mine: they are commit 4658299b (`docs(map): slices within 80 lines and 130 chars`, the
  Queen's step before wave 4). The story's work is done; close-story stopped at the scope check, before verification.
  The claim head needs moving past 4658299b (or the paths excused) before close-story runs again.
