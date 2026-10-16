# Brief: close-story-scope-refusal

**Date:** 2026-10-16
**Tier:** 1 - one module (`scripts/cycle.sh` close-story and its test), a clear fix once the owner chose the behaviour
**Source:** a live hive's weekly `/vulyk-evolve` report, which the owner pasted into this session; item 3 of three the owner ordered done

## Request (verbatim)

The hive's evolve report, the paragraph that names the defect:

> Повторяющуюся ловушку — правка за пределами ## Files пачкает дерево и драйвер не стартует — сегодня поймали снова на <file>.py. Это уже записано в памяти; чинить её стоит в самом Vulyk, не здесь.

The owner, 2026-10-16, on the order of the three items:

> А параллельно можно все три пункта делать или нет? Или нужно последовательно? Если последовательно, то первый, второй, потом третий.

The owner's choice, 2026-10-16, among three behaviours (the others: close-story commits the stray edits too; the driver only warns earlier):

> close-story отказывает сразу (Рекомендую)

## Mechanism (the Queen's reading, 2026-10-16)

- `close-story` runs `scope-check.sh` (`scripts/cycle.sh:1848`), which records out-of-scope paths but never blocks.
- The commit stages only the story's declared Files, the story file and the stats rows (`scripts/cycle.sh:1944-1956`), so an
  edit outside `## Files` stays uncommitted.
- The next `open-round` (or `claim` on relaunch) refuses the dirty tree (`scripts/cycle.sh:2215-2220`, `dirty_outside_paperwork`),
  often hours after the worker's turn ended; the driver stops there.

## Asks
1. close-story refuses a worker's edit outside ## Files: exit 4 listing the paths that scope-check counts out of scope and that would leave the tree dirty for open-round, so the worker reverts or returns NEEDS_CONTEXT in its own turn instead of the driver stopping at open-round later.
