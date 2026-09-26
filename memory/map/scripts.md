# Scout report: scripts/

## Purpose
Every deterministic (model-free) gate and helper VULYK runs on. Four families: the cycle's state
machine (`cycle.sh` + `lib.sh` + `journal.sh`; see `memory/map/cycle.md`), the report-only gates
(`ship-check.sh`, `human-check.sh`, `acceptance-log.sh`, `scope-check.sh`, `wave-check.sh`,
`trace-check.sh`, `release-check.sh`), `telemetry.sh` (opt-in anomaly telemetry,
`docs/telemetry.md`) and `token-report.py` (spend per spec, 0.18). Shell scripts are
`#!/usr/bin/env bash`, `set -u`, safe to re-run.

## Entry points
- `cycle.sh <verb> <spec-dir> [...]` - the cycle's CLI. Callers: the Queen's own Bash (solo
  `/vulyk-build` at Tier 1-2, `/vulyk-review`, `/vulyk-plan` `briefed`, `/vulyk-pause`/`resume`),
  `cycle-clerk` for the Workflow driver (only `advance`, `status`, `release`), workers
  (`close-story`). `advance` is the loop's one stepping verb since 0.18.
- `journal.sh <spec-dir> <stage> "<what>" "<next>"` - appends one line to `journal.md`; called by
  `cycle.sh`, `/vulyk-build` (hive launch line) and `/vulyk-plan` (approval line).
- `lib.sh` - sourced only. `is_story_file` :16, `pack_fingerprint` :27, `is_paperwork_path` :54,
  `paperwork_only` :68, `marker` :82, `constitution_file` :94 (`CLAUDE.vulyk.md` if present, else
  `CLAUDE.md` - every constitution read goes through it), `command_cell_exists` :98,
  `verification_segments` :114, `profile_value` :125, `client_path_filled` :142, `now_ts`, `slug_of`.
- `ship-check.sh <spec-dir>` / `--record <spec-dir> <version> [note]` - stage 06, `/vulyk-ship` 1, 4.
- `human-check.sh <spec-dir> <ACCEPTED|REJECTED> [note]` / `--check` - the owner's override.
- `acceptance-log.sh` - **legacy** pre-council ledger; `ship-check.sh`'s fallback only.
- `scope-check.sh <story-file> [range]` - run by `close-story`. Without a range it also excludes
  the `## Files` (and story files) of not-done sibling stories of the same spec (:27, :103-115).
- `wave-check.sh <spec-dir>` - `/vulyk-plan` step 7 only (not re-run by the build). Classes include
  `no-verify`, `verify-gap`, and `verify-cell` (:29): a `## Verification` segment that is not a
  `## Commands` cell of `constitution_file`.
- `trace-check.sh <spec-dir>` - `/vulyk-plan` step 7. A `## Requirements` quote may match the
  brief, a plan delta, or a `## Asks` item (:52-56, what repair stories quote).
- `token-report.py <project> [--spec <slug>] [--since YYYY-MM-DD] [--json] [--projects-root]` -
  reads `~/.claude/projects/<encoded>/` (main sessions, subagents incl. workflow agents, Workflow
  run records) + `memory/stats/council.jsonl`. Dedupes by `message.id`; raw = input + write + read
  + output; weighted = input + 1.25×write5m + 2×write1h + 0.1×read + output; never uses Workflow
  `totalTokens`. Attribution `slug_named_by` :104 / `collect` :258; output `print_human` :460.
  Called by `/vulyk-status` (14 days) and `/vulyk-evolve` (7 days). Stdlib only.
- `release-check.sh [count]` - the 1.0.0 meter, by hand.
- `top-model.sh` / `--explain` / `--apply` / `--check` - resolves the gate alias from
  `~/.claude.json`; `--apply` pins the Queen to `opus`. Callers: `/vulyk-bootstrap`, `/vulyk-plan`
  (Tier 4), `/vulyk-build` (hive), `/vulyk-status`, `top-model-brief.sh`.
- `redact.sh` - stdin→stdout secret mask; used by `/vulyk-plan` (brief.md), `handoff.py`, and the
  note writers in `cycle.sh` (`redact_note` :106), `human-check.sh`, `ship-check.sh`,
  `acceptance-log.sh`.
