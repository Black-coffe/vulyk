# Scout report: scripts/

## Purpose
Deterministic (model-free) gates and helpers. Families: the cycle state machine (`cycle.sh` + `lib.sh` +
`journal.sh`; `memory/map/cycle.md`), report-only gates (`ship-check.sh`, `human-check.sh`,
`acceptance-log.sh`, `scope-check.sh`, `wave-check.sh`, `trace-check.sh`, `release-check.sh`),
`telemetry.sh` (`docs/telemetry.md`), `token-report.py`, and the maintenance pair `evolve-ledger.py` +
the SessionStart brief. Shell is `#!/usr/bin/env bash`, `set -u`, safe to re-run.

## Entry points
- `cycle.sh <verb> <spec-dir> [...]` - the cycle CLI; `advance` is the loop's stepping verb. Callers:
  the Queen (solo T1-2, `/vulyk-review`, `/vulyk-plan`, pause/resume), `cycle-clerk` (only `advance`,
  `status`, `release`), workers (`close-story`).
- `lib.sh` - sourced only. `is_story_file` :16, `pack_fingerprint` :27, `is_paperwork_path` :54,
  `paperwork_only` :68, `marker` :82, `constitution_file` :94 (`CLAUDE.vulyk.md` if present, else
  `CLAUDE.md`), `command_cell_exists` :98, `client_path_filled`, `profile_value`.
- `ship-check.sh <spec-dir>` / `--record`; `human-check.sh <spec-dir> <ACCEPTED|REJECTED>`;
  `acceptance-log.sh` legacy. `scope-check.sh <story-file> [range]` runs in `close-story`.
- `wave-check.sh <spec-dir>` - `/vulyk-plan` step 7; classes `no-verify`, `verify-gap`, `verify-cell`
  (a `## Verification` segment that is not a `## Commands` cell). `trace-check.sh` - a `## Requirements`
  quote may match the brief, a plan delta or a `## Asks` item.
- `token-report.py <project> [--spec S] [--since D] [--json]` - spend from `~/.claude/projects/` +
  `council.jsonl`; dedupes by `message.id`; never uses Workflow `totalTokens`. `/vulyk-status` (14d),
  `/vulyk-evolve` (7d).
- `evolve-ledger.py <root> <verb>` (0.21) - owns `memory/stats/evolve.jsonl`, rows `proposal` /
  `run` / `verdict` (ts UTC, compact JSON). Verbs: `add` (component must be in `COMPONENTS` :29),
  `run --branch --commit --proposals`, `resolve [--reason-for B=TEXT]` (verdict from git: branch tip in
  the default branch = accepted; branch gone, unmerged = rejected; present, unmerged = `pending`, no row),
  `window [--n 40]` (last 40 proposals with verdicts + older rejections), `last` (newest run `ts`),
  `pending` (unmerged `vulyk/evolve-*`). Default branch: `origin/HEAD`, else `main`, `master`. Stdlib.
- `.claude/hooks/session-start-brief.sh` - prints the map line plus, when due, `maintenance due: ...`
  telling the Queen to run the Skills after the owner's task on the default branch, clean tree. Due:
  gc = any stub (`Stub captured by VULYK`) or >=10 raw learnings (CONSOLIDATED/README excluded);
  evolve = no `"kind":"run"` row, or last run >7 days, and a `council.jsonl` row newer than it, and no
  unmerged `vulyk/evolve-*` branch (that prints a "waits for the owner" line instead); ">28 days" adds
  the sunset hint; map = `memory/map/.stale`. Reads files with grep/awk on `"ts":"`, not python.
- `vulyk-update.sh` (fetch, hand off to `install.sh --upgrade`); `release-check.sh`; `top-model.sh` (`--explain/--apply/--check`, gate alias from
  `~/.claude.json`); `redact.sh` (stdin secret mask); `state.sh` (gitignored `.claude/state.json`);
  `git-hooks/post-merge` (stamps `memory/map/.stale`).
- `telemetry.sh` - `enum`, `agents`, `consent`, `record`, `scan [--final]`, `bundle`, `check`, `publish
  [--dry-run]` (prints a recipe), `inbox [--clear]` (VULYK repo only; `VULYK_HIVE` redirects the tree
  `--clear` stages in). Callers: `anomaly-scan.sh` (SessionEnd), `/vulyk-build`, `/vulyk-resume`,
  `/vulyk-evolve`.

## Key contracts
- `cycle.sh`: last stdout line is one JSON object; exits 0 ok · 1 usage · 2 precondition · 3 paused ·
  4 malformed report / red verify · 5 stale · 6 escalate. Other gates exit 0 and report;
  `telemetry.sh check` is the one exception.
- `is_paperwork_path` whitelist (lib.sh:54-64): spec `plan/journal/brief/council/*`, `memory/stats/
  {human,acceptance,ship,council,scope,anomalies}.jsonl`, `skills.json`, `memory/learnings/*.md`
  (one level), `VERSION`, `CHANGELOG.md`. **`evolve.jsonl` is not on it**, so the ledger commit that
  `/vulyk-evolve` makes on the default branch counts as software for `paperwork_only`, i.e. can stale
  an open round (the brief's own tree rule keeps evolve away from a mid-build tree).
- `telemetry.sh` `ENUM`/`AGENTS` are append-only public contracts; bundle rows codes and numbers only.

## Tests
`tests/maintenance.test.sh` (0.21; no model, no network; not wired into ci.yml): constitution caps
`CONSTITUTION_MAX_BYTES=7168` / `_LINES=120` on the repo `CLAUDE.md` and on the shipped render
(placeholders swapped in), `DESCRIPTIONS_MAX_BYTES=4623` for agent+command `description:` lines
(:31-33), the brief's due logic on fixture hives (:96), the ledger (:164). Sizes CR-stripped.

## install.sh - the upgrade contract
- `--upgrade [--check] [--constitution replace]`; a plain upgrade never writes the constitution
  (`print_migrate_hint` :390); `replace_constitution` :412 renders the release `CLAUDE.md` with the
  hive's marked blocks (`render_constitution` :329), backs up as `<name>.pre-<major.minor>.md`
  (`constitution_backup` :354).
- `copy_tree` filter (:78-88): `memory/stats/*.jsonl` never ship (human, scope, ship, evolve join
  council and anomalies in 0.21; a host that has them keeps them, the installer deletes nothing).
- Retired framework files are removed unless edited (`retired_edited` :1039); `unwire_hook` :846;
  `ensure_gitignore` :950; `clean_seeded_council` :1086; `anomaly-scan.sh` wired on SessionEnd :1117.

## Gotchas
- `close-story`'s `## Commands` match, `record-seat`'s taint and `is_paperwork_path` are security-relevant
  string matches: keep them anchored. `close-story` probes `timeout 5 true` (Windows cmd `timeout`).
- `evolve-ledger.py`: merge the changeset branch, never squash - a squash leaves the tip unmerged and
  reads as rejected.
- `telemetry/` (the inbox) is VULYK-repo-only; `copy_tree` never ships it.

last-verified: 2026-09-29 (v0.21.0)
