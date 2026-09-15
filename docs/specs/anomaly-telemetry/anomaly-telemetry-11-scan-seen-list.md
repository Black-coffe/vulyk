---
story: anomaly-telemetry-11
spec: anomaly-telemetry
status: todo
returned:
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 8
blocked_by: [anomaly-telemetry-08]
---

# Fix (round-3 review Critical 1): a subagent is measured once per lifetime - per-session seen-list under `.vulyk/`

## Goal
Story 08's bound skips a subagent only when its `agent_prefix_high` ref is already in the log, so a subagent under threshold is never recorded and is re-measured (one python start) on every `Stop`. Measured by the round-3 reviewer on a real 73-subagent session of this hive: 74 python starts and 25.7-26.5 s per `scan --transcript`, on every run; story 08's "1.1 s steady state" was timed on the no-transcript path that skips `detect_agents` entirely. After this story `detect_agents` keeps a per-session seen-list under `.vulyk/telemetry/seen/` (A18, `## Contracts` "Seen-list") that caches `measure`'s output per subagent file keyed by its byte size, so a finished subagent - anomalous or not - never starts python again, and a steady-state `scan --transcript` on a session with ~70 subagents starts python at most once (the main transcript's own measure).

## Requirements
> Все терминалы Claude Code с VULYK мониторят аномалии и ведут файл логирования.
> субагент дороже N токенов или вернул пусто (читается из его транскрипта)
> Правильно завернуто в фреймворк VULYK, чтобы не потерялось.
> owner 2026-09-15: repair the round-3 review's three findings only - bounded Stop-hook scan (record under-threshold subagents so they are never re-measured), docs/telemetry.md recipe brought to story 08's shape, skills.json back under the scope gate - then up to three more rounds

## Files
- scripts/telemetry.sh
- tests/telemetry.test.sh

## Non-goals
- Do not add a marker row to `memory/stats/anomalies.jsonl`, a new enum code, or any change to `record`, `bundle`, `check`, either row schema or the agent token set. The seen-list lives outside the log (A18); the committed log stays anomalies only.
- Do not change what `handoff.py measure` prints, and do not touch `handoff.py` or `.claude/hooks/anomaly-scan.sh` (round-3 Minor 5, the hook's `VULYK_HIVE` export, is NOT in this repair - the owner limited it to three findings).
- Do not change the `--final` semantics of `agent_empty` (A17) or the subagent path (`<dirname>/<sid>/subagents/**`, story 08). The seen-list feeds the existing detector logic the cached JSON instead of a fresh one; the detectors themselves are unchanged.
- Do not add an mtime or age guard; the cache key is the file's byte size, exact and content-derived.
- Do not fold round-3 Minors 6, 7, 11 or anything in `publish`, `inbox`, `docs/telemetry.md`, `scope-check.sh`, `ship-check.sh` (story 12 holds the last three this wave).
- Do not write anywhere but `.vulyk/telemetry/seen/` (already gitignored via `.vulyk/`, A5); no new `.gitignore` entry, no `shippable()` change.

## Map slice
plan.md A17, A18 and `## Contracts` (`scan` verb, "Seen-list", `measure` output, local row `ref` rules); `council/round-3/review.md` Critical 1 (the numbers, the reviewer's method: `git archive` scratch copy + python-counting shim); story 08 `## Implementation notes` (`SCAN_SEEN` sed pass, case 10's counting `python3` shim, the `## Implementation notes` substring trap when appending notes).

## Acceptance criteria
- [ ] `detect_agents` reads `.vulyk/telemetry/seen/<sid>` once per scan (`<sid>` = transcript basename without `.jsonl`; `mkdir -p` on first write); a subagent file whose basename appears there with its current byte size is not passed to `measure` - the cached JSON on that line drives the same `agent_prefix_high`/`agent_empty` logic as a fresh measure. A file absent from the list, or present with a different size, is measured and its line written (replaced) with `<basename>\t<bytes>\t<measure json>`. Story 08's log-ref check may stay; it is no longer the only bound.
- [ ] `agent_empty` under `scan --final` is evaluated from the cached JSON for an unchanged file, so a `SessionEnd` scan on a session whose subagents are all finished and already seen starts no python for them.
- [ ] Suite (new case beside case 10, same real layout, same counting `python3` shim): a fixture session with at least 40 under-threshold subagents (`agent-*.jsonl` + `.meta.json` each, prefix below `VULYK_ANOMALY_AGENT_PREFIX_TOKENS`) - the first `scan --transcript` starts python once per subagent (plus the main transcript's); the second `scan --transcript` starts python at most once and no subagent basename appears in the shim's argv log; the seen-list holds one line per subagent; appending one entry to one subagent file makes the third scan measure exactly that file and rewrite its line. `scan` with no `--transcript` writes no seen-list.
- [ ] Timing in `## Implementation notes` is of `scan --transcript <real session with ~70 subagents>` on a `git archive HEAD` scratch copy (the reviewer's method - never the real log): first run and second run, wall time and python-start count, against the reviewer's baseline of 74 starts / 25.7-26.5 s. Reject the story yourself if the second run starts python more than once.
- [ ] `.vulyk/telemetry/seen/` is never staged: `git status --porcelain` after the suite shows nothing under `.vulyk/`.

## Verification
`bash tests/telemetry.test.sh`

## Implementation notes

## Findings
