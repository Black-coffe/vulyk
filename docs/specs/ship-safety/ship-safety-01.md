---
story: ship-safety-01
spec: ship-safety
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
---

# Safe merge at ship

## Goal
`ship-check.sh` gains two stage-03 checks: the session's branch equals the recorded `**Branch:**` (on the default branch it keeps today's note), and `git merge-tree --write-tree --name-only --no-messages <default> <branch>` exits 0. Exit 1 fails stage 03 naming the conflicting files and the repair; any other exit fails it as "cannot check". `/vulyk-ship` step 2 merges only from a clean default branch, runs `git merge --abort` and stops on a failed merge, offers the repair on a conflict, and deletes the spec branch with `git branch -d` after the merge (never `-D`).

## Requirements
> 1. Перед выпуском ship-check проверяет, что ветка спеки вливается в main без конфликта. Конфликт или «не смог проверить» = NOT READY с списком файлов.
> 2. При конфликте королева останавливается и предлагает починку: влить main в ветку спеки и снова прогнать совет.
> 3. /vulyk-ship мержит только на чистой main. Сорвавшийся мерж откатывается, выпуск останавливается.
> 4. После выпуска ветка спеки удаляется безопасным git branch -d.
> 5. cycle.sh отказывает и называет обе ветки, если захват, закрытие истории или открытие раунда запущены не на ветке спеки. ship-check тоже сравнивает ветки.

## Files
- scripts/ship-check.sh
- .claude/commands/vulyk-ship.md
- tests/cycle.test.sh

## Non-goals
- Do not make ship-check exit non-zero or perform any merge or checkout itself.
- Do not merge the default branch into the spec branch automatically; the repair is offered, not run.
- Do not touch `cycle.sh` (story 02).

## Map slice
memory/map slices for scripts (ship-check) and commands (vulyk-ship).

## Acceptance criteria
- [ ] A spec branch that conflicts with the default branch: ship-check prints NOT READY and names the conflicting file.
- [ ] A clean spec branch: stage 03 shows an ok merge line and READY stays reachable.
- [ ] Standing on a third branch (neither recorded nor default): stage 03 fails naming both branches.
- [ ] A `merge-tree` exit other than 0/1 (simulated with a missing branch ref) fails stage 03 as "cannot check", never ok.
- [ ] `/vulyk-ship` step 2 names: clean default branch first, `git merge --abort` + stop on failure, the repair offer on a conflict, `git branch -d` after the merge.

## Verification
`bash tests/cycle.test.sh`

## Implementation notes
- scripts/ship-check.sh stage 03: branch comparison (a third branch fails, the default branch keeps its note) and a git merge-tree precheck after it.
- Surprise caught by the test: merge-tree exits 1, not 128, on a missing ref, so both refs are verified first and a conflict that names no file counts as cannot-check.
- vulyk-ship.md: step 1 names the conflict repair (owner's yes only), step 2 the clean-default merge, merge --abort on failure, git branch -d after.

## Findings
