# Scout report: scripts/

## Purpose
Deterministic (model-free) gates and helpers: the cycle state machine (`cycle.sh`, `lib.sh`, `journal.sh`;
`memory/map/cycle.md`), report-only gates, `defects-check.sh`, `redact.sh`, `telemetry.sh`
(`docs/telemetry.md`), `token-report.py`, `evolve-ledger.py` + the SessionStart brief. `set -u`, safe to re-run.

## Entry points
- `cycle.sh <verb> <spec-dir> [...]` - the cycle CLI; `advance` is the loop's stepping verb. Callers:
  the Queen (solo T1-2, `/vulyk-review`, `/vulyk-plan`, pause/resume), `cycle-clerk` (only `advance`,
  `status`, `release`), workers (`close-story`).
- `lib.sh` - sourced only. `is_story_file` :16, `pack_fingerprint` :27, `is_paperwork_path` :57,
  `paperwork_only` :87, `marker` :82, `constitution_file` :94, `command_cell_exists` :98. Model floor
  (ADR-015): `model_floor` :163 (default lines `fable 5.1`, `opus 5.5`, `sonnet 5.5`, `haiku 5.5
  cc>=2.1.293`; flag `unreleased` or `cc>=<x.y.z>`; `VULYK_MODEL_FLOOR` overrides per family),
  `model_version` :177, `claude_code_version` :189 (`CLAUDE_CODE_VERSION` env, else `claude --version`;
  empty if unknown), `version_lt` :199, `model_below_floor` :210 prints `<family> <ver> <floor>` for an
  ID, `<family> alias <floor>` for `unreleased`, `<family> cc <floor> <have|unknown> <need>` for `cc>=`
  when Claude Code is older, unknown or `<need>` malformed (fails closed).
- `ship-check.sh <spec-dir>` / `--record`; `human-check.sh <spec-dir> <ACCEPTED|REJECTED>`;
  `acceptance-log.sh` legacy. `scope-check.sh <story-file> [range]` runs in `close-story`; it filters out
  the story file and its own `memory/stats/scope.jsonl` (:93); `close-story --commit` exits 4 on its `  ! ` paths.
- `wave-check.sh <spec-dir>` - `/vulyk-plan` step 7; classes `no-verify`, `verify-gap`, `verify-cell`
  (a `## Verification` segment that is not a `## Commands` cell). `trace-check.sh` - a `## Requirements`
  quote may match the brief, a plan delta or a `## Asks` item.
- `token-report.py <project> [--spec S] [--since D] [--json]` - spend from `~/.claude/projects/` +
  `council.jsonl`; dedupes by `message.id`. `/vulyk-status` (14d), `/vulyk-evolve` (7d).
- `evolve-ledger.py <root> <verb>` - owns `memory/stats/evolve.jsonl`. Verbs: `add` (`COMPONENTS` :29),
  `run`, `resolve` (tip in default branch = accepted; branch gone, unmerged = rejected; present,
  unmerged = `pending`, no row), `window`, `last`, `pending`.
