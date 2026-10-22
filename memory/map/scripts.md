# Scout report: scripts/

## Purpose
Deterministic (model-free) gates and helpers: the cycle state machine (`cycle.sh`, `lib.sh`, `journal.sh`;
`memory/map/cycle.md`), report-only gates, the rules-tree tools (`defects-check.sh`, `defects-index.sh`,
`memory-triage.sh`), `redact.sh`, `telemetry.sh` (`docs/telemetry.md`), `token-report.py`,
`evolve-ledger.py` + the SessionStart brief. `set -u`, safe to re-run. No line numbers: `grep -n '^name()'`.

## Entry points
- `cycle.sh <verb> <spec-dir> [...]` - the cycle CLI; `advance` steps the loop. Callers: the Queen,
  `cycle-clerk` (only `advance`, `status`, `release`), workers (`close-story`).
- `lib.sh` - sourced only: `is_story_file`, `pack_fingerprint`, `is_paperwork_path`, `paperwork_only`,
  `marker`, `constitution_file`, `command_cell_exists`. Model floor (ADR-015): `model_floor` (default `fable
  5.1`, `opus 5.5`, `sonnet 5.5`, `haiku 5.5 cc>=2.1.293`; `VULYK_MODEL_FLOOR` overrides), `model_version`,
  `claude_code_version` (`CLAUDE_CODE_VERSION` env, else `claude --version`), `version_lt`,
  `model_below_floor` (prints `<family> <ver> <floor>` / `alias` / `cc ... <have|unknown> <need>`; fails closed).
- `ship-check.sh <spec-dir>` / `--record`; `human-check.sh <spec-dir> <ACCEPTED|REJECTED>`.
  `scope-check.sh <story-file> [range]` runs in `close-story`; `close-story --commit` exits 4 on its `  ! ` paths.
- `wave-check.sh` (`no-verify`, `verify-gap`, `verify-cell`), `trace-check.sh`, `token-report.py <project>
  [--spec S] [--since D] [--json]` (dedupes by `message.id`), `evolve-ledger.py <root> <verb>` (owns
  `memory/stats/evolve.jsonl`; `resolve`: tip in default branch = accepted, unmerged branch gone = rejected).
- `.claude/hooks/session-start-brief.sh` - map line; `[VULYK] model profile not chosen`; bootstrap offer
  while the Profile holds `<fill in`; `maintenance due: ...` when gc (any stub or >=10 raw learnings), evolve
  (no `run` row or >7 days, newer `council.jsonl` row) or map (`memory/map/.stale`) is due. grep/awk only.
- `vulyk-update.sh` (-> `install.sh --upgrade`); `release-check.sh`; `state.sh`; `git-hooks/post-merge`.
- `model-profile.sh` (ADR-020) - `opus-builds|sonnet-builds|economy` in `${CLAUDE_CONFIG_DIR:-~/.claude}/
  vulyk-model-profile`; only `--set` writes. `--chosen`, `--role`, `--recommend`, `--explain`. Unknown =
  `sonnet-builds`. `top-model.sh`: `VULYK_TOP_MODEL`, `TOP_MODEL =` pin, profile, `--plan`, opus; `--floor`
  exit 1 prints `below floor` (`/vulyk-build` Hive step 1 gates on it).
- `defects-index.sh [--check|--grep <regex>|--counts]` (0.32.0, ADR-021) - no arg writes
  `docs/defects/INDEX.md` (generated; tables Never/Allowed/How-to). `--check` exit 1 + `index stale`;
  `--grep` = `<ref>:<line>: <text>`, exit 1 no match; `--counts` = `cards n · never n · allowed n · how-to n ·
  allowed repeats n` (`/vulyk-status` prints it). Exit 2 usage/no library/no python.
