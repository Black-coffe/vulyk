# Self-evolution

Static configs rot. VULYK closes the loop with a weekly cycle that turns the hive's own experience into reviewed configuration changes.

## Signal collection (continuous, automatic)
- **SessionEnd hook** captures a learnings stub per session (set `VULYK_AUTOLEARN=1` for one-shot Haiku distillation of the transcript).
- **PostToolUse(Skill) hook** maintains per-skill counters in `memory/stats/skills.json`.
- Workers' `## Findings` sections record every wall hit during builds.

## The cycle: /vulyk-evolve
1. **Harvest** - `insight-harvester` clusters learnings by root cause (evidence threshold: 2+ occurrences); `skill-gardener` reviews usage counters.
2. **Diagnose** - friction patterns, retirement candidates (3+ weeks unused, severity-exempt skills excluded), promotion candidates (3+ manual repetitions).
3. **Propose** - a branch `vulyk/evolve-<date>` containing real diffs: rules added or tightened, agent prompts adjusted, new skill scaffolds, retirements moved to `_graveyard/` with `RETIRED.md`. One CHANGELOG line per change.
4. **Human gate** - you review the changeset like any PR. Nothing self-applies, everything is rollback-able, and the whole history of how your setup evolved lives in git.

## Design choices worth knowing
- **Deletion-biased.** Constitutions rot by accretion; the cycle prefers tightening and removing over adding. Smallest-fix ordering: path rule > agent prompt line > constitution change.
- **Severity beats frequency.** Rarely-fired safety skills are kept and marked, not culled.
- **Graveyard, not deletion.** Retired skills keep their history and a resurrection note.
- **Learnings are a buffer.** `/vulyk-gc` consolidates (cap 40); evolve promotes stable entries into rules or wiki notes where they stop costing per-session attention.
