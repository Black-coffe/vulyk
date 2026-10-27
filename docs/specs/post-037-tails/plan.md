# Post-0.37 tails: the ship gate, telemetry version, symbol-map leftovers, the publish step (plan)

**Tier:** 3 · **Spec slug:** `post-037-tails` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-015 (Sonnet executes, Opus judges), ADR-020 (model profiles; `routine stories: model: haiku`), Law 6 (a check that only warns is not a check), `docs/specs/symbol-map/plan.md` `## Rejected (next circle)` (no close-time gate, no git co-change, no JS/TS/PHP edges, no tree-sitter/ctags/LSP, no on-disk cache), `tests/maintenance.test.sh` caps (`CONSTITUTION_MAX_BYTES` 7168, `DESCRIPTIONS_MAX_BYTES` 4983), the public-repo rule (no host names in committed files)
**Depends on:** 0.37.0 (`scripts/symbol-map.py` + `.sh`, `tests/symbol-map.test.sh`, fixtures under `tests/fixtures/symbol-map/`; `scripts/ship-check.sh` council branch; `scripts/telemetry.sh` `vulyk_version()`); council reviews `docs/specs/symbol-map/council/round-1/review.md` and `round-2/review.md`

## Goal
Close the four tails left after 0.37.0 in one Tier 3 pass. (1) `scripts/ship-check.sh` stops printing READY when the owner's `**Checked:** ACCEPTED` is newer than a GREEN council row but code moved after it: stage 05 applies the one pack/commit staleness rule that `human-check.sh --check` and the no-council branch already apply, through a shared `scripts/lib.sh` function, with a failing test for the 0.37 case. (2) `scripts/telemetry.sh` takes the version from `VERSION` when there is no `.claude/vulyk-version` stamp but `install.sh` and `VERSION` sit side by side (the VULYK tree itself); every other tree keeps `0.0.0`. (3) `scripts/symbol-map.py` gets the leftovers: a `.py` run from a bash script is an `exact` link, `tests/fixtures/**` never appears, path mentions rank code, ADR and tests before the three root `.md` files, missing inputs survive the byte cap, `replay.py` no longer passes its arguments through MSYS bash, the bash-input run is profiled and the cheap fixes made with before/after figures written down, and a `--exact` flag prints the planner hand-off: `exact` lines plus a count of the `textual` rest per section. (4) The prose: `/vulyk-plan` recon runs `--exact` per file and hands that to the planner, the planner's `## Files` bullet reads it that way, `/vulyk-ship`'s publish step orders push, green CI on the release commit, then the tag; the script gets its one-line doc and the 163-char line is rewrapped. `VERSION` and `CHANGELOG.md` are release paperwork at ship; no story writes them.

