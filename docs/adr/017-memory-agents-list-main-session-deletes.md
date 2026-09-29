# ADR-017: Shell-less memory agents list deletions; the main session deletes

- Status: accepted (2026-09-29, the Queen under the owner's delegation: Andrei - "Вопросы, которые ты задал, я даю право тебе решить на твоё усмотрение")
- Date: 2026-09-29
- Spec: docs/specs/auto-maintenance

## Context
From plan.md `## Plan deltas`, verbatim:

> **2026-09-29, story 02 - gc could never delete.** The real gc run returned "I only have Read, Write, Edit and Glob, so I can't delete files". `librarian.md` told an agent without a shell to delete merged learnings and snapshots, so every `/vulyk-gc` would have left the buffer full. Decision: the librarian lists (`Delete:`), the main session deletes (`git rm`, `find -mtime +14`); `.claude/agents/librarian.md` joins story 02's `## Files`. Rejected: giving the librarian Bash (a memory writer that can run anything is a wider blast radius than two shell lines in the command).

## Options
1. The librarian reports a `Delete:` list; the command's main session runs `git rm` / `find -mtime +14` - chosen.
2. Give the librarian Bash - rejected: a memory writer that can run anything is a wider blast radius than two shell lines in the command.

## Decision
The librarian (a memory writer) keeps a tool set without a shell. File deletion and age-based pruning happen in the main session, driven by the librarian's `Delete:` list. Deciding factor: blast radius.

## Consequences
Not recorded beyond the delta: the command, not the agent, owns the destructive step, so an agent prompt that asks for deletion is a defect.

## Invariants created
- A memory-writing agent does not receive Bash; destructive filesystem steps live in the calling command's main session.
- An agent prompt must not instruct an action its tool set cannot perform; it reports the action for the main session instead.

## Revisit when
Not recorded.
