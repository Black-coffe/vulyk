# Scout report: install.sh upgrade contract (split from scripts.md)

Other slices: `scripts.md` (cycle scripts), `scripts-checks.md` (checks, tests), `scripts-hooks.md` (hooks).

## Purpose
`install.sh` installs and upgrades VULYK into a hive; `scripts/vulyk-update.sh` is the entry the owner runs.
`/vulyk-ship` step 2a calls `./install.sh <hive> --upgrade` (`memory/map/agents-and-commands.md`).

## Entry points
- `vulyk-update.sh` (-> `install.sh --upgrade`); `release-check.sh`; `git-hooks/post-merge`. Origin: `VULYK_REPO` or
  `.claude/vulyk-origin`; a cache cloned from another origin is refused. 0.53: the newest tag is `version_newest`
  (`scripts/version-order.sh`, `scripts-hooks.md`), and a target older than the installed version exits 1
  `update: <tag> is not newer than the installed v<x>` before any checkout (an equal one runs).
- `scripts/upgrade-base-check.sh <installer>` (0.53; the `check:` of card `upgrade-overwrites-host-edits`): builds a
  throwaway source (tags v0.1.0-v0.3.0 plus an unmerged branch) and a hive at v0.2.0; exit 1 per broken rule (a file
  equal to an older release's or to a branch-only blob replaced, or a file equal to v0.2.0's blob not replaced), 0 when
  it holds or the file has no `OWNED=` line, 2 usage / cannot build.

## install.sh - the upgrade contract
- `--upgrade [--check] [--constitution replace]`; a plain upgrade never writes the constitution. Defect hooks via
  `wire_hook`/`unwire_hook` (matcher ignored on unwire). Uses `vulyk_python`/`sed_inplace` from `lib.sh` beside it
  (found via `BASH_SOURCE`); awk values pass through `ENVIRON`, never `-v` (BSD awk refuses a newline).
  0.50: wires every hook into an existing `settings.json`; a manifest path is trusted for nothing (`..`, leading
  `/` dropped); `--upgrade` prints `unwired <event>: <script>` for a shipped hook the hive does not wire (`--wire`).
  A guard hook is wired once, only when `v$PREV` did not ship it (a later missing entry = owner's removal, stays).
  0.50.1: `PREV_UNKNOWN` is set when `v$PREV` is not a tag in the source; then `wire_entry`, `wire_shipped` and the
  git-guard branch only report the missing hook (`unwired ...`) and wire nothing.
  Telemetry consent is asked only on `--telemetry ask` (0.49; default off, flag `on|off|ask`).
  `ensure_gitignore` runs with globbing off (`set -f`, restored on each exit), so patterns like
  `docs/specs/*/DRIVER` are written literally (0.50.3).
  0.51: `--upgrade`/`--check` also name (never rewrite) `## Commands` rows with a note or several spans and measured
  council rounds over 210 s; a conflicted file whose body equals the installed release's merges frontmatter per key
  (`frontmatter conflict on <key>` parks it).
  0.53: `release_copy` - a framework file is replaced only when it equals (line endings ignored) its blob in the base;
  any other hive file merges three-way (base = that blob) or is kept with `.vulyk-new`; no other tag, commit or
  branch counts. tails-1115 (`prev_tag`): base = tag `v$PREV`, else the 40-hex commit in the hive's
  `.claude/vulyk-commit` when the source has it (`base` line), else none (one NOTE; nothing is a release copy).
  A git source (`SRC_GIT`) stamps its HEAD into `.claude/vulyk-commit` (a non-git source removes the stamp) and
  `copy_tree` ships its tracked files only (`git ls-files`, `.gitkeep` skipped); a ZIP source keeps the `find` walk.
  `wire_guard` wires `git-guard.sh`, `owner-guard.sh`, `court-guard.sh` once (only when `v$PREV` did not ship
  the script and the hive has it); entries carry `"onFailure": "block"` (`GUARDS` list; also written by `wire_hook`).
  `wire_permissions`: `ALLOW_VERBS` = `advance status release suite stamp-red close-story`, one `cycle.sh` rule
  each, plus `journal.sh`; an older broad `cycle.sh:*` rule is replaced (`narrowed allow: cycle.sh`); owner-only
  verbs and `human-check.sh` stay behind a prompt. `shippable` also drops `memory/stats/skills.json` (local,
  gitignored via `ensure_gitignore`); an upgrade prints `tracked memory/stats/skills.json - ... git -C <hive> rm
  --cached ...` if a hive tracks it. The `defects-inject.sh` matcher is `INJECT_MATCHER` (now with `PowerShell`);
  an older shipped matcher is moved (`OLD_INJECT_MATCHERS`), an owner's own is kept. A fresh install seeds
  `memory/memory.md` from `templates/memory.md`. `install_mod vulyk-pulse@vulyk`; `retire_mod vulyk-watcher@vulyk`.
  `shippable` drops `memory/stats/*.jsonl` and `.claude/vulyk-setup`.

## Gotchas
- The base needs `v$PREV` as a tag in the source or the stamped commit in it: `/vulyk-ship` step 2a tags each local
  build `v<version>`; hook wiring (`PREV_UNKNOWN`) still keys on the tag alone.
- CI jobs `install-smoke` and `full-suite` pin `/bin/bash` 3.2 and BSD sed (see `scripts.md` Gotchas).

last-verified: 2026-11-18 (tails-1115 base + tracked-only; 0.53.0-dev.1 audit-fixes-1113)
