---
story: autonomous-cycle-07
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 2
blocked_by: [autonomous-cycle-01]
---

# Installer and session brief: ship the workflow, allow the clerk's commands, pin the session, report the driver gate

## Goal
`install.sh` upgrades `.claude/workflows` like the other framework-owned trees, adds the two `Bash(...)` allow rules the clerk needs, pins the Queen session with `top-model.sh --apply`, and ignores the cycle's runtime files in the target hive; VULYK's own `.gitignore` does the same; the SessionStart brief tells the owner whether the Workflow driver's CLI gate is met.

## Requirements
> Оставить auto, сделать пин сессии обязательным. Политика не меняется: Fable везде, где он в плане, Opus где биллится кредитами. Сессия-королева больше не «не запинена по умолчанию» — install.sh/bootstrap сами делают --apply, SessionStart-бриф ругается, если сессия идёт не на топ-модели.

> Где Workflow недоступен — сегодняшняя петля в сессии, но через те же скрипты.

> Все «Принять» из таблицы входят в бриф: скрипт судит раунды, worktree-слепота, ## Asks, PAUSE, Briefed:, N/A, пороги.

## Files
- install.sh
- .gitignore
- .claude/hooks/top-model-brief.sh

## Non-goals
- Do not write `.claude/workflows/vulyk-cycle.js` (story 06) - only make the tree `OWNED`.
- Do not rewrite `.claude/settings.json` wholesale or add a `permissions` block to VULYK's own settings file; the allow rules go into the **target** hive's `settings.json` through a surgical helper shaped like `wire_session_hook` (`install.sh:144`), idempotent, Python-guarded with the same manual-instructions fallback.
- Do not change `TOP_MODEL = auto` semantics or `scripts/top-model.sh`; `--apply` is called, not modified.
- Do not try to detect the Pro `/config` Workflow flag from a hook - it is not visible; report the CLI version gate only.
- Do not touch `scripts/vulyk-update.sh` or the CI `install-smoke` job.

## Map slice
`docs/specs/autonomous-cycle/recon/scout-install.md` all sections (`OWNED` at `install.sh:34`, `wire_session_hook` at `:144`, `ensure_gitignore` at `:229-231`, version stamp at `:327-331`, `top-model-brief.sh:36-41` "NOT pinned" clause, `.gitignore` contents) · `docs/adr/001-cycle-state-contract.md` D2 "The Workflow driver" paragraph (the exact two allow rules), Consequences "Migration" bullet · `docs/specs/autonomous-cycle/plan.md` `## Assumptions` (driver mode detection) and `## Contracts` C12.

## Acceptance criteria
- [ ] `OWNED` in `install.sh` includes `.claude/workflows`; `--upgrade` replaces a changed `vulyk-cycle.js` in the target.
- [ ] A new helper adds `Bash(bash scripts/cycle.sh:*)` and `Bash(bash scripts/journal.sh:*)` to `permissions.allow` in the target's `.claude/settings.json` if absent, preserving every other key; running install twice adds nothing twice; without Python it prints the two lines to add and exits the helper 0.
- [ ] After the copy loop and version stamp, `install.sh` runs `bash "$DEST/scripts/top-model.sh" --apply` (skipped under `--check`/dry-run and when the resolver reports "already pinned"); its failure (no Python, unparsable file) is printed and does not fail the install.
- [ ] `ensure_gitignore`'s wanted list gains `.vulyk/` and `docs/specs/*/PAUSE`; VULYK's own `.gitignore` gains the same two lines.
- [ ] `top-model-brief.sh` appends one clause to its single `[VULYK]` line: `Workflow driver: CLI <ver> >= 2.1.154 - enable in /config on Pro` or `Workflow driver: unavailable (CLI <ver> < 2.1.154, fallback loop in session)` or `Workflow driver: CLI version unknown` when `claude --version` is absent; still one line, still exit 0, still fail-open.
- [ ] The existing "Queen session NOT pinned" clause is unchanged in wording.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
