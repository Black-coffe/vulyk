# The memory plane

## Layers (cheap -> rich)
| Layer | File(s) | Loaded | Written by |
|---|---|---|---|
| Constitution | `CLAUDE.md` (or `CLAUDE.vulyk.md` beside a project's own `CLAUDE.md`), ~7 KB | always, in the main session and every subagent that does not set `omitClaudeMd` | human + /vulyk-evolve changesets |
| Path rules | `.claude/rules/*` | on touch; always.md always | bootstrap, evolve |
| Defect cards | `docs/defects/**/*.md` | by the PreToolUse hook before a matching action, narrowest scope first | the session, on the owner's words |
| Pointer index | `memory/memory.md` (<=60 lines) | task start | drone-docs, librarian |
| Codebase map | `memory/map/<module>.md` (~80 lines each) | per relevant slice | drone-scout via /vulyk-map |
| LLM wiki | `docs/wiki/*` | on pointer follow | drone-docs |
| Learnings | `memory/learnings/*` | by /vulyk-evolve | a session or the owner, by hand -> librarian consolidates |
| Specs & ADRs | `docs/specs/*`, `docs/adr/*` | per task | queen-planner, lead-architect |

## Protocols that make it safe
- **Hint, not truth.** Every consumer verifies pointers against real code before acting. Maps drift; the protocol assumes it.
- **Single consolidator.** Workers append only to their own story files; `drone-docs` updates map/wiki from diffs; `librarian` alone merges learnings. No concurrent-write races by construction.
- **No automatic learnings.** The `SessionEnd` hook that wrote a learnings stub per session was removed in 0.18.0 (ADR-013 D7): it wrote empty stubs. A learning is now a file someone chose to write; a session history, if you want one, is the Chronicle plugin's job.
- **Freshness tracking.** `last-verified` dates on map files; git-hook staleness flag after merges; `/vulyk-status` cross-checks dates against git churn.
- **Compaction insurance.** The PreCompact hook snapshots the index and spec statuses, so `/compact` can never silently destroy orchestration state.
- **Session continuity.** `/clear` is mandatory hygiene under the token economy — the handoff layer makes it cheap. `handoff.py` dumps session state (git, todos, touched files, recent prompts) to `.claude/handoff/` on `/clear`/exit/compaction, `/vulyk-handoff` adds a model-written summary (decisions, dead ends, next step), and SessionStart restores the freshest handoff after a `/clear` or a compaction. Deliberately **not** in git: handoffs are per-machine session state, unlike the layers above. See [hooks-reference.md](hooks-reference.md).

## Claude Code's own auto memory
Outside the layers above, Claude Code keeps a private auto memory per repository at
`~/.claude/projects/<slug>/memory/` (per machine, not in git). It loads the first 200 lines or 25 KB of
its `MEMORY.md` into every session, and on some installs into subagents too. VULYK reads it, and the
owner decides what happens to it:
- **The signal.** At 160 lines or 20 KB (80% of either limit) the SessionStart brief adds `memory triage
  (MEMORY.md <n> lines, <k> KB ...)` to `maintenance due`, and the Queen runs `/vulyk-gc memory`. That
  triage asks the owner before it writes a card or deletes a file. Project lessons become cards in
  `docs/defects/`, personal ones stay, and stale ones go. The triage ends with `memory-triage.sh --mark`
  (`.claude/state/memory-triage.txt`, per machine). After that the signal stays quiet until `MEMORY.md` grows
  20 lines or 2 KB past the mark, so personal rules left over the threshold do not bring it back every session.
- **The off switch.** `"autoMemoryEnabled": false` in a project's `.claude/settings.json` (or
  `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`) turns auto memory off for that project: nothing is read from it or
  written to it. The owner's personal lessons (servers, access, people, their style, rules their own
  global `CLAUDE.md` sends there) then stop loading. Nothing in `docs/defects/` replaces them. VULYK never sets
  this switch, in its own repo or in a hive. Run the triage first if you want to set it.

## The LLM wiki
One note per domain or invariant, written for a model to read: declarative, terse, densely linked (`related:` frontmatter). Obsidian opens the folder natively if you want a human view, but the wiki's customer is the next agent that touches the domain. Wiki notes are where ADR invariants and promoted learnings end up - the long-term memory of the hive.

## Why not a vector database?
You can add one (semantic-search MCP servers pair well with VULYK for million-line monorepos). The default stays files-in-git because it is inspectable, diffable, mergeable, and survives every tooling change. Structure-first, embeddings-optional.