- `.claude/hooks/session-start-brief.sh` - map line; `[VULYK] model profile not chosen` line when
  `model-profile.sh --chosen` exits 1 (:25-29; Queen runs `/vulyk-models` once after the task); bootstrap offer (:15-23) while the Profile holds
  `<fill in`; when due, `maintenance due: ...` (Queen runs the Skills after the owner's task). gc = any
  stub or >=10 raw learnings; evolve = no `"kind":"run"` row or last run >7 days, plus a newer
  `council.jsonl` row, no unmerged `vulyk/evolve-*`; map = `memory/map/.stale`. grep/awk, not python.
- `vulyk-update.sh` (hands off to `install.sh --upgrade`); `release-check.sh`; `state.sh`
  (`.claude/state.json`); `git-hooks/post-merge` (stamps `memory/map/.stale`).
- `model-profile.sh` (0.30.0, ADR-020) - which family takes each role on THIS machine. One word
  (`opus-builds|sonnet-builds|economy`) in `${CLAUDE_CONFIG_DIR:-~/.claude}/vulyk-model-profile`; only
  `--set` writes it, installers never touch it. Modes: none = print active; `--chosen` (exit 0 known, 1
  not); `--set <n>`; `--role <role>` (roles `queen planner review seat worker routine gate architect
  review-second`); `--recommend` = `<profile> <plan>` (premium plan -> opus-builds); `--explain [n]`.
  No file or an unknown word reads as `sonnet-builds` (fail open). Exit 2 usage. `gate`/`architect`/
  `review-second` ask `top-model.sh` for the active profile, so pins still win.
- `top-model.sh` (0.30.0) - `--help` prints lines 2-45. New `--plan` -> `<plan> <premium|standard>`
  (premium = max, premium-seat). Gate order: `VULYK_TOP_MODEL` env, then `TOP_MODEL = <alias>` in ONE
  file, `CONST_FILE` :125-126 (`CLAUDE.vulyk.md` if it exists, else `CLAUDE.md`; `constitution_pin` :127
  reads only it), then the model profile (:135-154: opus-builds -> fable, economy -> opus; sonnet-builds
  falls through), then the plan, then opus. `second_reviewer` :185: off sonnet-builds it is sonnet.
  `--explain` "dispatched for" line varies by profile (:218-222). `--floor` (exit 1 + `below floor`
  lines): gate line only when SOURCE is constitution or env; provider pin check ~:301. `/vulyk-build`
  Hive step 1 gates on `--floor`.
- `defects-check.sh [<arg>]` (0.23; cards `docs/defects/*.md`, rules `README.md`) - no arg = audit
  (each effective-`block` card's `check:` must fail on every fixture, else `BLIND`); `<arg>` = gate
  (runs every `block`+`check` card; non-zero = `RED`). Exit 0 green, 1 red, 2 usage/no library/no
  python3. Red findings: `DEBT`, `UNDELIVERABLE`, `OVERLAP`, `ESCAPE`; red only when new (`is_new`
  :137), else an `old ...` info line. `DEFECTS_DIR` overrides the library.
- `injection-check.sh <file>` (0.26.1) - `check:` of `docs/defects/command-injection-follows-cwd.md`: a
  `!` injection in commands/`SKILL.md` naming a script by a relative path prints it, exit 1; exit 2 no python.
- `redact.sh` (stdin mask, exit 0, degrades to `cat`); `handoff.py` `_REDACT_FALLBACK` mirrors it (extend both).
- `telemetry.sh` - `enum`, `agents`, `consent`, `record`, `scan`, `bundle`, `check`, `publish`, `inbox`
  (VULYK repo only; `VULYK_HIVE` redirects). Callers: `anomaly-scan.sh`, `/vulyk-build`, `/vulyk-evolve`.

## Key contracts
- `cycle.sh`: last stdout line is one JSON object; exits 0 ok · 1 usage · 2 precondition · 3 paused ·
  4 malformed report / red verify · 5 stale · 6 escalate. Other gates exit 0 and report;
  `telemetry.sh check` is the one exception.
- `is_paperwork_path` whitelist (lib.sh:57-66): spec `plan/journal/brief/council/*`, `memory/stats/
  {human,acceptance,ship,council,scope,anomalies,evolve}.jsonl`, `skills.json`, `memory/learnings/*.md`
  (one level), `VERSION`, `CHANGELOG.md`.
- `telemetry.sh` `ENUM`/`AGENTS` are append-only public contracts; bundle rows codes and numbers only.

## Tests
`tests/maintenance.test.sh` (not in ci.yml): caps, brief due logic, ledger. `tests/defects.test.sh`:
`defects-check.sh`. `tests/telemetry.test.sh`: `floorcheck`, `tmrun` (top-model.sh gate pins).
`tests/mods.test.sh`: the pulse mod only. `tests/model-profile.test.sh`: the resolver (0.30.0).

## install.sh - the upgrade contract
- `--upgrade [--check] [--constitution replace]`; a plain upgrade never writes the constitution
  (`print_migrate_hint` :390); `replace_constitution` :412 (`render_constitution` :329), backs up as
  `<name>.pre-<major.minor>.md` (`constitution_backup` :354).
- `.claude/mods/vulyk-pulse` is in `OWNED` (:54); `.claude/mods/vulyk-watcher` stays there only so an
  upgrade removes the retired tree. `install_mod <id>` :1081 (called :1337 for `vulyk-pulse@vulyk`
  only): user-scope plugin from marketplace
  `Black-coffe/vulyk` via the `claude plugin` CLI (`VULYK_CLAUDE` overrides the binary); not installed ->
  `marketplace add` + `install`; installed -> `marketplace update` + `plugin update` each run; no `claude`
  or a CLI failure -> prints the commands, returns 0. A `false` for the id in project settings is reported
  as kept, never written. `retire_mod vulyk-watcher@vulyk` :1136 (called :1336) uninstalls the retired
  mod at user scope (`--check` only says it would); no `claude` or not installed -> no-op. `wire_plugin`
  and `YSK_ID` are gone: `.claude/hooks/ysk-offer.sh` (SessionStart, `wire_hook` :1333) offers Claude
  Code's built-in You-should-know mod instead of the installer enabling it.
  Mod: `docs/pulse.md` (working indicator, `hooks/hooks.json` -> `register.tsx`, `hooks/core.test.ts`),
  checked by `tests/mods.test.sh`.
- `shippable` filter (:67-91): `memory/stats/*.jsonl` never ship; the installer deletes nothing of a host's.

## Gotchas
- `close-story`'s `## Commands` match, `record-seat`'s taint and `is_paperwork_path` are security-relevant
  string matches: keep them anchored. `close-story` probes `timeout 5 true` (Windows cmd `timeout`).
- `evolve-ledger.py`: merge the changeset branch, never squash (reads as rejected).
- Retired framework files are removed unless edited (`retired_edited` :1109); `unwire_hook` :846.

last-verified: 2026-10-18 (v0.30.0)
