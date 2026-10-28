---
story: memory-triage-offer-01-ask-first
spec: memory-triage-offer
status: todo
returned:
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: ::error::memory triage is offered on its own line, not in maintenance due
---

# Memory triage: ask first

## Goal
At the threshold, `session-start-brief.sh` no longer calls `due` for the memory triage. It prints its own line:
`[VULYK] memory triage (MEMORY.md <n> lines, <k> KB of 200 lines / 25 KB) - Claude Code's own auto memory. After
the owner's current task, ask them once whether to run /vulyk-gc memory now (Skill tool; it reads every private
memory file). On a no, run bash scripts/memory-triage.sh --mark, which keeps the signal quiet until the index grows.`
The threshold and the mark logic are unchanged. `docs/memory-system.md` and `/vulyk-gc` say that the triage is
offered, not run.

## Files
- .claude/hooks/session-start-brief.sh
- tests/maintenance.test.sh
- docs/memory-system.md
- .claude/commands/vulyk-gc.md

## Non-goals
- No change to gc/evolve/map maintenance or to the thresholds.

## Acceptance criteria
- [ ] A hive with only a large `MEMORY.md` prints no `maintenance due` line and does print the ask-once line with the size.
- [ ] Every 0.41.0 threshold and mark case still holds.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
