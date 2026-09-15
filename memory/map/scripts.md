# Scout report: scripts/

## Purpose
Every deterministic (model-free) gate and helper VULYK's cycle runs on. Three families: the
council's state machine (`cycle.sh` + `lib.sh` + `journal.sh`, v0.12.0), the older report-only
gates beside it (`ship-check.sh`, `human-check.sh`, `acceptance-log.sh`, `scope-check.sh`,
`wave-check.sh`, `trace-check.sh`, `release-check.sh`), and `telemetry.sh` (v0.14.0, opt-in
anomaly telemetry, full contract in `docs/telemetry.md`). All are `#!/usr/bin/env bash`,
`set -u`, safe to re-run.

## Entry points
- `cycle.sh <verb> <spec-dir> [...]` - the council's own CLI (below). Called by `cycle-clerk`
  (Workflow driver) and directly by `/vulyk-build`, `/vulyk-review`, `/vulyk-plan`,
  `/vulyk-pause`, `/vulyk-resume` (fallback driver / on-demand round).
- `journal.sh <spec-dir> <stage> "<what>" "<next>"` - appends+prints one line to
  `<spec-dir>/journal.md`; called by `cycle.sh` itself and by `/vulyk-build` step 1 (the
  "tree is not yours" line) and `/vulyk-plan` step 9 (the approval path, the default).
- `lib.sh` - sourced only, never run (`. "$(dirname "$0")/lib.sh"`); no `exit` in it.
  Consumed by `cycle.sh`, `ship-check.sh`, `human-check.sh`, `acceptance-log.sh`,
  `release-check.sh`.
- `ship-check.sh <spec-dir>` / `--record <spec-dir> <version> [note]` - stage 06 gate, run by
  `/vulyk-ship` step 1 and 4.
- `human-check.sh <spec-dir> <ACCEPTED|REJECTED> [note]` / `--check <spec-dir>` - the owner's
  override record; not in any command file's auto-path, run by the Queen after the owner
  answers, or by `/vulyk-ship`'s STALE-check narrative.
- `acceptance-log.sh <spec-dir> <ACCEPTED|REJECTED|CANNOT_RUN> [note]` / `--check` - **legacy**:
  the pre-council stage-04 ledger (`drone-acceptance`, removed this release). `judge` never
  calls it; `ship-check.sh` falls back to it only for specs with no `council.jsonl` row.
- `scope-check.sh <story-file> [git-diff-range]` - called by `cycle.sh cmd_close_story`
  (always, not optional).
- `wave-check.sh <spec-dir>` - called by `/vulyk-plan` step 7, `/vulyk-build`'s `build:<wave>`
  action (pre-dispatch), and after every repair round.
- `trace-check.sh <spec-dir>` - called by `/vulyk-plan` step 7 and after a plan delta.
- `release-check.sh [target-count]` - standalone meter for the 1.0.0 bar; no caller in
  `.claude/`, run by hand.
- `top-model.sh` / `--explain` / `--apply` / `--check` - resolves `fable`|`opus` from
  `~/.claude.json` `oauthAccount`; `--apply` pins `.claude/settings.local.json`. Called by
  `/vulyk-bootstrap` (unconditional `--apply` now, v0.12.0), `/vulyk-build`, `/vulyk-review`,
  `/vulyk-status`, `.claude/hooks/top-model-brief.sh` (SessionStart).
- `redact.sh` - stdin->stdout secret mask; wired into `session-end-learnings.sh` and
  `handoff.py`, and into `/vulyk-plan` step 2 before a brief is written.
- `state.sh [spec-dir]` - writes gitignored `.claude/state.json` (derived story-status view).
  Read by `/vulyk-status`; never by `cycle.sh` (which derives its own story counts).
- `vulyk-update.sh [dir] [--check] [--version X]` - upgrade installer wrapper, `set -euo
  pipefail`; hands off to a fetched release's own `install.sh --upgrade`. Run by hand /
  the update-check hook's prompt.
- `git-hooks/post-merge` (sample, not auto-installed) - stamps `memory/map/.stale` after a
  merge; `/vulyk-status` step 4 checks for it.
