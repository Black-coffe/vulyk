---
description: Memory garbage collection - consolidate learnings, prune stale pointers, clean snapshots
argument-hint: []
---

Dispatch `librarian` for a full GC pass over `memory/` per its protocol (consolidate learnings, flag stale maps, prune snapshots >14 days, verify the pointer index).

Then act on its report in the main session:
- Stale maps -> offer to run `/vulyk-map` for the flagged modules now.
- "Needs human decision" items -> present them as a short list, decide nothing unilaterally.
- If `memory/learnings/CONSOLIDATED.md` exceeded its 40-entry cap, note that the next `/vulyk-evolve` should promote the oldest stable entries into rules or wiki notes (learnings are a buffer, not an archive).
