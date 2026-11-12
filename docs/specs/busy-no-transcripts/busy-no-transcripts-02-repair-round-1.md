---
story: busy-no-transcripts-02
status: done
returned: DONE
worker: worker-code
model: opus
wave: 2
blocked_by: []
narrow: true
red: required
red_reason: hives-behind --busy: a registry line with no path proves nothing ('   ')
red_verified_at: 2026-11-12T22:36:57Z 2f53e092e850400cc33692137037157fda9d5f6038d0b5957dc4a8f4a8d196f8
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 1. `hives-behind.sh --busy <hive>`: a hive with no transcript folder under any root is `idle`, with a reason that says no session has run there, as long as at least one hive in the registry resolves to a transcript folder; when none does (or there is no registry), it stays `unknown` (exit 1). DRIVER, fresh-transcript and subfolder checks are unchanged. Tests cover both cases.

## Implementation notes
- `naming_proven` takes the path before the first `|`, trims both ends and skips an empty path or an empty slug; spaces-only, tab-only and ` | hold ...` lines now prove nothing (tests for all three).
- Header comment rewritten: any-depth transcripts, `<slug>-*` subfolder sessions, and the proven-idle case.
- Real registry unchanged in outcome: the two folderless hives still read idle, the judge still 0 red.

## Findings
1. scripts/hives-behind.sh:151 [ask 1] `naming_proven` must count only a registry line that names a hive path as proof: a line whose path is empty (spaces or a tab only, or ` | hold 2026-11-19 x`) gives an empty slug, `[ -d "$r/projects/" ]` is true for every root, and a folderless hive reads `idle` (exit 0) although no registered hive resolves to a transcript folder, where the ask says it stays `unknown` (exit 1) - repro: `R=$(mktemp -d); mkdir -p $R/r/projects $R/h; printf '%s\n   \n' $R/h > $R/reg; VULYK_HIVES_FILE=$R/reg VULYK_SESSION_ROOTS=$R/r bash scripts/hives-behind.sh --busy $R/h; echo $?` prints `idle no session transcript folder for ... (no Claude Code session has run there)` and `0` (the same registry without the blank-looking line prints `unknown ...` and `1`; the base 40d1f374 prints `unknown` for both); the tests need a case of this shape next to the two they have.

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix. (No owner correction behind this finding: no card.)
- [ ] A registry line with no path (spaces only, a tab only, or ` | hold ...`) proves nothing: the folderless hive stays `unknown`, exit 1; tests cover all three shapes.
- [ ] The header comment of hives-behind.sh describes the proven-idle case.

## Files
- scripts/hives-behind.sh
- tests/maintenance.test.sh

## Verification
`bash tests/maintenance.test.sh`

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 2f53e092e850400cc33692137037157fda9d5f6038d0b5957dc4a8f4a8d196f8 (tests/maintenance.test.sh)
- impl: e6c903a8956b82b268d4f0110ff0226577a2663c9044dd0ded99a8cc7e617e6c
- stamped: 2026-11-12T22:36:57Z

```
::error::hives-behind --busy: a registry line with no path proves nothing ('   ') - expected '[exit=1]' in:
  ok    ship 2a: the local-beta step ends on hives-behind.sh
  ok    ship 2a: the step skips by name without a registry
  ok    ship 2a: the dev build is never pushed
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
maintenance.test.sh: 607 checks, 3 failed
```
