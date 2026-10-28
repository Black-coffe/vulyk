# Auto memory and story-read card delivery (plan)

**Tier:** 2 · **Spec slug:** `auto-memory-subagent-start` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-021 (rules tree, delivery), docs/wiki/rules-tree.md, docs/memory-system.md; horizon (ADR-022) skipped: card delivery and memory triage already exist, only the trigger is new
**Depends on:** 0.40.1 (`110a6f7`)

## Goal
Cards reach a builder before it starts thinking about a change, not only at its first edit: when any agent
reads a story file, `defects-inject.sh` shows the cards scoped to that story's `## Files`. This replaces the
owner's `SubagentStart` idea: its input carries no prompt (probe 2026-10-28), and Workflow-driver workers,
the main target, are not `Agent` calls the hook could look up. Separately, the SessionStart brief flags a
native `MEMORY.md` at 80% of Claude Code's load limit as `memory triage` due, and the docs say how to turn
auto memory off and what is lost; VULYK turns nothing off.

## Assumptions
- A story file is `docs/specs/<slug>/<name>.md` whose frontmatter has `story:`; `brief.md`, `plan.md` and other spec files deliver nothing.
- `## Files` entries are matched against card `paths:` as paths (a glob entry as its literal text); cards scoped only by `cmd:` or `tool:` do not fire on a Read.
- `Read` joins the PreToolUse matcher; every Read then starts the bash wrapper, which exits before python unless the input names `docs/specs/`. Its cost per Read is measured in story 01 and reported; no Claude Code `if` filter is relied on.
- The per-agent dedup is the existing one (`agent_id` + card ref), so a card shown on the story read is not repeated at the first edit.
- The auto memory dir is the one `memory-triage.sh` already derives (`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<slug>/memory`); a custom `autoMemoryDirectory` is not followed.
- Thresholds: 160 lines or 20480 bytes of `MEMORY.md` (80% of 200 lines / 25 KB, docs code.claude.com/docs/en/memory.md, read 2026-10-28).
- `SubagentStop` gets nothing: the request names it only in the title.
- Hives get the new matcher on their next `/vulyk-update`: the installer rewires the 0.32 matcher the way it rewired the 0.19 one; a hand-set matcher is kept.

## Stories

**Wave 1**
- `auto-memory-subagent-start-01-story-read-cards` — `defects-inject.sh` on `Read` of a story file shows the cards for its `## Files`; matcher, installer rewire, tests, docs.
- `auto-memory-subagent-start-02-memory-size-due` — SessionStart brief: native `MEMORY.md` at 160 lines / 20 KB makes `memory triage` due; `memory-triage.sh --dir`; docs on `autoMemoryEnabled`.

## Contracts
none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

**Approved:** Andrei, 2026-10-28 («да»)
**Branch:** vulyk/auto-memory-subagent-start
