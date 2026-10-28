---
story: cross-platform-02
spec: cross-platform
status: todo
returned:
tier: 3
worker: worker-code
wave: 2
blocked_by: [cross-platform-01]
---

# Every product site, hook and prose line on the helpers; install.sh sources lib.sh

## Goal
No product script, hook, command or agent prose line resolves Python by presence, edits in place with a bare `sed -i`,
parses a date with a GNU-only `date -d`, caps a command with a bare `timeout`, or expands an array unguarded under
`set -u`. `install.sh` sources `"$SRC/scripts/lib.sh"` right after `SRC` is set (a missing file is a loud exit 2 naming
«run from a full checkout»), and its five settings.json merges and the `:1291` edit go through `vulyk_python` and
`sed_inplace`. `tests/telemetry.test.sh`, the one suite that exercises `install.sh` and `telemetry.sh`, switches in the
same story so its own `sed -i` and `timeout` lines cannot mask a product regression.

## Requirements
> 3. Перевод всех продуктовых, командных (`.claude/commands/*.md`, `CLAUDE.md:76`) и тестовых файлов на переносимые вызовы.
> 7. `install.sh` подгружает `scripts/lib.sh` (`vulyk_python`, `sed_inplace`) при любом способе запуска.
> 6. Все раскрытия массивов в файлах с `set -u` — на `${a[@]+"${a[@]}"}`, и проверка на незащищённый `"${a[@]}"` в гейте.

## Files
- install.sh
- scripts/state.sh
- scripts/telemetry.sh
- scripts/redact.sh
- scripts/injection-check.sh
- scripts/leak-check.sh
- scripts/top-model.sh
- scripts/defects-check.sh
- scripts/defects-index.sh
- scripts/prompt-check.sh
- scripts/symbol-map.sh
- scripts/trace-autopsy.sh
- .claude/hooks/handoff.sh
- .claude/hooks/anomaly-scan.sh
- .claude/hooks/vulyk-update-check.sh
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-evolve.md
- .claude/commands/vulyk-review.md
- .claude/commands/vulyk-status.md
- .claude/agents/lead-review.md
- tests/telemetry.test.sh

## Non-goals
- `scripts/lib.sh`, `scripts/cycle.sh`, `scripts/py.sh` are story 01's and are done: use them, do not edit them. A helper
  that does not fit a site is `NEEDS_CONTEXT`, not a local copy.
- Hooks never source `lib.sh`: `handoff.sh` runs each of `python3`, `python`, `py` on `handoff.py` and falls through
  unless the exit was 0 or 1 (the `defect-intake.sh:27` form, one start per prompt), exit 0 when none runs;
  `anomaly-scan.sh` drops its presence gate for the same form or for `handoff.sh`'s answer. `defect-intake.sh`,
  `defects-inject.sh`, `session-start-brief.sh`, `top-model-brief.sh` are not touched (already stub-safe or guarded).
- No new script for prose: `lead-review.md:56` becomes `bash -c '. scripts/lib.sh && run_capped $((${VULYK_SUITE_TIMEOUT:-590} + 5)) <row>'`
  (same budget, same `SUITE:` line); a prose `date -d` keeps the same-line `|| date -v...` idiom of `top-model-brief.sh:54`;
  a prose `python` becomes `bash scripts/py.sh` (inside a `!` injection: `"${CLAUDE_PROJECT_DIR}/scripts/py.sh"`, per
  `docs/defects/command-injection-follows-cwd.md`).
- The other suites (`council`, `defects`, `inject`, `intake`, `solo`, `symbol-map`, `mods`, `token-report`,
  `maintenance`, `full-suite.sh`) belong to stories 03-05.

## Map slice
`memory/map/scripts.md` «Entry points» (wrappers over `.py`, `telemetry.sh`, `redact.sh`), «install.sh - the upgrade
contract»; `memory/map/agents-and-commands.md` «Agents» (`lead-review` suite line), «Commands - what each runs»
(`/vulyk-build`, `/vulyk-evolve`, `/vulyk-review`, `/vulyk-status`).

## Acceptance criteria
- [ ] `install.sh` into a clean dir, with a `python3` stub exiting 49 ahead of a real Python on PATH, still merges
      `settings.json` (telemetry parts `install`, `wiring` stay green); run from a copy that lacks `scripts/lib.sh`
      it exits 2 naming the file.
- [ ] Ask 7, every documented way of starting `install.sh` finds `lib.sh` through `BASH_SOURCE`, never the cwd: `bash
      <checkout>/install.sh <dest> --check` and `<checkout>/install.sh <dest> --check` (shebang) run from a cwd outside
      the checkout, and `scripts/vulyk-update.sh` (which runs the release's own `install.sh`) - each reaches the
      helpers (one test per form in telemetry part `install`). A symlink to `install.sh` is not a documented way: it
      exits 2 like the missing-file case, said in the story's Findings.
- [ ] Ask 9, upgrade half: a hive whose filled `## Commands` block still holds the old `python -m py_compile ...` cell
      keeps it byte-identical through `install.sh --upgrade` (telemetry part `install`); the hive's own cells are the
      host's, never rewritten.
- [ ] `grep -n 'command -v python\|sed -i \|timeout ' install.sh scripts/*.sh .claude/hooks/*.sh` shows only
      `scripts/lib.sh`, `scripts/py.sh`, `scripts/cycle.sh` (done in 01) and lines the plan keeps (same-line `||`
      fallbacks in hooks).
- [ ] `telemetry.sh`'s `prev_week`, `week_of`, `epoch_of` call `date_shift`/`date_epoch`; `state.sh` reports a snapshot
      stale when its epoch is empty, never fresh because of a `0`.
- [ ] The report's unguarded expansions in `telemetry.sh:842`, `redact.sh:53,65`, `anomaly-scan.sh:41`,
      `vulyk-update-check.sh:56` are guarded; `bash .claude/hooks/vulyk-update-check.sh` with `GITHUB_TOKEN` unset exits 0.
- [ ] `tests/telemetry.test.sh`: its 16 `sed -i` lines are `sed_inplace` (it sources `lib.sh` already), the `timeout`
      calls at the report's `:582,587` go through `run_capped` and pass with dead `timeout`/`gtimeout` stubs on PATH,
      the `:529` resolver is `vulyk_python`.
- [ ] `bash scripts/prompt-check.sh` is `ok` (every `scripts/py.sh` named in prose exists; no `--flag` drift).

## Verification
`bash tests/telemetry.test.sh --part telemetry && bash tests/telemetry.test.sh --part scan && bash tests/telemetry.test.sh --part install && bash scripts/defects-check.sh && bash tests/maintenance.test.sh`

## Implementation notes

## Findings
