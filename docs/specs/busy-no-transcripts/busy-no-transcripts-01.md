---
story: busy-no-transcripts-01
spec: busy-no-transcripts
status: todo
returned:
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required           # a new branch in the busy guard that decides whether a hive gets written into
red_reason:
---

# No transcript folder is idle once the naming rule is proven

## Goal
`hives-behind.sh --busy <hive>` prints `idle no session transcript folder ...` (exit 0) for a hive with no
transcript folder under any root, when at least one registered hive resolves to an exact `<root>/projects/<slug>/`
folder. With no registry, or no registered hive resolving, it keeps `unknown ...` (exit 1).

## Files
- scripts/hives-behind.sh
- tests/maintenance.test.sh
- CHANGELOG.md

## Non-goals
- No change to the DRIVER, fresh-transcript, subfolder `cwd` or root rules.
- No change to `/vulyk-ship` text: step 2a already upgrades on `idle`.
- No map or ADR edit (the ship's docs pass).

## Map slice
`memory/map/scripts.md` (`hives-behind.sh`)

## Acceptance criteria
- [ ] Registry lists the judged hive (no folder) and another hive whose folder exists: `idle`, exit 0, the line says no session has run there.
- [ ] Registry lists only hives with no folder: `unknown`, exit 1.
- [ ] No registry: `unknown`, exit 1 (the existing check stays green).
- [ ] A fresh transcript or a DRIVER still makes the hive busy whatever the registry says.
- [ ] CHANGELOG `[Unreleased]` names the change.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