- `telemetry.sh <verb>` (v0.14.0) - `enum` (the 8 codes) / `agents` (the fixed agent-token set,
  `other` catch-all) / `consent` (reads the `CLAUDE.md` Profile `Telemetry` row, first token
  only, default `off`) / `record <code> <value> <threshold> [--spec][--story][--ref][--model]
  [--tier][--agent]` (appends a 12-key row to `memory/stats/anomalies.jsonl`, deduped on
  `(code,ref)`) / `scan [--transcript <path>] [--final]` (runs the five detectors below; `--final`
  = SessionEnd, gates `agent_empty`) / `bundle [--week YYYY-Www] [--out <file>]` (local rows ->
  10-key bundle rows, no `ts`/`spec`/`story`/`ref`; no `--week` = previous+current ISO week) /
  `check <file>...` (the schema+anonymization gate, always exit reflects pass/fail unlike the
  other gates) / `publish [--week][--dry-run]` (never sends - writes/`check`s a bundle then
  PRINTS a copy recipe; local-checkout copy+commit recipe or fork-and-PR recipe, decided by
  `local_vulyk_repo()`) / `inbox [--clear]` (VULYK-repo-only: `check`s every
  `telemetry/inbox/<week>/<hive>.jsonl`, prints `<week> <code> <rows> <hives>` counts,
  `--clear` **stages** `git rm` of emptied week dirs - never commits). Called by
  `.claude/hooks/anomaly-scan.sh` (`scan`), `/vulyk-build`/`/vulyk-resume` (`record
  driver_refused`/`driver_relaunched`), `/vulyk-evolve` (`inbox`, the 7-day check-in), and by
  hand (`publish`).

## Key types / contracts (telemetry.sh)
- Two schemas (`docs/telemetry.md`): the **local row**, 12 keys incl. `ts/spec/story/ref`,
  committed to `memory/stats/anomalies.jsonl`; the **bundle row**, 10 keys, codes and numbers
  only. `check`'s anonymization guard runs first: any string value matching `[/\\@]` or
  whitespace fails the row, before any shape check.
- The five detectors `scan` runs: `detect_context` (main-thread tokens vs
  `VULYK_ANOMALY_CONTEXT_PCT`/`_TOKENS`, via `handoff.sh measure`), `detect_agents`
  (`agent_prefix_high`/`agent_empty` from each `agent-*.jsonl`, cached in the gitignored
  per-session seen-list `.vulyk/telemetry/seen/<sid>` keyed by basename+byte-size so an
  unchanged subagent file is never re-measured), `detect_council` (max round per spec in
  `council.jsonl`), `detect_stage` (gap between consecutive `journal.md` lines, one awk pass, no
  `date` spawn per line), `detect_scope` (`scope.jsonl` rows with non-zero `out_of_scope`, one
  row per story). `SCAN_SEEN` (loaded once per `scan` from `anomalies.jsonl`) short-circuits
  every detector before it calls `record`.
- The 8-code `ENUM` is a public contract - append-only, never renamed/removed. The `AGENTS`
  token set is fixed in this script (not read from `.claude/agents/`) so an owner-added agent
  never becomes free text in a bundle; anything unrecognized folds to `other`. `MODELS` = the
  four cascade rungs.

## Key types / contracts
- Every `cycle.sh` verb's **last stdout line**, on every exit code, is one JSON object
  `{"ok":bool,"verb":"...","exit":N,"next":"...","error":"..."}` (`emit()`, line 55) - no
  driver ever parses prose. `status --json` prints only that object (the full status object,
  see `cycle.md`). `record-seat`'s `--file <path>` (v0.13.1) takes precedence over stdin; a
  missing/unreadable/empty file is checked before anything is written and emits
  `error: "file: <path>"` at exit 2 (both drivers fall back to the stdin heredoc on that exit).
- Exit codes (`cycle.sh`): 0 ok (RED verdict from `judge` is ok:true too) - 1 usage -
  2 precondition (stderr names it) - 3 paused - 4 `record-seat` MALFORMED / `close-story` red
  verification only - 5 stale - 6 escalate.
- The other gates (`ship-check.sh`, `human-check.sh`, `acceptance-log.sh`, `release-check.sh`,
  `state.sh`, `trace-check.sh`, `wave-check.sh`, `redact.sh`) always `exit 0` - they report,
  they never block; refusal is the calling command's job. `telemetry.sh check` is the one
  verb outside `cycle.sh` whose exit code carries meaning (non-zero on any row that fails the
  schema/anonymization gate) - every other `telemetry.sh` verb is fail-open (`scan` exits 0
  with no `jq` or no `--transcript`; `publish` exits 0 on consent `off`).
