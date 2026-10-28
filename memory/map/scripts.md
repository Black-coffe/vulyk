# Scout report: scripts/

## Purpose
Deterministic (model-free) gates and helpers: the cycle state machine (`cycle.sh`, `lib.sh`, `journal.sh`;
`memory/map/cycle.md`), report-only gates, the rules-tree tools (`defects-check.sh`, `defects-index.sh`,
`memory-triage.sh`), `redact.sh`, `telemetry.sh` (`docs/telemetry.md`), `token-report.py`,
`evolve-ledger.py` + the SessionStart brief. `set -u`, safe to re-run. No line numbers: `grep -n '^name()'`.

## Entry points
- `cycle.sh <verb> <spec-dir> [...]` - the cycle CLI; `advance` steps the loop. Callers: the Queen,
  `cycle-clerk` (only `advance`, `status`, `release`), workers (`stamp-red` on a `red: required` story, then
  `close-story`; `stamp-red` takes a story file, not a spec dir).
- `lib.sh` - sourced only: `is_story_file`, `pack_fingerprint`, `is_paperwork_path`, `paperwork_only`,
  `marker`, `constitution_file`, `command_cell_exists`. Model floor (ADR-015): `model_floor` (default `fable
  5.1`, `opus 5.5`, `sonnet 5.5`, `haiku 5.5 cc>=2.1.293`; `VULYK_MODEL_FLOOR` overrides), `model_version`,
  `command_cell_round_only` (:180; a command in a `round-only` Purpose-marked row), `claude_code_version`
  (`CLAUDE_CODE_VERSION` env, else `claude --version`), `version_lt`,
  `model_below_floor` (prints `<family> <ver> <floor>` / `alias` / `cc ... <have|unknown> <need>`; fails closed).
  `verdict_stale <spec> <head-sha> <pack-fp>` (lib.sh:109; prints `CURRENT` rc 0 / `STALE (pack)` / `STALE (commit)`
  rc 1; pack first, then a `<sha>..HEAD` that is `paperwork_only` stays current): the human-check record's rule,
  called by `human-check.sh --check` (:57) and ship-check.sh (:255 ACCEPTED override, :302 no-council branch).
  The council GREEN row's pack/commit test is still inline (ship-check.sh:225-228).
  Red-receipt helpers (0.40.0): `verify_path_tokens` (:229), `sealed_tests <verification> <files>` (:235),
  `sha256_tool` (:255; sha256sum, else `shasum -a 256`), `set_hash <path>...` (:261; a missing file hashes as
  `missing <path>`). `cycle.sh stamp-red` and `close-story` use them (cycle.md).
  cycle.sh mark helpers (0.40.1): `fm_raw` (:2035), `fm_red` (:2044; frontmatter-only `red:`, the one reader of
  the mark), `repair_unmarks` (:2050; repair drops the mark only if every finding names a union `## Files` path).
- `ship-check.sh <spec-dir>` / `--record`; `human-check.sh <spec-dir> <ACCEPTED|REJECTED>`.
  `scope-check.sh <story-file> [range]` runs in `close-story`; `close-story --commit` exits 4 on its `  ! ` paths.
- `wave-check.sh` (`no-verify`, `verify-gap`, `verify-cell`, `verify-round-only`: a segment matching a
  `## Commands` row marked `round-only`, wave-check.sh:34,227; 0.40.0 report-only `red-no-test`: a
  `red: required` story whose `## Verification` seals no `## Files` path, and `red-value`: a `red:` value
  other than `required`; 0.40.1 the red block opens only on a `red:` line inside the frontmatter, wave-check.sh:249-259), `trace-check.sh`, `token-report.py <project>
  [--spec S] [--since D] [--json]` (dedupes by `message.id`), `evolve-ledger.py <root> <verb>` (owns
  `memory/stats/evolve.jsonl`; `resolve`: tip in default branch = accepted, unmerged branch gone = rejected).
- `.claude/hooks/session-start-brief.sh` - map line; `[VULYK] model profile not chosen`; bootstrap offer
  while the Profile holds `<fill in`; `maintenance due: ...` for gc, evolve, map (`memory/map/.stale`) or
  `vulyk-gc memory` (0.41.0): Claude Code's auto-memory MEMORY.md (path from `memory-triage.sh --dir`) at >= 160
  lines or >= 20480 bytes, quiet until +20 lines / +2048 bytes past `.claude/state/memory-triage.txt`
  (session-start-brief.sh:77-92). grep/awk only.
