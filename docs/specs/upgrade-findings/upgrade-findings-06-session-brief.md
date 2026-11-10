---
story: upgrade-findings-06
spec: upgrade-findings
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 3
blocked_by: [upgrade-findings-04]
red: required
red_reason: a cache older than 6 hours is refetched
red_verified_at: 2026-11-10T22:15:51Z cc1561f630fd0eb4f5c076a200ab0af224f2aac1f534696910e02b190b9796fe
---

# The session-start lines tell the truth: a 6-hour update check with its time, the litopys offer at three scopes

## Goal
**D1.** `.claude/hooks/vulyk-update-check.sh` asks the origin at most once per `VULYK_UPDATE_INTERVAL_HOURS`,
default 6 (was 24). Its cache line becomes `<epoch> <latest> <YYYY-MM-DDTHH:MMZ>` (plan.md `## Contracts` D1);
a cache without the third field counts as expired. The `update available` line keeps `installed v<X>, latest
v<Y>` and adds `(checked <YYYY-MM-DD HH:MM> UTC)`, the time of the fetch the answer came from. A test pins
that `scripts/vulyk-update.sh --check` fetches tags from the origin and never reads the hook's cache;
`vulyk-update.sh` is edited only if that test is red. `docs/hooks-reference.md` and the `README.md` hooks
table say 6 hours and the checked-at time. **D2.** `tests/maintenance.test.sh` runs the SessionStart brief
with litopys enabled at each scope in turn (user settings, project `settings.json`, project
`settings.local.json`) and with none; `.claude/hooks/session-start-brief.sh` is edited only for a scope whose
case is red. The test block's header comment states the finding in one sentence: which scopes are quiet on
0.50.x, and that a brief from a hook older than 0.49 read the project files only.

## Requirements
> 10. D1: the update-check cache lives 6 hours by default instead of 24, the `update available` line says when the latest version was checked, and `vulyk-update.sh --check` asks GitHub fresh before an upgrade.
> 11. D2: the litopys offer is reproduced with litopys enabled at each scope (user, project, local) or shown not reproducible on 0.50.x with how; every scope where the plugin is enabled silences the offer.

## Files
- .claude/hooks/vulyk-update-check.sh
- .claude/hooks/session-start-brief.sh
- scripts/vulyk-update.sh
- tests/telemetry.test.sh
- tests/maintenance.test.sh
- docs/hooks-reference.md
- README.md

## Non-goals
- Do not make the hook upgrade, fetch with git, or print when the origin is not ahead; its silences (no
  stamp, no `curl`, network failure, rate limit, running ahead) stay.
- Do not print a stale answer when a refetch fails: silent, as today.
- Do not add a litopys detection for a scope that is not user, project or local (no marketplace-cache probe),
  and do not change the offer's wording or the `Chronicle` row rule.
- Do not touch `install.sh`, the other brief lines (maintenance due, memory triage, tool.check mod) or the
  cache-origin check in `vulyk-update.sh`.
- `README.md`: the one `vulyk-update-check.sh` row only.
- Do not edit `tests/telemetry.test.sh` outside part `install-xp`. Tests use a fake `HOME` /
  `CLAUDE_CONFIG_DIR` and a stub `curl`; no real network, no real user settings.

## Map slice
`memory/map/scripts.md` → Entry points (`session-start-brief.sh`, `vulyk-update.sh`), Gotchas (no `date -d`,
no `sort -V`); `docs/hooks-reference.md` → rows `session-start-brief.sh`, `vulyk-update-check.sh`.

## Acceptance criteria
- [ ] `--part install-xp`: with a three-field cache 7 hours old naming an older tag and a stub origin
  answering a newer one, the hook refetches and names the newer tag; the failing label contains `a cache older
  than 6 hours is refetched`. A cache 5 hours old is used with no fetch (the stub counts calls).
- [ ] `--part install-xp`: the printed line contains `installed v<X>, latest v<Y>` and `(checked ` followed
  by the cache's own timestamp, also when the answer came from the cache; a two-field cache is refetched and
  rewritten with three fields; `VULYK_UPDATE_INTERVAL_HOURS=24` restores the old window.
- [ ] `--part install-xp`: `vulyk-update.sh --check` in a hive whose hook cache names an old tag reports the
  origin's newest tag.
- [ ] `tests/maintenance.test.sh`: four cases (user, project, local, none): the first three print no litopys
  line, the fourth prints the offer; the header comment carries the finding. If all four were green before
  any hook edit, `## Implementation notes` says "not reproducible on 0.50.x" and how it was run.
- [ ] `docs/hooks-reference.md` and the `README.md` row say 6 hours and name the checked-at time; no "once a
  day" is left for this hook.
- [ ] `bash scripts/portability-check.sh .claude/hooks/vulyk-update-check.sh .claude/hooks/session-start-brief.sh
  scripts/vulyk-update.sh` is clean (the timestamp is written with `date -u +...` at fetch time, never
  converted back from the epoch).

## Verification
`bash tests/telemetry.test.sh --part install-xp`
`bash tests/maintenance.test.sh`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->
- `.claude/hooks/vulyk-update-check.sh`: default 6 h; cache `<epoch> <latest> <YYYY-MM-DDTHH:MMZ>` (time from `date -u` at fetch); a line without a valid third field is expired; the update line ends `(checked YYYY-MM-DD HH:MM UTC)`.
- Decision: a failed refetch prints nothing this session and rewrites the cache with the last known tag and its own fetch time (an undated old answer is dropped to the installed version), so a later line never dates a stale answer as fresh.
- `scripts/vulyk-update.sh`: not edited; the new install-xp test (hook cache naming v9.2.0, origin at v9.11.0) was green before any change.
- `tests/telemetry.test.sh` (install-xp only): 7 h / 5 h / two-field / 24 h-window cases with a call-counting stub curl, plus the --check-ignores-cache case.
- D2 not reproducible on 0.50.x: `tests/maintenance.test.sh` run with litopys enabled in fake-HOME user settings, project settings.json, project settings.local.json and none; all four green before any hook edit, so `session-start-brief.sh` is unchanged.
- Docs: `docs/hooks-reference.md` row and the one `README.md` hooks row say 6 hours and the checked-at time.

## Findings

## Red receipt
- command: bash tests/telemetry.test.sh --part install-xp
- exit: 1
- tests: cc1561f630fd0eb4f5c076a200ab0af224f2aac1f534696910e02b190b9796fe (tests/maintenance.test.sh, tests/telemetry.test.sh)
- impl: 62b9d64ba49fcab76f3f6da14f71a5aedf991c7119e370eddc1018b9135cdf0b
- stamped: 2026-11-10T22:15:51Z

```
::error::a cache older than 6 hours is refetched: the newer tag is named - expected 'installed v0.9.0, latest v0.11.0' in:
  ok    install.sh --upgrade keeps the hive's ## Commands block (old python cell included) byte-identical
  ok    a hive with no model pin gets it on --upgrade, as before
  ok    ... and the log says so
  ok    three bad manifest lines: three skip (bad path) lines
  ok    ... skip (bad path) names the dot-dot line
  ok    ... skip (bad path): every named file still present
  ok    ... and a normal retired path is still removed
  ok    an owner's model pin survives --upgrade
  ok    ... and the log says it is kept
telemetry.test.sh: 58 checks, 7 failed
```
