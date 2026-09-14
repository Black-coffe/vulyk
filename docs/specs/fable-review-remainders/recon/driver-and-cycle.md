# Scout: driver dead-worker path, record-seat, release vs PAUSE (2026-09-14, drone-scout on sonnet)

## Driver `.claude/workflows/vulyk-cycle.js`
- Worker dispatch :145-152 - `parallel(...)`, each thunk `.catch(e => { log('worker threw: '+e.message); return null })`. A thrown agent() folds to null.
- A maxTurns-killed subagent resolves with `''` (driver.test.sh scenario (g) :265-280); `worker threw:` never fires for it.
- Classification :159 `typeof report === 'string' && report.trim() !== ''`; else :167 `lastError.set(file, 'worker returned no report')` - same wording for throw, empty resolve, cap death. No distinct cap reason exists (plan.md:161 names the gap).
- Two-miss stop :169-171 `{verb:'build', file, error}`. `Stop/Paused/BadLine` :35-47, caught :225-229. `clerk()` :53-62 parses the last stdout line; non-JSON -> BadLine; exit 3 -> Paused.
- Retry prompt :146-150 ("uncommitted edits ... git diff first"), model `opus`.
- `dispatchSeat` :93-102; Tier 4 review forks two agent() calls, `foldReviews` :76-89.
- `recordSeat` :183-187: heredoc delimiter `VULYK_<stamp>_<seat>_<attempt>`, `clerk('record-seat ... --stamp <stamp> <<'d'\n<body>\nd')` - the whole seat report is inline in the clerk's prompt. Exit 4 retry :196-198. lead-review records through the same path as seat `review`.
- `.claude/agents/cycle-clerk.md`: Bash only, sonnet, maxTurns 5; rule: `timeout: 600000` on every Bash call; last stdout line is the whole reply. The timeout rule lives only in the agent file (plan.md:104).
- tests/driver.test.sh: compiles the driver as `AsyncFunction(args, agent, parallel, pipeline, phase, log)` (:39-41); `run(args, script)` :100-146 with `script.clerk` (stub last lines) and `script.agents` (replies; `{throw:'msg'}` rejects); `withClaim()` :151-153 brackets claim/release. A cap-death scenario slots beside (g)/(o) with an `''` agents entry.

## `scripts/cycle.sh` record-seat / judge
- `cmd_record_seat` :1302-1373: `<spec> <N> <seat> [--model id] [--stamp s]`, report on stdin only (`REPORT="$(cat)"` :1366). `pause_guard`/`driver_guard` :1336-1337; open round :1340; stale :1346; already recorded :1352; attempts via `<seat>.attempt-K.md` :1357-1364, third = ABSENT exit 2.
- `SEAT=review` -> `cmd_record_seat_review` :1164-1186 (first line `VERDICT: PASS|BLOCK`, else attempt file + exit 4); else `cmd_record_seat_council` :1188-1293 (`reject_seat_report` at :1196,1199,1208,1216,1224,1227,1237,1254; attempt-2 leniency :1258-1287; `write_seat_file` :1291).
- No `--file` / `-` variant exists; a `--file <path>` branch goes before :1366 with stdin as fallback.
- council.test.sh record-seat scenarios: :646-660 preconditions; :661-703 staleness; :704-802 MALFORMED; :804-836 taint under real slug; :837-859 R8; :860-896 attempt-2 leniency; :897+ third attempt. Story 17 DRIVER block :2468-2690 (`probe_release`/`probe_pauserelease` :2649-2690). No scenario feeds record-seat from a file.

## `release` vs PAUSE (major 4)
- `pause_guard` cycle.sh:111-119 exits 3 unconditionally when `PAUSE` exists.
- `cmd_release` :2044-2063 calls `pause_guard "$SPEC" release` at :2051 - never reaches the stamp match / `rm -f DRIVER` at :2053-2062 on a paused spec.
- Prose claiming exit 0: `vulyk-cycle.js:231-233` (comment; release wrapped in `.catch(() => {})` :233), `.claude/commands/vulyk-build.md:87-88`, story 13 Non-goals line 29. `cmd_pause` :1953-1974 already deletes `DRIVER`.
- Tests: `claim under PAUSE exits 3` :2490-2493 exists; no scenario calls `release` under PAUSE.
- Variant 1: drop the guard call at :2051; add `release` to the exempt list at docs/adr/001-cycle-state-contract.md:160 (+ D2 verb table). Variant 2: keep exit 3, fix the three prose sites.
- Gotcha: `Glob`/`Grep` with a directory `path` returned nothing for this scout; exact `Read` paths worked.
