# Scout report: scripts/cycle.sh defect sites (drone-scout, 2026-09-15, verified against cycle.sh directly)

## 1. `open-round` "working tree not clean" (`cmd_open_round`, scripts/cycle.sh:1755; guard :1804-1820)
- `git status --porcelain` (:1805); per line, `is_paperwork_path "${line:3}"` (lib.sh); any non-paperwork path -> `emit false open-round 2 error "working tree not clean"`, dirty lines to stderr (:1817-1818).
- `is_paperwork_path()` whitelist: `docs/specs/*/{plan.md,journal.md,council/*,brief.md}` + six `memory/stats/*.jsonl` (`human`, `acceptance`, `ship`, `council`, `scope`, `anomalies`). The same predicate drives staleness (`paperwork_only()`).
- Hook-written files today: `anomalies.jsonl` whitelisted (v0.14.0); `memory/stats/skills.json` NOT (different filename, `.json`); `memory/learnings/*.md` NOT; `.claude/state.json` gitignored (moot).
- No other cycle.sh verb repeats this literal check. `ship-check.sh` stage 03 has its own, stricter clean-tree check (tests/cycle.test.sh:71,245,253,258: `skills.json`-alone and `council.jsonl`-alone both refuse there) - ship-check.sh itself not opened.
- Tests: tests/council.test.sh:1519-1525 (`open-round: preconditions - dirty tree -> exit 2`); :676-698 paperwork-only commits do not trip it.

## 2. `close-story` "already done" (`cmd_close_story`, :1469; guard :1480-1493)
- `ST=$(fm_field "$STORY" status)`; `todo|in-progress` proceed; `done` -> exit 2 `already done`; anything else -> exit 2 `status '$ST', expected todo or in-progress` (:1489-1490).
- The guard is the first check - before scope-check (:1514), before the `returned:` check, before verification. `status: done` is written only by close-story itself: :1589 (`--commit`, before `git commit`, reverted :1594 on commit failure) and :1600 (no `--commit`).
- If bypassed for an already-`done` story with an uncommitted diff: scope-check would run again, the commit path (:1569-1598) would re-stage `files_of "$STORY"` and cut a second `story(<id>)` commit; `status --json` (:306-357) reads only `status:` so it would fold either way.
- Tests: tests/council.test.sh:1105-1107 (`close-story: exit 2 on an already-done story`), after :1097-1103.

## 3. `taint_reason()` (:1145-1157), called `taint_reason "$REPORT" "$SLUG"` at :1205
- Scans the WHOLE report string with `grep -qE`; no line-type distinction (`run:` vs `saw:`/`why:`).
- Patterns, first hit wins, slug regex-escaped (:1151): (1) `\b<slug>-[0-9]{2}\b` (:1152); (2) `(docs/specs/)?\b<slug>/plan\.md` (:1153); (3) `.../journal\.md` (:1154); (4) `.../council/` (:1155).
- Round-6 evidence: `.vulyk/reports/anomaly-telemetry/round-6/haiku.attempt-2.md:8` - the seat's own `run:` `bash scripts/telemetry.sh record ... --story anomaly-telemetry-14 ...` and the `saw:` JSON echo both carry the id; the id is a synthesized CLI value, not a court leak.
- Tests: tests/council.test.sh:756-801 (`report_taint()` helper): `demo-01` in body tainted (:764-766); bare `plan.md`/`journal.md`/`council/` not (:767-771); `<slug>/plan.md` etc. tainted (:777-785); `docs/specs/<slug>/plan.md` tainted (:787-788); `<slug>-N` one digit not (:790-791); `vulyk-plan.md`, literal `<spec>/journal.md` not (:794-798); another spec's path not (:800-801). No test isolates a `run:` line.

## 4. `status --json` (`cmd_status`, :278-451)
- One JSON object, one `printf` (:445-450); no other stdout in the body. `--json` is not parsed as a flag anywhere - dispatcher (:2091-2099) always calls `cmd_status "$SPEC"`; the flag is convention.
- No verb writes output to a file; the only `--file` is `record-seat`'s INPUT (:1309-1340).
- Tests: tests/council.test.sh:168-186 (`status --json: exactly one JSON object with every C3 key`, `lines -eq 1` at :178).
