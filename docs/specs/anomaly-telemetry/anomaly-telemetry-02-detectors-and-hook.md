---
story: anomaly-telemetry-02
spec: anomaly-telemetry
status: todo
returned:
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 2
blocked_by: [anomaly-telemetry-01]
---

# Detectors: `scan` verb, `handoff.py measure`, the fail-open hook

## Goal
`scripts/telemetry.sh scan` runs the five detectors and records through the story-01 `record` verb: main-thread context above threshold and subagent prefix-cost / empty-return from transcripts via a new read-only `measure` mode in `handoff.py` built on `context_tokens()`; council rounds from `council.jsonl`; stage duration from each spec's `journal.md`; scope breaches from `scope.jsonl`. A new hook runs `scan` on Stop and SessionEnd, silently and fail-open, so every VULYK terminal logs anomalies without being asked.

## Requirements
> Все терминалы Claude Code с VULYK мониторят аномалии и ведут файл логирования.
> а именно контекстные аномалии, перебор по времени, избыточность Vulik, и такие разные вещи
> контекст сессии выше порога (функция уже есть в handoff.py); субагент дороже N токенов или вернул пусто (читается из его транскрипта); раундов совета больше потолка и стадия дольше бюджета (из journal.md и council.jsonl); отказ или перезапуск драйвера; выход worker'а за скоуп (уже пишется в scope.jsonl).

## Files
- scripts/telemetry.sh
- .claude/hooks/anomaly-scan.sh
- .claude/hooks/handoff.py
- .claude/settings.json
- tests/telemetry.test.sh

## Non-goals
- Do not change `record`, `bundle`, `check`, `consent`, `publish`, `agents`, the enum or either row schema - they are story 01's contract. A detector that needs a contract change reports it in the INTERFACES line.
- Do not record `driver_refused` / `driver_relaunched` - those are event calls from command files (story 03), not scan output.
- Do not measure the still-open last stage of a journal (plan A9). Do not add per-agent-class thresholds (plan A2); the `agent` token is the row's context, not a second threshold.
- Do not modify `context_tokens()`, any existing mode of `handoff.py`, `handoff.sh`, or any existing hook. `measure` is one new entry in `HOOK_MODES` and one new branch in `main()`'s chain (plan A7); no sibling python file.
- Wire the hook in VULYK's own `settings.json` only; wiring into existing hives on upgrade is `install.sh`'s `wire_hook` in story 05 (plan A13).
- Never put the dispatch `name` from `.meta.json` into a row - only `agentType`, mapped through the token set.
- Do not touch `vulyk-cycle.js`, `install.sh`, `scope-check.sh` or `cycle.sh`.

## Map slice
plan.md `## Contracts` (enum, local row, agent token set, `scan`, `measure`, hook) and A2, A7, A12; recon/hooks-and-stats.md §1 (hook wiring shape and fail-open convention), §2 (`context_tokens`, `resolve_window`), §4 (`scope.jsonl` row), §6 (subagent file paths, `.meta.json` beside each, entry shape); recon/weekly-and-publish.md Key types (`council.jsonl` row, `journal.md` line format); memory/map/cycle.md "Report-path recording" for what an empty return looks like.

## Acceptance criteria
- [ ] `python .claude/hooks/handoff.py measure <fixture main transcript>` prints the contract JSON with `tokens` equal to `context_tokens()`'s answer; with `--sidechain` on a fixture subagent file (every entry `isSidechain: true`, a sibling `.meta.json` with `agentType`) it reports `first_prefix`, `assistant_turns`, `last_has_text` and `agent_type`; on a missing file prints `{}` and exits 0; every existing `handoff.py` mode behaves as before (`bash .claude/hooks/handoff.sh status` unchanged).
- [ ] `scan --transcript <fixture>` against a fixture session dir with one subagent file above `VULYK_ANOMALY_AGENT_PREFIX_TOKENS` (`agentType` `cycle-clerk`) and one whose last assistant entry has no text block (`agentType` `my-custom-agent`) records exactly one `agent_prefix_high` row with `agent` `cycle-clerk` and one `agent_empty` row with `agent` `other`, `ref` = `agent:<basename>`; a second scan appends nothing.
- [ ] A fixture main transcript above the context threshold records one `context_high` row with `model` mapped to its alias (`claude-fable-5-1` -> `fable`, opus/sonnet/haiku likewise, else empty) and `agent` empty; the threshold used is percent-of-window when the window resolves, else `VULYK_ANOMALY_CONTEXT_TOKENS`.
- [ ] Fixture `council.jsonl` with a spec at round 3 records `council_rounds_high` (`ref` `council:<spec>`, `spec` and `tier` filled from that spec's `plan.md` `**Tier:**` line when present); a spec at round 2 records nothing.
- [ ] Fixture `journal.md` with two consecutive lines 30 hours apart records `stage_long` value 30 threshold 24; lines 2 hours apart record nothing.
- [ ] Fixture `scope.jsonl` with a row whose `out_of_scope` has two paths records `scope_breach` value 2 with `story` filled; a row with an empty list records nothing.
- [ ] `VULYK_TELEMETRY_SCAN=0 scan` writes nothing; `scan` with no transcript and no session dir still runs the stats-file detectors and exits 0.
- [ ] `anomaly-scan.sh` is wired in `settings.json` on `Stop` and `SessionEnd` beside the existing hooks, prints nothing on the success path, and exits 0 when jq, python or `scripts/telemetry.sh` is missing.

## Verification
`bash tests/telemetry.test.sh && python -m py_compile .claude/hooks/*.py`

## Implementation notes

## Findings
