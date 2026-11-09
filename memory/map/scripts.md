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
  (a missing file hashes as `missing <path>`). Portability helpers (0.44.0): `vulyk_python` sets `VULYK_PY`
  (first of python3/python/py that runs Python 3; preset trusted; call in the current shell, not `$(...)`),
  `sed_inplace <sed-args> <file>` (`-i.bak` then rm), `date_epoch <YYYY-MM-DD|...Z>` (GNU `-d`, else BSD `-j -f`),
  `date_shift <±days> [+fmt]`, `load_sample` (0.47: one `cpu N% top: ...` line, top five processes; CIM on Git
  Bash, `ps`/`uptime` elsewhere; non-zero + stderr reason; used by `cycle.sh suite_load`), `capped_by` (sets `VULYK_CAP` = timeout|gtimeout|python|"", each probed with `<it> 1
  true`), `run_capped <secs> <cmd>` / `run_capped_as <cap> <secs> <cmd>` (exit 124; secs 0 = uncapped; none = runs
  uncapped with a stderr line). `verdict_stale <spec> <head-sha> <pack-fp>` -> `CURRENT` rc 0 /
  `STALE (pack|commit)` rc 1; a `<sha>..HEAD` that is `paperwork_only` stays current. Used by `human-check.sh
  --check` and ship-check.sh.
- `ship-check.sh <spec-dir>` / `--record` (0.46 `ci` line, `ci_check`: needs a `.github/workflows/*.y*ml` and a
  GitHub `origin`, else `ci: not checked`; `gh run list --commit` for HEAD or the newest commit with only
  paperwork after; only the newest run per `workflowName` (by `createdAt`) is judged (0.47), so a re-run or dispatch clears a red;
  all `success` = ok, failed/pending/none = NOT READY, no/failing `gh` = `cannot confirm CI`); `human-check.sh <spec-dir> <ACCEPTED|REJECTED>`;
  `human-check.sh --show <spec-dir>` (0.48; writes nothing; `git diff --stat` then the diff, 300 lines max; base = merge-base
  with the default branch off it, else parent of the commit that added `<spec>/plan.md`, else the empty tree; exit 2 no dir/repo; the Queen pastes it in her reply before asking);
  `scope-check.sh <story-file> [range]` runs in `close-story` (`  ! ` paths -> `--commit` exit 4).
- `wave-check.sh` (`no-verify`, `verify-gap`, `verify-cell`, `verify-round-only`; report-only `red-no-test`,
  `red-value`; the red block opens only on a `red:` line inside frontmatter), `trace-check.sh`,
  `token-report.py <project> [--spec S] [--since D] [--json]` (dedupes by `message.id`), `evolve-ledger.py
  <root> <verb>` (owns `memory/stats/evolve.jsonl`; `resolve`: tip in default branch = accepted, branch gone = rejected).
- `acceptance-log.sh <spec-dir> <ACCEPTED|REJECTED|CANNOT_RUN> [note]` / `--check <spec-dir>` - appends to
  `memory/stats/acceptance.jsonl` with the pack identity (`head`, `pack`); `drift` is boolean or `"unknown"`
  (never read unknown as false); note redacted; always exits 0. `leak-check.sh <file>` - the `check:` of the
  `host-internals-in-public-repo` card; flags host-project internals in a public repo.
- `py.sh <python-args>` (0.44.0) - `exec "$VULYK_PY" "$@"` via `vulyk_python`; none: exit 2. The spelling for
  Python in `CLAUDE.md` and the commands. `run-capped.py <secs> <cmd>` - the cap `run_capped` falls back to
  (own process group, SIGTERM, 10 s grace, SIGKILL; Windows `taskkill /T`; exit 124).
- `portability-check.sh [<file>...]` (0.44.0) - the `check:` of card `shell-needs-gnu-or-bash4` (status block).
  No arg: `git ls-files '*.sh'` + constitution + `.claude/commands|agents/*.md` (not `tests/fixtures/`). Prints
  `portability-check: <file>:<line>: <rule>: <text>`; rules: bash4, sed-i, sed-bre, grep-P, stat-c, readlink-f,
  find-printf, xargs-r, date-d, pct-n, timeout, python, array, paste-s, case-in-subst, heredoc-in-subst.
  Bypass: same-line `# portable: <reason>`. Exit 0 / 1 hits / 2 usage; CI `shell` job.
