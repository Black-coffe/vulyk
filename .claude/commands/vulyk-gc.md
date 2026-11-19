---
description: Memory garbage collection - prune stale pointers, flag stale map slices
argument-hint: []
---

Collect what the librarian cannot read without a shell: one line per map slice, its last commit date and the number
of commits since then outside `memory/`:
`for f in memory/map/*.md; do d=$(git log -1 --format=%cs -- "$f"); printf '%s %s %s\n' "$f" "$d" "$(git rev-list --count --since="$d" HEAD -- . ':!memory')"; done`

Dispatch `librarian` for a full GC pass over `memory/` per its protocol (flag stale maps, verify the pointer index),
with that list in the dispatch. The learnings folder is retired (nothing writes it since 0.18), and so is the PreCompact
snapshot (`memory/snapshots/`): their files stay where they are, and nothing here reads, merges or deletes them.

Then act on its report in the main session:
- Stale maps -> offer to run `/vulyk-map` for the flagged modules now.
- "Needs human decision" items -> present them as a short list, decide nothing unilaterally.

Commit the index with this one line, run as written:

`git add ':(icase)memory/memory.md' && git commit -m "chore(memory): gc" -- ':(icase)memory/memory.md'`

The pathspec keeps `memory/stats/` and anything else staged out of it; `:(icase)` takes the index as
`memory.md` or `MEMORY.md`. Nothing changed: no commit. Then tell the owner in one line what changed.

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
