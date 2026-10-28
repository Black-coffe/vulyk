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

`f=memory/learnings/CONSOLIDATED.md; e0=$(git show HEAD:$f 2>/dev/null | grep -cE '^[0-9]+\. '); b0=$(git show HEAD:$f 2>/dev/null | wc -c); e1=$(grep -cE '^[0-9]+\. ' $f 2>/dev/null); b1=$(cat $f 2>/dev/null | wc -c); echo "CONSOLIDATED.md: entries $((e0))→$((e1)), bytes $((b0))→$((b1))"; if [ $((b0)) -gt 0 ] && { [ $((e1*2)) -lt $((e0)) ] || [ $((b1*2)) -lt $((b0)) ]; }; then echo "gc: refused - CONSOLIDATED.md lost more than half"; git diff --stat -- $f; else git add memory/learnings ':(icase)memory/memory.md' && git commit -m "chore(memory): gc" -- memory/learnings ':(icase)memory/memory.md'; fi`

The pathspec keeps `memory/stats/` and anything else staged out of it; `:(icase)` takes the index as
`memory.md` or `MEMORY.md`. Nothing changed: no commit.

Nobody has to remember this command: the SessionStart brief says `maintenance due: gc (...)` when stub
learnings exist or 10+ raw ones wait, and the Queen runs it after the owner's task, on the default branch
with a clean tree, then tells the owner in one line what changed, including the `CONSOLIDATED.md` counts.

## `memory` mode: one-off triage of private memory into cards

The SessionStart brief offers it (`[VULYK] memory triage (MEMORY.md <n> lines, ...)`, its own line, never in
`maintenance due`) once Claude Code's own `MEMORY.md` reaches 160 lines or 20 KB, 80% of what it loads. It runs only
on the owner's yes, because step 2 reads every file; a no runs `bash scripts/memory-triage.sh --mark`. The owner's
yes in step 4 still gates every write.
Private auto memory (`~/.claude/projects/<slug>/memory/`) is outside the repo and the `librarian` has no shell, so
the main session does every step itself. Never dispatch a subagent for it: personal files are never opened by one.

1. Run `bash "${CLAUDE_PROJECT_DIR}/scripts/memory-triage.sh"`. It lists `path<TAB>type<TAB>first heading` and
   writes nothing. `no private memory: <dir>` → say so in one line and stop.
2. Read each listed file.
3. Propose three heaps in one table, one row per file: **card** (a project rule: Never / Allowed / How-to),
   **personal / stays** (servers, access, people, the owner's style, anything with client data: stays in private
   memory), **delete** (stale, done, or a duplicate of an existing card: `bash scripts/defects-index.sh --grep <word>`).
   For a card row also give the target `docs/defects/<area>/<id>.md` (or an existing card it joins), the branch and
   the retold line.
4. Ask once with AskUserQuestion: the recommended list first, marked recommended; the other options are a changed
   list or no.
5. On no, or a changed list: redo the table from the owner's answer and ask again. Nothing is written before a yes.
6. On yes, write the cards. A card made from memory is retold, never an owner quote: no `## Owner quotes` line, and a
   `## Source` section with one line per file: `- YYYY-MM-DD · auto memory <file> · retold, not a quote`.
7. Run `bash scripts/leak-check.sh <card>` on each new or changed card. A hit: rewrite the line without the internal
   name, or move the file to the personal heap; no card is committed with a hit.
8. Delete each moved and each dropped file from the private memory dir, and their index lines: `bash
   scripts/memory-triage.sh --index-lines <dir>/MEMORY.md <file>...` prints exactly the lines to remove from that
   `MEMORY.md`. Personal files stay, with their lines.
9. Run `bash scripts/defects-index.sh`, then commit the cards and the index with `chore(defects): memory triage`.
   The commit message names counts, never a personal file or its content.
10. Run `bash scripts/memory-triage.sh --mark`, also when nothing was moved: it records the size the triage left,
    and the brief stays quiet until `MEMORY.md` grows 20 lines or 2 KB past it.
11. Report one line: cards written, files deleted from private memory, files kept.
