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
  empty if unknown), `version_lt` :199 (numeric dotted compare), `model_below_floor` :210 prints
  `<family> <ver> <floor>` for an ID, `<family> alias <floor>` for `unreleased`, `<family> cc <floor>
  <have|unknown> <need>` for `cc>=` when Claude Code is older, unknown or `<need>` malformed (fails closed).
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
  `<fill in` (not with `telemetry/inbox/`, not after a `| Bootstrap | declined ... |` row); when due,
  `maintenance due: ...` (Queen runs the Skills after the owner's task, default branch, clean tree). gc =
  any stub or >=10 raw learnings (CONSOLIDATED/README excluded); evolve = no `"kind":"run"` row or last
  run >7 days, plus a newer `council.jsonl` row, no unmerged `vulyk/evolve-*` (else a "waits" line);
  map = `memory/map/.stale`. grep/awk on `"ts":"`, not python.
- `vulyk-update.sh` (hands off to `install.sh --upgrade`); `release-check.sh`; `top-model.sh` (`--floor` :206: exit 1 + `below floor` lines; env VARS :233 now
  include `ANTHROPIC_DEFAULT_HAIKU_MODEL`; provider check :276 loops OPUS/SONNET/HAIKU pins, else `below
  floor risk:`; `below()` :213 adds two `cc` messages: Claude Code version unknown, or older than need
  -> "Run: claude update"; `/vulyk-build` Hive step 1 gates on it); `state.sh`
  (`.claude/state.json`); `git-hooks/post-merge` (stamps `memory/map/.stale`).
- `defects-check.sh [<arg>]` (0.23; cards `docs/defects/*.md`, rules `docs/defects/README.md`) - no arg =
  audit (each effective-`block` card's `check:` must fail on every fixture, else `BLIND`); `<arg>` = gate
  (runs every card that declares `block`+`check`, fixtures or not; non-zero = `RED`). Exit 0 green, 1 red,
  2 usage/no library/no python3. Red findings (python heredoc records `D`/`U`/`O`/`E`/`I`/`R`, :62-66):
  `DEBT` (>=2 quotes, not effective block), `UNDELIVERABLE` (text card, no `paths:`, :231), `OVERLAP`
  (one normalised key on two live cards, :266), `ESCAPE` (quote committed after the block `check:` line,
  no fixture/check change since, :241). Each is red only when new (line/card newer than the commit that
  added `README.md`, or uncommitted, `is_new` :137); else an `old ...` info line. A key inside another's
  key is an `ambiguous key` info line only. `DEFECTS_DIR` overrides the library.
- `redact.sh` (stdin mask, always exit 0, degrades to `cat`): 19 sed shapes :29-47 (token and
  credential shapes) + keyword assignments :48 + awk PEM blocks. `handoff.py` `_REDACT_FALLBACK` :580 mirrors it
  (extend both). Callers: brief.md, handoff dump, ledger notes.
- `telemetry.sh` - `enum`, `agents`, `consent`, `record`, `scan [--final]`, `bundle`, `check`, `publish
  [--dry-run]`, `inbox [--clear]` (VULYK repo only; `VULYK_HIVE` redirects). Callers: `anomaly-scan.sh`
  (SessionEnd), `/vulyk-build`, `/vulyk-resume`, `/vulyk-evolve`.

## Key contracts
- `cycle.sh`: last stdout line is one JSON object; exits 0 ok · 1 usage · 2 precondition · 3 paused ·
  4 malformed report / red verify · 5 stale · 6 escalate. Other gates exit 0 and report;
  `telemetry.sh check` is the one exception.
- `is_paperwork_path` whitelist (lib.sh:54-64): spec `plan/journal/brief/council/*`, `memory/stats/
  {human,acceptance,ship,council,scope,anomalies,evolve}.jsonl`, `skills.json`, `evolve.jsonl` (lib.sh:58), `memory/learnings/*.md` (one level), `VERSION`, `CHANGELOG.md`.
- `telemetry.sh` `ENUM`/`AGENTS` are append-only public contracts; bundle rows codes and numbers only.

## Tests
`tests/maintenance.test.sh` (no model/network; not in ci.yml): constitution caps `CONSTITUTION_MAX_BYTES=7168`
/ `_LINES=120` (repo and shipped render), `DESCRIPTIONS_MAX_BYTES=4623` (:31-33), brief due logic (:96),
bootstrap offer (:165), ledger, `green` terminal of build/review (:233), the `/vulyk-gc` guarded commit
line run on temp repos (:291). `tests/defects.test.sh` covers `defects-check.sh`.

## install.sh - the upgrade contract
- `--upgrade [--check] [--constitution replace]`; a plain upgrade never writes the constitution
  (`print_migrate_hint` :390); `replace_constitution` :412 renders it (`render_constitution` :329), backs
  up as `<name>.pre-<major.minor>.md` (`constitution_backup` :354).
- `copy_tree` filter (:78-88): `memory/stats/*.jsonl` never ship; the installer deletes nothing of a host's.
- Retired framework files are removed unless edited (`retired_edited` :1039); `unwire_hook` :846.

## Gotchas
- `close-story`'s `## Commands` match, `record-seat`'s taint and `is_paperwork_path` are security-relevant
  string matches: keep them anchored. `close-story` probes `timeout 5 true` (Windows cmd `timeout`).
- `evolve-ledger.py`: merge the changeset branch, never squash (reads as rejected).

last-verified: 2026-10-08 (v0.26.0)
