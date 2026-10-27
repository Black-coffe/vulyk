---
story: post-037-tails-02
spec: post-037-tails
status: done
returned: DONE
tier: 3
worker: worker-code
model: haiku
wave: 1
blocked_by: []
---

# Telemetry: the VULYK tree reports its version from `VERSION`, not 0.0.0

## Goal
After this story `scripts/telemetry.sh`'s `vulyk_version()` returns the content of `$ROOT/VERSION` when there is no `.claude/vulyk-version` stamp but `$ROOT/install.sh` and `$ROOT/VERSION` both exist (the VULYK repository itself); every other tree without a stamp keeps `0.0.0`, and a stamp still wins. One new case in `tests/telemetry.test.sh` covers the three branches. `model: haiku`: a routine fallback branch plus one test case, under the brief's `routine stories: model: haiku`.

## Requirements
> 8. Telemetry rows in VULYK's own repo carry the version from `VERSION`, not 0.0.0.

## Files
- scripts/telemetry.sh
- tests/telemetry.test.sh

## Non-goals
- Do not read `VERSION` when `install.sh` is absent: a hive may carry its own product `VERSION`, and that is not a VULYK version.
- Do not change the bundle `check` rules, `ENUM`, `AGENTS`, the row key sets, or any other `telemetry.sh` verb.
- Do not edit `scripts/lib.sh` (story 01 edits it in this wave), `install.sh`, `docs/telemetry.md` (it does not mention `0.0.0`) or the `.claude/vulyk-version` stamp logic in `install.sh`.
- Do not add a part to `tests/telemetry.test.sh`; the case goes into the existing `telemetry` part (the `record` row contract). If the `vulyk_version` cases live in another part, put it beside them and name that part in `## Implementation notes`.

## Map slice
`memory/map/scripts.md`: `## Entry points` (`telemetry.sh` verbs), `## Key contracts` (`ENUM`/`AGENTS` append-only), `## Tests` (`telemetry` has 17 parts, `--part <topic>` / `--list-parts`, `VULYK_INSTALL_CACHE`). Contract `Telemetry version` in `docs/specs/post-037-tails/plan.md` `## Contracts`.

## Acceptance criteria
- [ ] In a temp repo with no `.claude/vulyk-version`, an `install.sh` file and a `VERSION` file holding `1.2.3`, `bash scripts/telemetry.sh record ...` writes a row whose `vulyk` is `"1.2.3"` (whitespace and a trailing newline in `VERSION` stripped).
- [ ] Same temp repo with `VERSION` but no `install.sh`: the row's `vulyk` is `"0.0.0"`.
- [ ] Same temp repo with a `.claude/vulyk-version` stamp of `9.9.9` beside `install.sh` and `VERSION`: the row's `vulyk` is `"9.9.9"`.
- [ ] The case is in `tests/telemetry.test.sh` under the `telemetry` part and fails against the 0.37 `telemetry.sh` (the first assertion reads `0.0.0`).
- [ ] `git diff --stat` touches only the two files under `## Files`.

## Verification
`bash tests/telemetry.test.sh --part telemetry`

## Implementation notes
- scripts/telemetry.sh: `vulyk_version()` reads `.claude/vulyk-version` when present (unchanged rule); else reads `$ROOT/VERSION` only when `install.sh` and `VERSION` both exist; else `0.0.0`.
- tests/telemetry.test.sh: new block `--- vulyk version` inside the `telemetry` part, after the record cases, in its own temp repo (`$T/vrepo`); three assertions (VERSION with whitespace, VERSION without install.sh, stamp wins).
- The first assertion reads `0.0.0` against the 0.37 function (it had no VERSION branch), so it is red there by construction.

## Findings
