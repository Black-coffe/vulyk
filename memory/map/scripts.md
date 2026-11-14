# Scout report: scripts/ (cycle scripts)

Other slices: `scripts-checks.md` (checks, tests), `scripts-hooks.md` (hooks, redact, telemetry), `scripts-guards.md`,
`scripts-install.md`.

## Purpose
Deterministic (model-free) gates and helpers: the cycle state machine (`cycle.sh`, `lib.sh`, `journal.sh`;
`memory/map/cycle.md`), ship and acceptance gates, the hive registry check, `token-report.py`, `evolve-ledger.py`.
`set -u`, safe to re-run. No line numbers: `grep -n '^name()'`.

## Entry points
- `cycle.sh <verb> <spec-dir> [...]` - the cycle CLI; `advance` steps the loop. Callers: the Queen,
  `cycle-clerk` (only `advance`, `status`, `release`), workers (`stamp-red` takes a story file, then `close-story`).
- `lib.sh` - sourced only: `is_story_file`, `pack_fingerprint`, `is_paperwork_path`, `paperwork_only`, `marker`,
  `constitution_file`, `command_cell_exists`, `command_cell_round_only`; `## Commands` cell helpers (0.51,
  `cell_awk`): `command_cell_shape` -> `none|one|noted|several`, `command_cell_cmd` (the backticked span; text
  around it is a note; `several` exit 2), `commands_lint <constitution>` (names noted/several rows; the installer's
  dry run prints it). The lookups still accept any one of several spans; only a round-gate full-suite row refuses
  `several` (red part `several backticked commands in one cell`, `cycle.sh` `cmd_suite`); model floor (ADR-015:
  `model_floor`, `model_below_floor` fails closed, `VULYK_MODEL_FLOOR` overrides); red helpers `sealed_tests`,
  `set_hash` (a missing file hashes as `missing <path>`). Portability helpers (0.44.0): `vulyk_python` sets
  `VULYK_PY` (first of python3/python/py that runs Python 3; preset trusted; call in the current shell, not
  `$(...)`), `sed_inplace <sed-args> <file>` (`-i.bak` then rm), `date_epoch <YYYY-MM-DD|...Z>` (GNU `-d`, else BSD
  `-j -f`), `date_shift <±days> [+fmt]`, `load_sample` (0.47: one `cpu N% top: ...` line, top five processes; CIM
  on Git Bash, `ps`/`uptime` elsewhere; non-zero + stderr reason; used by `cycle.sh suite_load`), `capped_by` (sets
  `VULYK_CAP` = timeout|gtimeout|python|"", each probed with `<it> 1 true`), `run_capped <secs> <cmd>` /
  `run_capped_as <cap> <secs> <cmd>` (exit 124; secs 0 = uncapped; none = runs uncapped with a stderr line).
  `verdict_stale <spec> <head-sha> <pack-fp>` -> `CURRENT` rc 0 / `STALE (pack|commit)` rc 1; a `<sha>..HEAD` that
  is `paperwork_only` stays current. Used by `human-check.sh --check` and ship-check.sh.
- `ship-check.sh <spec-dir>` / `--record` (0.46 `ci` line, `ci_check`: needs a `.github/workflows/*.y*ml` and a
  GitHub `origin`, else `ci: not checked`; `gh run list --commit` for HEAD or the newest commit with only
  paperwork after; only the newest run per `workflowName` (by `createdAt`) is judged (0.47), so a re-run or
  dispatch clears a red; all `success` = ok, failed/pending/none = NOT READY, no/failing `gh` = `cannot confirm
  CI`); `human-check.sh <spec-dir> <ACCEPTED|REJECTED>`; `human-check.sh --show <spec-dir>` (0.48; writes nothing;
  `git diff --stat` then the diff, 300 lines max; base = merge-base with the default branch off it, else parent of
  the commit that added `<spec>/plan.md`, else the empty tree; exit 2 no dir/repo; the Queen pastes it in her reply
  before asking); `scope-check.sh <story-file> [range | --since <claim-head>]` runs in `close-story` (`  ! ` paths -> `--commit`
  exit 4). `human-check.sh`/`acceptance-log.sh` refuse (nothing recorded) when `redact.sh` fails (0.53).
- `py.sh <python-args>` (0.44.0) - `exec "$VULYK_PY" "$@"` via `vulyk_python`; none: exit 2. The spelling for
  Python in `CLAUDE.md` and the commands. `run-capped.py <secs> <cmd>` - the cap `run_capped` falls back to
  (own process group, SIGTERM, 10 s grace, SIGKILL; Windows `taskkill /T`; exit 124).
- `cycle.sh resume` (0.52): when HEAD is not the plan's `**Branch:**` (or, plan names none, `vulyk/<slug>` whose own
  plan copy names itself) and the tree is clean, it `git switch`es there first and the JSON gains `"switched"`; a
  dirty tree is only reported. `branch_guard` itself still never switches.
- `state.sh` - writes `.claude/state.json`/table for `/vulyk-status`. Reads `story:`, `status:`, `wave:`, `tier:`
  from the leading frontmatter block only (0.43.1), so a study report quoting the story template is not a story.
- `model-profile.sh` (ADR-020) - `opus-builds|sonnet-builds|economy`; only `--set` writes; unknown =
  `sonnet-builds`; `--recommend` prints `sonnet-builds <plan>` on every plan (0.49). `top-model.sh`: `--floor` exit
  1 prints `below floor`.
- `hives-behind.sh [--check|--canaries|--busy <hive>|--slug]` (registry, canaries, holds, busy test): `scripts-hives.md`.
  Caller: `/vulyk-ship` step 2a.

## Key contracts
- `cycle.sh`: last stdout line is one JSON object; exits 0 ok · 1 usage · 2 precondition · 3 paused ·
  4 malformed report / red verify · 5 stale · 6 escalate. Other gates exit 0 and report; `telemetry.sh check`
  and `defects-*` are exceptions.
- `is_paperwork_path` whitelist: spec `journal.md`, `council/*`; `memory/stats/{human,acceptance,ship,council,scope,
  anomalies,evolve}.jsonl`; top-level `memory/learnings/*.md`; `VERSION`, `CHANGELOG.md`, `CITATION.cff`; the hive's
  `.claude/vulyk-paperwork` globs. 0.53: `plan.md`/`brief.md` are paperwork only for the lines a cycle script writes
  (`spec_doc_strip`, `cycle.md`); `memory/stats/skills.json` is no paperwork (local, gitignored, not exempt in ship-check).

## Gotchas
- `close-story`'s `## Commands` match, `record-seat`'s taint and `is_paperwork_path` are security-relevant string
  matches: keep them anchored. `close-story` verification runs per line under `capped_by`/`run_capped` (a cap counts
  only if `<it> 1 true` passes: Windows cmd `timeout`; no cap = uncapped, a 124 is then the command's own).
- Scripts target bash 3.2 + BSD userland (macOS CI jobs `full-suite`, `install-smoke` pin `/bin/bash` 3.2, BSD sed,
  no `timeout`): no bare `sed -i`/`python`/`timeout`/`date -d`; run the gate after editing any `.sh`.

last-verified: 2026-11-14 (cycle scripts; 0.53.0-dev.1 audit-fixes-1113: paperwork set, state_get/cycle_state_dir, --since)
