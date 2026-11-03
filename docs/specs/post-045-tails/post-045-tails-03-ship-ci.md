---
story: post-045-tails-03
spec: post-045-tails
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 2
blocked_by: [post-045-tails-01]
red: required
red_reason: a failed CI run -> ci OPEN naming the workflow
red_verified_at: 2026-11-03T13:27:11Z f0a32879c4850af6e0accc39fbce809cae757094f7ad7cda2f223260a23fd716
---

# ship-check confirms CI on the branch head

## Goal
`ship-check.sh` gains a `ci` line. No `.github/workflows/*.yml|yaml` -> `ci: not checked - no CI workflow in this
repo` (ok). `origin` not on github.com -> `ci: not checked - no GitHub remote` (ok). Otherwise it asks
`gh run list --commit <sha> --json status,conclusion,workflowName` for HEAD, or for the newest commit with only
paperwork since (`paperwork_only`): at least one run and all `completed`/`success` -> ok, naming the sha; no run,
a pending run or any other conclusion -> NOT READY naming it; `gh` missing or failing -> NOT READY `cannot confirm
CI: <why>`. `/vulyk-ship` gets one step: on "no run for the head", push the branch and run `gh workflow run
<workflow> --ref <branch>`, wait for it, re-run ship-check. Red receipt: a fixture repo with a workflow, a github
remote and a fake `gh` answering a failed run must be NOT READY - today it is READY.

## Requirements
> подтверждение CI на ветке в ship-check

## Files
- scripts/ship-check.sh
- .claude/commands/vulyk-ship.md
- tests/cycle.test.sh

## Non-goals
- Do not edit `.github/workflows/ci.yml` (no branch-push trigger).
- ship-check stays exit 0 and never runs `gh workflow run` itself: it reads; the command acts.
- No env override to skip CI.

## Map slice
memory/map/scripts.md - ship-check.sh

## Acceptance criteria
- [ ] Today's ship part fixtures (no workflow dir) stay READY, with the `not checked - no CI workflow` line.
- [ ] Fake gh: success on HEAD -> ok; failure -> NOT READY naming the workflow; empty list -> NOT READY "no CI run"; in_progress -> NOT READY; gh exit 1 -> NOT READY "cannot confirm CI".
- [ ] Success on a commit followed only by paperwork -> ok; followed by a code commit -> NOT READY.
- [ ] Non-GitHub origin and no origin -> `not checked - no GitHub remote`.

## Verification
`bash tests/cycle.test.sh --part ship`

## Implementation notes
- `scripts/ship-check.sh`: `ci_check` runs after the stage-03 story line and prints `ci` lines. With no `.github/workflows/*.y*ml`, or an origin that is not `github.com[:/]`, the line is ok `not checked - ...`. Otherwise it walks `git rev-list --first-parent --max-count=20 HEAD`, stops at the first commit whose range to HEAD is not `paperwork_only`, and asks `gh run list --commit <sha> --json status,conclusion,workflowName --jq '...@tsv'` (gh's own `--jq`, no jq dependency). The newest commit with runs decides: every run completed/success -> ok `green on <sha7> (<workflows>)`; otherwise OPEN `<workflow> <status|conclusion> on <sha7>`. No run in the walk -> OPEN `no CI run for <head7> ...`. gh missing or exiting non-zero -> OPEN `cannot confirm CI: ...`. The exit code stays 0.
- Checked against real gh 2.91.0 on this repo through a throwaway worktree: d65bb82 -> `ci ok green on d65bb82 (CI)`, 3f60a43 (0.45.0, red CI) -> `ci OPEN CI failure on 3f60a43`. On this unpushed branch: `no CI run for 691cafd`.
- `.claude/commands/vulyk-ship.md` step 1: on `no CI run`, the Queen pushes the branch, runs `gh workflow run <file> --ref <branch>` (unless the push already started a run), waits with `gh run watch`, and runs ship-check again; a red run is a refusal. The description now reads «Pushes only the spec branch, for its CI run; never tags, publishes or deploys». `ci.yml` is untouched.
- Tests (`tests/cycle.test.sh` part ship): the demo fixture with no workflow dir stays READY with the not-checked line. A copy of it with a workflow commit, a paperwork check commit and a fake `gh` covers every acceptance case. Not covered: gh absent from PATH, since a real gh sits on this box's PATH.

## Findings

## Red receipt
- command: bash tests/cycle.test.sh --part ship
- exit: 1
- tests: f0a32879c4850af6e0accc39fbce809cae757094f7ad7cda2f223260a23fd716 (tests/cycle.test.sh)
- impl: d54e792886b53e30b6c35219909b48aad36eadb8fb54d75bdadd1c674718078a
- stamped: 2026-11-03T13:27:11Z

```
  ok    GREEN + newer ACCEPTED at HEAD is READY
  ok    code after ACCEPTED: stage 05 is OPEN
  ok    code after ACCEPTED: 05 names STALE (commit)
  ok    code after ACCEPTED: NOT READY
  ok    VERSION + CHANGELOG.md after ACCEPTED stays READY
  ok    a new story after ACCEPTED: 05 names STALE (pack)
  ok    a new story after ACCEPTED: NOT READY
the paperwork whitelist is anchored to docs/specs/*/ (R23/m-2): a commit under src/council/ or a bare src/journal.md is never paperwork, even though it shares the names
  ok    CURRENT right after the recorded check
  ok    src/council/x and src/journal.md are not paperwork -> STALE
```