- `defects-check.sh [<arg>]` - cards `docs/defects/<id>.md` or `<area>/<id>.md`, parsed by
  `.claude/hooks/defects_lib.py` (exit 2 if missing). No arg = audit (each effective-`block` check must fail
  on every fixture else `BLIND`; each `passes:` fixture must pass the excepted never's check); `<arg>` = gate
  (every `block`+`check` card, non-zero = `RED`). Red only when new (`is_new`), else an `old ...` info line:
  `DEBT` (prohibitive cards only), `UNDELIVERABLE` (`cmd:`/`tool:` count as paths), `OVERLAP`, `ESCAPE`,
  `CONFLICT` (permissive vs prohibitive, overlapping `paths:`, no `exception:`), `EXCEPTION` (ref names no live
  card, or a checked never with no `passes:`). Always red: `DUPLICATE` (id unique across folders), `INDEX`
  (INDEX.md present and stale; absent = one `no index` info line). Allowed with >=2 dated lines = info
  `allowed repeats`. Exit 0/1/2. `DEFECTS_DIR` overrides the library.
- `memory-triage.sh [<memory-dir>]` - read-only lister behind `/vulyk-gc memory`: TSV `path<TAB>type<TAB>
  first heading` per `*.md` bar `MEMORY.md`/`memory.md`; default `${CLAUDE_CONFIG_DIR:-~/.claude}/projects/
  <slug>/memory` (slug = root path, non-alnum -> `-`); absent = `no private memory: <dir>`, exit 0.
  `--index-lines <MEMORY.md> <file>...` prints the index lines naming those files; exit 2 bad input.
- `injection-check.sh <file>` - `check:` of `command-injection-follows-cwd`; exit 1 on a relative script path.
- `redact.sh` (stdin mask); `handoff.py` `_REDACT_FALLBACK` mirrors it (extend both).
- `telemetry.sh` - `enum`, `agents`, `consent`, `record`, `scan`, `bundle`, `check`, `publish`, `inbox`.

## Key contracts
- `cycle.sh`: last stdout line is one JSON object; exits 0 ok · 1 usage · 2 precondition · 3 paused ·
  4 malformed report / red verify · 5 stale · 6 escalate. Other gates exit 0 and report; `telemetry.sh check`
  and `defects-*` are exceptions.
- `is_paperwork_path` whitelist: spec `plan/journal/brief/council/*`, `memory/stats/*.jsonl` ledgers,
  `skills.json`, `memory/learnings/*.md`, `VERSION`, `CHANGELOG.md`.
- `telemetry.sh` `ENUM`/`AGENTS` are append-only public contracts.

## Tests
`tests/maintenance.test.sh` (not in ci.yml): caps (`RULES_ALWAYS_MAX_LINES=40` for path-less
`.claude/rules/*.md`), brief due logic, ledger, `memory-triage.sh`. `tests/defects.test.sh`: gate + index.
`tests/inject.test.sh`, `tests/intake.test.sh`: the hooks. `tests/telemetry.test.sh`: `floorcheck`, `tmrun`,
installer hook wiring (pins the inject matcher and defect hook entries). `tests/model-profile.test.sh`.

## install.sh - the upgrade contract
- `--upgrade [--check] [--constitution replace]`; a plain upgrade never writes the constitution
  (`print_migrate_hint`); `replace_constitution` backs up via `constitution_backup`; `render_constitution`
  takes Laws from `$SRC/CLAUDE.md`. `OWNED` includes `.claude/hooks`, so `defects_lib.py` ships.
- Defect hooks (grep `wire_hook`): UserPromptSubmit `defect-intake.sh`; PreToolUse `defects-inject.sh` with
  `INJECT_MATCHER='Edit|Write|MultiEdit|NotebookEdit|Bash|WebFetch|WebSearch|Agent|mcp__.*'` (an old narrower
  matcher is unwired and rewired); SessionStart `defects-inject.sh reset`; PostToolUse `defect-intake.sh`
  matcher `AskUserQuestion`, arg `answer`. `unwire_hook <event> <script>` ignores the matcher.
- `install_mod vulyk-pulse@vulyk` (`claude plugin` CLI, `VULYK_CLAUDE` overrides; failure prints the commands,
  returns 0); `retire_mod vulyk-watcher@vulyk`. Docs `docs/pulse.md`, tests `tests/mods.test.sh`.
- `shippable` filter: `memory/stats/*.jsonl` and `.claude/vulyk-setup` (the hive's court setup, install.sh:79)
  never ship; the installer deletes nothing of a host's.
- `--upgrade` ends with `Offer: no .claude/vulyk-setup ...` when that file is absent and the host has
  `package.json`, `pyproject.toml` or `requirements.txt` (install.sh:1546); it creates nothing.

## Gotchas
- `close-story`'s `## Commands` match, `record-seat`'s taint and `is_paperwork_path` are security-relevant
  string matches: keep them anchored. `close-story` probes `timeout 5 true` (Windows cmd `timeout`).
- `evolve-ledger.py`: merge the changeset branch, never squash (reads as rejected).
- Retired framework files are removed unless edited (`retired_edited`).
- Card parsing lives only in `defects_lib.py`; the gate, `defects-index.sh`, `defects-inject.sh` and
  `defect-intake.sh` import it. Rules: `docs/wiki/rules-tree.md`.

last-verified: 2026-10-22 (v0.34.0)