## Assumptions
- The staleness rule is one `scripts/lib.sh` function (`verdict_stale`, `## Contracts`) that `ship-check.sh` (both branches) and `human-check.sh --check` call; today each has its own copy. Semantics unchanged: a `REJECTED` row stays a refusal; a paperwork-only range after ACCEPTED (`paperwork_only`) stays current, so the release-paperwork commit `/vulyk-ship` makes does not stale the gate. The failing test is the check Law 6 asks for; no `docs/defects/` card, because the correction came from the Queen's own recon, not an owner line.
- Ask 8's condition is literal: no stamp **and** `$ROOT/install.sh` **and** `$ROOT/VERSION` both present. A hive with its own product `VERSION` and no `install.sh` keeps `0.0.0`. `docs/telemetry.md` does not mention `0.0.0` (read at plan time), so it is not touched. The new case goes into `tests/telemetry.test.sh`'s `telemetry` part, where the `record` row contract lives; if the worker finds the `vulyk_version` cases in another part, it says so in `## Implementation notes` and the Queen adjusts `## Verification` before dispatch.
- Ask 6 is a script flag, not a Queen-side trim: `--exact` (`## Contracts`). A hand-off trimmed by the Queen each plan is model work on every plan and the first thing to drift. Story 04 therefore sits in wave 2 behind story 03.
- `tests/fixtures/**` exclusion: a tracked path with a `fixtures` segment that comes after a `tests` or `test` segment is never listed in any section. The "every path under `tests/` counts as a test" minor is answered by that exclusion (the only live case was `tests/fixtures/symbol-map/bash/scripts/run.sh`); a runner such as `tests/full-suite.sh` listed under `tests:` is acceptable and stays.
- Missing inputs past the cap: a `## <path>` / `  ! missing` block is printed before every other block, so it can never fall past the 1536-byte cap. The "blocks in input order" line of the 0.37 contract is narrowed to the non-missing inputs.
- `replay.py` MSYS glob: fixed by running `scripts/symbol-map.py` through `sys.executable` instead of the bash wrapper, so no MSYS process sees the argument list. One line; folded into story 03 rather than dropped. Nothing in CI (Linux) can prove it; the worker records the local before/after `lines printed` on the three glob cases in `## Implementation notes` only if `.vulyk/symbol-map-replay/cases.json` is still on disk, otherwise notes "not re-run".
- Speed (answer 3): the worker profiles with `python -m cProfile -s cumtime scripts/symbol-map.py scripts/lib.sh`, makes only the fixes the profile shows (a read or a parse done more than once per run, a regex compiled per file, a `git ls-files` run more than once), no on-disk cache, no C extension, no hard time limit in a test; figures (median of 3 `time` runs on `scripts/lib.sh` and on `scripts/symbol-map.py`, before and after) go into story 03's `## Implementation notes`, and the Queen copies them into the CHANGELOG entry at ship. ~0.2 s is the wish, not an acceptance number.
- Ask 5's "where the docs list scripts": `README.md` `## What is measured, and what is not` (one bold-led line beside `scope-check.sh`, `wave-check.sh`, `trace-check.sh`) and the recon sentence of `/vulyk-plan` in `docs/command-reference.md`. No wiki page.
- Ask 2 is prose in `.claude/commands/vulyk-ship.md` only; VULYK's own Profile `Release / deploy` row stays `<fill in>` (answer 1). No test: `tests/maintenance.test.sh` guards the description budget, the body has no test, a trivial change names none.
- Known wave-check noise, accepted: `verify-gap` on story 04 (prose files have no test), `empty-glob` on story 03 if the new fixture paths do not exist yet.
- Story 02 carries `model: haiku` (a fallback branch plus one test case, the brief's routine marker). Stories 01, 03, 04 carry no model line: 01 is a trust-boundary gate, 03 is a 474-line parser with a profiling task, 04 edits agent and command protocol text.
- Coverage (drone-coverage, 2026-10-27): Ask 7 partial. Two gaps ride as assumptions: other paths under `tests/` keep
  counting as tests (only `tests/fixtures/**` is excluded), and the `replay.py` fix is proven only by a local re-run;
  `.vulyk/symbol-map-replay/cases.json` is on disk (checked by the Queen), so story 03 re-runs it.

## Stories

**Wave 1** (parallel; `## Files` disjoint)
- `post-037-tails-01-ship-gate` — one `verdict_stale` in `lib.sh`; `ship-check.sh` council branch and `human-check.sh --check` call it; failing `--part ship` case in `tests/cycle.test.sh` (ask 1).
- `post-037-tails-02-telemetry-version` — `vulyk_version()` falls back to `VERSION` beside `install.sh`; test case in `tests/telemetry.test.sh` (ask 8). `model: haiku`.
- `post-037-tails-03-symbol-map-script` — `symbol-map.py`: bash-runs-python edge, fixtures exclusion, path-mention ranking, missing-first, `--exact`, profile + cheap fixes; `replay.py` via `sys.executable`; fixtures and cases in `tests/symbol-map.test.sh` (asks 3, 4, 6, 7).

**Wave 2**
- `post-037-tails-04-protocol-docs` — `vulyk-plan.md` step 3 runs `--exact` per file and the line is rewrapped; `queen-planner.md` `## Files` bullet reads exact lines + counts; `vulyk-ship.md` publish step orders push, green CI, tag; one-line doc in `README.md` and `docs/command-reference.md` (asks 2, 5, 6). Blocked by 03.

## Contracts
- **`verdict_stale`** (`scripts/lib.sh`, story 01; internal to 01 but shared by two scripts): `verdict_stale <spec-dir> <head-sha> <pack-fp>`. Prints one line: `CURRENT`, `STALE (pack)` (`<pack-fp>` != `pack_fingerprint <spec-dir>`) or `STALE (commit)` (`<head-sha>` != `git rev-parse HEAD` and the range `<head-sha>..HEAD` is not `paperwork_only`); exit 0 on `CURRENT`, 1 on either `STALE`. Pack is tested before commit. `ship-check.sh`: an ACCEPTED human row that overrides a council row is accepted only when `verdict_stale` says `CURRENT`; otherwise stage 05 is `not ok` with the `STALE (...)` reason on its line and the final verdict is `NOT READY`. A REJECTED row is `not ok` as today. `human-check.sh --check` prints the same words it prints today, computed by the function.
- **`--exact`** (`scripts/symbol-map.sh|.py`, story 03 provides; story 04's prose consumes): `bash scripts/symbol-map.sh --exact [--story <story.md>] [--scope <path>]... <file>...`. Same blocks, same section order, same 1536-byte cap and `... N more` tail. In each section the `exact` lines print as today (cap 5 + `... N more`); the `textual` lines of that section collapse into one line `  textual  <N> not shown`. A section with only textual lines still prints (its count line only). `! missing`, `! unparsed`, `! imports not parsed for <ext>` lines are unchanged. Without `--exact` the output is the 0.37 output plus this spec's fixes. `--help` names the flag.
- **Path-mention ranking** (story 03, default and `--exact` modes): rank 0 any file that is not `.md`/`.rst`/`.txt` (code, config, tests); rank 1 `docs/adr/**`; rank 2 every other `.md`/`.rst`/`.txt`; rank 3 `CHANGELOG.md`, `CLAUDE.md`, `README.md` at the repo root; alphabetical inside a rank; the cap of 5 and `... N more` apply after ranking.
- **Bash-runs-python edge** (story 03): in a `.sh`/`.bash` file a token `"$(dirname "$0")/<name>.py"`, `"$DIR/<name>.py"`, `"$SCRIPT_DIR/<name>.py"`, `"${BASH_SOURCE[0]%/*}/<name>.py"` or a literal repo-relative `<path>.py` after `python`, `python3`, `"$PY"`-style variable or `exec` resolves like `source` does today (sourcing script's dir, then a unique basename among tracked files): the `.py` is `exact` under `imported` of the `.sh`, and the `.sh` is `exact` under `importers` of the `.py`.
- **Telemetry version** (story 02): `vulyk_version()` order: `.claude/vulyk-version` stamp; else `$ROOT/VERSION` (first line, whitespace stripped) when `$ROOT/install.sh` and `$ROOT/VERSION` both exist; else `0.0.0`. The bundle `check` rule (`vulyk` is a semver) is unchanged.

## Rejected
- Ask 6 as protocol text only (the Queen trims the script's output to `exact` lines and counts before the planner dispatch): no script change, but it is model work on every plan, it costs the Queen's context the full output anyway, and it drifts the first time a recon is hurried. A flag is ten lines of Python with a fixture case.
- A fifth story for ask 2 (`vulyk-ship.md` prose) in wave 1: one paragraph; its own worker's orientation and close cost more than the paragraph. Folded into story 04.
- A `docs/defects/` card for the ship-gate miss: Law 6 binds owner corrections; this was the Queen's own recon. The failing test in `tests/cycle.test.sh` is the check.

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all. Approved is the owner's
word, the stop at Tier 2-4; Briefed is written by `cycle.sh briefed` instead, at Tier 1 ("via
mini-brief"), with `--go`, or in no-question mode ("assumed"). Either closes stage 02. Council and
Checked close stages 04+05 together: a GREEN council row is enough on its own, and Checked is the
owner's override in either direction, newest timestamp wins. No line of this comment may start with
a marker: the scripts read the first line that does.

There is no default tier: `cycle.sh open-round` refuses to open a round while the `**Tier:**` line above
is missing or unparsable.
-->
**Approved:** <owner, date - stage 02, the unconditional gate. /vulyk-build refuses without this line.>
**Briefed:** via grill, Andrei, 2026-10-27
**Branch:** <written by /vulyk-build before wave 1 - stage 03: the branch every story commit lives on>
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** <written by scripts/cycle.sh judge/escalate - stages 04+05: "<GREEN|RED|ESCALATE|STALE> round <N>, <date>, at <sha7>, pack <fp12>[ - red: 2,5]", appended once per round.>
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
