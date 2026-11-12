# Scout report: install.sh upgrade contract (split from scripts.md)

Other slices: `scripts.md` (cycle scripts), `scripts-checks.md` (checks, tests), `scripts-hooks.md` (hooks).

## Purpose
`install.sh` installs and upgrades VULYK into a hive; `scripts/vulyk-update.sh` is the entry the owner runs.
`/vulyk-ship` step 2a calls `./install.sh <hive> --upgrade` (`memory/map/agents-and-commands.md`).

## Entry points
- `vulyk-update.sh` (-> `install.sh --upgrade`); `release-check.sh`; `git-hooks/post-merge`.

## install.sh - the upgrade contract
- `--upgrade [--check] [--constitution replace]`; a plain upgrade never writes the constitution. Defect hooks via
  `wire_hook`/`unwire_hook` (matcher ignored on unwire). Uses `vulyk_python`/`sed_inplace` from `lib.sh` beside it
  (found via `BASH_SOURCE`); awk values pass through `ENVIRON`, never `-v` (BSD awk refuses a newline).
  0.50: wires every hook into an existing `settings.json`; a manifest path is trusted for nothing (`..`, leading
  `/` dropped); `--upgrade` prints `unwired <event>: <script>` for a shipped hook the hive does not wire (`--wire`).
  `git-guard.sh` is wired once, only when `v$PREV` did not ship it (a later missing entry = owner's removal, stays).
  0.50.1: `PREV_UNKNOWN` is set when `v$PREV` is not a tag in the source; then `wire_entry`, `wire_shipped` and the
  git-guard branch only report the missing hook (`unwired ...`) and wire nothing.
  Telemetry consent is asked only on `--telemetry ask` (0.49; default off, flag `on|off|ask`).
  `ensure_gitignore` runs with globbing off (`set -f`, restored on each exit), so patterns like
  `docs/specs/*/DRIVER` are written literally (0.50.3).
  0.51: `--upgrade`/`--check` also name (never rewrite) `## Commands` rows with a note or several spans and measured
  council rounds over 210 s; a conflicted file whose body equals the installed release's merges frontmatter per key
  (`frontmatter conflict on <key>` parks it).
  `install_mod vulyk-pulse@vulyk`; `retire_mod vulyk-watcher@vulyk`. `shippable` drops `memory/stats/*.jsonl` and
  `.claude/vulyk-setup`.

## Gotchas
- The upgrade tag lookup needs `v$PREV` as a tag in the source: `/vulyk-ship` step 2a tags each local build
  `v<version>` for that reason.
- CI jobs `install-smoke` and `full-suite` pin `/bin/bash` 3.2 and BSD sed (see `scripts.md` Gotchas).

last-verified: 2026-11-12 (post-052-tails split; install bullets moved verbatim from scripts.md; 0.51.0-dev.1 upgrade-findings)
