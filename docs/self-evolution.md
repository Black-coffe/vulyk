# Self-evolution

Static configs rot. VULYK closes the loop with a weekly cycle that turns the hive's own experience into reviewed configuration changes.

## It runs itself
Nobody has to remember `/vulyk-gc`, `/vulyk-evolve` or `/vulyk-map`. The SessionStart brief computes from files and git what is due and, only then, prints `maintenance due: ...`:
- **gc** - stub learnings exist, or 10+ raw ones wait.
- **evolve** - it never ran, or ran 7+ days ago, and a council round was recorded since. An unmerged `vulyk/evolve-*` branch is "waiting for the owner's review" instead.
- **map** - the post-merge flag `memory/map/.stale` exists.

The Queen runs each due command through the Skill tool after the owner's current task, on the default branch with a clean tree, and tells the owner in one line what changed. Anywhere else it stays due for a later session. A quiet hive pays nothing: no line.

## Signal collection
- **Learnings** in `memory/learnings/`, written by a session or the owner when something was worth remembering. (The `SessionEnd` hook that wrote a stub per session was removed in 0.18.0: its stubs were empty.)
- **PostToolUse(Skill) hook** maintains per-skill counters in `memory/stats/skills.json`.
- **The ledgers** under `memory/stats/`: council rounds, scope breaches, anomalies (`SessionEnd` scan), and evolve's own hypothesis ledger.
- **Token spend**, read from the transcripts by `scripts/token-report.py` when evolve runs.
- `## Findings` sections in story files record every wall hit during builds.

## The cycle: /vulyk-evolve
0. **Ledger** - `scripts/evolve-ledger.py resolve` records the owner's verdict on earlier changesets from git (merged = accepted, deleted unmerged = rejected); `window` shows the last 40 proposals plus every older rejection as one line. A rejected hypothesis returns only with newer evidence. The ledger grows with proposals, not sessions, and evolve reads a bounded window of it.
1. **Harvest** - `insight-harvester` clusters learnings by root cause (evidence threshold: 2+ occurrences); `skill-gardener` reviews usage counters; `python scripts/token-report.py . --since <7 days ago>` prints the week's spend per spec (raw and weighted tokens, dispatches by agent type, rounds). That report is the spend: the `totalTokens` a Workflow run prints is the sum of final contexts and never counts. The council, human-check and anomaly numbers for the same week are read beside it, each with its n; a weekly count proves no trend.
2. **Diagnose** - friction patterns, retirement candidates (3+ weeks unused, severity-exempt skills excluded), promotion candidates (3+ manual repetitions).
3. **Judge** - a change is admitted only if always-loaded text grows against owner-signed evidence (a verbatim quote in a defect class code cannot check, or an accepted ADR), a change with no measurable effect cuts bytes, and it answers the critic questions (a safeguard removed without replacement, a loop without an exit, a rule drawn from one spec).
4. **Propose** - in its own worktree on `vulyk/evolve-<date>`, one commit and one CHANGELOG line per change, never in the owner's tree; each change is a ledger row.
5. **Human gate** - you review the changeset like any PR and merge it (not squash) to accept, or delete the branch to reject. Nothing self-applies, everything is rollback-able, and the whole history of how your setup evolved lives in git.

## Design choices worth knowing
- **Deletion-biased.** Constitutions rot by accretion; the cycle prefers tightening and removing over adding. Smallest-fix ordering: path rule > agent prompt line > constitution change. The constitution rides every agent that loads it, so a line there costs on every turn of every such agent - and `tests/maintenance.test.sh` holds it to ADR-013's cap.
- **Knowledge moves down, not up.** Learning -> path rule -> `check:` in code. The always-loaded layer is never where a lesson ends up if it can be scoped to a path or checked by code.
- **Severity beats frequency.** Rarely-fired safety skills are kept and marked, not culled.
- **Graveyard, not deletion.** Retired skills keep their history and a resurrection note.
- **Learnings are a buffer.** `/vulyk-gc` consolidates (cap 40); evolve promotes stable entries into rules or wiki notes where they stop costing per-session attention.

## Sunset
If evolve's last run is 28+ days old while council rounds keep landing, the brief marks it overdue and the Queen asks the owner once whether to retire it. A loop that does not run is retired to the graveyard, not extended (Law 2).
