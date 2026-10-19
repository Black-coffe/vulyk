---
story: ship-safety-02
spec: ship-safety
status: todo
returned:
tier: 2
worker: worker-code
wave: 2
blocked_by: [ship-safety-01]
---

# Branch guard in cycle.sh

## Goal
One helper in `cycle.sh`, called by `claim`, `close-story` and `open-round` after their usage checks: when the plan has a `**Branch:**` line and `git rev-parse --abbrev-ref HEAD` differs, exit 2 with "on <now>, the spec's commits live on <recorded>". `cmd_branch` refuses (exit 2) to check out an existing `vulyk/<slug>` whose tip is an ancestor of the default branch and is not the default branch's tip, naming both and saying to pick a new slug or delete the old branch. ADR-001's rows for these four verbs gain the new preconditions.

## Requirements
> 5. cycle.sh отказывает и называет обе ветки, если захват, закрытие истории или открытие раунда запущены не на ветке спеки. ship-check тоже сравнивает ветки.
> 6. cycle.sh не строит поверх старой, уже влитой ветки с тем же именем.

## Files
- scripts/cycle.sh
- tests/cycle.test.sh
- docs/adr/001-cycle-state-contract.md

## Non-goals
- No automatic `git checkout` to the right branch: refuse only (owner's answer 2).
- Do not change exit codes or messages of any other precondition.
- No guard on `claim` before a `**Branch:**` line exists.

## Map slice
memory/map slice for scripts/cycle.sh (claim, close-story, open-round, branch).

## Acceptance criteria
- [ ] `close-story` on a branch other than `**Branch:**` exits 2, names both branches, commits nothing.
- [ ] `open-round` and `claim` refuse the same way; on the recorded branch all three behave as before.
- [ ] `branch` on a slug whose `vulyk/<slug>` is already merged (and behind the default tip) exits 2 and writes no `**Branch:**` line; a fresh slug still creates its branch.
- [ ] Each new refusal has a test case in `tests/cycle.test.sh`, plus a neighbour case that must pass (the recorded branch; a fresh branch at the default tip).

## Verification
`bash tests/cycle.test.sh`

## Implementation notes

## Findings
