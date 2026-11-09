---
story: mass-audit-fixes-09
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 2
blocked_by: [mass-audit-fixes-04]
red: required
red_reason: cache remote differs
red_verified_at: 2026-11-09T13:42:37Z ca183da6a04742f12f13483c1d3075457a3b59e770d298ace48327b7e74b6b07
---

# The update path survives a moved tag and a foreign cache; the SessionEnd scan stops rescanning every journal

## Goal
`scripts/vulyk-update.sh` fetches tags with `--force --prune-tags` and prints one error line when the fetch
fails instead of dying silently under `set -e` (P3); before reusing the shared source cache it compares the
cache's `origin` URL with the declared origin (`.git` normalised) and refuses with a clear line when they
differ (S2-shell). `.claude/hooks/vulyk-update-check.sh` picks the newest tag with `git tag --sort=v:refname`
(or `tail -1` of a sorted list), never `sort -V` (ask 4, the rest of P9-10). `scripts/telemetry.sh`'s SessionEnd
scan runs `detect_stage` as one awk over all `docs/specs/*/journal.md` keyed by `FILENAME` and batches the
per-subagent `wc -c` calls into one (O4). Asks 4 and 11. Marked red: a refusal branch on the update path.

## Requirements
> 4. P9-10 extended: the SessionStart update check picks the newest tag without `sort -V`.
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- scripts/vulyk-update.sh
- .claude/hooks/vulyk-update-check.sh
- scripts/telemetry.sh
- tests/telemetry.test.sh

## Non-goals
- Do not change `install.sh` (stories 04 and 11 own it).
- Do not key the cache directory by repository; the remote check is the chosen fix (the owner may ask for the
  keyed cache later).
- Do not change what the scan detects or the anomaly codes; only how many processes it forks.
- Do not edit `tests/telemetry.test.sh` outside the `install-xp` and `scan` parts.

## Map slice
`memory/map/scripts.md` → Entry points (`vulyk-update.sh`, `telemetry.sh`, `session-start-brief.sh`),
Gotchas (bash 3.2 / BSD: no `sort -V`, no `date -d`).

## Acceptance criteria
- [ ] `--part install-xp`: with a local origin whose tag moved, `vulyk-update.sh --check` fetches and reports
  the new tag; with a fetch that fails it prints `update: fetch failed: <why>` and exits 1 (not a silent stop).
- [ ] `--part install-xp`: a cache whose `origin` is another repository is refused with a line naming both
  URLs (label contains `cache remote differs`); the matching URL with or without `.git` passes.
- [ ] `--part install-xp`: `vulyk-update-check.sh` names `v0.10.0` newer than `v0.9.0` with a `sort` stub that
  rejects `-V`.
- [ ] `--part scan`: the scan output on the fixture transcript is byte-identical before and after; the
  journal-stage detector forks once for N journals (counting `awk` stub).
- [ ] `bash scripts/portability-check.sh scripts/vulyk-update.sh .claude/hooks/vulyk-update-check.sh
  scripts/telemetry.sh` is clean.

## Verification
`bash tests/telemetry.test.sh --part install-xp && bash tests/telemetry.test.sh --part scan`

## Implementation notes
- scripts/vulyk-update.sh: VULYK_REPO may now be a URL or a local path (owner/name still means GitHub); `canon` drops `/` and `.git` and names a local repo by `git rev-parse --absolute-git-dir`, so Git for Windows' `C:/...` spelling equals the MSYS `/tmp/...` one.
- scripts/vulyk-update.sh: the cache is refused on a differing origin (`update: cache remote differs: cache origin A != declared origin B`); fetch is `--tags --force --prune --prune-tags` (`--prune-tags` acts only with `--prune`); a failing fetch or clone prints `update: fetch failed: <first stderr line>` and exits 1.
- .claude/hooks/vulyk-update-check.sh: `vsort` = `sort -t. -k1,1n -k2,2n -k3,3n` for both the newest-tag pick and the installed-vs-latest compare (its tags come from curl, so `git tag --sort` does not apply).
- scripts/telemetry.sh: detect_stage runs one awk over every journal (FNR==1 resets n/prev, spec from FILENAME); detect_agents takes every size from one `find -exec wc -c {} +`; the unused `file_bytes` helper is removed.
- tests/telemetry.test.sh install-xp: the existing update cases now declare the cache's origin (VULYK_REPO=$XREL) and put the tags on the origin, since the fetch now prunes cache-only tags; fetch failure is staged with `remote.origin.uploadpack false`.
- tests/telemetry.test.sh scan: the golden rows were captured from the pre-change code (ts and vulyk dropped); the shims count awk starts handed journal.md and every wc start.

## Findings

## Red receipt
- command: bash tests/telemetry.test.sh --part install-xp && bash tests/telemetry.test.sh --part scan
- exit: 1
- tests: ca183da6a04742f12f13483c1d3075457a3b59e770d298ace48327b7e74b6b07 (tests/telemetry.test.sh)
- impl: 8c8ea2e72a20da104f92c6e2f494a2ff0298fe31cca101ece5b07671c2600d15
- stamped: 2026-11-09T13:42:37Z

```
::error::a cache whose origin is another repository: exit 1 (cache remote differs) - expected [1], got [0]
::error::... refused with the label cache remote differs - expected 'update: cache remote differs:' in:
        fatal: Could not read from remote repository.
        
        Please make sure you have the correct access rights
        and the repository exists.
::error::vulyk-update-check.sh names v0.10.0 newer than v0.9.0, with no sort -V - expected 'installed v0.9.0, latest v0.10.0' in:
        
  ok    ... and stays silent for a version ahead of the tags
  ok    the hive's block holds the old python cell
  ok    install.sh --upgrade keeps the hive's ## Commands block (old python cell included) byte-identical
telemetry.test.sh: 37 checks, 12 failed
```
