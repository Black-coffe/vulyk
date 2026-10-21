---
story: court-setup-01
spec: court-setup
status: todo
returned:
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

## Findings
