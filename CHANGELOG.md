# Changelog

All notable changes to VULYK are documented here. `/vulyk-evolve` changesets append entries automatically (one line per change, with rationale).

## [0.1.0] - 2026-06-12

### Added
- Hive roster: 8 cascade-routed agents (queen-planner, lead-architect, lead-review, worker-code, worker-test, drone-scout, drone-docs, librarian).
- Orchestration commands: /vulyk-bootstrap, -plan, -build, -review, -map, -evolve, -gc, -status.
- Memory plane: pointer index, codebase map, LLM wiki conventions, learnings buffer, snapshots.
- Self-evolution cycle with insight-harvester and skill-gardener meta-skills, usage counters, and graveyard retirement.
- Hooks: session brief (SessionStart), learnings capture (SessionEnd, optional Haiku auto-distill), skill usage counter (PostToolUse), compaction guard (PreCompact); post-merge git-hook sample.
- Bootstrap interview, story/ADR/wiki-note templates, non-destructive installer, full documentation set.
