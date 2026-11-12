---
story: busy-no-transcripts-01
spec: busy-no-transcripts
status: done
returned: DONE
tier: 1
worker: worker-code
wave: 1
blocked_by: []
red: required           # a new branch in the busy guard that decides whether a hive gets written into
red_reason: hives-behind --busy: no folder, a registry hive resolves - idle
red_verified_at: 2026-11-12T21:37:59Z 008b66d1ffc50b4c4d1dd2ac03aa231bc993d55747777967d2def17f645fa554
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
- `naming_proven` reads the registry and the same roots as `--busy`; one registered hive with its exact transcript folder proves the rule. The judged hive's own folder would have taken the old path first.
- The first `idle` needle also matched the old `unknown ... cannot tell it is idle` line; tightened to `idle no session transcript folder` before the receipt.
- Real probes: the two folderless registered hives now read idle with the new reason; a hive with transcripts reads plain `idle`.

## Findings

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 008b66d1ffc50b4c4d1dd2ac03aa231bc993d55747777967d2def17f645fa554 (tests/maintenance.test.sh)
- impl: c18ee412956b998713428efdbfb4b6b3ed963b9a5e544c6ece35b3df65aa3db3
- stamped: 2026-11-12T21:37:59Z

```
::error::hives-behind --busy: no folder, a registry hive resolves - idle - expected 'idle no session transcript folder' in:
  ok    ship 2a: the local-beta step ends on hives-behind.sh
  ok    ship 2a: the step skips by name without a registry
  ok    ship 2a: the dev build is never pushed
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
maintenance.test.sh: 604 checks, 3 failed
```
