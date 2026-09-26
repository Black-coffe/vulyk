# Self-evolution

Static configs rot. VULYK closes the loop with a weekly cycle that turns the hive's own experience into reviewed configuration changes.

## Signal collection
- **Learnings** in `memory/learnings/`, written by a session or the owner when something was worth remembering. (The `SessionEnd` hook that wrote a stub per session was removed in 0.18.0: its stubs were empty.)
- **PostToolUse(Skill) hook** maintains per-skill counters in `memory/stats/skills.json`.
- **The ledgers** under `memory/stats/`: council rounds, scope breaches, anomalies (`SessionEnd` scan).
- **Token spend**, read from the transcripts by `scripts/token-report.py` when evolve runs.
- `## Findings` sections in story files record every wall hit during builds.

## The cycle: /vulyk-evolve
1. **Harvest** - `insight-harvester` clusters learnings by root cause (evidence threshold: 2+ occurrences); `skill-gardener` reviews usage counters; `python scripts/token-report.py . --since <7 days ago>` prints the week's spend per spec (raw and weighted tokens, dispatches by agent type, rounds). That report is the spend: the `totalTokens` a Workflow run prints is the sum of final contexts and never counts. A spec whose dispatches or rounds stand out is evidence for the friction list. The council, human-check and anomaly numbers for the same week are read beside it.
2. **Diagnose** - friction patterns, retirement candidates (3+ weeks unused, severity-exempt skills excluded), promotion candidates (3+ manual repetitions).
3. **Propose** - a branch `vulyk/evolve-<date>` containing real diffs: rules added or tightened, agent prompts adjusted, new skill scaffolds, retirements moved to `_graveyard/` with `RETIRED.md`. One CHANGELOG line per change.
4. **Human gate** - you review the changeset like any PR. Nothing self-applies, everything is rollback-able, and the whole history of how your setup evolved lives in git.

## Design choices worth knowing
- **Deletion-biased.** Constitutions rot by accretion; the cycle prefers tightening and removing over adding. Smallest-fix ordering: path rule > agent prompt line > constitution change. The constitution rides every agent that loads it, so a line there costs on every turn of every such agent.
- **Severity beats frequency.** Rarely-fired safety skills are kept and marked, not culled.
- **Graveyard, not deletion.** Retired skills keep their history and a resurrection note.
- **Learnings are a buffer.** `/vulyk-gc` consolidates (cap 40); evolve promotes stable entries into rules or wiki notes where they stop costing per-session attention.
