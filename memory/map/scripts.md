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
  `marker`, `constitution_file`, `command_cell_exists`, `command_cell_round_only` (:180). Model floor (ADR-015):
  `model_floor` (default `fable 5.1`, `opus 5.5`, `sonnet 5.5`, `haiku 5.5 cc>=2.1.293`; `VULYK_MODEL_FLOOR`
  overrides), `model_version`, `claude_code_version`, `version_lt`, `model_below_floor` (fails closed).
  `verdict_stale <spec> <head-sha> <pack-fp>` (lib.sh:109; `CURRENT` rc 0 / `STALE (pack)` / `STALE (commit)`
  rc 1; a `<sha>..HEAD` that is `paperwork_only` stays current): used by `human-check.sh --check` (:57) and
  ship-check.sh (:255, :302). The council GREEN row's test is inline (ship-check.sh:225-228).
  Red-receipt helpers (0.40.0): `verify_path_tokens` (:229), `sealed_tests` (:235), `sha256_tool` (:255),
  `set_hash` (:261; a missing file hashes as `missing <path>`). cycle.sh: `fm_raw` (:2035), `fm_red` (:2044;
  the one reader of the `red:` mark, frontmatter only), `repair_unmarks` (:2050).
- `ship-check.sh <spec-dir>` / `--record`; `human-check.sh <spec-dir> <ACCEPTED|REJECTED>`.
  `scope-check.sh <story-file> [range]` runs in `close-story`; `close-story --commit` exits 4 on its `  ! ` paths.
- `wave-check.sh` (`no-verify`, `verify-gap`, `verify-cell`, `verify-round-only` wave-check.sh:34,227; report-only
  `red-no-test`, `red-value`; the red block opens only on a `red:` line inside frontmatter, :249-259),
  `trace-check.sh`, `token-report.py <project> [--spec S] [--since D] [--json]` (dedupes by `message.id`),
  `evolve-ledger.py <root> <verb>` (owns `memory/stats/evolve.jsonl`; `resolve`: tip in default branch =
  accepted, unmerged branch gone = rejected).
- `trace-autopsy.sh <brief.md>` (0.42.0) - picks python3|python (none: exit 2), execs `trace-autopsy.py`
  (stdlib). Reads only the brief's `> ` lines; frames: Python `File "p", line N`, Node `at f (p:L:C)`, bash
  `p: line N:`, plain `p.ext:N` (FRAME_FORMS, first match per line, else PLAIN). `resolve`: whole tracked path is
  the tail of the frame path, else one file sharing >= 2 trailing parts; basename-only = `ambiguous`; none =
  `outside the repo`; `dist/` not mapped back. Writes `autopsy.md` beside the brief, <= 15 lines (MAX_LINES,
  MAX_FRAMES 3): HEAD, per frame its code line at HEAD + `git log -n 3 -L n,n:path` as `last touched:`, marks
  (outside / ambiguous / past end), `... N more repo frames`. Innermost first (Python traces reversed). No repo
  frame: one stdout line, no file. Trace text is data: git via argv list, only `ls-files` paths and digit lines;
  git failure = a mark. Exit 0 / 2 (usage, no python, not in git). Sole caller: `/vulyk-plan` step 2.
- `.claude/hooks/session-start-brief.sh` - map line; `[VULYK] model profile not chosen`; bootstrap offer
  while the Profile holds `<fill in`; `maintenance due: ...` for gc, evolve, map (`memory/map/.stale`); its own
  `[VULYK] memory triage (...)` ask-once line (>= 160 lines or 20480 bytes of auto-memory MEMORY.md, quiet until
  +20 lines / +2048 bytes past `.claude/state/memory-triage.txt`; a no runs `--mark`, :77-101).
- `vulyk-update.sh` (-> `install.sh --upgrade`); `release-check.sh`; `state.sh`; `git-hooks/post-merge`.
- `model-profile.sh` (ADR-020) - `opus-builds|sonnet-builds|economy` in `${CLAUDE_CONFIG_DIR:-~/.claude}/
  vulyk-model-profile`; only `--set` writes; unknown = `sonnet-builds`. `top-model.sh`: `VULYK_TOP_MODEL`,
  `TOP_MODEL =` pin, profile, `--plan`, opus; `--floor` exit 1 prints `below floor`. `GATE_HINT` (top-model.sh:49).
- `defects-index.sh [--check|--grep <regex>|--counts]` (ADR-021) - no arg writes `docs/defects/INDEX.md`;
  `--check` exit 1 `index stale`; `--grep` exit 1 no match. Exit 2 usage/no library/no python.
- `defects-check.sh [<arg>]` - cards parsed by `.claude/hooks/defects_lib.py` (exit 2 if missing). No arg =
  audit (`BLIND`); `<arg>` = gate (every `block`+`check` card, non-zero = `RED`). Red only when new, else an
  `old ...` line: `DEBT`, `UNDELIVERABLE`, `OVERLAP`, `ESCAPE`, `CONFLICT`, `EXCEPTION`. Always red: `DUPLICATE`,
  `INDEX`. Exit 0/1/2. `DEFECTS_DIR` overrides the library.
- `memory-triage.sh [<memory-dir>]` - read-only lister behind `/vulyk-gc memory` (TSV); `--index-lines`; exit 2
  bad input. `--dir` prints the default dir; `--mark` writes `<lines> <bytes>` to `.claude/state/memory-triage.txt`
  (its one write).