- `lib.sh` exports: `pack_fingerprint <spec-dir>` (sha256 of sorted story-file basenames,
  12 hex chars), `is_paperwork_path <repo-relative-path>` (the one whitelist: `plan.md`,
  `journal.md`, `council/*`, `brief.md` under `docs/specs/*/`, plus **six**
  `memory/stats/*.jsonl` files - `human`, `acceptance`, `ship`, `council`, `scope`, and
  `anomalies` (v0.14.0, joined the set because `telemetry.sh record` writes it)),
  `paperwork_only <root> <from> <to>`, `marker <plan.md>
  <Name>` (a `**Name:**` line's value, empty if placeholder `<...>`), `now_ts`, `slug_of`.

## Dependencies
- inbound: `cycle-clerk` agent (Bash, the Workflow driver's only shell access);
  `/vulyk-build`, `/vulyk-plan`, `/vulyk-review`, `/vulyk-ship`, `/vulyk-pause`,
  `/vulyk-resume`, `/vulyk-status`, `/vulyk-bootstrap` command files; `.claude/hooks/
  top-model-brief.sh` (SessionStart).
- outbound: `cycle.sh` shells to `git` (worktree add/remove/prune, rev-parse, status,
  diff, commit), sources `lib.sh`, execs `journal.sh` and `scope-check.sh`; reads/writes
  `memory/stats/council.jsonl`, `memory/stats/human.jsonl` (read-only override check),
  `docs/specs/<slug>/{plan.md,brief.md,journal.md,PAUSE,council/}`.
- `telemetry.sh` inbound: `.claude/hooks/anomaly-scan.sh` (Stop+SessionEnd hooks, `scan`,
  fail-open/silent); `/vulyk-build` and `/vulyk-resume` command files (`record
  driver_refused`/`driver_relaunched`); `/vulyk-evolve` (`inbox`, its 7-day check-in);
  `install.sh` (writes/reads the `CLAUDE.md` Profile `Telemetry` row `cmd_consent` reads, wires
  the hook via `wire_hook`). `telemetry.sh` itself shells to `handoff.sh measure` (context/
  agent-prefix token counts, fails open), `git rm` (`inbox --clear` only), reads
  `memory/stats/{council,scope}.jsonl` and `docs/specs/*/journal.md` for its detectors, and
  never shells to `git push`/`git commit`/`gh` anywhere in the file.

## Gotchas
- `record-seat`'s taint/MALFORMED checks, `close-story`'s verification-command whitelist
  (must equal a literal cell of the root `CLAUDE.md` `## Commands` table, or the exact string
  `none — reviewed by lead-review`), and `is_paperwork_path`'s anchoring to `docs/specs/*/`
  are all security-relevant string matches - a change to any one must stay anchored the same
  way or the whitelist silently widens.
- `acceptance-log.sh` and `drone-acceptance` are **not the same generation** as the council:
  the agent is gone, the script is kept only as `ship-check.sh`'s fallback for specs recorded
  before v0.12.0. Do not route new specs through it.
- `state.sh` and `.claude/state.json` are gitignored and derived - never read as truth by
  `cycle.sh` (which recomputes story counts itself from frontmatter on every `status` call).
- `cmd_release` (`release <spec> <stamp>`) is **not** `pause_guard`-ed (v0.13.1, ADR-001 D2's
  exempt list is `status`, `pause`, `resume`, `release`) - it must clear a dead driver's
  `DRIVER` semaphore even while the spec is paused; exit 2 only if a different stamp holds it.
- `telemetry.sh`'s `ENUM` and `AGENTS` sets are append-only public contracts: a code is never
  renamed/removed (older hives' bundles must still validate), and `AGENTS` is a **fixed list in
  this script**, not derived from `.claude/agents/` - an owner-added agent under that directory
  is legal on the hive side but reported as `other` here; `tests/telemetry.test.sh` guards the
  list against drift from the real roster.
- `telemetry.sh publish` and `bundle` never send anything themselves - `publish` at most copies
  a checked bundle into a local checkout's `telemetry/inbox/` and prints a recipe; no `git
  push`/`git commit`/`gh` call exists in the file, by design not by flag (file header comment).
- `telemetry/` (the inbox) is VULYK-repo-only - `install.sh`'s `copy_tree` does not walk it, so
  a hive's own history lives only in its `memory/stats/anomalies.jsonl`.

last-verified: 2026-09-15