- `trace-autopsy.sh <brief.md>` (0.42.0) - `vulyk_python` wrapper (none: exit 2) over `trace-autopsy.py`. Reads
  the brief's `> ` frames, resolves against `git ls-files`, writes `autopsy.md` beside the brief, <= 15 lines
  (3 frames): code line at HEAD + `git log -L` as `last touched:`. Trace text is data. Exit 0 / 2. Caller:
  `/vulyk-plan` step 2.
- `prompt-check.sh [--touched <path>...]` (0.43.0) - `vulyk_python` wrapper over `prompt-check.py`; no model.
  Root = the script's parent. Over `.claude/agents|commands/*.md` and `templates/*.md`: agent frontmatter,
  `omitClaudeMd` vs `docs/architecture.md`, backticked `scripts/` paths, `cycle.sh <verb>` vs the dispatcher
  `case`, `--flag` vs script lines, agent names in spans, `telemetry.sh` `AGENTS` vs agent files (hive mode:
  warnings). `--touched`: a finding involving no given path is a `warn`. Exit 0 / 1 blocking / 2 usage or no
  python. Callers: `close-story` (cycle.md) and CI's `shell` job.
- `state.sh` - writes `.claude/state.json`/table for `/vulyk-status`. Reads `story:`, `status:`, `wave:`, `tier:`
  from the leading frontmatter block only (0.43.1), so a study report quoting the story template is not a story.
- `.claude/hooks/session-start-brief.sh` - map line, profile/bootstrap offers, `maintenance due: ...` for gc,
  evolve, map, its `[VULYK] memory triage (...)` ask-once line (a no runs `--mark`), and (0.48) a line naming an
  enabled plugin whose `hooks/` greps `tool.check` (heuristic; such a mod can approve a call git-guard denied).
