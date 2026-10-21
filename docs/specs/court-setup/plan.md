# Court setup (plan)

**Tier:** 2 · **Spec slug:** `court-setup` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-013 D3 (no blind seat, no court), ADR-005 (installer upgrade contract), card upgrade-overwrites-host-edits
**Depends on:** 0.33.0 on main (19234b9 and later)

## Goal
The blind seats judge a court that can actually run the hive's code. When the hive has `.claude/vulyk-setup`, `build_court` runs it inside the fresh court before the round opens, capped at 300 seconds (`VULYK_SETUP_TIMEOUT` overrides). A non-zero exit or a timeout removes the court, leaves no round behind, and fails `open-round` with exit 2 and the tail of the setup log. The installer never ships, owns or removes `.claude/vulyk-setup`. `/vulyk-bootstrap` asks for it. An upgrade prints one offer line in a hive that has a dependency manifest and no setup file.

## Assumptions
- The script is read from the hive's working copy (`$ROOT/.claude/vulyk-setup`), so an uncommitted edit counts. It runs as `bash <file>` with the court as its working directory, and gets `VULYK_ROOT` (the hive) and `VULYK_COURT` (the court) so it can link `node_modules` or a venv instead of reinstalling.
- Its full output goes to `.vulyk/reports/<slug>/round-<n>/setup.log` (git-ignored). On failure the last 20 lines go to stderr, and the `open-round` error names the exit code or the timeout.
- The cap uses the same working-`timeout` probe as close-story (`cycle.sh:2001`). Where no working `timeout` exists, setup runs uncapped and stderr says so in one line.
- Files the setup creates (`node_modules`, `.venv`) are expected to be git-ignored in the hive. VULYK does not re-commit the court after setup.
- The offer line looks for `package.json`, `pyproject.toml` or `requirements.txt` at the hive root, and only on `--upgrade`. A fresh install is covered by the bootstrap question.
- Tier 1-2 rounds build no court (`cycle.sh:2207-2214`), so setup runs only where blind seats sit.

## Stories

**Wave 1**
- `court-setup-01` — `cycle.sh` `build_court` runs `.claude/vulyk-setup` with a cap; failure or timeout = no round, exit 2, log tail; council tests; `docs/cycle.md` line.

**Wave 2**
- `court-setup-02` — `install.sh` never ships the file and prints the upgrade offer line; bootstrap interview question; installer tests; CHANGELOG.

## Contracts
- none (Tier 2, built in order by the Queen).

## Integration gate
`bash tests/council.test.sh && bash tests/telemetry.test.sh`

## Descoped

*(empty)*

## Plan deltas

**Approved:** <owner, date>
