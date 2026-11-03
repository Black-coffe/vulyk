---
story: post-045-tails-03
spec: post-045-tails
status: todo
returned:
tier: 2
worker: worker-code
wave: 2
blocked_by: [post-045-tails-01]
red: required
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

## Findings
