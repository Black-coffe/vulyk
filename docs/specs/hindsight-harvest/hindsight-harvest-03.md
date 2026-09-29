---
story: hindsight-harvest-03
spec: hindsight-harvest
status: done
returned: DONE
tier: 2
worker: worker-code
model: sonnet
wave: 2
blocked_by: [hindsight-harvest-02]
---

# /vulyk-gc refuses to commit a gutted CONSOLIDATED.md

## Goal
Before `/vulyk-gc` commits, its commit step compares `memory/learnings/CONSOLIDATED.md` against `HEAD`: entry count (numbered
entry lines) and bytes. If either fell by more than half, the step refuses to commit and shows `git diff --stat` to the
owner. The one-line report always carries `CONSOLIDATED.md: entries a→b, bytes a→b`. gc runs unattended after the owner's task,
exactly when a collapse would go unseen.

## Requirements
> 5. /vulyk-gc не коммитит CONSOLIDATED.md, потерявший больше половины

## Files
- .claude/commands/vulyk-gc.md
- tests/maintenance.test.sh

## Non-goals
- Do not change the librarian's protocol or its consolidation rules.
- No new script or test file. The condition lives in the command's shell line, and `tests/maintenance.test.sh` extracts that line and runs it.
- Do not touch the 40-entry cap note.

## Map slice
memory/map/agents-and-commands.md: the `/vulyk-gc` entry.

## Acceptance criteria
- [ ] The commit step is one shell condition. It reads the entry count and bytes of `HEAD:memory/learnings/CONSOLIDATED.md` and of the working copy, refuses when either drops by more than 50%, and otherwise commits as before.
- [ ] A file new at `HEAD` (no previous version) never refuses.
- [ ] The owner-facing line always prints both pairs of numbers.
- [ ] `tests/maintenance.test.sh` extracts the commit-step condition from `vulyk-gc.md` and runs it in a throwaway git repo on three cases. A file cut from 10 entries to 4: refused, no commit. A file cut from 10 to 7: committed. A file new at `HEAD`: committed.
- [ ] The command file stays within the context budget that `tests/maintenance.test.sh` checks.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes
- `vulyk-gc.md`: the commit step is one backticked shell line. It counts `^[0-9]+\. ` entries and bytes at `HEAD` and in the working copy, always echoes `entries a→b, bytes a→b`, refuses (`git diff --stat`, no commit) when either halves, and commits as before otherwise. `$((…))` normalises BSD `wc -c` padding.
- `tests/maintenance.test.sh` extracts that exact line from the command and runs it in three throwaway repos: 10→4 refused, 10→7 committed, and a file new at `HEAD` committed.

## Findings
