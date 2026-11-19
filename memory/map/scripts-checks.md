# Scout report: scripts/ check scripts and tests (split from scripts.md)

Other slices: `scripts.md` (cycle), `scripts-hooks.md` (hooks, redact, telemetry), `scripts-install.md` (install.sh).

## Purpose
Report-only story/prompt/portability/defect checks, the symbol map, and the test runner (`tests/full-suite.sh`).

## Entry points
- `wave-check.sh` (`no-verify`, `verify-gap`, `verify-cell`, `verify-round-only`; report-only `red-no-test`,
  `red-value`; the red block opens only on a `red:` line inside frontmatter), `trace-check.sh`; both read story
  sections with the shared `FENCE_AWK` (0.54, as `cycle.sh`/`scope-check.sh`, cycle.md),
  `token-report.py <project> [--spec S] [--since D] [--json]` (dedupes by `message.id`), `evolve-ledger.py <root>
  <verb>` (owns `memory/stats/evolve.jsonl`; `resolve`: tip in default branch = accepted, branch gone = rejected).
- `portability-check.sh [<file>...]` (0.44.0) - the `check:` of card `shell-needs-gnu-or-bash4` (status block).
  No arg: `git ls-files '*.sh'` + constitution + `.claude/commands|agents/*.md` (not `tests/fixtures/`). Prints
  `portability-check: <file>:<line>: <rule>: <text> - fix: <fix>` (the rule's `FIX`). `--rules` prints each rule
  as `<rule>: <fix>`. Rule `sort-V` (tails-1115): `sort -V`/`--version-sort` in command position, fix
  `version_newest`/`version_newer` (`scripts/version-order.sh`). Exit 0 / 1 hits / 2 usage; CI `shell` job.
- `trace-autopsy.sh <brief.md>` (0.42.0) - `vulyk_python` wrapper (none: exit 2) over `trace-autopsy.py`. Reads
  the brief's `> ` frames, resolves against `git ls-files`, writes `autopsy.md` beside the brief, <= 15 lines
  (3 frames): code line at HEAD + `git log -L` as `last touched:`. Trace text is data. Exit 0 / 2. Caller: `/vulyk-plan` step 2.
- `prompt-check.sh [--touched <path>...]` (0.43.0) - `vulyk_python` wrapper over `prompt-check.py`; no model.
  Root = the script's parent. Over `.claude/agents|commands/*.md` and `templates/*.md`: agent frontmatter,
  `omitClaudeMd` vs `docs/architecture.md`, backticked `scripts/` paths, `cycle.sh <verb>` vs the dispatcher
  `case`, `--flag` vs script lines, agent names in spans, `telemetry.sh` `AGENTS` vs agent files (hive mode:
  warnings); rule `tools` (tails-1115): an agent whose `tools` lists the subagent-spawning tool (`SPAWN_TOOLS`).
  `--touched`: a finding involving no given path is a `warn`. Exit 0 / 1 blocking / 2 usage or no
  python. Callers: `close-story` (cycle.md) and CI's `shell` job.
- `defects-index.sh [--check|--grep <regex>|--counts]` (ADR-021) - no arg writes `docs/defects/INDEX.md`;
  `--check` exit 1 `index stale`. `defects-check.sh [<arg>|--files <path>...]` - cards parsed only by
  `.claude/hooks/defects_lib.py`; no arg = audit (`BLIND`, `block with no file scope`); `<arg>` = gate (non-zero =
  `RED`); `--files` (0.50, ADR-032 D3; what `close-story` calls) runs each block card's check per file its `paths:`
  glob matches: 0 / 1 red (`<ref> fails on <file>: ...`) / 2 no python. `defects-inject.sh` treats block cards as
  text and exits before Python with no card file. Red only when new, else an `old ...` line.
  Always red: `DUPLICATE`, `INDEX`. Exit 0/1/2. `DEFECTS_DIR` overrides the library.
- `symbol-map.sh [--exact] [--story <story.md>] [--scope <path>]... <file>...` - `vulyk_python` (none: exit 2),
  execs `symbol-map.py` (repo = `git ls-files`). Per input a `## <path>` block: `tests`, `importers`, `imported`,
  `guard tests`, `path mentions`; lines `exact` or `textual`; `--exact` folds textual into `textual <N> not shown`.
  Section cap 5; stdout <= 1536 bytes. Exit 0 / 1 input missing / 2 usage. Callers: recon, `worker-code`, solo build.
  `symbol-map.sh --fill-tests <spec-dir>` (0.54): each `todo` non-repair story gets the `exact` tests of its files in
  `## Files` and a non-`round-only` `## Commands` cell naming each in `## Verification`; a placeholder cell = a `pick`
  line, exit 1; uncapped; exit 2 usage / no repo. Caller: `/vulyk-plan` step 7.
- `acceptance-log.sh <spec-dir> <ACCEPTED|REJECTED|CANNOT_RUN> [note]` / `--check <spec-dir>` - appends to
  `memory/stats/acceptance.jsonl` with the pack identity (`head`, `pack`); `drift` is boolean or `"unknown"`
  (never read unknown as false); note redacted; always exits 0. `leak-check.sh <file>` - the `check:` of the
  `host-internals-in-public-repo` card; flags host-project internals in a public repo: absolute paths outside the
  VULYK root (drive, Git Bash/WSL, home), Claude temp-folder paths, transcript slugs of other projects, every hive
  root of the private registry and terms of the private lists (hits reported without the root/term; passes `~/`,
  `<placeholder>` paths, URLs, system paths); exit 1 hits, 0 clean/missing file, 2 no python (0.53).
- `upgrade-base-check.sh <installer>` (0.53) - `check:` of card `upgrade-overwrites-host-edits` (scripts-install.md).
  `defects-check.sh` (0.53) dates owner quotes past commits listed in `<library>/.scrub-revs` only where the commit did
  nothing but mask a span (checked from git); `--files` never runs a card's check on that card's own fixtures.

## Tests
- `tests/full-suite.sh [--jobs N] [--list | --steps | --step K]` (ADR-029) - every `tests/*.test.sh` as capped
  parts; suites with `--list-parts` run one `--part` job each. A step = a chunk of <= `--jobs` (default cores,
  max 12) jobs started together; `inject`/`intake` latency jobs go last, one per step. `--steps` prints S,
  `--step K` runs one (0.46: first prints `PARTS K/S: <names>`, PART lines as parts end; part names lose edge
  hyphens), no flag runs all. Each part has its own cap `VULYK_PART_CAP` (default and max 300; above
  = exit 2). Output `PART <name> ok|FAIL|SKIP|CAP <N>s cap <C>s`, then `STEP K/S: ok|FAIL <N>s` or `SUITE: ...
  parts= skip= fail=`. Exit 0 / 1 (FAIL, CAP, growth, strict SKIP) / 2; never 124. No whole-run budget:
  `VULYK_SUITE_TIMEOUT` is no longer read here. CLAUDE.md row `Full suite steps (round-only)`; the round runs it
  through `cycle.sh suite` (cycle.md); CI runs one `full-suite` job.
- `suite-parts-check.sh <file>` - reads `PART` lines (full-suite output or a `suite.log`); prints `suite-parts-check:
  cut part <name>: <N>s of cap <C>s (cap|over-cap|grew)` for a CAP line, a cap > 300, or N*10 > C*7. Exit 1 any,
  0 none (a readable file with no PART line), 2 no argument or `no such file: <path>` (0.46). Used by
  `full-suite.sh` and `cmd_suite`.
- Split parts (0.52): `council.test.sh` `verbs`/`verbs2`/`verbs3`; `cycle.test.sh` `close`/`close2`, `red`/`red2`
  (each pair shares a fixture block); `driver.test.sh`, `telemetry.test.sh` cover needs_context and `agent_prefix_high`.
  0.54: `council.test.sh` `repair-scope`, `round-scope`/`round-scope2`/`round-scope5`/`round-scope6` (shared helpers);
  `cycle.test.sh` `merge-gate`. solo-gate-1118: `council.test.sh` `solo-gate`, `roster3`, `round-scope7`;
  `telemetry.test.sh` `upgrade2`, `wiring3`.
- `tests/symbol-map.test.sh` also holds the `--- trace-autopsy` block; `tests/maintenance.test.sh`: caps, brief
  due logic, ledger, prompt-check fixture copies, the hives-behind section (fixture registries via `VULYK_HIVES_FILE`).

## Gotchas
- `evolve-ledger.py`: merge the changeset branch, never squash (reads as rejected).
- `trace-autopsy.py` reads code via `git show HEAD:`, so an uncommitted file reads `not at HEAD`.
last-verified: 2026-11-18 (tails-1115 fix:/--rules/sort-V/tools;
  narrow-repair-1115 FENCE_AWK, --fill-tests, parts; solo-gate-1118 parts)
