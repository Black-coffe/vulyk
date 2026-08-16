# The memory plane

## Layers (cheap -> rich)
| Layer | File(s) | Loaded | Written by |
|---|---|---|---|
| Constitution | `CLAUDE.md` | always | human + /vulyk-evolve changesets |
| Path rules | `.claude/rules/*` | on touch | bootstrap, evolve |
| Pointer index | `memory/memory.md` (<=60 lines) | task start | drone-docs, librarian |
| Codebase map | `memory/map/<module>.md` (~80 lines each) | per relevant slice | drone-scout via /vulyk-map |
| LLM wiki | `docs/wiki/*` | on pointer follow | drone-docs |
| Learnings | `memory/learnings/*` | by /vulyk-evolve | session hook -> librarian |
| Specs & ADRs | `docs/specs/*`, `docs/adr/*` | per task | queen-planner, lead-architect |

## Protocols that make it safe
- **Hint, not truth.** Every consumer verifies pointers against real code before acting. Maps drift; the protocol assumes it.
- **Single consolidator.** Workers append only to their own story files; `drone-docs` updates map/wiki from diffs; `librarian` alone merges learnings. No concurrent-write races by construction.
- **Freshness tracking.** `last-verified` dates on map files; git-hook staleness flag after merges; `/vulyk-status` cross-checks dates against git churn.
- **Compaction insurance.** The PreCompact hook snapshots the index and spec statuses, so `/compact` can never silently destroy orchestration state.
- **Session continuity.** `/clear` is mandatory hygiene under the token economy — the handoff layer makes it cheap. `handoff.py` dumps session state (git, todos, touched files, recent prompts) to `.claude/handoff/` on `/clear`/exit/compaction, `/vulyk-handoff` adds a model-written summary (decisions, dead ends, next step), and SessionStart restores the freshest handoff. Deliberately **not** in git: handoffs are per-machine session state, unlike the layers above. See [hooks-reference.md](hooks-reference.md).

## The LLM wiki
One note per domain or invariant, written for a model to read: declarative, terse, densely linked (`related:` frontmatter). Obsidian opens the folder natively if you want a human view, but the wiki's customer is the next agent that touches the domain. Wiki notes are where ADR invariants and promoted learnings end up - the long-term memory of the hive.

## Why not a vector database?
You can add one (semantic-search MCP servers pair well with VULYK for million-line monorepos). The default stays files-in-git because it is inspectable, diffable, mergeable, and survives every tooling change. Structure-first, embeddings-optional.
