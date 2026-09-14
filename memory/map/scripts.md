# Scout report: scripts/

## Purpose
Every deterministic (model-free) gate and helper VULYK's cycle runs on. Two families: the
council's state machine (`cycle.sh` + `lib.sh` + `journal.sh`, v0.12.0) and the older
report-only gates it now sits beside (`ship-check.sh`, `human-check.sh`, `acceptance-log.sh`,
`scope-check.sh`, `wave-check.sh`, `trace-check.sh`, `release-check.sh`). All are
`#!/usr/bin/env bash`, `set -u`, safe to re-run.

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

## Key types / contracts
- Every `cycle.sh` verb's **last stdout line**, on every exit code, is one JSON object
  `{"ok":bool,"verb":"...","exit":N,"next":"...","error":"..."}` (`emit()`, line 55) - no
  driver ever parses prose. `status --json` prints only that object (the full status object,
  see `cycle.md`).
- Exit codes (`cycle.sh`): 0 ok (RED verdict from `judge` is ok:true too) - 1 usage -
  2 precondition (stderr names it) - 3 paused - 4 `record-seat` MALFORMED / `close-story` red
  verification only - 5 stale - 6 escalate.
- The other gates (`ship-check.sh`, `human-check.sh`, `acceptance-log.sh`, `release-check.sh`,
  `state.sh`, `trace-check.sh`, `wave-check.sh`, `redact.sh`) always `exit 0` - they report,
  they never block; refusal is the calling command's job.
- `lib.sh` exports: `pack_fingerprint <spec-dir>` (sha256 of sorted story-file basenames,
  12 hex chars), `is_paperwork_path <repo-relative-path>` (the one whitelist: `plan.md`,
  `journal.md`, `council/*`, `brief.md` under `docs/specs/*/`, plus the five
  `memory/stats/*.jsonl` files), `paperwork_only <root> <from> <to>`, `marker <plan.md>
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

last-verified: 2026-09-13
