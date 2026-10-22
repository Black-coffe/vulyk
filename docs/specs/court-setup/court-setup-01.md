---
story: court-setup-01
spec: court-setup
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
---

# The court runs the hive's setup before a round opens

## Goal
`build_court` runs `$ROOT/.claude/vulyk-setup`, when present, inside the new court after the reduction commit, with `VULYK_ROOT` and `VULYK_COURT` set and a 300-second cap (`VULYK_SETUP_TIMEOUT`). Output goes to `.vulyk/reports/<slug>/round-<n>/setup.log`. A non-zero exit or a timeout removes the court and the empty round directory, prints the log's last 20 lines to stderr, and emits `open-round` exit 2 with "court setup failed (exit N)" or "court setup timed out after Ns". Without the file, nothing changes.

## Requirements
> 1. Если в улье есть .claude/vulyk-setup, он запускается в копии для совета перед раундом.
> 2. Ошибка или превышение 5 минут: раунд не открывается, копия удаляется, виден хвост лога.

## Files
- scripts/cycle.sh
- tests/council.test.sh
- docs/cycle.md

## Non-goals
- No change to which tiers build a court, to seat dispatch, or to N/A counting.
- No re-commit of the court after setup and no copying of `.env` or other untracked files: that is the hive script's call.
- No setup for the reviewer, who never enters the court.

## Map slice
memory/map: the cycle.sh slice, `open-round` / `build_court`.

## Acceptance criteria
- [ ] With a setup script that writes a marker into `$VULYK_COURT` and exits 0, `open-round` opens the round, and the marker exists in the court.
- [ ] With a setup script that exits 3, `open-round` exits 2 naming "exit 3", no `ROUND` file and no court directory remain, and the log tail is on stderr.
- [ ] With `VULYK_SETUP_TIMEOUT=2` and a script that sleeps 10 s, `open-round` exits 2 naming the timeout, and the court is removed.
- [ ] Without the file, the existing open-round tests pass unchanged.

## Verification
`bash tests/council.test.sh`

## Implementation notes
- `scripts/cycle.sh`: new `run_court_setup`, called last in `build_court` (after the reduction commit). Reads `$ROOT/.claude/vulyk-setup` from the working copy, runs `bash <file>` with cwd = the court, stdin `/dev/null`, `VULYK_ROOT`/`VULYK_COURT` set, output to `$ROOT/.vulyk/reports/<slug>/round-<n>/setup.log`. Cap: `VULYK_SETUP_TIMEOUT` (default 300, non-numeric or 0 falls back to 300), the same `timeout 5 true` probe as close-story; without a working `timeout` it runs uncapped and says so on stderr. On non-zero/124: log tail (20 lines) on stderr, court removed (`remove_worktree_path` is `--force`, so untracked `node_modules` do not block it), empty round dir removed, `emit false open-round 2 error "court setup failed (exit N)" | "court setup timed out after Ns"`.
- `tests/council.test.sh`: three cases after the worktree-failure block, outside the `--quick` skip (success with marker + log, exit 3, 2 s timeout on a 10 s sleep). The cwd check uses a relative marker file: on Windows `$PWD` is an MSYS path and `VULYK_COURT` a `C:/` one.
- `docs/cycle.md`: one passage in the stage 05 paragraph.
- Rejected: re-running setup on an in-place re-stamp only when the head moved - `build_round` always rebuilds the court, so setup runs with it every time.

## Findings
