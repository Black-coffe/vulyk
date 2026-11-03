# ADR-030: CI on the branch head before ship - the Queen dispatches branch CI, no branch-push trigger, never a silent pass

- Status: proposed
- Date: 2026-11-03
- Spec: docs/specs/post-045-tails
- Relates to: ADR-026 (CI before ship). The archivist could not re-read ADR-026 in this harvest (no directory listing
  available); the owner checks whether this extends it or overlaps it before accepting.

## Context
0.45.0 reached main with red CI; the spec adds the process check whose absence allowed that (plan.md `## Goal`).
The plan's assumptions, verbatim:

> Ask 7 (owner: «Пропуск с причиной»): a new ship-check line `ci`: no `.github/workflows/*.y*ml` -> `ci: not checked -
> no CI workflow in this repo` (ok); no `origin` remote on github.com -> `ci: not checked - no GitHub remote` (ok);
> otherwise `gh run list --commit <sha> --json status,conclusion,workflowName` (verified on gh 2.91.0 here) on HEAD,
> or on the newest commit with only paperwork since (`paperwork_only`, as the council line uses): every run completed
> `success` and at least one run -> ok; none, pending, or any other conclusion -> NOT READY naming it; `gh` absent or
> failing -> NOT READY `cannot confirm CI: <why>`, never a silent pass. ship-check stays exit 0 (it reports).

> Who starts branch CI (a side-agent note, model text, raised that VULYK's `ci.yml` runs only on main, PRs and
> `workflow_dispatch`): `/vulyk-ship` gains one step - when ship-check says no run for the head, the Queen pushes the
> branch and runs `gh workflow run <workflow> --ref <branch>` itself (owner rule: push/release are mine to run), then
> waits for it. `ci.yml` is not changed: a trigger on every branch push would spend a Linux+macOS run on each story
> commit. Rejected: a branch-push trigger in `ci.yml`. The owner can veto this at approval.

Approval line: `**Approved:** Andrei, 2026-11-03 (branch-CI step in /vulyk-ship kept: the Queen pushes the branch and runs
`gh workflow run`)`.

## Options
1. The Queen pushes the spec branch and dispatches `gh workflow run <workflow> --ref <branch>` at ship (chosen) - one CI
   run per ship, started by the session that owns push.
2. Rejected: a branch-push trigger in `ci.yml` - spends a Linux+macOS run on each story commit.

## Decision
Ship requires a green CI run on the branch head (or the newest commit with only paperwork since) wherever a CI can run.
`ship-check.sh` reports it as the `ci` line; it skips only with a stated reason (no workflow, no GitHub remote) and treats
an absent or failing `gh` as NOT READY, never a pass. Branch CI is started by `/vulyk-ship` via `workflow_dispatch`, not by
a push trigger. Deciding factor: CI cost per story commit, and the owner's rule that push/release are the Queen's to run.

## Consequences
Not recorded beyond the above: a ship now includes a push of the spec branch and a wait for the dispatched run; `ci.yml`
must keep `workflow_dispatch`.

## Invariants created
- `ship-check.sh`'s `ci` line never passes silently: every skip names its reason; an unreadable CI state is NOT READY.
- `ship-check.sh` stays exit 0 for the `ci` line (it reports; the Queen acts).
- `ci.yml` gets no trigger on every branch push; it keeps `workflow_dispatch` so `/vulyk-ship` can start branch CI.
- Only the Queen (owner-run session) pushes the branch and dispatches the run; no subagent does.

## Revisit when
Not recorded.
