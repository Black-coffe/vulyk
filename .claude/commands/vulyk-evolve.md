---
description: Weekly self-evolution cycle - mine learnings and usage stats, propose config diffs as a reviewable changeset
argument-hint: [--dry-run to report without writing the changeset]
---

Run the evolution cycle. Use the `insight-harvester` and `skill-gardener` skills - they define the method. "$ARGUMENTS"

1. **Harvest.** Read `memory/learnings/` (raw + CONSOLIDATED), `memory/stats/skills.json`, and - if the user can paste it - the output of the built-in `/insights` command (ask once; proceed without it if unavailable).
2. **Diagnose.** Produce three lists with evidence: (a) top 3 friction patterns (repeated mistakes, expensive habits, recurring re-explanations); (b) skills/rules unused for 3+ weeks -> archive candidates; (c) patterns done manually 3+ times -> new skill/rule candidates.
3. **Propose.** On a branch `vulyk/evolve-<date>`, write the actual diffs: edits to `CLAUDE.md` project profile, `.claude/rules/`, agent prompts, new skill scaffolds; move archived skills to `.claude/skills/_graveyard/<name>/` adding `RETIRED.md` (date, reason, evidence). Append a CHANGELOG.md entry justifying EVERY change in one line each.
4. **Human gate.** Present the changeset as a review: per-change rationale, expected effect, rollback note. Apply NOTHING to the main branch yourself. With `--dry-run`, stop after the diagnosis report.

Discipline notes: prefer deleting and tightening over adding - constitutions rot by accretion; a rule that fires rarely but prevents disasters stays (frequency is not the only signal - say when you keep something for severity reasons).