- `state.sh [spec-dir]` - gitignored `.claude/state.json`, read by `/vulyk-status` only.
- `vulyk-update.sh [dir] [--check] [--version X] [--telemetry ..] [--constitution replace]` -
  fetches a release and hands off to its own `install.sh --upgrade`, passing `--constitution
  replace` through.
- `git-hooks/post-merge` (sample) - stamps `memory/map/.stale`.
- `telemetry.sh <verb>` - `enum` (8 codes), `agents` (fixed token set incl. retired
  `council-sonnet`, then `other`), `consent`, `record`, `scan [--final]`, `bundle`, `check`,
  `publish [--dry-run]` (prints a recipe, never sends), `inbox [--clear]` (VULYK repo only).
  Callers: `.claude/hooks/anomaly-scan.sh` (SessionEnd only since 0.18), `/vulyk-build`
  (`driver_refused` when the Workflow call throws), `/vulyk-resume` (`driver_relaunched`),
  `/vulyk-evolve`.

## Key contracts
- `cycle.sh`: last stdout line is one JSON object on every exit; exits 0 ok · 1 usage ·
  2 precondition · 3 paused · 4 malformed report / red verification · 5 stale · 6 escalate.
- The other gates always exit 0 and report; refusal is the calling command's job.
  `telemetry.sh check` is the one non-cycle verb whose exit code carries meaning.
- `is_paperwork_path` whitelist: `docs/specs/*/{plan.md,journal.md,brief.md,council/*}`,
  `memory/stats/{human,acceptance,ship,council,scope,anomalies}.jsonl`, `memory/stats/skills.json`,
  `memory/learnings/*.md` (one level), `VERSION`, `CHANGELOG.md` (0.18). `paperwork_only`,
  `open-round`'s and `claim`'s dirty-tree checks, and the staleness checks all go through it.
- `telemetry.sh` `ENUM` and `AGENTS` are append-only public contracts; bundle rows have 10 keys,
  codes and numbers only; `check`'s anonymization guard runs first.

## Dependencies
- inbound: the commands above; `cycle-clerk`; `.claude/hooks/top-model-brief.sh`,
  `anomaly-scan.sh`; `install.sh` (Telemetry row, hook wiring).
- outbound: `cycle.sh` → `git` (worktree, rev-parse, status, diff, commit), `lib.sh`,
  `journal.sh`, `scope-check.sh`, `redact.sh`, GNU `timeout` when it works; `telemetry.sh` →
  `handoff.sh measure`, `git rm` (`inbox --clear` only), never `git push`/`commit`/`gh`.

## install.sh (1150 lines) - the upgrade contract
- `--upgrade [--check] [--constitution replace]`. A plain upgrade never writes the constitution:
  `print_migrate_hint` :373 prints the size difference and the replace command.
  `replace_constitution` :395 renders the release's `CLAUDE.md` with the hive's `VULYK:PROFILE` and
  `VULYK:COMMANDS` block bodies (`render_constitution` :312), keeps the old file as
  `<name>.pre-<major.minor>.md` (`constitution_backup` :337), refuses a file without the markers.
- Retired framework files (in the old manifest, gone from the release) are removed unless edited
  since the previous version shipped them (`retired_edited` :918) - `council-sonnet.md`,
  `session-end-learnings.sh` in 0.18. `unwire_hook` :739 drops `anomaly-scan.sh` from `Stop` and the
  learnings hook from `SessionEnd` (only if that file went).
- `ensure_gitignore` :843 adds `.vulyk/`, `.claude/worktrees/`, `PAUSE`, `DRIVER` and others;
  `clean_seeded_council` :964; `memory/stats/{council,anomalies}.jsonl` never ship.

## Gotchas
- `close-story`'s `## Commands` cell match, `record-seat`'s taint and `is_paperwork_path`'s
  anchoring are security-relevant string matches: keep them anchored.
- `close-story`'s timeout wrapper probes `timeout 5 true` first: on Windows a PATH `timeout` can
  be the cmd.exe one; without a working GNU `timeout` verification runs unbounded.
- `state.sh` output is derived; `cycle.sh` never reads it.
- `release` is not PAUSE-guarded, so a dead driver's `DRIVER` stamp can always be cleared.
- `telemetry/` (the inbox) is VULYK-repo-only; `copy_tree` never ships it.

last-verified: 2026-09-27 (v0.18.0, ADR-013)
