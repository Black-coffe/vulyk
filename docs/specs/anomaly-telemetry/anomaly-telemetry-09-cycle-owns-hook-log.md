---
story: anomaly-telemetry-09
spec: anomaly-telemetry
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 6
blocked_by: [anomaly-telemetry-02, anomaly-telemetry-05]
---

# Fix (council round 2, review Major 7): a cycle verb owns the hook-written log; the gates stop refusing it

## Goal
`anomaly-scan.sh` writes `memory/stats/anomalies.jsonl` on every `Stop`, and nothing in the cycle commits it: `open-round` waves it through `is_paperwork_path`, `close-story --commit` adds only story files and `scope.jsonl`, and `ship-check` stage 03 then reports `working tree is not clean` - so the ship gate stays NOT READY until a hand commit that ADR-001 forbids (`1a91924` already is one; round 2 evidenced it again at `07:00:13Z`). After this story the cycle's committing verbs stage the log like the other stats files, `ship-check`'s clean-tree test passes the hook-written stats files through, and `scope-check` no longer counts them as a story's out-of-scope edits (the `out_of_scope:1` on stories 05 and 06 was this file).

## Requirements
> memory/stats/anomalies.jsonl, коммитится: та же полка и та же конвенция, что у council.jsonl и human.jsonl: файл в git, еженедельная команда читает его тем же способом, история аномалий видна в истории репозитория.
> Правильно завернуто в фреймворк VULYK, чтобы не потерялось.

## Files
- scripts/cycle.sh
- scripts/ship-check.sh
- scripts/scope-check.sh
- tests/cycle.test.sh

## Non-goals
- Do not widen `is_paperwork_path` or its `docs/specs/*/` anchoring (memory/map/scripts.md Gotchas: security-relevant string match); the log is already on its whitelist (story 01). Use it, do not edit `lib.sh`.
- Do not make `ship-check` ignore arbitrary dirty paths: only paths that pass `is_paperwork_path` under `memory/stats/` are passed through, and they are named in the stage-03 report line, not hidden.
- Do not touch `scripts/telemetry.sh`, the hook, `tests/telemetry.test.sh` (story 08 holds them this wave), `install.sh`, `vulyk-cycle.js`, `journal.sh`.
- Do not add a new verb or a scheduler: the log rides in the commits that already exist (`close-story --commit`, `open-round --commit`, `judge --commit`, `escalate --commit`, `briefed`/`branch --commit`).
- Do not rewrite `scope-check`'s diff logic; one exclusion for the two hook-written stats files (`memory/stats/anomalies.jsonl`, `memory/stats/skills.json`) when a story does not name them.

## Map slice
memory/map/cycle.md "Files, one writer each", "`cycle.sh` verbs", "Tests"; memory/map/scripts.md "Key types / contracts" (`is_paperwork_path`, gates always exit 0) and "Gotchas"; plan.md `## Contracts` (local row, "Hook-written log ownership") and Plan deltas 2026-09-15 round 3; `council/round-2/review.md` findings 7 and 11; ADR-001 (paperwork commits only via `cycle.sh --commit`).

## Acceptance criteria
- [ ] Every `cycle.sh` verb that commits with `--commit` also stages `memory/stats/anomalies.jsonl` when `git status --porcelain` shows it modified or untracked, in the same commit; a verb without `--commit` stages nothing new. Suite: a scratch repo where the log has an uncommitted row, `close-story --commit` leaves `git status --porcelain` empty for that path and the commit touches it.
- [ ] `ship-check` stage 03: a dirty tree whose only dirty paths pass `is_paperwork_path` and live under `memory/stats/` is reported `clean (hook-written stats pending: <paths>)` and does not block stage 03; any other dirty path still reports `working tree is not clean`. Suite: both cases, in the same scratch repo, via a case added to `tests/cycle.test.sh` (there is no separate ship-check suite - say so in the case name).
- [ ] `scope-check` excludes `memory/stats/anomalies.jsonl` and `memory/stats/skills.json` from `out_of_scope` unless the story's `## Files` names them; the `scope.jsonl` row is otherwise unchanged. Suite: a story with one named file and the log dirty records `out_of_scope` `[]`.
- [ ] `bash tests/cycle.test.sh` green; the existing cases (`close-story` whitelist, `open-round` paperwork test, gate exit codes) are unchanged.

## Verification
`bash tests/cycle.test.sh`

## Implementation notes
- `commit_paperwork()` (scripts/cycle.sh) now appends `memory/stats/anomalies.jsonl` to its path set whenever the file exists on disk, so every `--commit`'d verb (judge/escalate/briefed/branch/open-round/reopen) stages it in the same commit; `close-story --commit`'s own manual `git add` block (it doesn't call `commit_paperwork`) got the same one-line addition next to its `scope.jsonl` staging.
- Guard: `git add -A -- <existing> <missing>` fails the *whole* pathspec (exit 128, nothing staged) when one path doesn't exist yet - a spec whose Stop hook never fired has no `anomalies.jsonl` at all. Fixed by only appending the path when `[ -e memory/stats/anomalies.jsonl ]`; added a regression case for it (`tests/cycle.test.sh`, "commit_paperwork: a verb still commits cleanly when memory/stats/anomalies.jsonl does not exist on disk yet").
- `ship-check.sh` stage 03: a dirty tree is now walked line by line (`git status --porcelain`); if every dirty path is under `memory/stats/` and passes `is_paperwork_path`, stage 03 reports `ok ... clean (hook-written stats pending: <paths>)` instead of failing; any other dirty path still fails with the original message.
- `scope-check.sh`: after the existing story-file exclusion, drops `memory/stats/anomalies.jsonl` and `memory/stats/skills.json` from `CHANGED` unless the story's own `## Files` names one of them, so they never count toward `out_of_scope`.
- Did not touch `scripts/lib.sh` or widen `is_paperwork_path` (already had `memory/stats/anomalies.jsonl` from story 01).
- Added 3 new cases to `tests/cycle.test.sh` (own new "hooklog" scratch spec, copying `cycle.sh`/`journal.sh`/`scope-check.sh` and a minimal `## Commands` cell): close-story --commit stages the log; the no-log-on-disk regression above; ship-check stage 03 hook-only-dirty passes, hook+real-dirt still blocks.

## Findings
