# Scout report: scripts/

## Purpose
Deterministic (model-free) gates and helpers: the cycle state machine (`cycle.sh`, `lib.sh`, `journal.sh`;
`memory/map/cycle.md`), report-only gates, `defects-check.sh`, `redact.sh`, `telemetry.sh`
(`docs/telemetry.md`), `token-report.py`, `evolve-ledger.py` + the SessionStart brief. `set -u`, safe to re-run.

## Entry points
- `cycle.sh <verb> <spec-dir> [...]` - the cycle CLI; `advance` is the loop's stepping verb. Callers:
  the Queen (solo T1-2, `/vulyk-review`, `/vulyk-plan`, pause/resume), `cycle-clerk` (only `advance`,
  `status`, `release`), workers (`close-story`).
- `lib.sh` - sourced only. `is_story_file` :16, `pack_fingerprint` :27, `is_paperwork_path` :54,
  `paperwork_only` :68, `marker` :82, `constitution_file` :94, `command_cell_exists` :98. Model floor
  (ADR-015): `model_floor` :163 (default lines `fable 5.1`, `opus 5.5`, `sonnet 5.5`, `haiku 5.5
  cc>=2.1.293`; flag `unreleased` or `cc>=<x.y.z>`; `VULYK_MODEL_FLOOR` overrides per family),
  `model_version` :177, `claude_code_version` :189 (`CLAUDE_CODE_VERSION` env, else `claude --version`;
  empty if unknown), `version_lt` :199, `model_below_floor` :210 prints `<family> <ver> <floor>` for an
  ID, `<family> alias <floor>` for `unreleased`, `<family> cc <floor> <have|unknown> <need>` for `cc>=`
  when Claude Code is older, unknown or `<need>` malformed (fails closed).
- `ship-check.sh <spec-dir>` / `--record`; `human-check.sh <spec-dir> <ACCEPTED|REJECTED>`;
  `acceptance-log.sh` legacy. `scope-check.sh <story-file> [range]` runs in `close-story`.
- `wave-check.sh <spec-dir>` - `/vulyk-plan` step 7; classes `no-verify`, `verify-gap`, `verify-cell`
  (a `## Verification` segment that is not a `## Commands` cell). `trace-check.sh` - a `## Requirements`
  quote may match the brief, a plan delta or a `## Asks` item.
- `token-report.py <project> [--spec S] [--since D] [--json]` - spend from `~/.claude/projects/` +
  `council.jsonl`; dedupes by `message.id`. `/vulyk-status` (14d), `/vulyk-evolve` (7d).
- `evolve-ledger.py <root> <verb>` - owns `memory/stats/evolve.jsonl` (`proposal`/`run`/`verdict` rows).
  Verbs: `add` (component in `COMPONENTS` :29), `run`, `resolve` (verdict from git: tip in default
  branch = accepted; branch gone, unmerged = rejected; present, unmerged = `pending`, no row), `window
  [--n 40]`, `last`, `pending`. Default branch: `origin/HEAD`, else `main`, `master`.