- `vulyk-update.sh` (-> `install.sh --upgrade`); `release-check.sh`; `state.sh`; `git-hooks/post-merge`.
- `model-profile.sh` (ADR-020) - `opus-builds|sonnet-builds|economy` in `${CLAUDE_CONFIG_DIR:-~/.claude}/
  vulyk-model-profile`; only `--set` writes; unknown = `sonnet-builds`. `top-model.sh`: `VULYK_TOP_MODEL`,
  `TOP_MODEL =` pin, profile, `--plan`, opus; `--floor` exit 1 prints `below floor`. `GATE_HINT` (top-model.sh:49, under `--help` and `--explain`)
  names the gate's scope: Tier 4 review/planner, lead-architect, a missed story's retry; a hive's own judge uses
  `model-profile.sh --role seat` with explicit `--effort`.
- `defects-index.sh [--check|--grep <regex>|--counts]` (0.32.0, ADR-021) - no arg writes generated
  `docs/defects/INDEX.md`. `--check` exit 1 + `index stale`; `--grep` = `<ref>:<line>: <text>`, exit 1 no
  match; `--counts` (`/vulyk-status` prints it). Exit 2 usage/no library/no python.
- `defects-check.sh [<arg>]` - cards `docs/defects/<id>.md` or `<area>/<id>.md`, parsed by
  `.claude/hooks/defects_lib.py` (exit 2 if missing). No arg = audit (each effective-`block` check must fail
  on every fixture else `BLIND`; each `passes:` fixture must pass the excepted never's check); `<arg>` = gate
  (every `block`+`check` card, non-zero = `RED`). Red only when new (`is_new`), else an `old ...` info line:
  `DEBT` (prohibitive cards only), `UNDELIVERABLE` (`cmd:`/`tool:` count as paths), `OVERLAP`, `ESCAPE`,
  `CONFLICT` (permissive vs prohibitive, overlapping `paths:`, no `exception:`), `EXCEPTION` (ref names no live
  card, or a checked never with no `passes:`). Always red: `DUPLICATE`, `INDEX` (INDEX.md present and
  stale; absent = `no index` info). Exit 0/1/2. `DEFECTS_DIR` overrides the library.
- `memory-triage.sh [<memory-dir>]` - read-only lister behind `/vulyk-gc memory`: TSV `path<TAB>type<TAB>
  first heading`; default dir under `${CLAUDE_CONFIG_DIR:-~/.claude}/projects/<slug>/memory`; absent =
  `no private memory: <dir>`, exit 0. `--index-lines <MEMORY.md> <file>...`; exit 2 bad input.
  0.41.0: `--dir` prints the default dir only; `--mark` writes `<lines> <bytes>` of MEMORY.md to
  `.claude/state/memory-triage.txt` (no MEMORY.md: nothing, exit 0) - its one write.
- `symbol-map.sh [--exact] [--story <story.md>] [--scope <path>]... <file>...` (0.37.0, `--exact` 0.38.0) - picks
  python3|python (none: exit 2), execs `symbol-map.py` (stdlib; repo = `git ls-files`). Per input a `## <path>`
  block of sections `tests`, `importers`, `imported`, `guard tests` (tests using os.walk/rglob/glob(/git
  ls-files/listdir/iterdir), `path mentions` (ranked code, docs/adr, other docs, root CHANGELOG/CLAUDE/README);
  each line `exact` (Python `ast` import, bash `source`/`.`, a bash-run `.py` (`$DIR/x.py` or after a runner),
  also via a re-exporting `__init__`) or `textual` (stem as whole word, path as substring). `--exact` keeps
  `exact` lines, folds textual ones into `textual  <N> not shown`. Never listed: scope (inputs, `--scope`,
  story `## Files` globs, the story) and a `fixtures` path after a `tests`/`test` segment. A missing input's
  block prints first. Non-py/non-shell input: `! imports not parsed for <ext>`; unparseable py: `! unparsed`.
  Section cap 5 + `... N more`; stdout <= 1536 bytes (symbol-map.py:32) ending in one `... N more` line.
  Exit 0 / 1 an input missing (all still reported) / 2 usage, no python, not in git. Reports only. Edges parse
  per kind on first need. Callers: recon (`vulyk-plan` step 3, `--exact`), `worker-code`, solo build.
- `injection-check.sh <file>` - `check:` of `command-injection-follows-cwd`; exit 1 on a relative script path.
- `redact.sh` (stdin mask); `handoff.py` `_REDACT_FALLBACK` mirrors it (extend both).
- `telemetry.sh` - `enum`, `agents`, `consent`, `record`, `scan`, `bundle`, `check`, `publish`, `inbox`.
  `vulyk_version`: `.claude/vulyk-version`, else `VERSION` only when `install.sh` sits beside it (the VULYK
  repo itself), else `0.0.0` (telemetry.sh:156-168).

## Key contracts
- `cycle.sh`: last stdout line is one JSON object; exits 0 ok · 1 usage · 2 precondition · 3 paused ·
  4 malformed report / red verify · 5 stale · 6 escalate. Other gates exit 0 and report; `telemetry.sh check`
  and `defects-*` are exceptions.
- `is_paperwork_path` whitelist: spec `plan/journal/brief/council/*`, `memory/stats/*.jsonl` ledgers,
  `skills.json`, `memory/learnings/*.md`, `VERSION`, `CHANGELOG.md`.
- `telemetry.sh` `ENUM`/`AGENTS` are append-only public contracts (`AGENTS` gained `drone-horizon`, 0.35.0,
  telemetry.sh:65; a removed agent moves to `RETIRED_AGENTS`, :78). `ENUM` (:36-46) now ends
  `model_below_floor`, `fable_limit_fallback` (recorded by the session commands, not by a scan).

## Tests (0.37.0)
- `tests/full-suite.sh [--jobs N] [--list]` - every `tests/*.test.sh` once, in parallel (`--jobs` = cores,
  cap 12); a suite answering `--list-parts` (telemetry, council, cycle) contributes one `--part` job per
  part. Latency checks (`inject`/`intake` `--part latency`) run alone at the end. Budget
  `VULYK_SUITE_TIMEOUT` (default 590 s; 0 = uncapped); output `ok|FAIL|TIMEOUT <N>s <cmd>` per job + a
  `full suite:` summary; exit 0 / 1 FAIL / 124 TIMEOUT (outranks) / 2 usage (full-suite.sh:19-29).
  `tests/full-suite.test.sh` tests it; `tests/symbol-map.test.sh` (CLAUDE.md `Symbol map` row, not round-only)
  runs on copies of `tests/fixtures/symbol-map/{python,bash}` and `docs/specs/symbol-map/replay.py`, and rides
  the suite as a plain job. These are the `(round-only)` rows in CLAUDE.md `## Commands`; a story
  verifies with a `--part` row instead. CI runs it as one job (ci.yml:107).
- `telemetry` (17 parts), `council` (11), `cycle` (7), `inject`/`intake` take `--part <topic>` /
  `--list-parts`; unknown part exits 1. `VULYK_INSTALL_CACHE` = one pristine install copied.
- `tests/maintenance.test.sh`: caps (`RULES_ALWAYS_MAX_LINES=40`), brief due logic, ledger,
  `memory-triage.sh`. `tests/defects.test.sh`: gate + index. `tests/model-profile.test.sh`.

## install.sh - the upgrade contract
- `--upgrade [--check] [--constitution replace]`; a plain upgrade never writes the constitution
  (`print_migrate_hint`); `replace_constitution` backs up via `constitution_backup`; `render_constitution`
  takes Laws from `$SRC/CLAUDE.md`. `OWNED` includes `.claude/hooks`, so `defects_lib.py` ships.
- Defect hooks (grep `wire_hook`): UserPromptSubmit `defect-intake.sh`; PreToolUse `defects-inject.sh` with
  `INJECT_MATCHER='Edit|Write|MultiEdit|NotebookEdit|Read|Bash|WebFetch|WebSearch|Agent|mcp__.*'` (install.sh:1402;
  the 0.19 and 0.32 matchers are unwired and rewired). 0.41.0 `Read`: `story_files()` turns a Read of
  `docs/specs/<slug>/<name>.md` with `story:` frontmatter into its `## Files` paths; any other Read exits in
  bash before python; folded refs are not marked seen on a story Read (only shown ones); SessionStart `defects-inject.sh reset`; PostToolUse `defect-intake.sh`
  matcher `AskUserQuestion`, arg `answer`. `unwire_hook <event> <script>` ignores the matcher.
- `install_mod vulyk-pulse@vulyk` (`VULYK_CLAUDE` overrides the CLI; failure returns 0); `retire_mod
  vulyk-watcher@vulyk`. `shippable` drops `memory/stats/*.jsonl` and `.claude/vulyk-setup` (install.sh:79).
- `--upgrade` ends with `Offer: no .claude/vulyk-setup ...` when absent and the host has a manifest
  (install.sh:1546); it creates nothing.
- `report_full_suite_row <file>` (install.sh:397) runs after `report_fill_status` for CLAUDE.md and
  CLAUDE.vulyk.md, on `--upgrade` and `--check`; names a Commands block with no `full suite` row marked
  `round-only` (pre-0.36); read-only, the block is the hive's.

## Gotchas
- `close-story`'s `## Commands` match, `record-seat`'s taint and `is_paperwork_path` are security-relevant
  string matches: keep them anchored. `close-story` probes `timeout 5 true` (Windows cmd `timeout`).
- `evolve-ledger.py`: merge the changeset branch, never squash (reads as rejected).
- Retired framework files are removed unless edited (`retired_edited`).
- Card parsing lives only in `defects_lib.py` (`docs/wiki/rules-tree.md`).

last-verified: 2026-10-28 (auto-memory-subagent-start merge 211602d, 0.41.0)
