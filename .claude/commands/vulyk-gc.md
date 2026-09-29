---
description: Memory garbage collection - consolidate learnings, prune stale pointers, clean snapshots
argument-hint: []
---

Dispatch `librarian` for a full GC pass over `memory/` per its protocol (consolidate learnings, flag stale maps, prune snapshots >14 days, verify the pointer index).

Then act on its report in the main session:
- Deletions are yours: the librarian has no shell. `git rm` the raw learnings its `Delete:` list names and
  every stub (`grep -l 'Stub captured by VULYK' memory/learnings/*.md`); remove snapshots older than 14 days
  (`find memory/snapshots -type f -mtime +14 ! -name .gitkeep -delete`).
- Stale maps -> offer to run `/vulyk-map` for the flagged modules now.
- "Needs human decision" items -> present them as a short list, decide nothing unilaterally.
- If `memory/learnings/CONSOLIDATED.md` exceeded its 40-entry cap, note that the next `/vulyk-evolve` should promote the oldest stable entries into rules or wiki notes (learnings are a buffer, not an archive).

Commit the result: `git add memory/learnings memory/memory.md && git commit -m "chore(memory): gc"` (only those
paths; `memory/stats/` and the rest of the tree are not gc's). Nothing changed: no commit.

Nobody has to remember this command: the SessionStart brief says `maintenance due: gc (...)` when stub
learnings exist or 10+ raw ones wait, and the Queen runs it after the owner's task, on the default branch
with a clean tree, then tells the owner in one line what changed.
