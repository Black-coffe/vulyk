---
story: audit-fixes-1113-01
spec: audit-fixes-1113
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a release is newer than its dev builds
red_verified_at: 2026-11-13T16:44:09Z 51fc756ebca4ee1f7ab98f842cd0460bf8008f2b83fa16510239cd3a053c6750
---

# One version comparison for the update check and vulyk-update.sh

## Goal
A new sourced file, `scripts/version-order.sh`, holds the one comparison of VULYK versions (plan.md `## Contracts`
V1): a release `X.Y.Z` is newer than every `X.Y.Z-dev.N`, `dev.10` is newer than `dev.3`, and numeric fields
compare as numbers. `.claude/hooks/vulyk-update-check.sh` uses it both to pick the newest tag and to compare that
tag with the installed version. `scripts/vulyk-update.sh` uses it to pick its target and refuses a target that is
not newer than the installed version. Marked red: a parser and a refusal branch on the update path.

## Requirements
> 1. Version order: a release `X.Y.Z` is newer than any `X.Y.Z-dev.N`, and `dev.10` is newer than `dev.3`. The update-check hook and `vulyk-update.sh` use one shared comparison, and `vulyk-update.sh` refuses a target that is not newer than the installed version.

## Files
- scripts/version-order.sh
- .claude/hooks/vulyk-update-check.sh
- scripts/vulyk-update.sh
- tests/telemetry.test.sh

## Non-goals
- Do not filter dev tags out of the tag list, and do not change the cache file, the check interval or the fetch
  options: only the order and the refusal change.
- Do not touch `install.sh` (story 06 owns it in wave 2).
- Do not add the subagent exit to the hook: story 05 does that for every SessionStart hook in wave 2.
- Do not edit `tests/telemetry.test.sh` outside the `install-xp` part.
- No `sort -V`, no bash 4 syntax: the file is sourced by a hook on bash 3.2 and BSD userland.

## Map slice
`memory/map/scripts-hooks.md` → Entry points (`vulyk-update-check.sh`); `memory/map/scripts-install.md` → Entry
points, Gotchas; `memory/map/scripts.md` → Gotchas (bash 3.2 / BSD).

## Acceptance criteria
- [ ] `version_newer 0.52.0 0.52.0-dev.3` exits 0 and the reverse exits 1; `0.52.0-dev.10` is newer than
  `0.52.0-dev.3`; `0.52.0-dev.3` is newer than `0.51.9` and `0.50.3`; equal versions are not newer; a leading `v`
  is accepted on either side. The failing label of the first case contains `a release is newer than its dev builds`.
- [ ] `version_newest` fed `v0.50.3`, `v0.52.0-dev.3`, `v0.52.0`, `v0.52.0-dev.10` prints `v0.52.0`.
- [ ] The update check, installed `0.52.0-dev.3`, tags `v0.52.0-dev.3` and `v0.52.0`: its line names `v0.52.0` as
  the latest. Installed `0.52.0` with the same tags: silent. The existing case "silent for a version ahead of the
  tags" still passes.
- [ ] `vulyk-update.sh`, installed `0.52.0`, newest tag `v0.52.0-dev.3` or `v0.50.3`: one line `update: v<target>
  is not newer than the installed v<installed>`, exit 1, no file of the hive written; `--check` prints the same
  line. An equal version keeps today's up-to-date line and exit code.
- [ ] Both scripts source `scripts/version-order.sh`; neither keeps a second ordering of its own.
- [ ] `bash scripts/portability-check.sh scripts/version-order.sh scripts/vulyk-update.sh
  .claude/hooks/vulyk-update-check.sh` is clean.

## Verification
`bash tests/telemetry.test.sh --part install-xp`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line. -->
- `scripts/version-order.sh` (new): `version_newer`, `version_newest`; key "X Y Z R N" (R=1 release, 0 pre-release; N the number after the pre-release's last dot), built with parameter expansion, no subshell per comparison.
- `.claude/hooks/vulyk-update-check.sh`: `vsort` gone; sources the file from its own tree (`../../scripts/`), a missing copy exits 0 (fails open); `version_newest` picks the tag, `version_newer "$LATEST" "$INSTALLED"` decides.
- `scripts/vulyk-update.sh`: sources the file beside it (missing: one error line, exit 1); `git tag --sort=v:refname` replaced by `version_newest`; a target older than the installed version is refused before checkout, pinned `--version` included; equal passes as before; an unstamped hive (`none`) is not compared.
- `tests/telemetry.test.sh` (install-xp): order cases, the hook's dev/release cases, the refusal (default, `--check`, pinned), equal not refused, both scripts source the file.
CHANGELOG: the update check and `vulyk-update.sh` share one version order (a release is newer than its dev builds, dev.10 after dev.3); `vulyk-update.sh` refuses a target older than the installed version.

## Findings

## Red receipt
- command: bash tests/telemetry.test.sh --part install-xp
- exit: 1
- tests: 51fc756ebca4ee1f7ab98f842cd0460bf8008f2b83fa16510239cd3a053c6750 (tests/telemetry.test.sh)
- impl: b274a2340c3344fe2bfa28b682f29993320712d672c641ce2221492c737c6044
- stamped: 2026-11-13T16:44:09Z

```
::error::version_newer: a release is newer than its dev builds - expected [0], got [1]
  ok    install.sh --upgrade keeps the hive's ## Commands block (old python cell included) byte-identical
  ok    a hive with no model pin gets it on --upgrade, as before
  ok    ... and the log says so
  ok    three bad manifest lines: three skip (bad path) lines
  ok    ... skip (bad path) names the dot-dot line
  ok    ... skip (bad path): every named file still present
  ok    ... and a normal retired path is still removed
  ok    an owner's model pin survives --upgrade
  ok    ... and the log says it is kept
telemetry.test.sh: 78 checks, 16 failed
```
