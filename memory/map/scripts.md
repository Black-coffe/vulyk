# Scout report: scripts/

## Purpose
Deterministic (model-free) gates and helpers: the cycle state machine (`cycle.sh`, `lib.sh`, `journal.sh`;
`memory/map/cycle.md`), report-only gates, rules-tree tools, `redact.sh`, `telemetry.sh`
(`docs/telemetry.md`), `token-report.py`, `evolve-ledger.py`, the SessionStart brief. `set -u`, safe to
re-run. No line numbers: `grep -n '^name()'`.

## Entry points
- `cycle.sh <verb> <spec-dir> [...]` - the cycle CLI; `advance` steps the loop. Callers: the Queen,
  `cycle-clerk` (only `advance`, `status`, `release`), workers (`stamp-red` takes a story file, then `close-story`).
- `lib.sh` - sourced only: `is_story_file`, `pack_fingerprint`, `is_paperwork_path`, `paperwork_only`, `marker`,
  `constitution_file`, `command_cell_exists`, `command_cell_round_only`; model floor (ADR-015: `model_floor`,
  `model_below_floor` fails closed, `VULYK_MODEL_FLOOR` overrides); red helpers `sealed_tests`, `set_hash`
  (a missing file hashes as `missing <path>`). `verdict_stale <spec> <head-sha> <pack-fp>` -> `CURRENT` rc 0 /
  `STALE (pack|commit)` rc 1; a `<sha>..HEAD` that is `paperwork_only` stays current. Used by `human-check.sh
  --check` and ship-check.sh.
- `ship-check.sh <spec-dir>` / `--record`; `human-check.sh <spec-dir> <ACCEPTED|REJECTED>`;
  `scope-check.sh <story-file> [range]` runs in `close-story` (`  ! ` paths -> `--commit` exit 4).
- `wave-check.sh` (`no-verify`, `verify-gap`, `verify-cell`, `verify-round-only`; report-only `red-no-test`,
  `red-value`; the red block opens only on a `red:` line inside frontmatter), `trace-check.sh`,
  `token-report.py <project> [--spec S] [--since D] [--json]` (dedupes by `message.id`), `evolve-ledger.py
  <root> <verb>` (owns `memory/stats/evolve.jsonl`; `resolve`: tip in default branch = accepted, branch gone = rejected).
- `acceptance-log.sh <spec-dir> <ACCEPTED|REJECTED|CANNOT_RUN> [note]` / `--check <spec-dir>` - appends to
  `memory/stats/acceptance.jsonl` with the pack identity (`head`, `pack`); `drift` is boolean or `"unknown"`
  (never read unknown as false); note redacted; always exits 0. `leak-check.sh <file>` - the `check:` of the
  `host-internals-in-public-repo` card; flags host-project internals in a public repo.