- `.claude/hooks/session-start-brief.sh` - map line; bootstrap offer (:15-23) while the Profile holds
  `<fill in`; when due, `maintenance due: ...` (Queen runs the Skills after the owner's task). gc = any
  stub or >=10 raw learnings; evolve = no `"kind":"run"` row or last run >7 days, plus a newer
  `council.jsonl` row, no unmerged `vulyk/evolve-*`; map = `memory/map/.stale`. grep/awk, not python.
- `vulyk-update.sh` (hands off to `install.sh --upgrade`); `release-check.sh`; `state.sh`
  (`.claude/state.json`); `git-hooks/post-merge` (stamps `memory/map/.stale`).
- `top-model.sh` (0.26.2) - `--help` prints lines 2-42. Gate model order: `VULYK_TOP_MODEL` env, then
  `TOP_MODEL = <alias>` in ONE file, `CONST_FILE` :121-122 (`CLAUDE.vulyk.md` if it exists, else
  `CLAUDE.md`; `constitution_pin` :123 reads only it, so prose in a project's own CLAUDE.md never pins),
  then the plan, then opus. Plan-branch hints name `${CONST_FILE##*/}` (:146, :148).
  `--floor` (case :207; exit 1 + `below floor` lines): env VARS :234 (incl. `ANTHROPIC_DEFAULT_HAIKU_MODEL`);
  `below()` :214 (two `cc` messages: version unknown, or older than need -> "Run: claude update");
  gate line :237 `below "gate model ($SOURCE)" "$MODEL"` only when SOURCE is constitution or env (a
  plan-chosen alias is judged by the frontmatter lines); provider check :279 loops OPUS/SONNET/HAIKU
  pins, else `below floor risk:`. `/vulyk-build` Hive step 1 gates on `--floor`.
- `defects-check.sh [<arg>]` (0.23; cards `docs/defects/*.md`, rules `docs/defects/README.md`) - no arg =
  audit (each effective-`block` card's `check:` must fail on every fixture, else `BLIND`); `<arg>` = gate
  (runs every `block`+`check` card; non-zero = `RED`). Exit 0 green, 1 red, 2 usage/no library/no
  python3. Red findings (records `D`/`U`/`O`/`E`/`I`/`R`, :62-66): `DEBT` (>=2 quotes, not effective
  block), `UNDELIVERABLE` (text card, no `paths:`, :231), `OVERLAP` (one normalised key on two live
  cards, :266), `ESCAPE` (quote committed after the block `check:` line, :241). Red only when new
  (newer than the commit that added `README.md`, or uncommitted, `is_new` :137); else an `old ...`
  info line. `DEFECTS_DIR` overrides the library.
- `injection-check.sh <file>` (0.26.1) - the `check:` of `docs/defects/command-injection-follows-cwd.md`.
  Reads `!` injections in `.claude/commands/*.md`, `SKILL.md`, `*.fixture`; a script path not starting
  `${CLAUDE_PROJECT_DIR}`/`${CLAUDE_SKILL_DIR}`/`${CLAUDE_PLUGIN_ROOT}`/`$HOME`, `/`, `~` or a drive
  letter is relative: prints it, exit 1. Other file types exit 0; exit 2 no python.
- `redact.sh` (stdin mask, always exit 0, degrades to `cat`): 19 sed shapes :29-47 + keyword assignments
  :48 + awk PEM blocks. `handoff.py` `_REDACT_FALLBACK` :606 mirrors it (extend both).
- `telemetry.sh` - `enum`, `agents`, `consent`, `record`, `scan [--final]`, `bundle`, `check`, `publish
  [--dry-run]`, `inbox [--clear]` (VULYK repo only; `VULYK_HIVE` redirects). Callers: `anomaly-scan.sh`
  (SessionEnd), `/vulyk-build`, `/vulyk-resume`, `/vulyk-evolve`.

## Key contracts
- `cycle.sh`: last stdout line is one JSON object; exits 0 ok · 1 usage · 2 precondition · 3 paused ·
  4 malformed report / red verify · 5 stale · 6 escalate. Other gates exit 0 and report;
  `telemetry.sh check` is the one exception.
- `is_paperwork_path` whitelist (lib.sh:54-64): spec `plan/journal/brief/council/*`, `memory/stats/
  {human,acceptance,ship,council,scope,anomalies,evolve}.jsonl`, `skills.json`, `memory/learnings/*.md`
  (one level), `VERSION`, `CHANGELOG.md`.
- `telemetry.sh` `ENUM`/`AGENTS` are append-only public contracts; bundle rows codes and numbers only.

## Tests
`tests/maintenance.test.sh` (no model/network; not in ci.yml): constitution caps, brief due logic,
ledger, `/vulyk-gc` commit line. `tests/defects.test.sh` covers `defects-check.sh`.
`tests/telemetry.test.sh`: `floorcheck` helper plus `tmrun` (runs top-model.sh in a temp project) for
the gate-pin cases (constitution file choice, `--floor` gate line).

## install.sh - the upgrade contract
- `--upgrade [--check] [--constitution replace]`; a plain upgrade never writes the constitution
  (`print_migrate_hint` :390); `replace_constitution` :412 (`render_constitution` :329), backs up as
  `<name>.pre-<major.minor>.md` (`constitution_backup` :354).
- `copy_tree` filter (:78-88): `memory/stats/*.jsonl` never ship; the installer deletes nothing of a host's.

## Gotchas
- `close-story`'s `## Commands` match, `record-seat`'s taint and `is_paperwork_path` are security-relevant
  string matches: keep them anchored. `close-story` probes `timeout 5 true` (Windows cmd `timeout`).
- `evolve-ledger.py`: merge the changeset branch, never squash (reads as rejected).
- Retired framework files are removed unless edited (`retired_edited` :1109); `unwire_hook` :846.

last-verified: 2026-10-14 (v0.26.2)