- `.claude/hooks/git-guard.sh` (0.48, PreToolUse `Bash|PowerShell`; card `work-discarded-by-git-verb`; `docs/hooks-reference.md`)
  - denies git verbs that discard uncommitted work: stash push/save/bare/-u/drop/clear, `checkout .|-f|-- <path>`, worktree
  `restore`, `reset --hard`, `clean -f`, `switch -f`, `branch -D`, `worktree remove -f`. Input with `agent_id` (subagent):
  every listed verb denied, no `git status`, unreadable quotes denied. Main session: denied only if `git status --porcelain`
  shows the affected paths dirty (clean -f/stash -u: untracked too); names 10 then `+N more`; stash drop/clear and
  `branch -D` are subagent-only. Follows `cd`/`-C`. Fails open (no python, bad JSON, error: exit 0). Python tried in order `$VULYK_PY`, python3, python, py; stdin read as UTF-8 (0.50). `--check <file>`
  (the card's check; `porcelain` field fakes status): exit 1 on deny. Python sits in a no-op heredoc below `exit 0`.
  Not covered: rm, `bash -c`, scripts/aliases. No env off-switch; owner removes the settings entry.
- `.claude/hooks/handoff.sh` - skips a `python3` that is the Windows Store stub (exit 49) or fails to launch,
  and starts a working Python once per call (0.43.1); `handoff.py` `_REDACT_FALLBACK` mirrors `redact.sh`.
- `vulyk-update.sh` (-> `install.sh --upgrade`); `release-check.sh`; `git-hooks/post-merge`.
- `model-profile.sh` (ADR-020) - `opus-builds|sonnet-builds|economy`; only `--set` writes; unknown =
  `sonnet-builds`; `--recommend` prints `sonnet-builds <plan>` on every plan (0.49). `top-model.sh`: `--floor` exit 1 prints `below floor`.
- `defects-index.sh [--check|--grep <regex>|--counts]` (ADR-021) - no arg writes `docs/defects/INDEX.md`;
  `--check` exit 1 `index stale`. `defects-check.sh [<arg>|--files <path>...]` - cards parsed only by `.claude/hooks/defects_lib.py`;
  no arg = audit (`BLIND`, `block with no file scope`); `<arg>` = gate (non-zero = `RED`); `--files` (0.50, ADR-032
  D3; what `close-story` calls) runs each block card's check per file its `paths:` glob matches: 0 / 1 red
  (`<ref> fails on <file>: ...`) / 2 no python. `defects-inject.sh` treats block cards as text and exits before Python with no card file. Red only when new, else an `old ...` line.
  Always red: `DUPLICATE`, `INDEX`. Exit 0/1/2. `DEFECTS_DIR` overrides the library.
- `memory-triage.sh` - read-only lister behind `/vulyk-gc memory`; `--mark` is its one write.
- `symbol-map.sh [--exact] [--story <story.md>] [--scope <path>]... <file>...` - `vulyk_python` (none: exit 2),
  execs `symbol-map.py` (repo = `git ls-files`). Per input a `## <path>` block: `tests`, `importers`, `imported`,
  `guard tests`, `path mentions`; lines `exact` or `textual`; `--exact` folds textual into `textual <N> not shown`.
  Section cap 5; stdout <= 1536 bytes. Exit 0 / 1 input missing / 2 usage. Callers: recon, `worker-code`, solo build.
- `redact.sh` (stdin mask). `telemetry.sh` - `enum`, `agents`, `consent`, `record`, `scan`, `bundle`, `check`,
  `publish`, `inbox`; `vulyk_version`: `.claude/vulyk-version`, else `VERSION` beside `install.sh`, else `0.0.0`.
  `ENUM`/`AGENTS` are append-only (removed agents go to `RETIRED_AGENTS`; `ENUM` ends `model_below_floor`,
  `fable_limit_fallback`). The scan counts handoff Python starts (0.43.1). Dates go through `date_epoch` /
  `date_shift` (prev ISO week = `date_shift -7 +%G-W%V`).

## Key contracts
- `cycle.sh`: last stdout line is one JSON object; exits 0 ok · 1 usage · 2 precondition · 3 paused ·
  4 malformed report / red verify · 5 stale · 6 escalate. Other gates exit 0 and report; `telemetry.sh check`
  and `defects-*` are exceptions.
- `is_paperwork_path` whitelist: spec `plan/journal/brief/council/*`, `memory/stats/*.jsonl`, `skills.json`,
  `memory/learnings/*.md`, `VERSION`, `CHANGELOG.md`.

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
  0 none (a readable file with no PART line), 2 no argument or `no such file: <path>` (0.46). Used by `full-suite.sh` and `cmd_suite`.
- `tests/symbol-map.test.sh` also holds the `--- trace-autopsy` block; `tests/maintenance.test.sh`: caps, brief
  due logic, ledger, prompt-check fixture copies.

## install.sh - the upgrade contract
- `--upgrade [--check] [--constitution replace]`; a plain upgrade never writes the constitution. Defect hooks via
  `wire_hook`/`unwire_hook` (matcher ignored on unwire). Uses `vulyk_python`/`sed_inplace` from `lib.sh` beside it
  (found via `BASH_SOURCE`); awk values pass through `ENVIRON`, never `-v` (BSD awk refuses a newline).
  0.50: wires every hook into an existing `settings.json`; a manifest path is trusted for nothing (`..`, leading
  `/` dropped); `--upgrade` prints `unwired <event>: <script>` for a shipped hook the hive does not wire (`--wire`).
  `git-guard.sh` is wired once, only when `v$PREV` did not ship it (a later missing entry = owner's removal, stays).
  Telemetry consent is asked only on `--telemetry ask` (0.49; default off, flag `on|off|ask`).
  `install_mod vulyk-pulse@vulyk`; `retire_mod vulyk-watcher@vulyk`. `shippable` drops `memory/stats/*.jsonl` and `.claude/vulyk-setup`.

## Gotchas
- `close-story`'s `## Commands` match, `record-seat`'s taint and `is_paperwork_path` are security-relevant string
  matches: keep them anchored. `close-story` verification runs per line under `capped_by`/`run_capped` (a cap counts
  only if `<it> 1 true` passes: Windows cmd `timeout`; no cap = uncapped, a 124 is then the command's own).
- Scripts target bash 3.2 + BSD userland (macOS CI jobs `full-suite`, `install-smoke` pin `/bin/bash` 3.2, BSD sed,
  no `timeout`): no bare `sed -i`/`python`/`timeout`/`date -d`; run the gate after editing any `.sh`.
- `evolve-ledger.py`: merge the changeset branch, never squash (reads as rejected).
- `trace-autopsy.py` reads code via `git show HEAD:`, so an uncommitted file reads `not at HEAD`.

last-verified: 2026-11-09 (0.50.0 mass-audit-fixes; ship-check stage 02 at Tier 2-4 wants `**Approved:**` or `--go`, ADR-032 D4). Over the ~80-line budget.