- `trace-autopsy.sh <brief.md>` (0.42.0) - python3|python wrapper (none: exit 2) over `trace-autopsy.py`. Reads
  the brief's `> ` lines (Python/Node/bash/plain frames), resolves against `git ls-files` (`ambiguous` / `outside
  the repo` marks), writes `autopsy.md` beside the brief, <= 15 lines (3 frames): code line at HEAD + `git log -L`
  as `last touched:`. Only a Python traceback's own frames are reversed (0.43.1): `path:N` refs after it keep
  order behind it. Trace text is data (git via argv). Exit 0 / 2. Sole caller: `/vulyk-plan` step 2.
- `prompt-check.sh [--touched <path>...]` (0.43.0) - python3|python wrapper over `prompt-check.py`; no model.
  Root = the script's parent, so a fixture copy checks itself. Over `.claude/agents|commands/*.md` and
  `templates/*.md`: agent frontmatter (name = file, model, `maxTurns`, `tools`), `omitClaudeMd` against the
  `except ... carries \`omitClaudeMd: true\`` sentence of `docs/architecture.md`, backticked `scripts/` paths,
  `cycle.sh <verb>` against the dispatcher `case` (no `case "$VERB" in` = a warning, 0.43.1), `--flag` against
  non-comment script lines (+ same-stem `.py`), agent names anywhere in a backticked span (0.43.1), `telemetry.sh`
  `AGENTS` vs agent files. Hive mode (`.claude/vulyk-version` exists): AGENTS mismatches are warnings.
  `--touched`: a finding involving no given path (globs ok) is a `warn`. Exit 0 clean / 1 blocking / 2 usage,
  no python. Callers: `close-story` (cycle.md) and CI's `shell` job. Tests: `maintenance.test.sh`, `cycle.test.sh`.
- `state.sh` - writes `.claude/state.json`/table for `/vulyk-status`. Reads `story:`, `status:`, `wave:`, `tier:`
  from the leading frontmatter block only (0.43.1), so a study report quoting the story template is not a story.
- `.claude/hooks/session-start-brief.sh` - map line, profile/bootstrap offers, `maintenance due: ...` for gc,
  evolve, map, and its `[VULYK] memory triage (...)` ask-once line (a no runs `--mark`).
- `.claude/hooks/handoff.sh` - skips a `python3` that is the Windows Store stub (exit 49) or fails to launch,
  and starts a working Python once per call (0.43.1); `handoff.py` `_REDACT_FALLBACK` mirrors `redact.sh`.
- `vulyk-update.sh` (-> `install.sh --upgrade`); `release-check.sh`; `git-hooks/post-merge`.
- `model-profile.sh` (ADR-020) - `opus-builds|sonnet-builds|economy`; only `--set` writes; unknown =
  `sonnet-builds`. `top-model.sh`: `--floor` exit 1 prints `below floor`.
- `defects-index.sh [--check|--grep <regex>|--counts]` (ADR-021) - no arg writes `docs/defects/INDEX.md`;
  `--check` exit 1 `index stale`. `defects-check.sh [<arg>]` - cards parsed only by `.claude/hooks/defects_lib.py`;
  no arg = audit (`BLIND`); `<arg>` = gate (non-zero = `RED`). Red only when new, else an `old ...` line.
  Always red: `DUPLICATE`, `INDEX`. Exit 0/1/2. `DEFECTS_DIR` overrides the library.
- `memory-triage.sh [<memory-dir>]` - read-only lister behind `/vulyk-gc memory`; `--index-lines`; `--dir`;
  `--mark` writes `<lines> <bytes>` to `.claude/state/memory-triage.txt` (its one write).
- `symbol-map.sh [--exact] [--story <story.md>] [--scope <path>]... <file>...` - python3|python (none: exit 2),
  execs `symbol-map.py` (repo = `git ls-files`). Per input a `## <path>` block: `tests`, `importers`, `imported`,
  `guard tests`, `path mentions`; lines `exact` or `textual`; `--exact` folds textual into `textual <N> not shown`.
  Section cap 5; stdout <= 1536 bytes. Exit 0 / 1 input missing / 2 usage. Callers: recon, `worker-code`, solo build.
- `redact.sh` (stdin mask). `telemetry.sh` - `enum`, `agents`, `consent`, `record`, `scan`, `bundle`, `check`,
  `publish`, `inbox`; `vulyk_version`: `.claude/vulyk-version`, else `VERSION` beside `install.sh`, else `0.0.0`.
  `ENUM`/`AGENTS` are append-only (removed agents go to `RETIRED_AGENTS`; `ENUM` ends `model_below_floor`,
  `fable_limit_fallback`). The scan counts handoff Python starts (0.43.1).

## Key contracts
- `cycle.sh`: last stdout line is one JSON object; exits 0 ok · 1 usage · 2 precondition · 3 paused ·
  4 malformed report / red verify · 5 stale · 6 escalate. Other gates exit 0 and report; `telemetry.sh check`
  and `defects-*` are exceptions.
- `is_paperwork_path` whitelist: spec `plan/journal/brief/council/*`, `memory/stats/*.jsonl`, `skills.json`,
  `memory/learnings/*.md`, `VERSION`, `CHANGELOG.md`.

## Tests
- `tests/full-suite.sh [--jobs N] [--list]` - every `tests/*.test.sh` once, in parallel (cap 12); suites with
  `--list-parts` (telemetry, council, cycle) run one `--part` job each; `inject`/`intake` latency runs alone last.
  `VULYK_SUITE_TIMEOUT` (590 s; 0 = uncapped); exit 0 / 1 FAIL / 124 TIMEOUT / 2 usage. These are the
  `(round-only)` rows in CLAUDE.md `## Commands`; CI runs one `full-suite` job.
- `tests/symbol-map.test.sh` (not round-only) also holds the `--- trace-autopsy` block (speed check best of
  three under 1000 ms) and an awk guard on `/vulyk-plan` step 2. `tests/maintenance.test.sh`: caps, brief due
  logic, ledger, prompt-check fixture copies.

## install.sh - the upgrade contract
- `--upgrade [--check] [--constitution replace]`; a plain upgrade never writes the constitution. Defect hooks via
  `wire_hook`/`unwire_hook` (matcher ignored on unwire). `install_mod vulyk-pulse@vulyk`; `retire_mod
  vulyk-watcher@vulyk`. `shippable` drops `memory/stats/*.jsonl` and `.claude/vulyk-setup`.

## Gotchas
- `close-story`'s `## Commands` match, `record-seat`'s taint and `is_paperwork_path` are security-relevant string
  matches: keep them anchored. `close-story` probes `timeout 5 true` (Windows cmd `timeout`).
- `evolve-ledger.py`: merge the changeset branch, never squash (reads as rejected).
- `trace-autopsy.py` reads code via `git show HEAD:`, so an uncommitted file reads `not at HEAD`.

last-verified: 2026-10-28 (post-043-tails, 0.43.1; trimmed to the cap, line numbers dropped)
