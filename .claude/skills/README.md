# Skills

Project-specific skills live here. VULYK ships only the two `_meta` skills that power `/vulyk-evolve`;
your domain skills are added over time - drafted by the evolution cycle from your own repeated patterns,
reviewed by you, and retired to `_graveyard/` when they stop earning their place.

Skill format: a directory containing `SKILL.md` with YAML frontmatter (`name`, `description` with concrete
trigger phrasing) and a body that teaches the method, not just the goal. Keep skills under ~150 lines;
link out to `docs/wiki/` for domain knowledge instead of duplicating it.

Only a skill's description is always loaded; its body loads when the skill is used. A procedure that
only some sessions need belongs here, not in the constitution, which every agent that loads it pays
for on every turn.
