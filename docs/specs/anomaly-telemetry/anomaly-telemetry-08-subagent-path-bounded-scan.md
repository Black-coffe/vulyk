---
story: anomaly-telemetry-08
spec: anomaly-telemetry
status: todo
returned:
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

## Findings
