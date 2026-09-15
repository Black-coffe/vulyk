---
story: anomaly-telemetry-11
spec: anomaly-telemetry
status: done
returned: DONE
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
- [x] `detect_agents` reads `.vulyk/telemetry/seen/<sid>` once per scan (`<sid>` = transcript basename without `.jsonl`; `mkdir -p` on first write); a subagent file whose basename appears there with its current byte size is not passed to `measure` - the cached JSON on that line drives the same `agent_prefix_high`/`agent_empty` logic as a fresh measure. A file absent from the list, or present with a different size, is measured and its line written (replaced) with `<basename>\t<bytes>\t<measure json>`. Story 08's log-ref check may stay; it is no longer the only bound.
- [x] `agent_empty` under `scan --final` is evaluated from the cached JSON for an unchanged file, so a `SessionEnd` scan on a session whose subagents are all finished and already seen starts no python for them.
- [x] Suite (new case beside case 10, same real layout, same counting `python3` shim): a fixture session with at least 40 under-threshold subagents (`agent-*.jsonl` + `.meta.json` each, prefix below `VULYK_ANOMALY_AGENT_PREFIX_TOKENS`) - the first `scan --transcript` starts python once per subagent (plus the main transcript's); the second `scan --transcript` starts python at most once and no subagent basename appears in the shim's argv log; the seen-list holds one line per subagent; appending one entry to one subagent file makes the third scan measure exactly that file and rewrite its line. `scan` with no `--transcript` writes no seen-list.
- [x] Timing in `## Implementation notes` is of `scan --transcript <real session with ~70 subagents>` on a `git archive HEAD` scratch copy (the reviewer's method - never the real log): first run and second run, wall time and python-start count, against the reviewer's baseline of 74 starts / 25.7-26.5 s. Reject the story yourself if the second run starts python more than once.
- [x] `.vulyk/telemetry/seen/` is never staged: `git status --porcelain` after the suite shows nothing under `.vulyk/`.

## Verification
`bash tests/telemetry.test.sh`

## Implementation notes
- Files: `scripts/telemetry.sh` (`detect_agents`, plus two new helpers `file_bytes` and `measure_fields`), `tests/telemetry.test.sh` (new case 10b).
- **Seen-list.** `detect_agents` loads `.vulyk/telemetry/seen/<sid>` once (newline-anchored string, the `SCAN_SEEN` trick, so one basename never matches inside another), keys each subagent on `<basename>\t<bytes>\t`, and feeds the cached JSON to the same two detectors. A file absent or grown is measured and its line written; the whole list is rewritten once at the end of the `find` loop, so a line for a file that no longer exists is dropped with it. Story 08's log-ref check stays, now only as the cheap skip for a file already recorded under every code this scan could write.
- **Why the byte size, not the line count or an mtime:** exact, content-derived and free (`wc -c`), and a subagent transcript only ever grows.
- **Second change in the same loop, and it is the one worth reviewing:** the four `jq` calls per subagent became one `jq` for the WHOLE seen-list at load (`jq -R -r` over the TSV, fields looked up by the same key) plus one `measure_fields` jq for a freshly measured file. Without it a steady-state scan still cost ~20 s on the real session - ~290 jq spawns at ~50 ms each on Windows - and the story's own timing bar would have read 20 s against a 26 s baseline. A cached line the batch pass cannot parse falls back to a per-file jq, so a corrupt list degrades to the old cost, never to a wrong answer.
- **Timing, reviewer's method** (`git archive HEAD` scratch copy + a counting `python3` shim, real session `7670018b-…` with 73 subagents, this Windows hive, runs interleaved back to back): HEAD **29.0 s / 74 starts**, then **28.5 s / 74 starts** - the same cost every run, matching the reviewer's 74 starts / 25.7-26.5 s. New code **22.6 s / 74 starts** cold (one measure per subagent, once per lifetime), then **6.8 s / 1 start** and **7.1 s / 1 start**; `--final` is also **1 start**. The residual ~7 s is `find` + 73 `wc -c` + `record`/`jq` outside `detect_agents`, not python.
- Suite: case 10b, 40 under-threshold subagents plus one over-threshold with a `tool_use` last entry (so the cached JSON is proven to drive `agent_prefix_high` and `--final` `agent_empty`, not just the skip); a second `python3` shim logs argv, so "no python for this file" is asserted by basename, not only by a count. 206 checks, 0 failed.
- `git status --porcelain` after the suite: nothing under `.vulyk/` (the suite works in its own temp hive; `.gitignore:33` covers the real one).
- Trap for the next worker on this file: the Bash tool strips one level of backslash from a heredoc'd Python script, so `"\t"` in a patch script arrives as a tab escape and `"\\n"` silently becomes a line continuation. Build backslashes with `chr(92)` when patching this suite.

## Findings
