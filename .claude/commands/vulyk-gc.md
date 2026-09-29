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

Commit the result with this one line, run as written. It prints the counts for your report line, and it refuses
to commit a `CONSOLIDATED.md` that lost more than half its entries or bytes. gc runs unattended, so a collapsed
rewrite would otherwise go unseen. On a refusal, show the owner the diff and commit nothing.

`f=memory/learnings/CONSOLIDATED.md; e0=$(git show HEAD:$f 2>/dev/null | grep -cE '^[0-9]+\. '); b0=$(git show HEAD:$f 2>/dev/null | wc -c); e1=$(grep -cE '^[0-9]+\. ' $f 2>/dev/null); b1=$(cat $f 2>/dev/null | wc -c); echo "CONSOLIDATED.md: entries $((e0))→$((e1)), bytes $((b0))→$((b1))"; if [ $((b0)) -gt 0 ] && { [ $((e1*2)) -lt $((e0)) ] || [ $((b1*2)) -lt $((b0)) ]; }; then echo "gc: refused - CONSOLIDATED.md lost more than half"; git diff --stat -- $f; else git add memory/learnings memory/memory.md && git commit -m "chore(memory): gc" -- memory/learnings memory/memory.md; fi`

The pathspec keeps `memory/stats/` and anything else staged out of it. Nothing changed: no commit.

Nobody has to remember this command: the SessionStart brief says `maintenance due: gc (...)` when stub
learnings exist or 10+ raw ones wait, and the Queen runs it after the owner's task, on the default branch
with a clean tree, then tells the owner in one line what changed, including the `CONSOLIDATED.md` counts.