- `symbol-map.sh [--exact] [--story <story.md>] [--scope <path>]... <file>...` - picks python3|python (none: exit
  2), execs `symbol-map.py` (repo = `git ls-files`). Per input a `## <path>` block: `tests`, `importers`,
  `imported`, `guard tests`, `path mentions`; lines `exact` (ast import, bash `source`, bash-run `.py`) or
  `textual`. `--exact` folds textual into `textual  <N> not shown`. Section cap 5; stdout <= 1536 bytes
  (symbol-map.py:32). Exit 0 / 1 input missing / 2 usage, no python, not in git. Callers: recon (`vulyk-plan`
  step 3), `worker-code`, solo build.
- `injection-check.sh <file>` - `check:` of `command-injection-follows-cwd`; exit 1 on a relative script path.
- `redact.sh` (stdin mask); `handoff.py` `_REDACT_FALLBACK` mirrors it (extend both).
- `telemetry.sh` - `enum`, `agents`, `consent`, `record`, `scan`, `bundle`, `check`, `publish`, `inbox`.
  `vulyk_version`: `.claude/vulyk-version`, else `VERSION` beside `install.sh`, else `0.0.0` (:156-168).

## Key contracts
- `cycle.sh`: last stdout line is one JSON object; exits 0 ok · 1 usage · 2 precondition · 3 paused ·
  4 malformed report / red verify · 5 stale · 6 escalate. Other gates exit 0 and report; `telemetry.sh check`
  and `defects-*` are exceptions.
- `is_paperwork_path` whitelist: spec `plan/journal/brief/council/*`, `memory/stats/*.jsonl` ledgers,
  `skills.json`, `memory/learnings/*.md`, `VERSION`, `CHANGELOG.md`.
- `telemetry.sh` `ENUM`/`AGENTS` are append-only (`AGENTS` :65; removed agents go to `RETIRED_AGENTS`, :78;
  `ENUM` :36-46 ends `model_below_floor`, `fable_limit_fallback`).

## Tests
- `tests/full-suite.sh [--jobs N] [--list]` - every `tests/*.test.sh` once, in parallel (cap 12); suites with
  `--list-parts` (telemetry 17, council 11, cycle 7) run one `--part` job per part; `inject`/`intake` latency
  runs alone last. `VULYK_SUITE_TIMEOUT` (590 s; 0 = uncapped); exit 0 / 1 FAIL / 124 TIMEOUT / 2 usage
  (full-suite.sh:19-29). These are the `(round-only)` rows in CLAUDE.md `## Commands`; CI runs one job (ci.yml:107).
- `tests/symbol-map.test.sh` (not round-only) runs on copies of `tests/fixtures/symbol-map/{python,bash}` and
  `docs/specs/symbol-map/replay.py`. Since 0.42.0 it also holds the `--- trace-autopsy` block (fixture git repo
  with two authors, built in the test; Python/Node/bash/plain frames, marks, hostile trace never run, no-frame,
  12-frame cap, exit 2 cases) and an awk guard that `/vulyk-plan` step 2 (`2. Brief.` to `3. Recon.`) names
  `bash scripts/trace-autopsy.sh docs/specs/<slug>/brief.md` and `autopsy.md`.
- `tests/maintenance.test.sh`: caps (`RULES_ALWAYS_MAX_LINES=40`), brief due logic, ledger, `memory-triage.sh`.
  `tests/defects.test.sh`, `tests/model-profile.test.sh`. `VULYK_INSTALL_CACHE` = one pristine install copied.

## install.sh - the upgrade contract
- `--upgrade [--check] [--constitution replace]`; a plain upgrade never writes the constitution
  (`print_migrate_hint`); `replace_constitution` backs up. `OWNED` includes `.claude/hooks`.
- Defect hooks (grep `wire_hook`): UserPromptSubmit `defect-intake.sh`; PreToolUse `defects-inject.sh` with
  `INJECT_MATCHER` (install.sh:1402; older matchers unwired and rewired); `Read` of a story file turns into its
  `## Files` paths (`story_files()`); SessionStart `defects-inject.sh reset`; PostToolUse `defect-intake.sh`
  (`AskUserQuestion`). `unwire_hook <event> <script>` ignores the matcher.
- `install_mod vulyk-pulse@vulyk` (`VULYK_CLAUDE` overrides the CLI; failure returns 0); `retire_mod
  vulyk-watcher@vulyk`. `shippable` drops `memory/stats/*.jsonl` and `.claude/vulyk-setup` (:79).
- `--upgrade` ends with `Offer: no .claude/vulyk-setup ...` when absent (:1546). `report_full_suite_row`
  (:397) names a Commands block with no `round-only` full-suite row; read-only.

## Gotchas
- `close-story`'s `## Commands` match, `record-seat`'s taint and `is_paperwork_path` are security-relevant
  string matches: keep them anchored. `close-story` probes `timeout 5 true` (Windows cmd `timeout`).
- `evolve-ledger.py`: merge the changeset branch, never squash (reads as rejected).
- Retired framework files are removed unless edited (`retired_edited`).
- Card parsing lives only in `defects_lib.py` (`docs/wiki/rules-tree.md`).
- `trace-autopsy.py` resolves from `git ls-files` of the brief's repo and reads code via `git show HEAD:`, so an
  uncommitted file reads `not at HEAD`; `-L` blame is of HEAD, not the working tree.

last-verified: 2026-10-28 (trace-autopsy merge 46d13ad, 0.42.0)
