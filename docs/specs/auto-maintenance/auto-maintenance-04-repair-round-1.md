---
story: auto-maintenance-04
status: todo
returned:
worker: worker-code
model: opus
wave: 4
blocked_by: []
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 5. gc, evolve and map refresh run themselves; neither the owner nor another user needs to know these commands.

## Findings
1. .claude/commands/vulyk-evolve.md:60 and :68 [ask 5] evolve's telemetry-inbox deletions must reach the default branch only through the owner's merge of the evolve branch, but now `telemetry.sh inbox --clear` stages `git rm` in the owner's tree (scripts/telemetry.sh:896, `git -C "$ROOT" rm`), the changeset is built in a separate worktree, and step 5's `git add memory/stats/evolve.jsonl && git commit -m "chore(evolve): ledger <date>"` commits the whole index, so the inbox bundles are deleted on main directly while their distillate lives only in the branch's CHANGELOG (lost if the owner rejects by deleting the branch) - repro: `grep -n "inbox --clear\|chore(evolve): ledger" .claude/commands/vulyk-evolve.md` and `ls telemetry/inbox` (the directory exists in this repo, so the paragraph applies here)

## Files
- CLAUDE.md
- tests/maintenance.test.sh
- .claude/hooks/session-start-brief.sh
- .claude/commands/vulyk-gc.md
- .claude/agents/librarian.md
- docs/hooks-reference.md
- README.md
- memory/learnings/*
- memory/memory.md
- scripts/evolve-ledger.py
- .claude/commands/vulyk-evolve.md
- docs/self-evolution.md
- install.sh
- tests/telemetry.test.sh

## Verification
`bash tests/maintenance.test.sh`
`bash tests/telemetry.test.sh`
`bash tests/solo.test.sh`
