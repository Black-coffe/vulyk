---
story: weekly-budget-01
spec: weekly-budget
status: todo
returned:
tier: 4
worker: worker-code
wave: 1
blocked_by: []
---

# M1, M3, M4: the guarded `/usage` call, the clerk's Bash ceiling, the 1 pp step rate

## Goal
Three numbers ADR-028 hangs on exist in `docs/specs/weekly-budget/measure-poller.json`, each with the gap between the setup and
a real build stated beside it, plus three synthetic fixtures with the real stream shape that story 03's tests read. No product
file changes. All probes run in the foreground (ADR-024), from a fresh temp dir outside any repo, never in this checkout.

## Requirements
> 1. Данные: /usage с кэшем, журнал на каждый аккаунт; предохранитель: только бесплатный ответ, иначе стоп.
> 3. Формула: (остаток-резерв)/дни; окна 1ч/24ч; прогноз; предупреждение / разгон; 5ч-окно где есть.
> чтобы он опирался на семидневный лимит, высчитывал, сколько процентов осталось, высчитывал, сколько дней осталось

## Files
- docs/specs/weekly-budget/measure-poller.json
- tests/fixtures/budget/usage-report.json
- tests/fixtures/budget/usage-noreport.json
- tests/fixtures/budget/usage-misfire.json
- tests/model-profile.test.sh

## Non-goals
- Never run the unguarded form (no `MSYS_NO_PATHCONV=1` under Git Bash): it is a paid model call. Every probe pins `--model haiku`.
- No `scripts/budget.sh`, no helper script committed: probe commands live in the scratch dir and in `## Implementation notes`.
- No owner data in any committed file: no absolute percents, reset times, session ids, paths, account or org names. M4 records
  deltas only (pp steps and minutes between them). Fixture values are synthetic; only keys and nesting are real.
- No OAuth endpoint, no `.credentials.json`, no third-party cache (ADR-028 fork 6).

## Map slice
`memory/map/scripts.md` «Entry points» (`run-capped.py`, `py.sh`), «Gotchas»; `memory/map/agents-and-commands.md` «Agents»
(`cycle-clerk`). Read ADR-028 «Measurements» and recon.md «Probe».

## Acceptance criteria
- `tests/model-profile.test.sh` gains a part that fails unless `docs/specs/weekly-budget/measure-poller.json` exists, parses, and records `cost_usd` and `local_command` for every shell measured, and the three fixtures parse (the JSON row alone cannot fail: close-story verifies before `git add`).
- [ ] **M1** for Git Bash (`MSYS_NO_PATHCONV=1`) and PowerShell: `MSYS_NO_PATHCONV=1 VULYK_BUDGET_POLLING=1 claude -p "/usage"
      --output-format stream-json --verbose --model haiku` run three times each; recorded per shell: `total_cost_usd`,
      `local_command_run.command`, wall seconds (min/max), the `limits[].kind` values seen, whether `percent` is an integer, the
      `severity` and `is_active` values seen with one line on what they appear to mean; whether user- or project-scope hooks
      fired with cwd = the temp dir (marker-file test); where the `-p` transcript lands and whether `token-report.py` or
      `anomaly-scan.sh` would read that dir. **Gate:** any guarded run with `total_cost_usd != 0` or no `local_command_run` ->
      `returned: NEEDS_CONTEXT` with the raw lines in `## Findings`; stop probing.
- [ ] **M3**: through headless `claude -p` with the `cycle-clerk` agent, the longest single Bash call (try ~30, ~60, ~100 s)
      the clerk returns from with its last stdout line intact. Recorded with `decision`: `poll-in-advance` when ≥ 100 s, else
      `no-poll` (then `advance` calls `gate --no-poll` and hooks alone refresh). Not a stop either way.
- [ ] **M4**: guarded readings every ~15 min over ≤ 120 min while wave 1 runs (story 02 spends real tokens meanwhile); per
      window kind: count of readings, distinct values, pp moved, minutes between steps, and a recommended rate floor
      (`min_span_min`, `min_pp`). Fewer than 2 distinct values is a result, not a stop: `rate_floor_rec` = ADR-028's (20 min,
      1 pp), `confirmed: false`.
- [ ] `measure-poller.json`: `{"cc_version", "m1":{"shells":[{"shell","runs","cost_usd_max","local_command","wall_s":[min,max],
      "kinds":[...],"percent_int"}],"severity_seen","is_active_seen","hooks_fired_in_poll_cwd","transcript_read_by_vulyk",
      "not_measured":[...]},"m3":{"clerk_bash_max_s","decision"},"m4":{...,"rate_floor_rec","confirmed"},"gaps":[...]}`;
      `not_measured` names macOS zsh, Linux bash and an API-key config dir; `gaps` says how each setup differs from a real build.
- [ ] Fixtures (each a JSON array of the stream events): `usage-report.json` (one `weekly_all`, one `weekly_scoped` with
      `scope.model.display_name: "Fable"`, one `session`), `usage-noreport.json` (local command, cost 0, `usage_report` with no
      `limits[]`), `usage-misfire.json` (`total_cost_usd` > 0 and no `local_command_run`).

## Verification
`bash tests/model-profile.test.sh`

## Implementation notes

## Findings
