---
story: auto-maintenance-04
status: done
returned: DONE
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

## Implementation notes
- Major 1: step 2 now distils only; the clear moved into step 5, run inside the evolve worktree (`VULYK_HIVE=<worktree> bash scripts/telemetry.sh inbox --clear`) and committed there with the table's CHANGELOG line, so bundles leave the default branch only through the owner's merge. The ledger commit takes a pathspec (`-- memory/stats/evolve.jsonl`) and so does gc's commit, so nothing else staged rides along. New case (b2) in `tests/telemetry.test.sh`: the worktree gets the three staged deletions, the owner's tree and index stay clean.
- Minor, skills.json: the brief's "clean tree" now says `memory/stats/skills.json` aside - the Skill counter rewrites it on every Skill call, so the first due run would otherwise block the second.
- Minor, contract: plan.md says `last` prints the newest run ts (what the code and the brief use).
- Minor, dry-run: `--dry-run` writes no proposal or run row; step 0's verdict rows are git facts and stay.
- Minor, "step 4's CHANGELOG" -> step 5.
- Minor, ask 4 (A8): not descoped - the real evolve run happens right after the merge in this session, on the merged procedure; running it on this branch would build its worktree from a main that lacks the new command.

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
