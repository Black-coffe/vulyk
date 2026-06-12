---
name: insight-harvester
description: Mines raw session learnings and /insights output into evidenced friction patterns and concrete config-diff proposals. Used by /vulyk-evolve. Trigger when asked to analyze learnings, find friction patterns, or prepare an evolution changeset.
---

# Insight Harvester

Turn raw observations into configuration improvements with evidence.

## Inputs
- `memory/learnings/*.md` (raw, per-session) and `memory/learnings/CONSOLIDATED.md`
- Pasted output of the built-in `/insights` command, when available
- Recent `docs/specs/*/` story files with `## Findings` walls

## Method
1. **Cluster, do not enumerate.** Group observations by underlying cause, not surface symptom. "Worker touched out-of-scope file" three times across different specs is ONE pattern.
2. **Demand evidence.** Every pattern cites at least 2 occurrences (file + date). Single events are noted, not acted on.
3. **Map pattern -> smallest fix.** Prefer, in order: a path-scoped rule in `.claude/rules/` > a line in an agent prompt > a CLAUDE.md constitution change (most expensive context-wise - last resort).
4. **Write fixes as diffs**, not advice. "Add to `.claude/rules/api.md`: 'All new endpoints require an authz check; see wiki/auth-invariants'" - copy-pasteable.
5. **Specificity test:** a rule that would equally apply to any random repo is too generic to add. Project-specific or nothing.

## Output
A ranked table: pattern | evidence (n, links) | proposed diff | expected effect | rollback note.
