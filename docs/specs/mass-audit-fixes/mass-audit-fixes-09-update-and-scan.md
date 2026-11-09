---
story: mass-audit-fixes-09
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 2
blocked_by: [mass-audit-fixes-04]
red: required
red_reason: cache remote differs
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

## Findings
