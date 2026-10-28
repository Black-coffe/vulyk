---
story: memory-triage-offer-01-ask-first
spec: memory-triage-offer
status: done
returned: DONE
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: ::error::memory triage is offered on its own line, not in maintenance due
red_verified_at: 2026-10-28T17:09:02Z 8204398ad7fe6cf653d01db1541e22570546a71aa79b291e777a95e0d689e70a
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
- [x] A hive with only a large `MEMORY.md` prints no `maintenance due` line and does print the ask-once line with the size.
- [x] Every 0.41.0 threshold and mark case still holds.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes
- `memline` replaces the `due` call and prints after the `maintenance due` line; threshold and mark logic untouched. The size text is kept, so the 0.41.0 tests and the map stay true. 3 new checks: no `maintenance due`, the ask-once wording, the `--mark` on a no.
- Docs: `docs/memory-system.md` signal bullet, `/vulyk-gc` memory-mode intro.

## Findings

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 8204398ad7fe6cf653d01db1541e22570546a71aa79b291e777a95e0d689e70a (tests/maintenance.test.sh)
- impl: 33fb34f4b67ac52cb7984d5d209658997a0db5946d2ab5bab927628fc8a70b3e
- stamped: 2026-10-28T17:09:02Z

```
  ok    memory-triage: a file without frontmatter lists with type -
  ok    memory-triage: MEMORY.md is not a row
  ok    memory-triage: exactly two rows
  ok    memory-triage: an absent dir says so
  ok    memory-triage: an absent dir exits 0
  ok    memory-triage --index-lines: names the moved file's line
  ok    memory-triage --index-lines: takes a bare file name
  ok    memory-triage --index-lines: leaves other lines out
  ok    memory-triage: writes nothing
maintenance.test.sh: 173 checks, 3 failed
```
