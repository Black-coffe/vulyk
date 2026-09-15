---
story: anomaly-telemetry-08
spec: anomaly-telemetry
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 6
blocked_by: [anomaly-telemetry-02, anomaly-telemetry-07]
---

# Fix (council round 2, review Critical 1 + Majors 5, 6): the agent detectors must see real subagents, and a Stop-hook scan must be bounded

## Goal
`scan` resolves a session's subagents where Claude Code writes them - `<dirname>/<transcript basename without .jsonl>/subagents/` and its `workflows/<wf>/` subdirectories (recon/hooks-and-stats.md §6) - not beside the main transcript, so `agent_prefix_high` and `agent_empty` fire in a real hive (today: 0 agent rows in the committed log; 233 real files under four session dirs, none where the code looks). The suite's fixture mirrors that layout, so case 10 fails when the path is wrong. A `Stop`-hook scan is bounded: the current session's subagents only, no python start for a file already recorded, one `jq` pass per stats file instead of per-row spawns (31 s measured in round 1 with no transcript at all). `agent_empty` is recorded only for a finished transcript, so a worker mid-turn at `Stop` time never becomes a permanent false row.

## Requirements
> Все терминалы Claude Code с VULYK мониторят аномалии и ведут файл логирования.
> субагент дороже N токенов или вернул пусто (читается из его транскрипта)
> Правильно завернуто в фреймворк VULYK, чтобы не потерялось.

## Files
- scripts/telemetry.sh
- .claude/hooks/anomaly-scan.sh
- .claude/hooks/handoff.py
- tests/telemetry.test.sh

## Non-goals
- Do not change `record`, `bundle`, `check`'s key/enum rules, `consent`, `publish`, `inbox`, the enum, either row schema or the agent token set. Two fold-ins below touch `recipe_pr` and one regex in `check`; nothing else in those verbs.
- Do not add a per-machine marker file, a cache or a "last scanned" ledger (review option rejected in plan A17): the bound comes from scope (this session's subagents), the existing (code, ref) dedupe checked *before* spawning python, and single-pass jq.
- Do not change what `handoff.py measure` prints, and do not touch `context_tokens()` or any other mode. Finding 16 is a stdin fix only.
- Do not touch `install.sh` (`wire_hook` needs no change), `docs/telemetry.md`, `cycle.sh`, `ship-check.sh`, `scope-check.sh` - stories 09 and 10 own those; story 10 (wave 7) rewrites the docs for what this story changes, so record the final semantics in `## Implementation notes`.
- Do not fix review findings 7, 9, 10, 11-docs, 12-paperwork here.

## Map slice
plan.md `## Contracts` (`scan`, `measure`, hook, local row `ref` rules) and A2, A12, A17; recon/hooks-and-stats.md §1 (hook stdin payload, fail-open shape), §6 (real subagent paths, `.meta.json` beside each file, `isSidechain`); `council/round-2/review.md` findings 1, 5, 6, 8, 12 and opus UNASKED (1)-(2) as summarised in plan `## Plan deltas` 2026-09-15 round 3; story 02 `## Implementation notes` (the PATH-shim bash trick, `< /dev/null` on `measure`).

## Acceptance criteria
- [ ] Critical 1: `scan --transcript <p>` looks for subagents at `$(dirname p)/$(basename p .jsonl)/subagents/` recursively (`agent-*.jsonl` directly there and under `workflows/*/`); nothing is read from `$(dirname p)/subagents/`. The suite fixture is `<tmp>/<sid>.jsonl` + `<tmp>/<sid>/subagents/agent-a1.jsonl` + `<tmp>/<sid>/subagents/workflows/wf1/agent-a2.jsonl` (each with its `.meta.json`); a control file at `<tmp>/subagents/agent-a3.jsonl` above threshold must produce no row. Existing case 10 is rewritten to this layout, not duplicated.
- [ ] Major 5 (bounded): with no `--transcript`, `scan` reads no subagent file; `detect_agents` greps the log once for existing `agent:<basename>` refs and never runs `measure` on a file whose ref is already present under both agent codes; `detect_council`, `detect_stage`, `detect_scope` each make at most one `jq` (or `awk`) pass over their file and no per-row `jq`/`date`/`grep` spawns. Worker records `time bash scripts/telemetry.sh scan` (no transcript, committed log) before and after in `## Implementation notes`.
- [ ] Major 6 (`agent_empty` only when finished): `anomaly-scan.sh` reads `hook_event_name` from the hook payload and passes `--final` to `scan` on `SessionEnd`; without `--final`, `agent_empty` is neither recorded nor deduped away (`agent_prefix_high` still is). Suite: a subagent whose last assistant entry is a `tool_use` yields no `agent_empty` row from a plain scan, and one row from `scan --final`; a second `--final` scan appends nothing.
- [ ] Finding 16: `python .claude/hooks/handoff.py measure <f>` with stdin attached to a terminal (suite: `</dev/tty` when available, else a FIFO nobody writes with a 5 s `timeout`) returns without blocking - `measure` is dispatched before the hook-payload stdin read, or removed from `HOOK_MODES`.
- [ ] Finding 15: `spec_tier` accepts a `spec` only if it matches `^[A-Za-z0-9._-]+$`; anything else yields tier 0 and no path is built (suite: a `council.jsonl` row with `spec` `../x` records `council_rounds_high` with `spec` `""`, tier 0).
- [ ] Finding 11 (dedupe): `scope_breach`'s `ref` becomes `scope:<story>` (one row per story, first breach wins) - contract updated in plan.md; suite: two `scope.jsonl` rows for the same story yield one row.
- [ ] Fold-in, finding 8 (same file): with rows in two weeks and no local checkout, `publish` prints the fork/`cd` step once and each week's block starts from `git switch <default-branch>` before `git switch -c telemetry/<week>-<hive>`, so each PR carries exactly one week; the existing ordered-needle case covers both blocks. Opus UNASKED (1): `check`'s `vulyk` regex is anchored `^\d+\.\d+\.\d+$` (suite: `1.2.3-x` rejected).

## Verification
`bash tests/telemetry.test.sh`

## Implementation notes
- Files: `scripts/telemetry.sh`, `.claude/hooks/anomaly-scan.sh`, `.claude/hooks/handoff.py`, `tests/telemetry.test.sh`. Final semantics for story 10's docs rewrite are below.
- **Subagent path (Critical 1).** `detect_agents` takes the main transcript and reads `$(dirname p)/$(basename p .jsonl)/subagents/**/agent-*.jsonl` (one `find`); `$(dirname p)/subagents/` is never touched. With no `--transcript` it returns before any `find`, so a bare `scan` opens no subagent file.
- **Bound (Major 5).** One `sed` pass over the log per scan builds `SCAN_SEEN` (`<code> <ref>` pairs, newline-delimited and newline-anchored, so `scope:a` does not match `scope:abc`); every detector asks it before working, so python never starts for an already-recorded subagent and `record` is not called for an already-recorded breach. `detect_scope` is one `jq` pass (was three `jq` per row); `detect_stage` is one `awk` pass per journal with the ISO timestamp converted inside awk by days-from-civil (was a `date` spawn per line).
- **Timing, re-measured on a throwaway copy of `HEAD` so the real log stayed clean** (`time bash scripts/telemetry.sh scan`, no transcript, committed 93-row log, this Windows hive): old code **33.6 s, then 32.8 s on a second run** - it pays the same cost every time; new code **19.6 s on the first run, 1.1 s in steady state**. The one-off 19.6 s is the ref migration recording the `scope_breach` rows under their new `scope:<story>` ref: that is `record`'s own per-row subprocess cost, out of scope here, and it happens once per hive.
- **`agent_empty` (Major 6).** Recorded under `scan --final` only; the hook reads `.hook_event_name` and passes `--final` on `SessionEnd`. A file is skipped on a `Stop` scan once its `agent_prefix_high` row exists, and on a `--final` scan only when its `agent_empty` row exists too - so a subagent that ends non-empty is re-measured once per SessionEnd, never once per turn.
- **Contract folded in:** `spec_tier`/`detect_council` reject a spec outside `^[A-Za-z0-9._-]+$` via `valid_slug` (row carries `spec:""`, tier 0; ref stays `council:<raw>` so the anomaly is still recorded once); `scope_breach` ref is `scope:<story>`, falling back to `scope:<ts>` only for a row with no story; `check`'s `vulyk` rule is anchored `^[0-9]+[.][0-9]+[.][0-9]+$`; `publish` prints one fork/`cd` for all weeks and each week's block starts `git switch "$base"`. plan.md already carried all four contract lines from the planner's round-3 delta, so no paperwork edit was needed.
- **Two decisions worth review.** (1) The PR recipe captures `base="$(git rev-parse --abbrev-ref HEAD)"` right after the clone instead of printing a literal default-branch name: the fork's default branch is not knowable from a hive, and nothing in this script may run a command to find out. (2) Anchoring `vulyk` made `check`'s anonymization guard unreachable (every remaining string field is shape-anchored, so a path would be reported as that field's own failure), so the guard was moved to run first among the value rules. The rule set is unchanged; only which reason is reported first.
- Suite: case 10 rewritten (not duplicated) to the real layout - session dir + `workflows/wf1/`, plus a control file at `<tmp>/subagents/agent-a3.jsonl` that must produce no row - with a counting `python3` shim proving the second scan starts no interpreter for an already-recorded subagent. The hook cases now export `VULYK_HIVE="$HIVE"`: the hook itself resolves its root from `CLAUDE_PROJECT_DIR`, but the `telemetry.sh` it execs resolved `ROOT` by `git rev-parse`, so the suite had been appending rows to the real repo's `memory/stats/anomalies.jsonl`.
- `handoff.py measure` is dispatched at the top of `main()` and dropped from `HOOK_MODES`; `mode_measure` already exits, so nothing after it runs. No other mode and no printed output changed.
- **Handover / trap worth knowing.** A previous attempt left the code correct but destroyed this story's `## Map slice`, `## Acceptance criteria` and `## Verification` sections. Cause: the exact string `## Implementation notes` also appears *inside* a Non-goals bullet, so a naive "split the file on that marker" appends notes over the middle of the story. I reproduced the same corruption once before anchoring on a line that equals the heading. Anyone scripting an append to a story file should match the heading at line start, not as a substring.

## Findings
